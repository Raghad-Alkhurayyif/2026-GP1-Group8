"""
WHOSE SYMPTOM IS IT - the person each finding belongs to, and the result as
seen for the person the assessment is actually for.

Why this exists. When a complaint mentions somebody else, Layer 1 sets
`confirm_subject` and the app asks "Are you completing this assessment for
someone else?". The answer was then thrown away: every finding stayed in the
result whoever it belonged to. So

    "my sister has a fever but I don't, I only feel hot"   + "for me"

still recorded the sister's fever as the user's, and the same text answered
"for my sister" recorded the user's own `feeling hot` as the sister's. The
question changed nothing.

Two parts:

  * `subject_of` labels one finding: "self" (the user), "other" (the person
    they wrote about), "both", or "unknown" when the sentence names someone
    else and gives no clue for this finding. Layer 1 calls it for every match
    and stores the label as `subject`.

  * `for_subject(result, "self" | "other")` is applied once the user has
    answered, and returns the result with only that person's findings in it.
    An "unknown" finding is kept in both views - leaving it in costs the user
    one tap on the review screen, dropping it could lose a real symptom.

The label comes from the nearest person named before the finding:

    "my sister has a fever and I have a headache"
       fever     <- "sister"  -> other
       headache  <- "i"       -> self
    "my mom has a headache, I feel nauseous and dizzy"
       dizzy     <- "i"       -> self
    "my son and i both have a cough"
       cough     <- "my son and i" -> both

and what is said right after it can change that: "...but I don't" (denied
for the user), "...and I have one too" (both), "I don't have a fever but my
son does" (the son's). Only when the text names nobody before the finding,
or after it in the same sentence, does it fall back on the context engine's
verdict (DEPENDENT / FAMILY scope -> other).

Anything the view leaves out is returned in `set_aside`, so the app can show
it on the review screen instead of dropping it silently.

Owner: Aljoury.
"""

import re

from normalize import normalize
from patient_context_rules import PATIENT_RULES

SELF, OTHER, BOTH, UNKNOWN = "self", "other", "both", "unknown"

FIRST_PERSON = {"i", "me", "my", "myself", "mine"}
THIRD_PERSON = {"he", "she", "him", "his", "her", "hers", "they", "them",
                "their"}
POSSESSIVES = {"my", "our", "his", "her", "their"}
# The relatives the context rules already know, without the "my ": "sister",
# "little one", "granddad"... Read from the same table so the two cannot drift.
RELATIVES = sorted({lit[3:] for lit, cat, _d in PATIENT_RULES
                    if cat in ("FAMILY", "DEPENDENT") and lit.startswith("my ")
                    and "family" not in lit}, key=len, reverse=True)
RELATIVE_RE = re.compile(
    r"\b(?:%s)\s+(?:%s)\b" % ("|".join(POSSESSIVES),
                              "|".join(map(re.escape, RELATIVES))))

# Where one sentence ends. A clause break is not enough: "I feel nauseous
# and dizzy" has no subject after the "and", and the dizziness is still mine.
SENTENCE_BREAK = re.compile(r"[.;?!]")
# Where one clause ends, for the present-tense check below.
CLAUSE_BREAK = re.compile(
    r"[.;,?!]|\b(?:and|but|while|whereas|plus|though|although)\b")

# Two people as one subject: "my son and i both have a cough", "both me and
# my sister", "we both have a fever".
_REL = r"(?:%s)\s+(?:%s)" % ("|".join(POSSESSIVES),
                             "|".join(map(re.escape, RELATIVES)))
TOGETHER_RE = re.compile(
    r"\b(?:(?:i|me)\s+and\s+%s|%s\s+and\s+(?:i|me|myself)|we|us|both of us|"
    r"all of us)\b" % (_REL, _REL))

# What the user says right after a finding, about who else has it. Only a
# bare ellipsis counts: "but i do not feel hot" denies feeling hot, not the
# sister's fever, so the reply has to end the clause.
_GAP = r"^(?:(?!\b(?:i|me|my|myself)\b)[^.;])*?"
_END = r"\s*(?=[,.;?!]|$|\b(?:but|and|though|although)\b)"
# "my sister has a fever BUT I DON'T"
SELF_DENIAL = re.compile(
    _GAP + r"\b(?:(?:i do not|i have not|i am not|not me|not mine|not myself)"
    r"(?:\s+have\s+(?:it|one|that|any|them))?|i have (?:none|neither)"
    r"(?: of them)?)" + _END)
# "...and I HAVE ONE TOO", "my son has no fever BUT I DO"
SELF_HAS = re.compile(
    _GAP + r"\b(?:(?:now )?i (?:have|got|get) (?:it|one|that|them|the same"
    r"(?: thing)?)(?: too| as well)?|i also have (?:it|one|that|them)|"
    r"i do(?: too)?|me too|me as well|so do i|so have i|same here|"
    r"same (?:for|with) me)" + _END)
# "i have a fever LIKE MY SISTER" - both of them.
LIKE_OTHER = re.compile(r"^\s*(?:too |as well )?(?:just )?(?:like|same as)\s+"
                        + _REL + r"\b")
# "I don't have a fever BUT MY SON DOES"
OTHER_HAS = re.compile(
    r"^[^.;]*?\b(?:but |and )?(?:%s|he|she|they)\s+(?:does|do|did|has (?:one|"
    r"it|that|them)|have (?:one|it|them)|got (?:one|it))(?: too| as well)?"
    % _REL + _END)

# Present-tense verbs that make a relative's complaint a current one rather
# than family history: "my sister HAS a fever, not me" against "my mother HAD
# asthma". Only used to decide whether such a finding counts once the user
# says the assessment is for that person.
PRESENT_TENSE = {"is", "are", "has", "have", "keeps", "keep", "cannot",
                 "seems", "looks", "feels", "gets", "started", "began",
                 "woke", "wont", "being", "getting", "acting", "becoming"}


def _clause_start(norm, pos):
    start = 0
    for m in CLAUSE_BREAK.finditer(norm, 0, pos):
        start = m.end()
    return start


def _people(norm, lo, hi):
    """[(start, end, who)] for every subject word between lo and hi."""
    hits = [(m.start(), m.end(), BOTH) for m in TOGETHER_RE.finditer(norm, lo, hi)]
    taken = [(a, b) for a, b, _ in hits]
    for m in RELATIVE_RE.finditer(norm, lo, hi):
        if not any(a <= m.start() < b for a, b in taken):
            hits.append((m.start(), m.end(), OTHER))
            taken.append((m.start(), m.end()))
    for m in re.finditer(r"[\w']+", norm[lo:hi]):
        a, b = lo + m.start(), lo + m.end()
        # The "my" of "my son" is not the user.
        if any(ta <= a < tb for ta, tb in taken):
            continue
        if m.group() in FIRST_PERSON:
            hits.append((a, b, SELF))
        elif m.group() in THIRD_PERSON:
            hits.append((a, b, OTHER))
    return sorted(hits)


def clause_subject(norm, span):
    """
    The nearest person named before the finding: "my mom has a headache, I
    feel nauseous and dizzy" gives the dizziness to "I". With nobody before
    it, the first person named after it in the same sentence: "fever and a
    rash, my son is two". None when the text names nobody.
    """
    s, e = span
    before = _people(norm, 0, s)
    if before:
        return before[-1][2]
    m = SENTENCE_BREAK.search(norm, e)
    after = _people(norm, e, m.start() if m else len(norm))
    return after[0][2] if after else None


def mentions_someone_else(norm):
    return bool(RELATIVE_RE.search(norm)) or any(
        w in THIRD_PERSON for w in re.findall(r"[\w']+", norm))


def subject_of(norm, span, status):
    """
    "self", "other", "both" or "unknown" for one finding. `status` is the
    context engine's verdict on it, BEFORE Layer 1 turns DEPENDENT into
    PRESENT.
    """
    who = clause_subject(norm, span)
    if who:
        return who
    if status in ("dependent", "family"):
        return OTHER
    return UNKNOWN if mentions_someone_else(norm) else SELF


def follow_up(norm, span):
    """
    What is said right after a finding about who else has it:
      "denied"     the user does not   ("...but i do not")
      "self_has"   the user does       ("...and i have one too", "but i do")
      "other_has"  the other person does ("...but my son does")
    """
    rest = norm[span[1]:]
    if SELF_DENIAL.search(rest):
        return "denied"
    if SELF_HAS.search(rest):
        return "self_has"
    if OTHER_HAS.search(rest) or LIKE_OTHER.search(rest):
        return "other_has"
    return None


def present_for_other(norm, span):
    """A relative's finding written in the present tense, not as history."""
    lo = _clause_start(norm, span[0])
    # "my sister has a fever, not me": the comma cut the clause short of the
    # verb, so look back across one break.
    lo = _clause_start(norm, max(0, lo - 1)) if not norm[lo:span[0]].strip() \
        else lo
    words = set(re.findall(r"[\w']+", norm[lo:span[0]]))
    return bool(words & PRESENT_TENSE) and "had" not in words


def combine(a, b):
    if a is None or a == b:
        return b
    if b is None:
        return a
    if UNKNOWN in (a, b):
        return a if b == UNKNOWN else b
    return BOTH


# ---------------------------------------------------------------- the view
def _keep(entry, who):
    subj = entry.get("subject", UNKNOWN)
    if subj in (BOTH, UNKNOWN):
        return True
    return subj == (SELF if who == SELF else OTHER)


def _fill_missing(result):
    """
    Layers 2 and 3 add findings without a `subject`. Label them the same way,
    from where their matched text sits in the sentence.
    """
    norm = result.get("normalized", "")
    for key in ("symptoms", "negated", "excluded", "confirm", "clarify"):
        for f in result.get(key, []):
            if "subject" in f:
                continue
            mt = normalize(f.get("matched_text") or "")
            at = norm.find(mt) if mt else -1
            status = f.get("status") or f.get("reason")
            if at < 0:
                f["subject"] = UNKNOWN
                continue
            span = (at, at + len(mt))
            f["subject"] = subject_of(norm, span, status)
            reply = follow_up(norm, span)
            asserted = key in ("symptoms", "confirm", "clarify")
            if asserted and ((f["subject"] == OTHER and reply == "self_has")
                             or (f["subject"] == SELF
                                 and reply == "other_has")):
                f["subject"] = BOTH
            elif reply:
                f["reply"] = reply
            if status == "family" and f["subject"] == OTHER:
                f["present_for_other"] = present_for_other(norm, span)


def _strip(entry, *keys):
    return {k: v for k, v in entry.items() if k not in keys}


def for_subject(result, who, vocab=None):
    """
    The result with only the findings of the person the assessment is for.
    Pass Layer 1's `vocab` so red flags can be rebuilt for what is kept.

    who = "self"   the user's own findings. Somebody else's finding the user
                   explicitly said they do NOT have ("...but I don't") is
                   recorded as denied, because it is. One the user said they
                   have as well ("my son has no fever but I do") is theirs.
    who = "other"  the other person's findings. A present-tense complaint
                   about them that the context engine filed as FAMILY ("my
                   sister has a fever, not me") is theirs, and so is one the
                   user denied for themselves but gave to them ("I don't have
                   a fever but my son does").

    Whatever is left out goes in `set_aside`, for the app to show.
    """
    if who not in (SELF, OTHER):
        raise ValueError(f"who must be 'self' or 'other', not {who!r}")
    out = dict(result)
    _fill_missing(out)
    them = OTHER if who == SELF else SELF
    # The reply that hands a finding to the person being assessed.
    gives_it = "self_has" if who == SELF else "other_has"

    symptoms = [s for s in out.get("symptoms", []) if _keep(s, who)]
    have = {s["column"] for s in symptoms}
    negated = []
    for n in out.get("negated", []):
        if n.get("reply") == gives_it and n.get("subject") in (them, UNKNOWN):
            if n["column"] not in have:
                symptoms.append(_strip(n, "status"))
                have.add(n["column"])
        elif _keep(n, who):
            negated.append(n)
    excluded = []
    restored = []
    for x in out.get("excluded", []):
        if x["column"] in have:
            continue
        if who == SELF and x.get("subject") == OTHER \
                and x.get("reply") == "self_has":
            # "my sister had a fever last week and now i have one"
            restored.append(x)
        elif who == OTHER and x.get("status") == "family" \
                and x.get("subject") == OTHER and x.get("present_for_other"):
            restored.append(x)
        elif _keep(x, who):
            excluded.append(x)

    if who == SELF:
        for f in out.get("symptoms", []) + out.get("excluded", []):
            if f.get("subject") == OTHER and f.get("reply") == "denied" \
                    and f["column"] not in have \
                    and f["column"] not in {n["column"] for n in negated}:
                negated.append(_strip(f, "method", "score", "status",
                                      "family"))

    restored_clarify = []
    asked = {c.get("family") for c in out.get("clarify", []) if _keep(c, who)}
    for x in restored:
        entry = _strip(x, "status")
        fam = entry.pop("family", None)
        if fam is None:
            symptoms.append(entry)
            have.add(x["column"])
            continue
        # "my dad has chest pain, not me" excluded every member of the
        # chest-pain family. Restored, it is the family's question again,
        # never five asserted kinds of chest pain at once.
        if fam in asked:
            continue
        asked.add(fam)
        members = sorted(m["column"] for m in result.get("excluded", [])
                         if m.get("family") == fam)
        restored_clarify.append({
            "matched_text": entry["matched_text"],
            "candidates": members,
            "question": (vocab[members[0]].get("question")
                         if vocab else None) or "Which of these is closest?",
            "family": fam,
            "subject": entry["subject"]})

    out["symptoms"] = symptoms
    out["negated"] = [n for n in negated if n["column"] not in have]
    out["excluded"] = excluded
    out["confirm"] = [c for c in out.get("confirm", []) if _keep(c, who)]

    # Everything left out is SHOWN, never silently dropped, for the same
    # reason a denial is shown: the subject is our reading of the sentence,
    # and the user is the one who can correct it. The app lists these on the
    # review screen and asks about each one.
    settled = have | {n["column"] for n in out["negated"]}
    set_aside = []
    for group in ("symptoms", "confirm"):
        for f in result.get(group, []):
            if _keep(f, who) or f["column"] in settled:
                continue
            settled.add(f["column"])
            set_aside.append({k: v for k, v in f.items()
                              if k not in ("method", "score", "question",
                                           "status", "reason")})
    # A question about the other person's symptom ("which kind of chest
    # pain?") is set aside as the symptom it asks about.
    for c in result.get("clarify", []):
        if _keep(c, who) or c.get("family") in asked:
            continue
        asked.add(c.get("family"))
        set_aside.append({
            "column": c.get("family"), "family": c.get("family"),
            "candidates": c.get("candidates", []),
            "matched_text": c.get("matched_text"),
            "display": (c.get("matched_text") or c.get("family")
                        or "").capitalize(),
            "layer": c.get("layer", "lexicon"), "subject": c.get("subject")})
    out["set_aside"] = set_aside
    out["clarify"] = [c for c in out.get("clarify", []) if _keep(c, who)] \
        + restored_clarify

    # Red flags follow the findings. With the vocabulary they are rebuilt, so
    # a finding restored from `excluded` raises its flag too: "my dad has
    # chest pain, not me", answered "for my dad", must still escalate.
    if vocab is not None:
        out["red_flags"] = [
            {"column": s["column"], "level": vocab[s["column"]]["red_flag"],
             "reason": vocab[s["column"]]["red_flag_reason"],
             "matched_text": s.get("matched_text"),
             "display": s.get("display", s["column"])}
            for s in symptoms
            if vocab.get(s["column"], {}).get("red_flag")]
    else:
        out["red_flags"] = [f for f in out.get("red_flags", [])
                            if f["column"] in have]

    gone = ({s["column"] for s in result.get("symptoms", [])}
            | {c.get("family") for c in result.get("clarify", [])}) \
        - have - {c.get("family") for c in out["clarify"]}
    out["modifiers"] = [m for m in out.get("modifiers", [])
                        if m.get("column") not in gone]

    out["n_actionable"] = len(symptoms) + len(out["clarify"]) \
        + len(out["confirm"])
    out["confirm_subject"] = False
    out["subject"] = who
    return out
