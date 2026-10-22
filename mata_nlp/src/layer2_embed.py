"""
LAYER 2 - embedding retrieval for the text Layer 1 could not place.

Built from Khadijah's SapBERT notebook. Her model choice, her query rewriting
and her margin-based ambiguity gate are kept. What changed is where the work
happens, and this file exists mainly to say why.

WHAT THE NOTEBOOK DID, AND WHY IT WAS RESTRUCTURED

The notebook was a second complete pipeline. It took raw text, found spans with
GLiNER, judged negation / whose / when with its own 400-line copy of Layer 1's
context engine, matched to columns with SapBERT, and emitted a result dict with
the same keys Layer 1 emits. Two systems, each answering the whole question.

That is a problem for one reason that outweighs every other: the context engine
was DUPLICATED. Running both copies over all 903 test sentences, they agree on
98.4% of findings - so nothing is broken today - but the copy is already built
on a stale contract (80 context rules against our 86, 1,470 lexicon phrases
against our 1,681), and every bug fixed in one copy from now on has to be found
again in the other. The fixes that engine has taken - denial carrying through a
list, retraction needing an empty tail, the modal guard, commas breaking
modifier scope, "since last night" not being history - were each found by a
failing sentence. Finding them twice is not a cost worth paying.

So Layer 2 now does ONE job: take what Layer 1 left in `unmatched`, and try to
place it. It does not re-read the sentence, and it never judges context itself -
it calls the SAME assessor object Layer 1 used, on the same normalized text.
There is no second copy of anything.

WHAT THIS MEANS IN PRACTICE

    r = layer1.extract(text)      # lexicon: exact, synonym, composed, loose
    r = layer2.extend(r)          # embeddings: only r["unmatched"]

Layer 1 is precise and literal. Layer 2 is the fallback for wording nobody put
in the lexicon. Running Layer 2 only on leftovers also makes it cheap: most
sentences leave one or two fragments, not twenty spans.

THE THRESHOLD IS NOT OPTIONAL

The notebook had SIMILARITY_THRESHOLD = None, which means `phrase_status` could
never return "below_threshold" and every span became a candidate bound to its
nearest column however far away that was. Cosine similarity always has a
nearest neighbour; with 327 columns and no floor, "my car broke down" resolves
to a symptom. It also made the reported `coverage` meaningless, since the
denominator counted a bucket that could never fill.

A floor is mandatory here. MIN_SIMILARITY below is a PLACEHOLDER and is marked
as one: it has not been measured, because this workspace cannot download the
model. `calibrate_layer2.py` picks it from the 500-sentence dev half and prints
what each candidate value costs. Run that before anyone quotes a Layer 2 number.

GLINER IS OPTIONAL AND OFF BY DEFAULT

The notebook ran GLiNER (~500 MB) to find spans, plus SapBERT (~440 MB). But
Layer 1 already hands us the leftover fragments, so span detection is mostly
done. GLiNER is kept behind a flag for the case where a leftover fragment holds
a symptom inside a longer run of text. Default off: two 500 MB models on the
critical path of a phone app needs a deliberate decision, not a default.

Owner: Khadijah (model, query rewriting, margins); Aljoury (wiring, contract).
"""

import hashlib
import json
import re
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
CACHE = DATA / "column_embeddings.npz"

DEFAULT_MODEL = "cambridgeltl/SapBERT-from-PubMedBERT-fulltext"

# MEASURED, and the measurement is why Layer 2 is NOT recommended.
#
# On 806 real leftovers from 250 sentences, counting only what extend() would
# actually ADD (a column Layer 1 does not already hold, on a span the context
# engine does not mark denied, historical, somebody else's or uncertain):
#
#   threshold   raw   NEW   noise
#     0.60      200    81     0
#     0.65      128    40     0
#     0.70       68    10     0
#     0.75       24     2     0
#     0.78       12     0     0
#
# The counts are not the problem. READING the NEW findings is. Of the twenty
# highest-scoring, four were right. The rest included:
#
#   "i have a dry cough ..."              -> coughing up sputum   (the opposite)
#   "a tight feeling in my chest ..."     -> throat feels tight   (wrong part)
#   "even after sleeping ..."             -> insomnia             (that is fatigue)
#   "i am pregnant and have a pounding headache" -> pain during pregnancy
#   "coughing up ... streaks of blood"    -> coughing up sputum   (that is hemoptysis)
#   "numbness between my legs ..."        -> leg weakness         (not stated)
#
# In every one of those Layer 1 had already recorded the correct column, and
# Layer 2 would have added a wrong one beside it - a 1 in the feature vector
# for a symptom the person never described. That is worse than silence, and no
# threshold fixes it: at 0.75 only 2 findings survive at all.
#
# So Layer 2 stays OFF by default. MIN_SIMILARITY is set to 0.75 rather than to
# the lowest clean value, as a do-no-harm floor for anyone who enables it.
MIN_SIMILARITY = 0.75
#

# Top-1 must beat top-2 by this much, or the match is offered as a question
# instead of asserted. Khadijah's value, kept.
MIN_MARGIN = 0.05
TOP_K = 5
# Widest a leftover is allowed to grow when it is widened to its clause.
WORD_WINDOW = 10

# Khadijah's query rewriting. A leftover fragment is how a person talks; a
# column name is how a database is written. Dropping filler and turning
# "my belly really hurts" into "abdominal pain" moves the query toward the
# space the column names live in before the similarity is taken.
QUERY_DROP = {
    "my", "the", "a", "an", "his", "her", "your", "their", "our", "some",
    "really", "rlly", "very", "so", "kinda", "bit", "little", "is", "are",
    "been", "has", "have", "keeps", "somewhere", "feels", "feel", "felt",
}
QUERY_VERBS = {
    "hurts": "pain", "hurt": "pain", "hurting": "pain", "aches": "pain",
    "aching": "pain", "ache": "pain", "burns": "burning", "itches": "itching",
    "throbs": "throbbing",
}
QUERY_SITES = {
    "belly": "abdominal", "tummy": "abdominal", "stomach": "abdominal",
    "abdomen": "abdominal", "gut": "abdominal",
}
PREPOSITIONS = (r"in|on|under|behind|around|near|at|of|across|over|above|"
                r"below|between|inside")
_TOKEN = re.compile(r"[a-z'-]+")


def rewrite_query(phrase):
    """
    ("abdominal pain", "pain") for "pain in my belly".

    The second value is the bare sensation, used to blend two similarities:
    the rewritten phrase, and the sensation alone. Blending stops a long
    fragment from drifting away from the sensation that actually matters.
    """
    tokens = [QUERY_SITES.get(t, QUERY_VERBS.get(t, t))
              for t in _TOKEN.findall(phrase.lower()) if t not in QUERY_DROP]
    text = " ".join(tokens) or phrase.lower()
    m = re.fullmatch(rf"(.+?) (?:{PREPOSITIONS}) (.+)", text)
    if m and len(m.group(2).split()) <= 3:
        return f"{m.group(2)} {m.group(1)}", m.group(1)
    return text, None


class Layer2:
    """
    Embedding fallback. Holds a reference to the Layer 1 instance so that the
    column list and the context assessor are literally the same objects - the
    two layers cannot drift apart because there is only one of each.
    """

    def __init__(self, layer1, model_name=DEFAULT_MODEL, device=None,
                 encoder=None, use_gliner=False,
                 min_similarity=MIN_SIMILARITY, min_margin=MIN_MARGIN):
        # An injected encoder NEVER touches the on-disk cache. The self-test
        # uses a fake one, and the fingerprint is keyed on the model name and
        # the column list - neither of which changes when the encoder is
        # swapped - so without this the fake vectors are written to
        # column_embeddings.npz and the next real run loads them silently and
        # matches everything to nonsense. Found by running the calibrator
        # straight after the self-test.
        self._may_cache = encoder is None
        self.layer1 = layer1
        self.model_name = model_name
        self.min_similarity = min_similarity
        self.min_margin = min_margin
        self.use_gliner = use_gliner
        self.reason = None
        # layer1.vocab is already the 327 LIVE columns - the dead ones were
        # filtered out when it was loaded, so there is nothing to filter here.
        self.columns = list(layer1.vocab)
        # `encoder` is injectable so every path in this file can be tested
        # without downloading 440 MB. The real one is built lazily.
        self._encoder = encoder
        self._device = device
        self._matrix = None

    # -- the model ------------------------------------------------------
    def _build_encoder(self):
        import torch
        from transformers import AutoModel, AutoTokenizer

        device = self._device or ("cuda" if torch.cuda.is_available() else "cpu")
        tok = AutoTokenizer.from_pretrained(self.model_name)
        mod = AutoModel.from_pretrained(self.model_name).to(device).eval()

        def encode(texts):
            out = []
            for i in range(0, len(texts), 64):
                batch = tok(texts[i:i + 64], padding=True, truncation=True,
                            max_length=64, return_tensors="pt").to(device)
                with torch.no_grad():
                    # [CLS], which is what SapBERT is trained to use as the
                    # entity representation. Mean pooling scores worse on it.
                    h = mod(**batch).last_hidden_state[:, 0, :]
                out.append(h.cpu().numpy())
            return np.vstack(out)

        return encode

    def available(self):
        """Can this actually run? Cheap check, no download."""
        if self._encoder is not None:
            return True
        import importlib.util
        return all(importlib.util.find_spec(m)
                   for m in ("torch", "transformers"))

    @property
    def encoder(self):
        if self._encoder is None:
            self._encoder = self._build_encoder()
        return self._encoder

    @staticmethod
    def _unit(v):
        n = np.linalg.norm(v, axis=1, keepdims=True)
        return v / np.maximum(n, 1e-12)

    def _fingerprint(self):
        h = hashlib.sha256("\n".join(self.columns).encode()).hexdigest()[:16]
        return f"{self.model_name}|{h}"

    def column_matrix(self):
        """
        The 327 column names, encoded once and cached on disk.

        The notebook re-encoded all 327 on every run. That is 327 forward
        passes to produce a file that only changes when the vocabulary does.
        """
        if self._matrix is not None:
            return self._matrix
        if CACHE.exists() and self._may_cache:
            try:
                z = np.load(CACHE, allow_pickle=False)
                if str(z["fingerprint"]) == self._fingerprint():
                    self._matrix = z["vectors"]
                    return self._matrix
            except Exception:
                pass            # a stale or corrupt cache is rebuilt, not fatal
        vecs = self._unit(np.asarray(self.encoder(self.columns), dtype=np.float32))
        self._matrix = vecs
        if not self._may_cache:
            return self._matrix
        try:
            np.savez_compressed(CACHE, vectors=vecs,
                                fingerprint=np.array(self._fingerprint()))
        except Exception:
            pass                # read-only disk must not break extraction
        return self._matrix

    # -- matching -------------------------------------------------------
    def score(self, phrases):
        """(n_phrases, n_columns) cosine similarity, one batched forward pass."""
        rewritten, sensations = [], []
        for p in phrases:
            r, s = rewrite_query(p)
            rewritten.append(r)
            sensations.append(s)
        # The bare sensations are encoded in the SAME batch, appended after the
        # rewritten phrases, so each one has to remember which phrase it came
        # from. The first version of this built a dict whose keys and values
        # were the two indices the wrong way round and then unpacked them in
        # that same wrong order, so it indexed `sims` with a position in
        # `queries` and crashed with "index 805 is out of bounds for axis 0
        # with size 805" on the first real run. Two parallel lists are harder
        # to get wrong than a dict comprehension with a `start=` offset.
        blend_rows, blend_queries = [], []
        for i, s in enumerate(sensations):
            if s:
                blend_rows.append(i)
                blend_queries.append(s)

        queries = rewritten + blend_queries
        vecs = self._unit(np.asarray(self.encoder(queries), dtype=np.float32))
        cols = self.column_matrix()
        sims = vecs[:len(rewritten)] @ cols.T
        for k, row in enumerate(blend_rows):
            sims[row] = (sims[row] + vecs[len(rewritten) + k] @ cols.T) / 2
        return sims

    def candidates(self, phrase, sims_row):
        order = np.argsort(-sims_row)[:TOP_K]
        return [{"column": self.columns[i], "score": round(float(sims_row[i]), 4)}
                for i in order]

    # -- the contract ---------------------------------------------------
    @staticmethod
    def clause(norm, span):
        """
        A leftover fragment widened to its clause.

        Measured, on the real model: the leftover "and heavy" from "my
        shoulder is bad, feels tight and heavy" scores `heavy menstrual flow`
        at 0.589 for a shoulder complaint. Widened to its clause, "feels tight
        and heavy" is about shoulders again. A two-word fragment carries too
        little meaning for an embedding to place, and Layer 1 cuts fragments
        wherever it happened to stop matching, not at a meaningful boundary.

        Widening to the CLAUSE, not the sentence: scoring the whole sentence
        would mostly re-find what Layer 1 already found, which adds nothing
        and crowds out the leftover this call is actually about.
        """
        if not norm:
            return None
        s, e = int(span[0]), int(span[1])
        left = max((norm.rfind(c, 0, s) for c in ".,;!?"), default=-1)
        right = min((i for i in (norm.find(c, e) for c in ".,;!?") if i != -1),
                    default=len(norm))
        text = norm[left + 1:right].strip()
        if not text:
            return None

        # A sentence with no internal punctuation is ONE clause, so without a
        # cap a long run-on widens to the whole sentence - and then every
        # leftover in it gets the same query, which both wastes the call and
        # mostly re-finds what Layer 1 already matched. Keep a window of at
        # most WORD_WINDOW words around the fragment instead.
        words = text.split()
        if len(words) <= WORD_WINDOW:
            return text
        frag = norm[s:e].split()
        at = 0
        for i in range(len(words) - len(frag) + 1):
            if words[i:i + len(frag)] == frag:
                at = i
                break
        spare = max(0, WORD_WINDOW - len(frag))
        start = max(0, at - spare // 2)
        return " ".join(words[start:start + max(len(frag), WORD_WINDOW)])

    def queries_for(self, result):
        """
        ([text actually scored], [fragment it came from]) for a Layer 1 result.

        extend() and calibrate_layer2.py MUST both go through here. They did
        not: the clause widening lived inside extend() while the calibrator
        called score() on the raw fragments, so a whole calibration run
        measured behaviour the component no longer had, and the threshold it
        produced was for a different input distribution than production. A
        calibrator that does not score what production scores is calibrating
        nothing.
        """
        left = list(result.get("unmatched") or [])
        spans = result.get("unmatched_spans") or []
        norm = result.get("normalized", "")
        if len(spans) == len(left) and norm:
            return [self.clause(norm, sp) or f
                    for f, sp in zip(left, spans)], left
        return list(left), left

    def extend(self, result):
        """
        Take `result["unmatched"]`, place what can be placed, and return the
        same dict. Rows added carry layer="embedding". Nothing Layer 1 decided
        is ever overwritten.
        """
        left = list(result.get("unmatched") or [])
        if not left:
            result.setdefault("layers_run", []).append("embed:nothing_to_do")
            return result
        queries, left = self.queries_for(result)
        try:
            sims = self.score(queries)
        except Exception as exc:
            # The model is a 440 MB download. Not having it is a normal state
            # on a fresh clone and must never break extraction.
            self.reason = f"{type(exc).__name__}: {exc}"
            result.setdefault("layers_run", []).append("embed:unavailable")
            result["layer2_error"] = self.reason
            return result

        spans = result.get("unmatched_spans") or []
        norm = result.get("normalized", "")
        statuses = []
        if spans and len(spans) == len(left) and norm:
            try:
                # assess() returns a DICT {span_index: status}, not a list.
                # Iterating it yields the integer KEYS, so every status read as
                # "0", matched none of the branches below, and every placement
                # fell through to "asserted symptom" - Layer 2 was ignoring
                # context completely. The length check below passed because a
                # dict has the right number of entries. Found by running the
                # calibrator locally with a fake encoder; no amount of staring
                # at it would have shown this.
                got = self.layer1.context.assess(norm, [tuple(s) for s in spans])
                statuses = [str(got.get(i, "present")).lower()
                            for i in range(len(spans))]
            except Exception:
                statuses = []
        if len(statuses) != len(left):
            statuses = ["present"] * len(left)

        taken = {s["column"] for s in result.get("symptoms", [])}
        taken |= {n["column"] for n in result.get("negated", [])}
        kept_unmatched, added = [], 0

        for phrase, row, status in zip(left, sims, statuses):
            cands = self.candidates(phrase, row)
            best, second = cands[0], (cands[1] if len(cands) > 1 else None)

            if best["score"] < self.min_similarity:
                kept_unmatched.append(phrase)
                continue
            if best["column"] in taken:
                kept_unmatched.append(phrase)
                continue

            entry = {"column": best["column"], "matched_text": phrase,
                     "layer": "embedding", "method": "sapbert",
                     "score": best["score"]}

            # Too close to call: ask rather than assert. Same policy Layer 1
            # uses for a site-less sensation.
            if second and best["score"] - second["score"] < self.min_margin:
                result.setdefault("confirm", []).append({
                    **entry,
                    "question": (f"By \"{phrase}\", do you mean "
                                 f"{best['column']} or {second['column']}?"),
                    "reason": "low_margin",
                    "candidates": [c["column"] for c in cands[:3]],
                })
                added += 1
                taken.add(best["column"])
                continue

            status = str(status).lower()
            if status == "negated":
                result.setdefault("negated", []).append(entry)
            elif status in ("family", "historical", "age_mismatch"):
                result.setdefault("excluded", []).append({**entry, "status": status})
            elif status in ("uncertain", "dependent"):
                # Matched but not asserted. Same bucket Layer 1 uses, so the
                # app has one rule for "ask before using" regardless of which
                # layer found it.
                result.setdefault("confirm", []).append(
                    {**entry, "question": f"Do you have {best['column']}?",
                     "reason": status})
                result.setdefault("excluded", []).append({**entry, "status": status})
            else:
                result.setdefault("symptoms", []).append(entry)
                meta = self.layer1.vocab.get(best["column"], {})
                if meta.get("red_flag"):
                    result.setdefault("red_flags", []).append({
                        "column": best["column"], "level": meta["red_flag"],
                        "reason": meta.get("red_flag_reason", ""),
                    })
            taken.add(best["column"])
            added += 1

        result["unmatched"] = kept_unmatched
        result["n_actionable"] = len(result.get("symptoms", []))
        result.setdefault("layers_run", []).append(f"embed:+{added}")
        return result


# -- module-level contract, kept so pipeline.py works without a model -------
_SINGLETON = None


def extend(result, layer1=None):
    """
    Pass-through unless a Layer 2 has been constructed with a Layer 1.
    pipeline.py builds one properly; this keeps old call sites working.
    """
    if layer1 is None and _SINGLETON is None:
        result.setdefault("layers_run", []).append("embed:not_configured")
        return result
    return (_SINGLETON or Layer2(layer1)).extend(result)


def self_test():
    """
    Exercise every path with a FAKE encoder, so the wiring can be checked
    without downloading the model. This proves the plumbing, NOT the quality
    of the embeddings - only the real model can show that.
    """
    import sys
    sys.path.insert(0, str(ROOT / "src"))
    from layer1_lexicon import Layer1

    l1 = Layer1()
    rng = np.random.default_rng(0)

    def fake_encoder(texts):
        # Deterministic pseudo-embeddings: identical strings get identical
        # vectors, so "nearest column" is stable and testable.
        out = []
        for t in texts:
            seed = int(hashlib.sha256(t.encode()).hexdigest()[:8], 16)
            out.append(np.random.default_rng(seed).normal(size=64))
        return np.asarray(out, dtype=np.float32)

    l2 = Layer2(l1, encoder=fake_encoder, min_similarity=-1.0)
    checks = []
    for text in ["my chest feels tight when i walk fast, no cough",
                 "the thing in my side is doing it again",
                 "everything is fine"]:
        r = l1.extract(text)
        before = len(r["symptoms"]), len(r["unmatched"])
        r = l2.extend(r)
        after = len(r["symptoms"]), len(r["unmatched"])
        checks.append((text, before, after, r["layers_run"][-1]))

    print("Layer 2 wiring check (FAKE encoder - proves plumbing, not quality)")
    for text, before, after, note in checks:
        print(f"  {text[:46]:48} symptoms {before[0]}->{after[0]}  "
              f"unmatched {before[1]}->{after[1]}  [{note}]")
    # Exercise the sensation-blend path explicitly. The crash above shipped
    # because every phrase in this test happened to produce no sensation, so
    # the blending loop never ran. "pain in my belly" rewrites to
    # ("abdominal pain", "pain") and forces it.
    mixed = ["pain in my belly", "and heavy", "burning in my chest"]
    sims = l2.score(mixed)
    blended = sum(1 for p in mixed if rewrite_query(p)[1])
    assert sims.shape == (len(mixed), len(l2.columns)), sims.shape
    print(f"\n  sensation-blend path: {blended} of {len(mixed)} phrases "
          f"blended, shape {sims.shape} - OK")

    print(f"  columns loaded: {len(l2.columns)}")
    print(f"  cache path    : {CACHE.relative_to(ROOT)}")
    print(f"\n  MIN_SIMILARITY = {MIN_SIMILARITY} - measured on 805 real leftovers\n  against a noise control. Re-run calibrate_layer2.py after any\n  change to the fragment widening.")
    _ = rng, json
    return 0


if __name__ == "__main__":
    raise SystemExit(self_test())
