"""
The whole NLP component in one call, so the app has one thing to import.

    from pipeline import Pipeline
    p = Pipeline()                      # loads everything once
    out = p.run("my chest feels tight when i walk fast")

Runs Layer 1, then Layer 2, then Layer 3, each taking and returning the same
dict. Layer 3 is still a placeholder and passes the result through.

Layer 2 (SapBERT embeddings over what Layer 1 could not place) is written but
OFF by default, because it needs a 440 MB model download and extraction must
work on a fresh clone with no network:

    p = Pipeline(use_layer2=True)

Calibrate its similarity floor first - see calibrate_layer2.py.

If a classifier is supplied, the follow-up step runs too and the result says
whether to ask or to decide:

    p = Pipeline(model=my_classifier)   # anything with predict_proba
    out = p.run(text)
    out["next_step"]["action"]          # "ask" | "decide" | "fall_back"

Owner: Aljoury.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "src"))

from layer1_lexicon import Layer1
import layer2_embed
import layer3_llm
import subject


class Pipeline:
    @staticmethod
    def load_classifier(path=None):
        """
        The trained disease model, or None if it has not been built yet.

        Never raises: a fresh clone has no classifier.joblib until
        `python3 src/train_classifier.py` has been run, and extraction has to
        work without it.
        """
        path = Path(path or ROOT / "data/classifier.joblib")
        if not path.exists():
            return None
        try:
            from joblib import load
            return load(path)
        except Exception:
            return None

    def __init__(self, data_dir=None, model=None, use_followup=True,
                 use_layer2=False, use_layer3=False):
        self.layer1 = Layer1(data_dir or ROOT / "data")
        self.classifier_columns = None
        if model is None:
            bundle = self.load_classifier()
            if bundle is not None:
                model = bundle["model"]
                # The column ORDER the model was fitted on. Feeding it Layer 1's
                # order without checking would silently scramble every feature
                # if the vocabulary is ever reordered.
                self.classifier_columns = bundle["columns"]
        # Layer 2 is OFF by default and that is deliberate: it is a 440 MB
        # model download, and extraction has to work on a fresh clone with no
        # network. Turn it on explicitly once the threshold is calibrated.
        # It is constructed WITH layer1 so that it shares the same column list
        # and the same context assessor - there is no second copy of either.
        self.layer2 = None
        if use_layer2:
            self.layer2 = layer2_embed.Layer2(self.layer1)
        # Layer 3 costs a network call per request and needs GEMINI_API_KEY.
        # It builds either way and reports itself unavailable without one.
        self.layer3 = layer3_llm.Layer3(self.layer1) if use_layer3 else None
        self.model = model
        self.followup = None
        if use_followup:
            try:
                from followup import FollowUp
                self.followup = FollowUp()
            except Exception as exc:
                # The table has to be built once from the dataset. Not having it
                # is normal on a fresh clone, and must not break extraction.
                self.followup_error = f"{type(exc).__name__}: {exc}"

    def feature_vector(self, result):
        """
        Three states per column, which is what the confidence gate needs:
            1   asserted            (result["symptoms"])
            0   explicitly denied   (result["negated"])
            -1  unknown             everything else
        Pass `1`s and `0`s to a model trained on complete vectors; see
        HANDOFF.md for why unknown must NOT be folded into 0 at inference.
        """
        cols = list(self.layer1.vocab)
        state = dict.fromkeys(cols, -1)
        for s in result["symptoms"]:
            state[s["column"]] = 1
        for n in result["negated"]:
            state.setdefault(n["column"], 0)
            if state[n["column"]] != 1:
                state[n["column"]] = 0
        return cols, [state[c] for c in cols]

    def run(self, text, age=None, known=(), rounds_done=0):
        r = self.layer1.extract(text, age=age)
        if self.layer2 is not None:
            r = self.layer2.extend(r)
        else:
            r = layer2_embed.extend(r)
        if self.layer3 is not None:
            r = self.layer3.extend(r)
        else:
            r = layer3_llm.extend(r)

        if self.model is not None and self.followup is not None:
            cols, state = self.feature_vector(r)
            by_col = dict(zip(cols, state))
            order = self.classifier_columns or cols
            # 1 for asserted, 0 for everything else. With a masked-trained
            # model that is not an approximation: unmentioned and absent were
            # the same thing in training. See src/train_classifier.py.
            x = [[1 if by_col.get(c) == 1 else 0 for c in order]]
            probs = self.model.predict_proba(x)[0]
            settled = set(known) | {s["column"] for s in r["symptoms"]} \
                | {n["column"] for n in r["negated"]}
            # An asserted EMERGENCY red flag stops the questioning outright.
            # See src/followup.py and Algorithm 1 in the design document.
            emergency = any(f.get("level") == "EMERGENCY"
                            for f in r.get("red_flags", []))
            # `age` is passed through so the suggestions cannot include a
            # symptom the patient's age rules out. Layer 1 already removes
            # those from what it extracts; without this the follow-up could
            # offer one back.
            r["next_step"] = self.followup.next_step(
                probs, known=settled, rounds_done=rounds_done,
                emergency=emergency, age=age)
        return r

    def for_subject(self, result, who):
        """
        `result` with only the findings of the person the assessment is for,
        once the user has answered "Are you completing this assessment for
        someone else?". `who` is "self" or "other". See src/subject.py.
        """
        return subject.for_subject(result, who, vocab=self.layer1.vocab)

    def for_age(self, result, age):
        """
        `result` with the age rules applied, once the app knows who the
        assessment is for and how old they are. A symptom whose column only
        applies within an age range that `age` falls outside of (an adult
        with `irritable infant`, an 8-year-old with `vaginal bleeding after
        menopause`) is moved out of `symptoms` and `confirm` into `age_set_aside`
        and recorded in `excluded` as `age_mismatch`. It is never dropped
        silently: the app shows `age_set_aside` so the user can say the
        symptom applies after all.

        Layer 1 can apply the same rule during extraction, but only when the
        age is known before the text is read. In the app it is not: whether
        the assessment is for the user or for someone else is asked after
        extraction, so the age is applied here instead.
        """
        result = dict(result)
        set_aside = list(result.get("age_set_aside", []))
        excluded = list(result.get("excluded", []))

        def ruled_out(column):
            meta = self.layer1.vocab.get(column, {})
            lo, hi = meta.get("age_min"), meta.get("age_max")
            return (lo is not None and age < lo) or (hi is not None and age > hi)

        for field in ("symptoms", "confirm"):
            kept = []
            for s in result.get(field, []):
                if ruled_out(s.get("column", "")):
                    set_aside.append(s)
                    excluded.append({**s, "status": "age_mismatch"})
                else:
                    kept.append(s)
            result[field] = kept

        result["age_set_aside"] = set_aside
        result["excluded"] = excluded
        return result


if __name__ == "__main__":
    p = Pipeline()
    print(f"layer 1 engines: {p.layer1.engines()}")
    print(f"follow-up      : "
          f"{'ready' if p.followup else getattr(p, 'followup_error', 'off')}\n")

    for t in ["my chest feels tight when i walk fast, no cough",
              "my son has a fever and wont eat",
              "I might be getting a cough, or maybe its just constipation?"]:
        r = p.run(t)
        print(f"> {t}")
        print(f"   symptoms : {[s['column'] for s in r['symptoms']]}")
        if r["negated"]:
            print(f"   denied   : {[n['column'] for n in r['negated']]}")
        if r.get("confirm"):
            print(f"   confirm  : {[c['column'] for c in r['confirm']]}")
        if r.get("confirm_subject"):
            print("   whose?   : written about a dependent - confirm with the user")
        print(f"   layers   : {r['layers_run']}\n")
