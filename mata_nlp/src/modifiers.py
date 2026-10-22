"""
SEVERITY, ONSET, DURATION, PROGRESSION - the words the 327 columns cannot hold.

THE PROBLEM. Every one of the 327 symptom columns is a yes/no switch. So for

    "severe stomach pain, my belly is rigid"

Layer 1 can say `sharp abdominal pain = 1` and nothing else. The words "severe"
and "rigid" - the entire reason this is an emergency rather than indigestion -
have nowhere to go. There is no `severe abdominal pain` column and no severity
field anywhere in the dataset. Same for suddenness: `diminished vision` cannot
tell "my vision went suddenly" (a stroke) from "my vision has got worse over
two years" (glasses).

The clinic layer already knows this and compensates by running its own regexes
over the RAW TEXT, looking for "severe abdominal pain", "sudden vision loss",
"fever for more than 3 days". That works, and it means the text gets parsed
twice by two components that can drift apart - which is exactly the problem the
single red-flag column was created to fix.

WHAT THIS DOES. Layer 1 has already read the sentence, so it reports what it
saw. The clinic layer can then combine structured facts:

    column `sharp abdominal pain`  +  severity `severe`   -> escalate
    column `diminished vision`     +  onset `suddenly`    -> escalate
    column `fever`                 +  duration 4 days     -> escalate

rather than re-reading the text. One component reads words; everyone else reads
facts.

WHAT THIS IS NOT. It does not decide anything. A severity word is reported, not
acted on - whether "severe abdominal pain" means the emergency department is a
clinical judgement, and it belongs in the clinic layer with a clinician's name
on it. This file only answers "what did the person actually say".

Each modifier is attached to the NEAREST symptom in the sentence, by character
distance, and carries its own text so the clinic layer can show the user why it
escalated.

Owner: Aljoury.
"""

import re

SEVERITY = "severity"
ONSET = "onset"
DURATION = "duration"
PROGRESSION = "progression"

# (pattern, kind, value) - `value` is the normalised reading, which is what a
# rule should branch on; the matched text is kept for showing the user.
#
# `high` and `low` are deliberately coarse. A numeric pain score would be false
# precision: nobody types "7/10" and a three-way split is all the wording
# supports.
PATTERNS = [
    # ---- severity, high -------------------------------------------------
    (r"\bsevere(?:ly)?\b", SEVERITY, "high"),
    (r"\bexcruciating\b", SEVERITY, "high"),
    (r"\bunbearable\b", SEVERITY, "high"),
    (r"\bagonis(?:ing|ed)\b|\bagoniz(?:ing|ed)\b", SEVERITY, "high"),
    (r"\bworst\b.{0,20}\b(?:ever|of my life|pain)\b", SEVERITY, "high"),
    (r"\bthe worst (?:pain|headache|i have ever)\b", SEVERITY, "high"),
    (r"\bcrushing\b", SEVERITY, "high"),
    (r"\bintense\b", SEVERITY, "high"),
    (r"\bextremely\b", SEVERITY, "high"),
    (r"\bkilling me\b", SEVERITY, "high"),
    (r"\bcannot (?:stand|bear|take) (?:it|the pain)\b", SEVERITY, "high"),
    (r"\bdoubled over\b", SEVERITY, "high"),
    (r"\bscreaming\b", SEVERITY, "high"),
    (r"\b10 out of 10\b|\b9 out of 10\b", SEVERITY, "high"),
    # ---- severity, moderate ---------------------------------------------
    (r"\bmoderate(?:ly)?\b", SEVERITY, "moderate"),
    (r"\bquite bad\b|\bpretty bad\b|\breally bad\b", SEVERITY, "moderate"),
    (r"\bbad enough to\b", SEVERITY, "moderate"),
    # ---- severity, low ---------------------------------------------------
    (r"\bmild(?:ly)?\b", SEVERITY, "low"),
    (r"\bslight(?:ly)?\b", SEVERITY, "low"),
    (r"\ba (?:bit|little)\b", SEVERITY, "low"),
    (r"\bnot (?:too|that) bad\b", SEVERITY, "low"),
    (r"\bmanageable\b", SEVERITY, "low"),
    (r"\bbarely\b", SEVERITY, "low"),
    (r"\bniggl(?:e|ing)\b|\bdull\b", SEVERITY, "low"),

    # ---- onset, sudden ---------------------------------------------------
    # The single most important group here. "Sudden" changes the triage level
    # for vision loss, weakness, headache and chest pain, and no column can
    # carry it.
    (r"\bsudden(?:ly)?\b", ONSET, "sudden"),
    (r"\ball of a sudden\b", ONSET, "sudden"),
    (r"\bout of nowhere\b", ONSET, "sudden"),
    (r"\bout of the blue\b", ONSET, "sudden"),
    (r"\bcame on (?:fast|quickly|suddenly|within)\b", ONSET, "sudden"),
    (r"\bstarted (?:suddenly|all at once)\b", ONSET, "sudden"),
    (r"\bin an instant\b|\bwithin (?:seconds|minutes)\b", ONSET, "sudden"),
    (r"\bone (?:minute|moment) .{0,30}\bthe next\b", ONSET, "sudden"),
    # ---- onset, gradual --------------------------------------------------
    (r"\bgradual(?:ly)?\b", ONSET, "gradual"),
    (r"\bslowly\b|\bover (?:weeks|months|years)\b", ONSET, "gradual"),
    (r"\bcrept up\b|\bbuilt up slowly\b", ONSET, "gradual"),

    # ---- progression -----------------------------------------------------
    (r"\bgetting worse\b|\bgot worse\b|\bworsening\b", PROGRESSION, "worse"),
    (r"\bspreading\b|\bspread to\b", PROGRESSION, "worse"),
    (r"\bworse (?:than|each|every) (?:yesterday|day|time)\b", PROGRESSION, "worse"),
    (r"\bnot (?:getting )?(?:any )?better\b|\bwill not go away\b",
     PROGRESSION, "persistent"),
    (r"\bstill (?:there|here|going on)\b|\bhas not shifted\b", PROGRESSION, "persistent"),
    (r"\bcomes and goes\b|\bon and off\b|\bin waves\b", PROGRESSION, "intermittent"),
    (r"\bgetting better\b|\beasing (?:off|up)\b|\bimproving\b", PROGRESSION, "better"),
]

_COMPILED = [(re.compile(p), kind, value) for p, kind, value in PATTERNS]

# Duration is parsed rather than listed, because the NUMBER is the point:
# "fever for 2 days" and "fever for 3 weeks" are different triage decisions.
_NUMBER = {
    "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
    "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "a few": 3,
    "couple of": 2, "couple": 2, "several": 4,
}
_UNIT_HOURS = {"hour": 1, "hours": 1, "day": 24, "days": 24,
               "week": 168, "weeks": 168, "month": 720, "months": 720,
               "year": 8760, "years": 8760}

_DURATION = re.compile(
    r"\b(?:for|over|since|in)\s+(?:the\s+(?:past|last)\s+)?"
    r"(\d+|a few|couple of|couple|several|a|an|one|two|three|four|five|six|"
    r"seven|eight|nine|ten)\s+"
    r"(hour|hours|day|days|week|weeks|month|months|year|years)\b")

# "since Monday", "since yesterday" - a real duration the patient gives, but
# one this file cannot turn into a number without knowing today's date. The
# app knows the date; Layer 1 does not, so it reports the words and stops.
_SINCE_NAMED = re.compile(
    r"\bsince\s+(yesterday|this morning|last night|monday|tuesday|wednesday|"
    r"thursday|friday|saturday|sunday)\b")


def find(text):
    """
    [{kind, value, text, span}] - every modifier in the normalised text.

    `value` is what a rule should branch on. `text` is what to show the user.
    """
    out = []
    for pattern, kind, value in _COMPILED:
        for m in pattern.finditer(text):
            out.append({"kind": kind, "value": value, "text": m.group().strip(),
                        "span": (m.start(), m.end())})

    for m in _DURATION.finditer(text):
        n_raw, unit = m.group(1), m.group(2)
        n = int(n_raw) if n_raw.isdigit() else _NUMBER.get(n_raw, 1)
        hours = n * _UNIT_HOURS[unit]
        out.append({"kind": DURATION, "value": hours, "text": m.group().strip(),
                    "span": (m.start(), m.end())})

    for m in _SINCE_NAMED.finditer(text):
        out.append({"kind": DURATION, "value": None, "text": m.group().strip(),
                    "span": (m.start(), m.end())})

    # Collapse OVERLAPPING readings of the same thing, longest first. Two
    # patterns can both fire on one phrase - "the worst headache" and "worst
    # headache of my life" both say severity high - and reporting both would
    # make the clinic layer count one complaint twice.
    out.sort(key=lambda d: (-(d["span"][1] - d["span"][0]), d["span"][0]))
    kept = []
    for d in out:
        s, e = d["span"]
        if any(d["kind"] == k["kind"]
               and not (e <= k["span"][0] or s >= k["span"][1])
               for k in kept):
            continue
        kept.append(d)
    kept.sort(key=lambda d: d["span"][0])
    return kept


def attach(mods, symptoms):
    """
    Give each modifier the nearest symptom, by character distance.

    `symptoms` is [(column, (start, end))] in the same coordinates as the text
    the modifiers were found in. A modifier with no symptom within reach keeps
    `column: None` - it is still reported, because "severe" on its own is worth
    showing even when Layer 1 could not place the symptom it described.
    """
    out = []
    for m in mods:
        ms, me = m["span"]
        best = None
        for col, (ss, se) in symptoms:
            gap = 0 if (ms < se and ss < me) else min(abs(ms - se), abs(ss - me))
            if best is None or gap < best[0]:
                best = (gap, col)
        # 60 characters is about one clause. Beyond that the two are unrelated
        # and guessing a link would be worse than reporting none.
        col = best[1] if best is not None and best[0] <= 60 else None
        out.append({**m, "column": col})
    return out


if __name__ == "__main__":
    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from normalize import normalize

    cases = [
        "severe stomach pain and my belly feels rigid",
        "my vision went suddenly in one eye",
        "my vision has got worse over years",
        "i have had a fever for 4 days and it is getting worse",
        "mild headache, comes and goes",
        "the worst headache of my life, came on suddenly",
        "a bit of a cough for two weeks",
        "chest pain since monday, not getting any better",
        "i have a cough",
    ]
    for c in cases:
        n = normalize(c)
        mods = find(n)
        print(f"\n{c}")
        if not mods:
            print("    (none)")
        for m in mods:
            print(f"    {m['kind']:<12} {m['value']!s:<12} '{m['text']}'")
