"""
CONTEXT ASSESSMENT - is a matched symptom actually asserted, about the patient,
and happening now?

Uses medspaCy's ConText algorithm when it is installed, and falls back to the
hand-written rules in normalize.py when it is not. The fallback matters: the
project must still run on a machine without a C++ compiler, and a marker should
not have to install anything to see the code work.

DIVISION OF LABOUR, and the reason for it:

  all four axes -> local_context.py, the ConText algorithm over this project's
                   own patient rule table
  reinforcement -> medspaCy's ConText, where it is installed

This used to be a split: negation local, the other three axes from medspaCy.
That was wrong, and Aljoury's 200 sentences showed why - on a machine without
medspaCy, "My son has a cough, not me" recorded the cough as the patient's own.
A fallback that loses negation is obviously broken; one that loses the
experiencer axis quietly lies. So the algorithm is implemented locally for all
four axes and medspaCy is a second opinion.

ConText's negation is tuned for CLINICAL NOTES, where "Denies: fever, cough,
chest pain" means all three are denied - so a negation deliberately carries
across commas. Patients do not write that way. "no fever, my head hurts" denies
only the fever, and ConText denied the headache too. Measured on this project's
own cases, ConText got 2 of 10 negations wrong that the local rules got right -
which is why medspaCy may only ESCALATE a status, never clear one.

The four axes:

    negation     "no fever"                    -> not present
    experiencer  "my mother has asthma"        -> not the patient
    temporality  "I had a fever last week"     -> not now
    certainty    "I was worried it was a flu"  -> not asserted

Only a symptom that is asserted, about the patient, and current should reach
the model as a positive feature.

Owner: Aljoury.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from local_context import (LocalContext, PRESENT, NEGATED, FAMILY,
                           HISTORICAL, UNCERTAIN)


class ContextAssessor:
    """
    assess(normalised_text, spans) -> {span_index: status}

    `spans` is a list of (start, end) character offsets into the SAME string
    that was passed as `normalised_text`.
    """

    # DEFAULT: the local rules. medspaCy is opt-in, and the reason is not
    # preference, it is reproducibility and one measured safety failure.
    #
    # The component used to prefer medspaCy whenever it happened to be
    # installed. That made the shipped behaviour depend on an optional
    # package: the same text, the same code, two different answers. Running
    # the suite on a machine with medspaCy installed exposed what that costs.
    #
    #   1. `run_tests.py` dropped to 172/173. "my dad had a heart attack at 50
    #      and now my chest hurts" lost BOTH chest-pain columns, because the
    #      generic rules let "my dad had" scope forward over the patient's own
    #      complaint. The local rules ask which kind of chest pain, correctly.
    #
    #   2. Worse, and the reason this is not a preference: in a long run-on
    #      sentence containing "had a fever last week", medspaCy marked
    #      `hemoptysis` - coughing up blood, an EMERGENCY red flag - as
    #      HISTORICAL, along with shortness of breath and four abdominal pain
    #      columns. A red flag suppressed by a time expression three clauses
    #      away is exactly the failure this component exists to prevent. The
    #      local rules return all three as asserted red flags.
    #
    #   3. Every number this project reports - 903 sentences, the 500-sentence
    #      holdout, CADEC - was measured on the local rules, and web/layer1.js
    #      ports ONLY the local rules. So with medspaCy active, `verify_web.py`
    #      no longer guarantees anything: the Python and the browser silently
    #      disagree.
    #
    # The old claim that medspaCy "only ever makes a verdict stricter" was
    # true and misleading: stricter here means suppressing true positives,
    # including red flags. Pass prefer_medspacy=True to compare the two
    # engines (check_context.py does); nothing in the shipped path does.
    def __init__(self, prefer_medspacy=False):
        self.engine = "rules"
        self._nlp = None
        self.local = LocalContext()
        if prefer_medspacy:
            self._try_medspacy()

    # ------------------------------------------------------------------ setup
    def _try_medspacy(self):
        """
        Load a minimal medspaCy pipeline: a tokenizer, a sentence splitter and
        ConText. Target matching is NOT delegated - this project's matcher has
        a compositional parser and family logic that TargetRule cannot express.
        """
        try:
            import spacy
            # Imported only to find out whether it is installed; medspaCy
            # registers its spaCy components as a side effect of the import,
            # so this is load-bearing even though nothing calls it.
            import medspacy  # noqa: F401
            from medspacy.context import ConText
        except Exception as exc:          # not installed, or a version mismatch
            self._why = f"{type(exc).__name__}: {exc}"
            return

        try:
            try:
                nlp = spacy.load("en_core_web_sm", disable=["ner", "lemmatizer"])
            except OSError:
                # No model downloaded. A blank pipeline still tokenises, which
                # is all ConText needs.
                nlp = spacy.blank("en")
            if "sentencizer" not in nlp.pipe_names and not nlp.has_pipe("parser"):
                nlp.add_pipe("sentencizer")
            self._context = ConText(nlp)
            self.custom_rules = 0
            try:
                from medspacy.context import ConTextRule
                from patient_context_rules import build
                rules = build(ConTextRule)
                self._context.add(rules)
                self.custom_rules = len(rules)
            except Exception as exc:
                # The default clinical rule set still loads; it just will not
                # fire on patient wording. Worth knowing, not worth failing.
                self._rules_error = f"{type(exc).__name__}: {exc}"
            self._nlp = nlp
            self.engine = "medspacy"
        except Exception as exc:
            self._why = f"{type(exc).__name__}: {exc}"
            self._nlp = None

    @property
    def unavailable_reason(self):
        return getattr(self, "_why", None)

    @property
    def rules_note(self):
        """How many patient-language rules were added, or why none were."""
        local = (f"{self.local.n_rules} local modifier rules, "
                 f"{len(self.local.terminators)} terminators")
        if self.engine != "medspacy":
            return local + " (medspaCy not installed - same four axes)"
        err = getattr(self, "_rules_error", None)
        if err:
            return f"patient rules NOT loaded ({err}) - clinical defaults only"
        return f"{getattr(self, 'custom_rules', 0)} patient-language rules added"

    # ----------------------------------------------------------------- assess
    def assess(self, text, spans, original=None, idx_map=None):
        """
        `text`/`spans` are in normalised coordinates. `original`/`idx_map` give
        the user's untouched sentence, which ConText needs - it reads real
        punctuation and capitalisation.

        All four axes come from the local rules. ConText, where it is
        installed, may only ESCALATE a verdict - turn a `present` into family,
        historical or uncertain - and may never clear one. See the note at the
        top of this file for why its negation is not trusted.
        """
        status = self._assess_rules(text, spans)
        if self._nlp is None:
            return status

        try:
            if original and idx_map:
                from normalize import to_original_span
                mapped = [to_original_span(idx_map, s, e, original)
                          for s, e in spans]
                extra = self._assess_medspacy(original, mapped)
            else:
                extra = self._assess_medspacy(text, spans)
        except Exception as exc:
            # Never lose a symptom to a library error - but do not hide it either.
            self.last_error = f"{type(exc).__name__}: {exc}"
            return status

        for i, s in extra.items():
            # ESCALATE ONLY. ConText may move a symptom from `present` to one
            # of the three exclusion axes; it may never move one back to
            # `present`, and its negation verdict is ignored entirely. That
            # asymmetry is deliberate: on this project's own cases ConText got
            # 2 of 10 negations wrong that the local rules got right, and the
            # errors were in the dangerous direction.
            if s in (FAMILY, HISTORICAL, UNCERTAIN) and status.get(i) == PRESENT:
                status[i] = s
        return status

    def diagnose(self, original):
        """
        Print what ConText says about every entity it finds in `original`.
        Use this when a case looks wrong - it shows the engine's raw verdict
        rather than the combined one.
        """
        if self._nlp is None:
            print(f"medspaCy not loaded: {self.unavailable_reason}")
            return
        doc = self._context(self._nlp(original))
        print(f"  text      : {original}")
        try:
            print(f"  sentences : {[s.text for s in doc.sents]}")
        except Exception:
            print("  sentences : (no sentence boundaries - no parser/sentencizer)")
        mods = None
        for getter in (lambda: doc._.context_graph.modifiers,
                       lambda: doc.spans.get("context_modifiers"),
                       lambda: [e._.modifiers for e in doc.ents]):
            try:
                mods = getter()
                if mods:
                    break
            except Exception:
                continue
        if not mods:
            print("  modifiers : none found")
            print("              (if the sentence clearly has one, its trigger "
                  "wording is not in the rule set)")
            return
        flat = []
        for m in mods:
            if isinstance(m, (list, tuple)):
                flat.extend(m)
            else:
                flat.append(m)
        for m in flat:
            cat = getattr(m, "category", "?")
            txt = None
            # medspaCy versions expose the trigger span under different names.
            for attr in ("span", "modifier_span", "_span"):
                sp = getattr(m, attr, None)
                if sp is not None and hasattr(sp, "text"):
                    txt = sp.text
                    break
            if txt is None:
                start = getattr(m, "start", None)
                end = getattr(m, "end", None)
                if start is not None and end is not None:
                    txt = doc[start:end].text
            print(f"  modifier  : {cat:<22} '{txt or m}'")

    def _assess_medspacy(self, text, spans):
        from spacy.util import filter_spans

        doc = self._nlp(text)
        ents, order = [], []
        for i, (s, e) in enumerate(spans):
            sp = doc.char_span(s, e, label="SYMPTOM", alignment_mode="expand")
            if sp is not None:
                ents.append(sp)
                order.append((sp.start_char, sp.end_char, i))
        doc.ents = filter_spans(ents)
        doc = self._context(doc)

        out = dict.fromkeys(range(len(spans)), PRESENT)
        for ent in doc.ents:
            idx = None
            for s_char, e_char, i in order:
                if s_char == ent.start_char and e_char == ent.end_char:
                    idx = i
                    break
            if idx is None:
                continue
            u = ent._
            if getattr(u, "is_negated", False):
                out[idx] = NEGATED
            elif getattr(u, "is_family", False):
                out[idx] = FAMILY
            elif getattr(u, "is_historical", False):
                out[idx] = HISTORICAL
            elif getattr(u, "is_uncertain", False) or getattr(u, "is_hypothetical", False):
                out[idx] = UNCERTAIN
        return out

    def _assess_rules(self, text, spans):
        return self.local.assess(text, spans)


if __name__ == "__main__":
    from normalize import normalize

    a = ContextAssessor()
    print(f"engine: {a.engine}")
    if a.engine == "rules" and a.unavailable_reason:
        print(f"  medspaCy not used -> {a.unavailable_reason}")
        print("  install:  pip3 install medspacy")
        print("            python3 -m spacy download en_core_web_sm")
    print()

    cases = [
        ("no fever, my head hurts", ["fever", "head hurts"]),
        ("my mother has asthma and I have a cough", ["asthma", "cough"]),
        ("I had a fever last week, now just tired", ["fever", "tired"]),
        ("I was worried it was a fever but it is just a sore throat",
         ["fever", "sore throat"]),
    ]
    for raw, targets in cases:
        t = normalize(raw)
        spans = []
        for w in targets:
            w = normalize(w)
            i = t.find(w)
            if i >= 0:
                spans.append((i, i + len(w)))
        res = a.assess(t, spans)
        print(f'"{raw}"')
        for i, (s, e) in enumerate(spans):
            print(f"    {t[s:e]:<16} -> {res[i]}")
        print()
