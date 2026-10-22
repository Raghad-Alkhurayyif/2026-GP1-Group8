"""
Small shared facts and helpers, used at RUNTIME.

WHY THIS FILE EXISTS. Three things the matcher needs at runtime used to live
inside one-time builder scripts, so a deployed server imported
`build_vocabulary.py` (to split a column name) and `build_display_labels.py`
(to read a CSV), and that one in turn imported `seed_lexicon.py`. Nothing broke
- none of them pull in a heavy library - but it made a simple question
impossible to answer: which files does the server actually need?

Now the answer is clean. The builders and the matcher both import from here,
and the builders are not needed at runtime at all.

Owner: Aljoury.
"""

import csv
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data"

# The sensations a column name can end with, longest first so that
# "stiffness or tightness" is tried before "sore" would match inside it.
SENSATIONS = [
    "stiffness or tightness",
    "cramps or spasms",
    "lump or mass",
    "swelling",
    "weakness",
    "numbness",
    "bleeding",
    "redness",
    "burning",
    "discharge",
    "itch",
    "pain",
    "sore",
]

# Words that narrow a body site without changing which part of the body it is.
# "upper abdominal" and "sharp abdominal" are both the abdomen.
QUALIFIERS = {"sharp", "burning", "upper", "lower", "low"}

# Columns written in clinical language. A user will never type these words, so
# each one is unreachable without a lexicon entry. Hand-made: it is a
# judgement about what a patient says, not a property of the data.
JARGON = {
    "anorexia", "apnea", "arthralgia", "ascites", "coryza", "cyanosis",
    "diaphoresis", "dysphagia", "dyspnea", "dysuria", "edema", "epistaxis",
    "hematemesis", "hematuria", "hemoptysis", "hesitancy", "jaundice",
    "lacrimation", "lymphedema", "melena", "myalgia", "pallor", "paresthesia",
    "polyuria", "pruritus", "regurgitation", "syncope", "vertigo",
}


def split_compositional(name):
    """
    Return (body_site, sensation) if the column is site + sensation, else
    (None, None).

        "knee swelling"        -> ("knee", "swelling")
        "lower abdominal pain" -> ("lower abdominal", "pain")
        "fever"                -> (None, None)
    """
    for s in SENSATIONS:
        if name.endswith(" " + s):
            return name[: -len(s)].strip(), s
    return None, None


def anatomical_root(site):
    """Drop qualifier words so 'upper abdominal' and 'sharp abdominal' share a root."""
    toks = [t for t in site.split() if t not in QUALIFIERS]
    return " ".join(toks) if toks else site


def load_display_labels(path=None):
    """{column: the words to put on a button}. Built by build_display_labels.py."""
    path = path or DATA / "display_labels.csv"
    out = {}
    with open(path, newline="", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            out[r["column"]] = r["display"]
    return out


if __name__ == "__main__":
    for name in ("knee swelling", "lower abdominal pain", "sharp chest pain",
                 "fever", "hand or finger stiffness or tightness"):
        site, sens = split_compositional(name)
        root = anatomical_root(site) if site else "-"
        print(f"  {name:<40} site={site!s:<24} sensation={sens!s:<10} root={root}")
    print(f"\n  {len(load_display_labels())} display labels loaded")


# The member of an ambiguity family that names the whole REGION rather than a
# part of it. The families exist because their members point to measurably
# different diseases, so the question is worth asking when we do not know the
# part - but "my knee is really sore" was being answered with "which part: hip,
# knee, ankle, foot, or the leg generally?", which asks the person something
# they just said. Naming the generic member lets the matcher tell the two cases
# apart: "leg" stays a question, "knee" does not.
FAMILY_GENERIC = {
    "lower-limb-pain": "leg pain",
    "upper-limb-pain": "arm pain",
}

# Words that carry no part-of-the-body meaning, so they can never be what makes
# one family member different from another. Without this, `foot or toe pain`
# would count "or" as distinguishing and match almost any sentence.
FAMILY_GLUE = {"or", "and", "of", "the", "a", "in", "pain", "ache"}

# Parts of the body a family member covers but is not NAMED after.
#
# The distinguishing words are derived from the column name, which works while
# patients use the column's own vocabulary and fails the moment they do not:
# `foot or toe pain` yields {"foot", "toe"}, so "heel pain" was being met with
# "which part - hip, knee, ankle, foot, or the leg generally?". The heel is
# part of the foot and the person had already said so.
#
# These names also override the generic-member rule above, and only these. The
# rule exists so that "my leg hurts" stays a question, which is right - the leg
# generally is exactly the vague case. But "my calf hurts" is not vague. The
# calf resolves to `leg pain` because the vocabulary has no finer column for
# it, not because the person was unclear, so the question has been answered.
# Single words only: the matcher tests word membership, so a two-word entry
# would never fire. `groin` is deliberately absent - `groin pain` is a column
# in its own right and must not be folded into the leg.
#
# Every word here is already a site the compositional matcher knows, with the
# right anatomical root. That is the point: the site table could place "heel
# pain" on the foot all along, and then the family question asked which part
# of the leg it was, because the question's own word list is derived from the
# column NAME and the heel is not in it. Listing a part the site table does
# not know would do nothing - there would be no match to resolve - so new
# entries belong in the site table first and here second.
FAMILY_SYNONYMS = {
    ("lower-limb-pain", "foot or toe pain"):
        {"heel"},
    ("lower-limb-pain", "leg pain"):
        {"calf", "calves", "shin", "thigh"},
    ("lower-limb-pain", "knee pain"):
        {"kneecap"},
    ("upper-limb-pain", "hand or finger pain"):
        {"thumb", "knuckle"},
    ("upper-limb-pain", "arm pain"):
        {"forearm"},
}
