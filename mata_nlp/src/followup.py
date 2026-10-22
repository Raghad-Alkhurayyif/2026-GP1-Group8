"""
FOLLOW-UP QUESTIONS - decide whether to ask, and what to put in front of the
person when asking.

WHY THIS EXISTS, in numbers measured on this project's own dataset
(experiments/ has the scripts). Accuracy against how many symptoms the person
mentioned, at the level the app actually acts on - which clinic:

    1 symptom    30%        2 symptoms   64%
    3 symptoms   83%        4 symptoms   91%        all (mean 5.3)   95%

And emergency recall, which is the number that sets the rule:

    1 symptom    12%  (30% with the red-flag override)
    2 symptoms   45%  (68%)
    3 symptoms   75%  (88%)

At one symptom, seven out of ten true emergencies are missed even with the
override. So a one-symptom complaint must not produce a decision. It must
produce a question.

TWO FINDINGS THAT SHAPED THIS FILE, both of which contradicted what I expected:

1. A yes/no question is a weak instrument. Asking the single most informative
   yes/no question moved clinic accuracy 64% -> 66%, and a budget of eight
   questions saturated at 67%. One more VOLUNTEERED symptom moved it to 83%.
   The reason is arithmetic: a well-chosen yes/no question still gets "no" 75%
   of the time, and "no" tells a model that already assumes everything
   unmentioned is absent almost nothing.

   So the follow-up is an OPEN question - "what else are you feeling?" - with a
   few chips beside it, not an interrogation.

2. The chips should be scored by DISAGREEMENT, not by likelihood. Four chips
   chosen as "what is this person most likely to also have" got more taps
   (33% vs 24%) and produced WORSE decisions (clinic 69% vs 74%), because the
   symptoms every candidate disease shares do not narrow anything. Chips chosen
   as "what do the candidates disagree about" get fewer taps and each tap
   splits the candidate set.

   Which is convenient: the same scoring rule serves the chips and the question,
   so there is only one mechanism here.

   Measured, from a two-symptom opening, four disagreement-scored chips:
       clinic 64% -> 74%,  emergency recall 48% -> 62%

HOW IT WORKS

One table: P(symptom | disease), 754 x 327, counted straight off the training
set. It does not depend on which model is trained, so Khadijah can change
models freely. Then, per request:

    probs  -> top 20 candidate diseases
           -> weight each by its posterior
           -> for each symptom, the weighted variance of P(symptom | disease)
           -> the four highest, excluding anything already said

That is the whole algorithm. No second model, no extra dataset.

REBUILD THE TABLE FROM THE TRAINING SPLIT, not the whole file. The shipped
table is built from everything, which is fine for a demo and wrong for a
reported number.

Owner: Aljoury.
"""

import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

DATA = Path(__file__).resolve().parent.parent / "data"

N_CANDIDATES = 20        # how many diseases stay "in play"
N_HINTS = 4              # chips on the screen
ASK_BELOW = 0.50         # top-1 posterior under this -> ask instead of answer

# RED FLAGS AS CHIPS - Aljoury's decision, 13 Oct.
#
# An earlier version of this file excluded every red-flag column from the chips
# on the grounds that suggesting a serious symptom to a worried person invites a
# false yes. That was wrong, and the reason it was wrong is the whole point of
# the scoring rule: chips are chosen by what the surviving candidate diseases
# DISAGREE about, not by what is likely or what is alarming. A red flag only
# reaches the list when answering it genuinely splits the candidates - which is
# exactly when it is the most useful question anyone could ask. Withholding it
# then makes the system worse at the only job that matters.
#
# What this still does NOT do, and must not:
#   * offer a red flag because it is COMMON. Prevalence scoring would do that;
#     disagreement scoring does not, and this was measured - see the module
#     docstring and experiments/hints.py.
#   * offer anything on thin evidence. A chip needs a positive disagreement
#     score, so a symptom every candidate agrees about never appears.
#
# Each hint reports whether it is a red flag so the interface can present it in
# the same neutral way as the others rather than with alarm.


# --------------------------------------------------------------- build the table
def build_theta(dataset_csv, out=None, train_index=None):
    """
    Count P(symptom | disease) off the dataset and save it.

    `train_index` is an optional boolean mask or index array selecting the
    TRAINING rows. Pass it. Building from every row leaks the test set into the
    questions the app asks.
    """
    import numpy as np
    import pandas as pd

    keep = []
    with open(DATA / "vocabulary.csv", newline="", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            if r["keep"] == "1" and r["alive"] == "1":
                keep.append(r["column"])

    head = pd.read_csv(dataset_csv, nrows=0)
    use = [c for c in head.columns if c in set(keep)]
    df = pd.read_csv(dataset_csv, usecols=["diseases", *use],
                     dtype=dict.fromkeys(use, "int8"))
    if train_index is not None:
        df = df.iloc[train_index]

    dis = df["diseases"].astype("category")
    codes = dis.cat.codes.to_numpy()
    names = list(dis.cat.categories)
    X = df[use].to_numpy(dtype=np.float32)

    theta = np.zeros((len(names), len(use)), dtype=np.float32)
    for c in range(len(names)):
        rows = X[codes == c]
        if len(rows):
            theta[c] = rows.mean(0)

    out = Path(out or DATA / "symptom_given_disease.npz")
    np.savez_compressed(out, theta=theta.astype(np.float16),
                        diseases=np.array(names), columns=np.array(use))
    print(f"wrote {out}  ({theta.shape[0]} diseases x {theta.shape[1]} symptoms, "
          f"{out.stat().st_size / 1024:.0f} KB)")
    if train_index is None:
        print("  NOTE: built from EVERY row. Rebuild with train_index= before "
              "reporting any number from it.")
    return out


# ------------------------------------------------------------------- use it
class FollowUp:
    """
    ask, hints = FollowUp().next_step(probs, known_columns)

    `probs` is the model's probability over diseases, in the same disease order
    as the table. `known_columns` is every column already settled - mentioned,
    confirmed, denied - so none of them is offered again.
    """

    def __init__(self, table=None, labels=None):
        import numpy as np
        self.np = np
        path = Path(table or DATA / "symptom_given_disease.npz")
        if not path.exists():
            raise FileNotFoundError(
                f"{path} not found. Build it once:\n"
                f"    python3 src/followup.py build <dataset.csv>")
        z = np.load(path, allow_pickle=False)
        self.theta = z["theta"].astype(np.float32)
        self.diseases = [str(d) for d in z["diseases"]]
        self.columns = [str(c) for c in z["columns"]]
        self.index = {c: i for i, c in enumerate(self.columns)}

        # The one canonical escalation list, read from the vocabulary rather
        # than hand-written here. See src/add_red_flags.py.
        #
        # The age ranges are read in the same pass, and for the same reason:
        # Layer 1 removes a symptom that cannot apply at the patient's age,
        # and this selection had no idea the rule existed. Offering an
        # impossible symptom is not merely a wasted question - `irritable
        # infant` is ages 0 to 3 AND an URGENT_24H red flag, so an
        # eleven-year-old could be offered it, tap it, and have the urgency
        # level raised on a symptom that cannot apply to them. Thirteen of the
        # 327 columns carry a range and three of those are red flags.
        self.red_flags = {}
        self.age_range = {}
        try:
            with open(DATA / "vocabulary.csv", newline="",
                      encoding="utf-8-sig") as f:
                for r in csv.DictReader(f):
                    if r.get("red_flag"):
                        self.red_flags[r["column"]] = r["red_flag"]
                    lo = r.get("age_min") or ""
                    hi = r.get("age_max") or ""
                    if lo.strip() or hi.strip():
                        self.age_range[r["column"]] = (
                            int(lo) if lo.strip() else None,
                            int(hi) if hi.strip() else None)
        except Exception:
            pass

        if labels is None:
            try:
                from vocab_utils import load_display_labels
                labels = load_display_labels()
            except Exception:
                labels = {}
        self.labels = labels

    def label(self, column):
        return self.labels.get(column, column)

    def applies_at(self, column, age):
        """
        Can this column apply at this age? True when the age is unknown.

        An unknown age must not silently suppress candidates: the rules are
        there to stop an impossible symptom being offered, not to narrow the
        question whenever the age has not been asked for yet.
        """
        if age is None:
            return True
        lo, hi = self.age_range.get(column, (None, None))
        if lo is not None and age < lo:
            return False
        if hi is not None and age > hi:
            return False
        return True

    def hints(self, probs, known=(), n=N_HINTS, age=None):
        """The n symptoms the surviving candidates disagree about most."""
        np = self.np
        p = np.asarray(probs, dtype=np.float64).ravel()
        if p.sum() <= 0:
            return []
        p = p / p.sum()

        k = min(N_CANDIDATES, len(p))
        cand = np.argpartition(-p, k - 1)[:k]
        w = p[cand]
        w = w / w.sum()
        th = self.theta[cand]                       # (k, n_symptoms)

        mean = w @ th
        score = w @ (th ** 2) - mean ** 2           # weighted variance

        for c in known:
            if c in self.index:
                score[self.index[c]] = -1.0

        # Age-impossible columns are removed BEFORE the top n is taken, so
        # that dropping one promotes the next real candidate rather than
        # leaving a short list.
        for i, c in enumerate(self.columns):
            if not self.applies_at(c, age):
                score[i] = -1.0

        order = np.argsort(-score)[: max(n, 0)]
        return [{"column": self.columns[i],
                 "display": self.label(self.columns[i]),
                 "expected": round(float(mean[i]), 3),
                 "score": round(float(score[i]), 4),
                 "red_flag": self.red_flags.get(self.columns[i], "")}
                for i in order if score[i] > 0]

    def should_ask(self, probs, threshold=ASK_BELOW):
        """True when the model is not confident enough to answer yet."""
        np = self.np          # numpy is loaded lazily and held on self
        p = np.asarray(probs, dtype=np.float64).ravel()
        return bool(p.size == 0 or p.max() < threshold)

    def next_step(self, probs, known=(), threshold=ASK_BELOW, rounds_done=0,
                  emergency=False, age=None):
        """
        What the app should do next.

        Two rounds at most: the measurements showed questioning saturating
        after about three questions, so a third round buys nothing and costs
        the person's patience.

        `emergency` short-circuits the whole thing. When an EMERGENCY red flag
        has already matched - in the original text or on an asserted symptom -
        the answer is not in doubt and the person needs to be sent to care, so
        asking them "what else are you feeling?" is both useless and unsafe.
        Nothing they add can lower the level, because the urgency engine keeps
        the most urgent level found and never lowers it, so the only effect of
        asking would be delay. This was specified in the component design
        before it existed here, and the design was right.
        """
        np = self.np          # numpy is loaded lazily and held on self
        p = np.asarray(probs, dtype=np.float64).ravel()
        top = int(p.argmax()) if p.size else -1
        if emergency:
            return {
                "action": "escalate",
                "disease": self.diseases[top] if top >= 0 else None,
                "confidence": round(float(p.max()), 3) if p.size else 0.0,
                "hints": [],
                "prompt": None,
                "reason": "an EMERGENCY red flag matched; do not ask further",
            }
        confident = not self.should_ask(p, threshold)
        if confident or rounds_done >= 2:
            return {
                "action": "decide" if confident else "fall_back",
                "disease": self.diseases[top] if top >= 0 else None,
                "confidence": round(float(p.max()), 3) if p.size else 0.0,
                "hints": [],
                "prompt": None,
            }
        return {
            "action": "ask",
            "disease": self.diseases[top] if top >= 0 else None,
            "confidence": round(float(p.max()), 3) if p.size else 0.0,
            "hints": self.hints(p, known, age=age),
            # Open, not closed. This wording is deliberately a memory jog and
            # not a claim about what the person has - see the README note on
            # suggestibility.
            "prompt": "What else are you feeling?",
        }


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "build":
        if len(sys.argv) < 3:
            print("usage: python3 src/followup.py build <dataset.csv>")
            raise SystemExit(1)
        build_theta(sys.argv[2])
        raise SystemExit(0)

    import numpy as np

    fu = FollowUp()
    print(f"table: {len(fu.diseases)} diseases x {len(fu.columns)} symptoms")
    print(f"ask when top-1 confidence < {ASK_BELOW}\n")

    # Stand in for the classifier: put the weight on a few plausible diseases.
    def posterior(*weighted):
        p = np.full(len(fu.diseases), 1e-9)
        for name, mass in weighted:
            hits = [i for i, d in enumerate(fu.diseases) if name in d.lower()]
            for i in hits:
                p[i] = mass / len(hits)
        return p / p.sum()

    cases = [
        ("a chesty, breathless complaint",
         posterior(("asthma", .22), ("pneumonia", .20), ("bronchitis", .18),
                   ("chronic obstructive", .12)),
         ["shortness of breath", "cough"]),
        ("a confident one",
         posterior(("common cold", .93), ("acute sinusitis", .04)),
         ["coryza", "sneezing", "sore throat"]),
        ("a vague abdominal complaint",
         posterior(("gastritis", .14), ("gastroesophageal", .13),
                   ("appendicitis", .11), ("cholecystitis", .10),
                   ("irritable bowel", .10), ("gastroenteritis", .09)),
         ["sharp abdominal pain"]),
    ]
    for title, p, known in cases:
        step = fu.next_step(p, known)
        print(f"{title}")
        print(f"   known      : {known}")
        print(f"   top guess  : {step['disease']}  (confidence {step['confidence']})")
        print(f"   action     : {step['action'].upper()}")
        if step["hints"]:
            print(f"   prompt     : \"{step['prompt']}\"")
            print("   chips      : " + "   ".join(
                f"[ {h['display']} ]" for h in step["hints"]))
            print("                " + ", ".join(
                f"{h['column']} (expected {h['expected']})"
                for h in step["hints"]))
        print()
