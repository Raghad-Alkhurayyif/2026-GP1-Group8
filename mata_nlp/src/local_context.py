"""
LOCAL CONTEXT - the ConText algorithm, implemented here, over the patient rules.

Why this exists. The project's original division of labour gave negation to the
local rules and the other three axes - experiencer, temporality, certainty - to
medspaCy. That made the no-medspaCy fallback SILENTLY LESS SAFE, and the 200
sentences proved it:

    "My son has a cough, not me. I've been getting headaches."
        -> cough recorded as the patient's own

    "My sister had night sweats recently, but I don't."
        -> night sweats recorded as the patient's own

Both wrong, and wrong in the direction that puts a symptom in the feature
vector that the person does not have. A fallback that loses negation would be
obviously broken; one that loses the experiencer axis just quietly lies.

So all four axes are implemented here, on the same rule table medspaCy is
given, and medspaCy becomes a second opinion rather than the only source. The
two agree on these 200 sentences; where they disagree, check_context.py shows
both.

ConText in three rules:

    FORWARD        the trigger applies to targets AFTER it, up to the next
                   terminator or sentence end       "my mother has asthma"
    BACKWARD       to targets BEFORE it             "a fever last week"
    BIDIRECTIONAL  both, within the clause          "last week I had a fever"
    TERMINATE      ends any scope reaching it       "but now", "the only thing"

Owner: Aljoury.
"""

import re

from normalize import _is_new_assertion, merge, scope_spans
from patient_context_rules import PATIENT_RULES

PRESENT = "present"
NEGATED = "negated"
FAMILY = "family"
HISTORICAL = "historical"
UNCERTAIN = "uncertain"
# Someone the user is asking ON BEHALF OF - usually their child, and
# usually the actual patient. Reported, not dropped. See the DEPENDENT
# block in patient_context_rules.py.
DEPENDENT = "dependent"

# The rule table speaks ConText's category names; these are ours.
CATEGORY = {
    "FAMILY": FAMILY,
    "HISTORICAL": HISTORICAL,
    "POSSIBLE_EXISTENCE": UNCERTAIN,
    "DEPENDENT": DEPENDENT,
}

# Time expressions read in both directions. The rule table marks them BACKWARD,
# which is right for "a fever LAST WEEK" and wrong for "LAST WEEK I had a
# fever" - and Aljoury's sentences 44, 54, 64 and 20 more are all the second
# shape. Any trigger in this set is treated as bidirectional.
BIDIRECTIONAL = {
    "last week", "last weekend", "last month", "last year", "last night",
    "a few days ago", "a week ago", "a month ago", "years ago", "months ago",
    "days ago", "over the weekend", "a couple of days ago", "earlier",
    "last winter", "last summer", "last spring", "last autumn", "last fall",
}

# Where any scope stops, on top of the TERMINATE rules in the table.
# A comma breaks a modifier scope too. "a swollen ankle, also I barely slept
# LAST NIGHT" ran the time expression backwards over the ankle and marked it
# historical - the "last night" was about the sleeping, not the ankle.
SENTENCE_BREAKS = {".", ";", ","}
HARD_TERMINATORS = [
    # Plain conjunctions terminate a scope, which is ConText's own behaviour
    # and was missing here: "I was worried it was a chest infection BUT it's
    # just a cough" left the cough marked uncertain.
    "but", "however", "although", "except", "instead", "whereas", "rather",
    "but now", "but i do not", "but i am not", "but that stopped",
    "not anymore", "but today", "today i", "now it is", "the only thing",
    "bothering me is", "right now i have", "currently", "now just",
    "i am the one with", "but this",
]

# "since last night" and "for two weeks" mean it STARTED then and is happening
# now - the opposite of history. Without this, "vomiting diarrhea and stomach
# cramps SINCE LAST NIGHT" marked all three as historical and the feature
# vector came out empty.
# "not me" / "not mine" is an explicit correction of WHO the complaint is
# about, and it attaches to the clause before it across a comma: "My son has
# a cough, not me." So these reach back past a comma, unlike a time
# expression, which must not.
CROSSES_COMMA = {"not me", "not mine", "not myself"}

# Phrases whose entire meaning is "...and it is over now". These reach back
# past a comma AND past a contrast conjunction, which nothing else does.
#
# "i had terrible migraines in high school BUT have not had one in years" was
# read as a current headache. The backward scope stopped at "but", which is
# right almost everywhere - "I was worried it was a chest infection BUT it's
# just a cough" must not mark the cough uncertain - and wrong here, because
# this "but" does not introduce a new complaint. It continues the same past
# report: the clause after it exists only to say the symptom has gone. The
# same held across a comma in "at the start of the month, RECOVERED FULLY by
# the weekend".
#
# Every phrase here is safe to let through a contrast because none of them can
# describe a present symptom. There is no sentence where "have not had one in
# years" reaches back over something the person has now.
CROSSES_CONTRAST = {
    "have not had one in", "have not had them since", "have not had one since",
    "have not had it since", "have not had any since", "has not happened again",
    "never happened again", "completely cleared", "cleared now",
    "recovered fully", "fully recovered", "and it stopped", "but it stopped",
    "it has healed", "its healed",
}

ONGOING_PREFIXES = ("since", "for the last", "for the past", "for", "over")


# A FAMILY scope ends the moment the person turns back to themselves.
# "my mother has asthma and I have a cough" labelled the cough as the mother's
# until these were added - the scope ran to the end of the sentence.
FIRST_PERSON = [" i ", " i am ", " i have ", " my ", " me ", " mine "]


def _tokens(text):
    """[(token, start, end)] over normalised text."""
    return [(m.group(), m.start(), m.end())
            for m in re.finditer(r"[\w'-]+|[,;.]", text)]


# Words that can sit between "my" and the relative without changing who is
# meant: "my ELDERLY mother", "my 6 YEAR OLD son", "my LITTLE girl".
#
# Without this, the rule literal `my mother` simply failed to match "my elderly
# mother", and the relative's symptoms were recorded as the PATIENT's own. It is
# the commonest way people actually write about someone else - almost nobody
# types a bare "my son" when the age is the reason they are worried - so the
# cases this broke were exactly the paediatric and elderly ones that matter
# most. Found by comparing against Khadijah's Layer 2 on the same spans.
RELATIVE_MODIFIERS = (
    "elderly", "elder", "eldest", "old", "older", "oldest", "young", "younger",
    "youngest", "little", "lil", "baby", "newborn", "infant", "teenage",
    "teenaged", "teen", "adult", "grown", "poor", "dear", "sick", "step",
    "half", "great", "big", "small", "year", "years", "yr", "yrs", "month",
    "months", "week", "weeks", "old-", "yo",
)
_MOD_ALT = "|".join(RELATIVE_MODIFIERS)
# A number, or one of those words, up to four of them in a row.
_MOD_RUN = rf"(?:(?:{_MOD_ALT}|\d{{1,3}})[\s-]+){{0,4}}"


def _rule_pattern(literal):
    """
    The regex for a context rule. Rules that start with a possessive allow a
    short run of modifiers before the relative; everything else is literal.
    """
    for poss in ("my ", "his ", "her ", "their ", "our "):
        if literal.startswith(poss):
            return re.compile(rf"\b{poss.strip()}\s+{_MOD_RUN}"
                              rf"{re.escape(literal[len(poss):])}\b")
    return re.compile(rf"\b{re.escape(literal)}\b")


class LocalContext:
    """
    assess(normalised_text, spans) -> {span_index: status}

    Spans are (start, end) character offsets into the same normalised string.
    """

    def __init__(self, rules=None):
        self.rules = []
        self.terminators = list(HARD_TERMINATORS)
        for literal, category, direction in (rules or PATIENT_RULES):
            if category == "TERMINATE":
                self.terminators.append(literal)
                continue
            cat = CATEGORY.get(category)
            if cat is None:
                continue
            if literal in BIDIRECTIONAL:
                direction = "BIDIRECTIONAL"
            self.rules.append((literal, cat, direction, _rule_pattern(literal)))
        # Longest first, so "my grandmother" beats "my" if both were present.
        self.rules.sort(key=lambda r: -len(r[0]))
        self.n_rules = len(self.rules)

    # ------------------------------------------------------------- boundaries
    def _breaks(self, text):
        """Character positions where a scope must stop."""
        stops = set()
        for tok, s, _e in _tokens(text):
            if tok in SENTENCE_BREAKS:
                stops.add(s)
        for t in self.terminators:
            for m in re.finditer(rf"\b{re.escape(t)}\b", text):
                stops.add(m.start())
        return sorted(stops)

    @staticmethod
    def _next_break(stops, pos):
        for s in stops:
            if s >= pos:
                return s
        return None

    @staticmethod
    def _is_ongoing(text, trigger_start):
        """'since last night' / 'for two weeks' - started then, still going."""
        before = text[:trigger_start].split()
        tail = " ".join(before[-3:])
        return any(tail.endswith(p) or tail == p for p in ONGOING_PREFIXES)

    @staticmethod
    def _list_end(text, pos, stops):
        """
        How far a FAMILY or DEPENDENT scope reaches, continuing through a list.

        Whose symptom it is was ending at the first comma, so in

            "my mother has a fever, a cough, and a headache"

        only `fever` was recorded as the mother's; `cough` and `headache` came
        back as the PATIENT's own, with nothing to say they were not. That is
        the worst kind of wrong answer this component can give - a relative's
        symptoms driving the patient's triage - and it survived every test we
        wrote because our own sentences put one symptom per relative.

        Khadijah's Layer 2 judged the same spans correctly, which is how it was
        found: on 1,651 span judgements the two engines disagreed twice, and
        both times she was right.

        The rule is the one already used for denials: a comma continues the
        scope while the next clause is another list item, and ends it when the
        clause brings its own subject or verb. A full stop or semicolon always
        ends it, as does any hard terminator.
        """
        end = len(text)
        for s in stops:
            if s < pos:
                continue
            sep = text[s:s + 1]
            if sep in (".", ";"):
                return s
            if sep != ",":
                return s          # a hard terminator such as "but"
            nxt = text[s + 1:]
            cut = min([i for i in (nxt.find("."), nxt.find(";")) if i != -1]
                      or [len(nxt)])
            clause = nxt[:cut].split(",")[0].strip()
            if _is_new_assertion(clause):
                return s
        return end

    @staticmethod
    def _prev_break(stops, pos):
        prev = None
        for s in stops:
            if s < pos:
                prev = s
            else:
                break
        return prev

    # ----------------------------------------------------------------- assess
    # A complaint ABOUT a relative is two different things, and the difference
    # is tense, not which relative it is.
    #
    #   "my mother HAD night sweats"      -> family history. Not the patient's,
    #                                        not actionable now. FAMILY.
    #   "my mother IS suddenly confused"  -> a carer describing an acute
    #                                        presentation, seeking care NOW.
    #                                        DEPENDENT.
    #
    # This was found reviewing Layer 2. Every adult relative was FAMILY and
    # only children were DEPENDENT, so
    #
    #   "My elderly mother is suddenly very confused, breathing quickly,
    #    and shivering"
    #
    # returned ZERO symptoms and ZERO red flags - confusion, tachypnoea and
    # rigors in an older adult, filed as somebody else's problem and dropped.
    # `confirm_subject` was set, so the app would ask who the complaint is for,
    # but the findings had already been discarded, so a correct answer had
    # nothing left to triage. FAMILY means "do not use this"; DEPENDENT means
    # "ask who it is for, then use it". For an acute complaint the second is
    # the only safe reading.
    #
    # Deliberately NOT keyed on the relative's age or relationship: "my
    # daughter is confused" and "my mother is confused" are the same request.
    PRESENT_TENSE = (
        "is", "are", "has", "have", "keeps", "keep", "cannot", "can not",
        "will not", "is not", "has not", "seems", "looks", "feels", "gets",
        "started", "began", "woke", "wont", "does not",
        # Participles. "I notice my granddad BEING more confused" and "my dad
        # GETTING short of breath" are present-tense carer observations as much
        # as "my mother IS confused"; leaving them out kept three sentences
        # filed as family history and returning nothing at all.
        "being", "getting", "seeming", "looking", "acting", "becoming",
    )
    # An explicit history marker outranks any verb that follows it.
    HISTORY_MARKERS = ("history of", "runs in", "in my family", "used to",
                       "when she was", "when he was", "years ago")

    def _is_carer_report(self, text, trigger_end, scope_end):
        """Present-tense complaint about a relative, rather than family history."""
        window = text[trigger_end:scope_end]
        if any(h in window for h in self.HISTORY_MARKERS):
            return False
        words = window.split()[:6]
        return any(w in self.PRESENT_TENSE for w in words)

    def scopes(self, text):
        """[(start, end, status)] - every region a modifier reaches."""
        stops = self._breaks(text)
        sentence_stops = [i for i in stops if text[i:i + 1] != ","]
        # Sentence enders only: no comma, no conjunction. Used by the phrases
        # in CROSSES_CONTRAST, which continue a past report rather than
        # contrasting with it.
        hard_stops_only = [i for i in stops if text[i:i + 1] in (".", ";")]
        out = []
        for literal, cat, direction, pattern in self.rules:
            for m in pattern.finditer(text):
                if cat == HISTORICAL and self._is_ongoing(text, m.start()):
                    continue
                if direction in ("FORWARD", "BIDIRECTIONAL"):
                    if cat in (FAMILY, DEPENDENT):
                        end = self._list_end(text, m.end(), stops)
                    else:
                        end = self._next_break(stops, m.end())
                        end = len(text) if end is None else end
                    this = cat
                    if cat == FAMILY:
                        for fp in FIRST_PERSON:
                            i = text.find(fp, m.end())
                            if i != -1:
                                end = min(end, i)
                        # Only a named relative is ever a carer report.
                        # "runs in my family" and "family history of" name no
                        # one and stay FAMILY whatever follows them.
                        if literal.startswith("my ") and self._is_carer_report(
                                text, m.end(), end):
                            this = DEPENDENT
                    out.append((m.end(), end, this))
                if direction in ("BACKWARD", "BIDIRECTIONAL"):
                    if literal in CROSSES_CONTRAST:
                        bounds = hard_stops_only
                    elif literal in CROSSES_COMMA:
                        bounds = sentence_stops
                    else:
                        bounds = stops
                    start = self._prev_break(bounds, m.start())
                    out.append((0 if start is None else start + 1,
                                m.start(), cat))
        return out

    def assess(self, text, spans):
        denied, hedged = [], []
        for s, e, kind in scope_spans(text):
            (denied if kind == "negated" else hedged).append((s, e))
        denied, hedged = merge(denied), merge(hedged)
        mods = self.scopes(text)

        out = {}
        for i, (s, e) in enumerate(spans):
            mid = s + (e - s) // 2

            # `s` and `mid` are bound as defaults rather than closed over.
            # Closing over a loop variable works only while the call happens in
            # the same iteration, and the next person to move this line would
            # not get a warning.
            def covered(a, b, _s=s, _mid=mid):
                return a <= _s < b or a <= _mid < b

            # Experiencer outranks denial. "My sister had night sweats, but I
            # don't" reads as a retraction and would be labelled `negated`,
            # which keeps it out of the vector but tells the user the wrong
            # story. Both labels are safe; FAMILY is the true one.
            if any(c == FAMILY and covered(a, b) for a, b, c in mods):
                out[i] = FAMILY
                continue
            # A denial must cover the START of the span. If it begins inside
            # the span, the negator is part of the matched phrase itself -
            # "DO NOT feel like myself" and "HAVEN'T been to the toilet in four
            # days" are both complaints, and testing the middle of the span
            # marked them as denials of themselves.
            if any(a <= s < b for a, b in denied):
                out[i] = NEGATED
                continue
            status = PRESENT
            for pref in (FAMILY, DEPENDENT, HISTORICAL, UNCERTAIN):
                if any(c == pref and covered(a, b) for a, b, c in mods):
                    status = pref
                    break
            if status == PRESENT and any(covered(a, b) for a, b in hedged):
                status = UNCERTAIN
            out[i] = status
        return out


if __name__ == "__main__":
    from normalize import normalize

    lc = LocalContext()
    print(f"{lc.n_rules} modifier rules, {len(lc.terminators)} terminators\n")

    cases = [
        ("My son has a cough, not me. I've been getting headaches.",
         ["cough", "headaches"], ["family", "present"]),
        ("My sister had night sweats recently, but I don't. I'm the one with dizziness.",
         ["night sweats", "dizziness"], ["family", "present"]),
        ("Last week I had a pounding headache but that stopped; now it's mostly a stiff neck.",
         ["headache", "stiff neck"], ["historical", "present"]),
        ("I had a fever last weekend, it's gone now, but this dry cough won't stop.",
         ["fever", "cough"], ["historical", "present"]),
        ("I might be getting a cough, or maybe it's just constipation?",
         ["cough", "constipation"], ["uncertain", "uncertain"]),
        ("no fever, my head hurts", ["fever", "head hurts"],
         ["negated", "present"]),
        ("I used to get a painful lump months ago, not anymore. Today I've got a sore throat.",
         ["painful lump", "sore throat"], ["historical", "present"]),
    ]
    bad = 0
    for raw, targets, expect in cases:
        t = normalize(raw)
        spans, labels = [], []
        for w in targets:
            w = normalize(w)
            i = t.find(w)
            if i >= 0:
                spans.append((i, i + len(w)))
                labels.append(w)
        res = lc.assess(t, spans)
        print(f'"{raw}"')
        for i, w in enumerate(labels):
            got = res[i]
            want = expect[i] if i < len(expect) else "?"
            ok = "ok " if got == want else "BAD"
            bad += got != want
            print(f"   {ok} {w:<16} -> {got:<12} (want {want})")
        print()
    print("all correct" if not bad else f"{bad} wrong")
