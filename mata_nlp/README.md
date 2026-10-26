# Ma'ta — NLP component

**GP 1448, Sprint 1.** Free-text patient complaint → symptoms, each with a
status, plus red flags, modifiers, the follow-up questions worth asking, and a
327-column feature vector for the condition model that Sprint 2 will train.

Owner: Aljoury Alreemi. 20 files, 840 KB, no installation required.

```python
from pipeline import Pipeline

p = Pipeline()                      # load once, at application startup
out = p.run("my chest feels tight and i have no cough")
```

```
out["symptoms"]   [{"column": "chest tightness", ...}]
out["negated"]    [{"column": "cough", ...}]
out["red_flags"]  [{"column": "chest tightness", "level": "EMERGENCY", ...}]
```

## What comes back

| field | what it holds |
|---|---|
| `symptoms` | the patient has it now |
| `negated` | the patient says they do **not** have it |
| `excluded` | real mentions that are not current complaints — past, somebody else's, age-impossible |
| `confirm` | the patient is unsure; one yes/no question resolves it |
| `clarify` | the wording names a family of columns, not one; carries the question to ask |
| `red_flags` | `EMERGENCY` or `URGENT_24H`, with the reason |
| `modifiers` | severity, onset, duration, attached to the nearest symptom |
| `next_step` | **absent** in Sprint 1 — see **Scope** below |
| `confirm_subject` | true when the complaint may be about somebody else |
| `unmatched` | text no layer could place — what Layer 2 and 3 receive. Fragments, not sentences: fine as layer input, not fit to show a person |

Every finding in `symptoms`, `negated`, `excluded`, `confirm` and `red_flags`
also carries:

| field | |
|---|---|
| `display` | plain words for the same thing: "head cold", "black poo", "tingly" where `column` says `coryza`, `melena`, `paresthesia`. **Which one to render depends on who is reading.** A clinician's assessment should show `column` — the clinical term is the precise one and belongs in a medical record. Buttons, chips and anything the patient reads should show `display`, because nobody taps "melena". |
| `matched_text` | the patient's own words that produced this finding. Show it beside the clinical term — "melena ← *black sticky stool*" lets a clinician verify the interpretation without re-reading the whole complaint. |
| `layer` | `lexicon` or `llm`: whether the phrase was matched directly or inferred by the language model. The three display tiers belong here: *in the patient's words* / *patient confirmed when asked* / *inferred, not stated directly*. |
| `subject` | whose finding it is: `self` (the user), `other` (the person they wrote about), `both`, or `unknown` when the text names someone else and gives no clue for this finding. |

A `clarify` entry carries `candidate_displays` alongside `candidates`, for the
buttons.

When `confirm_subject` is true the app asks who the assessment is for, then
calls `p.for_subject(out, "self")` or `p.for_subject(out, "other")` (the
server's `POST /assign-subject`). That keeps only the chosen person's
findings: "my sister has a fever but I don't, I only feel hot" answered *for
me* keeps `feeling hot` and records `fever` as denied; answered *for my
sister* it keeps only `fever`. `unknown` findings are kept either way, and
whatever is left out comes back in `set_aside` so the review screen can show
it and let the user correct us. See
`src/subject.py`; tests in `tests/test_subject.py`.

`feature_vector()` returns the 327-column vector that the condition
classifier will consume: `1` asserted, `0` denied, `−1` unknown.

## Scope

This component turns free text into that vector. It stops there.

**Predicting a condition from the vector is not part of it.** Training that
model is PBI-16, Sprint 2, and it has not been done, so no trained model ships
here.

`src/followup.py` is the slot it will plug into. The question-selection logic
is written, and until a model is supplied the key is simply left out:
`out` has **no** `next_step` key at all, so read it with
`out.get("next_step")` rather than `out["next_step"]`. Supplying a model as
`Pipeline(model=...)` turns it on.

A preliminary classifier was fitted during Sprint 1 while designing that
interface. It is in the supporting archive under `sprint2_preliminary/`,
labelled as such, and is **not** the Sprint 2 deliverable.

## The three layers

1. **Lexicon, compositional and fuzzy matching, plus the context engine.**
   1,712 phrases over 327 live columns, 145 ConText-style rules on four
   standard axes (negation, experiencer, temporality, certainty) and two of
   this project's own (dependent, age mismatch). Deterministic and offline.
2. **Embedding retrieval** — slot present, not enabled. Measured and rejected
   on evidence: 4 of its top 20 placements were correct.
3. **Language model fallback (Gemini).** Off by default. `Pipeline(use_layer3=True)`
   with `GEMINI_API_KEY` in the environment. Adds about 20 points of recall and
   over-maps symptoms the vocabulary cannot express — see the report.

**The API key must never ship inside the Android app.** Layer 3 runs
server-side only (NFR-2).

## Measured accuracy

| | lexicon only | + Layer 3 |
|---|---|---|
| 240 gold sentences, held-out half — symptom found | 64.1% | 84.3% |
| 240 gold sentences, held-out half — symptom **and** status correct | 56.2% | 75.2% |
| 1,250 CADEC patient posts — mention recall | 66.6% | 80.0% |
| 500 project sentences — correct body system | 88.8% | — |
| 203 regression sentences | 173/173, no false positives | — |

The held-out half and the development half agree to within half a point on
status accuracy (75.7% against 75.2%), which is the evidence that nothing is
fitted to the sentences it was built against.

Tests, evaluation scripts, the frozen answer key and the measurement runbook
are in the supporting archive, not here. They are what the report cites.

## Optional dependencies

Nothing is required. `rapidfuzz` makes spelling correction faster and
`medspacy` offers an alternative context engine; both fall back to the
standard library and the shipped figures are from the fallbacks.
`google-genai` is needed only for Layer 3.
