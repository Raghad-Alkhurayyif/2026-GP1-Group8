"""
LOOSE MATCHING - the same words, in a different order, with filler between.

The exact and synonym passes need a phrase to appear contiguously. Real
sentences do not cooperate:

    phrase "swollen tonsils"   text "my tonsils look swollen and red"
    phrase "heart racing"      text "my heart keeps racing for no reason"
    phrase "croaky voice"      text "my voice has gone croaky"
    phrase "heavy periods"     text "my periods are really heavy now"

Every one of those is the user saying exactly what the phrase says. Writing a
new lexicon entry for each word order is endless; matching on the SET of
content words within a tight window is not.

Five guards keep it from over-matching. The first three were there from the
start; the last two were added after the loose matcher produced `hand or finger
swelling` from "a rash on my hands that itches like crazy; NO SWELLING of my
lips" - pairing "hands" with a "swelling" that was both in another clause and
inside a denial.

  * EVERY content word of the phrase must be present. Not most - all.
  * They must fall inside a window scaled to the phrase length, so words from
    two different complaints are never combined.
  * Phrases with only one content word are skipped - those are already handled
    by the exact pass, and a one-word "set" match is just a word match.
  * The window may not contain a clause break (, ; .) - words either side of
    one belong to two different complaints.
  * The window may not contain a denial word the phrase itself does not have,
    or the match swallows the very thing that negates it.

Light suffix stripping is applied, and only here: "itchy" and "itches" have to
meet, while the exact pass stays strict so that `burning` and `burn` remain
separable.

A SIXTH GUARD WAS TRIED AND REVERTED, October 2026. The loose matcher pairs
`feel down` with "i feel little shocks down my spine" and records DEPRESSION -
also on "i feel the swelling going down" and "i feel better lying down". The
window limit cannot separate those from "my periods are really heavy now",
because both put two words between the phrase's words; what differs is whether
those words are filler or another symptom.

Requiring the gap to be grammatical filler fixed all four false positives and
kept the four cases this matcher exists for, but cost 6 of the 173 regression
sentences and 4 points of gold-set recall, because the filler list cannot be
written by hand without excluding ordinary English. It was reverted rather than
tuned: the gold set had already been scored by then, so every further
adjustment would have been fitted to data that is spent. The false positive is
reported as a limitation in the project report instead.

If it is picked up again, the thing to try is a real stopword list rather than
a hand-written one, measured against all four gates before anything else.

Owner: Aljoury.
"""

# Deliberately short. Dropping too much turns a two-word phrase into a
# one-word one, which is then skipped.
STOPWORDS = {
    "my", "the", "a", "an", "is", "are", "am", "was", "were", "i", "in", "of",
    "and", "to", "it", "its", "has", "have", "had", "been", "be", "that",
    "this", "for", "with", "on", "at", "when", "so", "very", "really", "me",
    "or", "any", "some", "there", "here", "ive", "im",
    # Possessives are filler. Without these, "tugging at HIS ear" cannot meet
    # the phrase "tugging at HER ear".
    "his", "her", "their", "your", "our", "hers", "theirs",
    # Pure filler. "spotting WHILE pregnant" could not meet "spotting and im
    # 10 weeks pregnant" until these were dropped.
    "while", "during", "lately", "constantly", "quite",
    "about", "every", "all",
    # NOT "lot" or "bit" - those carry quantity. Dropping "lot" reduced
    # "drinking a lot of water" to {drink, water}, which then matched "I can
    # still DRINK WATER" and recorded thirst for someone saying the opposite.
}

# A loose match may not reach across these: they end a clause, and words from
# two different clauses are two different complaints. "a rash on my hands that
# itches like crazy ; NO SWELLING of my lips" produced `hand or finger
# swelling` by pairing "hands" with a "swelling" that was both in another
# clause and inside a denial.
CLAUSE_BREAKS = {",", ";", "."}

# Nor may it swallow a denial word that its own phrase does not contain.
NEGATORS_IN_TEXT = {"no", "not", "cannot", "never", "without", "nothing"}

SCORE_LOOSE = 0.78

# A SEVENTH GUARD, October 2026 - the one the sixth was reaching for.
#
# The sixth guard asked whether the words BETWEEN a phrase's words were
# filler. That is unanswerable without a frequency list, which is why it was
# reverted. This guard asks a different and much easier question: are the
# phrase's OWN words distinctive enough to be worth matching loosely at all?
#
# `seeing things` matched "can you SEE the last THING i typed" and recorded
# DELUSIONS OR HALLUCINATIONS for somebody asking whether their message
# arrived. `feel down` matched "i feel little shocks DOWN my spine", "i feel
# the swelling going DOWN" and "i feel better lying DOWN" and recorded
# DEPRESSION three times. All four are the same failure: every content word in
# the phrase is a generic English word, so the pair carries no clinical signal
# on its own and the idiom's meaning lives entirely in the adjacency that
# loose matching is designed to ignore.
#
# Contrast the four cases this matcher exists for - `heavy periods`,
# `spotting while pregnant`, `tugging at her ear`, `hearing voices`. Each has
# at least one word a person would only use about a body or a symptom:
# period, pregnant, ear, voice. That asymmetry is the whole rule.
#
# So: refuse to loose-match a phrase when EVERY one of its content words is
# generic. Applied mechanically across the lexicon at index-build time, never
# per sentence - the criterion is a property of the phrase, so it cannot be
# fitted to a particular false positive.
#
# Exact matching is untouched. "i am seeing things" and "i feel down" still
# match, because they match exactly. Only the fuzzy-across-a-gap path closes.
GENERIC_WORDS = {
    # Generic perception and cognition verbs.
    "see", "saw", "look", "watch", "hear", "listen", "feel", "think", "know",
    "notice", "seem", "sound", "tell", "say", "ask", "wonder",
    # Generic action verbs.
    "go", "goe", "come", "get", "got", "make", "take", "put", "give", "keep",
    "let", "turn", "do", "doe", "did", "use", "want", "need", "try", "start",
    "stop", "happen", "bother", "last", "stay",
    # Generic nouns and adverbs that carry no clinical content.
    "thing", "stuff", "bit", "time", "day", "way", "kind", "sort", "lot",
    "down", "up", "out", "off", "over", "back", "away", "around", "again",
    "much", "many", "more", "most", "less", "well", "better", "worse",
    "good", "bad", "fine", "okay", "ok", "normal", "weird", "funn", "odd",
    "strange", "right", "left", "little", "big", "small", "long", "short",
    "new", "old", "same", "other", "next", "first", "today", "now",
}


def loose_unsafe(phrase):
    """
    True when a phrase must not be matched loosely - see GENERIC_WORDS above.

    A phrase qualifies only if EVERY content word is generic. One distinctive
    word is enough to keep it, which is why `hearing voices` survives and
    `hearing things` does not.
    """
    cw = [stem(w) for w in content_words(phrase)]
    return bool(cw) and all(w in GENERIC_WORDS for w in cw)


def stem(word):
    """Strip one common suffix, if what is left is still a real-looking word."""
    w = word
    for suf in ("ing", "es", "ed", "s", "y"):
        if w.endswith(suf) and len(w) - len(suf) >= 3:
            return w[: -len(suf)]
    return w


def content_words(phrase):
    return [w for w in phrase.split() if w not in STOPWORDS]


class LooseMatcher:
    def __init__(self, phrases):
        """`phrases` maps a normalised phrase -> (column, kind)."""
        self.index = []           # (stem set, phrase, column, n content words)
        self.refused = []         # phrases held back by the seventh guard
        for p, (col, _kind) in phrases.items():
            cw = content_words(p)
            if len(cw) < 2:
                continue
            # Seventh guard. Kept as a list rather than dropped silently, so
            # `python3 -c "...LooseMatcher(...).refused"` shows exactly which
            # phrases lost their loose path and the choice stays auditable.
            if loose_unsafe(p):
                self.refused.append((p, col))
                continue
            stems = frozenset(stem(w) for w in cw)
            if len(stems) < 2:    # e.g. "aches and aching" collapses to one
                continue
            own_neg = bool(set(p.split()) & NEGATORS_IN_TEXT)
            self.index.append((stems, p, col, len(cw), own_neg))
        # Longest first: a 3-word phrase is more specific than a 2-word one.
        self.index.sort(key=lambda r: -r[3])

    def match(self, text, taken=None):
        """
        Find loose matches in `text`, skipping character ranges in `taken`.

        Returns [(start, end, column, phrase, score)] with no two results
        overlapping, longest phrase first.
        """
        words, pos = [], []
        i = 0
        for w in text.split():
            i = text.index(w, i)
            words.append(w)
            pos.append((i, i + len(w)))
            i += len(w)
        stems = [stem(w) for w in words]
        where = {}
        for idx, s in enumerate(stems):
            where.setdefault(s, []).append(idx)

        used = [False] * len(words)
        if taken:
            for idx, (s, e) in enumerate(pos):
                if any(not (e <= ts or s >= te) for ts, te in taken):
                    used[idx] = True

        out = []
        for want, phrase, column, n, own_neg in self.index:
            if not all(s in where for s in want):
                continue
            hit = self._tight_window(want, where, n, used, words, own_neg)
            if hit is None:
                continue
            lo_i, hi_i = hit
            for k in range(lo_i, hi_i + 1):
                used[k] = True
            out.append((pos[lo_i][0], pos[hi_i][1], column, phrase, SCORE_LOOSE))
        return out

    @staticmethod
    def _tight_window(want, where, n, used, words=None, own_neg=False):
        """
        Pick one position per wanted stem so the span is as short as possible,
        and reject it if the words are too far apart to be one complaint.
        """
        limit = max(6, 2 * n + 3)
        options = [sorted(p for p in where[s] if not used[p]) for s in want]
        if any(not o for o in options):
            return None

        # Anchor on the rarest stem, then take the nearest occurrence of each
        # other stem. Cheap, and good enough for phrases of two to five words.
        anchor_i = min(range(len(options)), key=lambda k: len(options[k]))
        best = None
        for a in options[anchor_i]:
            picked = [a]
            for k, opt in enumerate(options):
                if k == anchor_i:
                    continue
                picked.append(min(opt, key=lambda p: abs(p - a)))
            lo, hi = min(picked), max(picked)
            if hi - lo + 1 > limit:
                continue
            if words is not None:
                span = words[lo:hi + 1]
                if any(w in CLAUSE_BREAKS for w in span):
                    continue          # the words sit in two different clauses
                if not own_neg and any(w in NEGATORS_IN_TEXT for w in span):
                    continue          # a denial got swallowed into the match
            if best is None or (hi - lo) < (best[1] - best[0]):
                best = (lo, hi)
        return best


if __name__ == "__main__":
    import csv
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from normalize import normalize

    data = Path(__file__).resolve().parent.parent / "data"
    phrases = {}
    with open(data / "vocabulary.csv", newline="", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            if r["keep"] == "1" and r["alive"] == "1":
                phrases[normalize(r["column"])] = (r["column"], "exact")
    with open(data / "lexicon.csv", newline="", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            if r["status"] == "active":
                phrases.setdefault(normalize(r["phrase"]), (r["column"], "synonym"))

    M = LooseMatcher(phrases)
    print(f"{len(M.index)} multi-word phrases indexed\n")

    cases = [
        ("my tonsils look swollen and red", "swollen or red tonsils"),
        ("my heart keeps racing for no reason", "palpitations"),
        ("my voice has gone croaky", "hoarse voice"),
        ("my periods are really heavy now", "heavy menstrual flow"),
        ("my nails have gone ridged and brittle", "irregular appearing nails"),
        ("my scalp is so itchy", "itchy scalp"),
        ("i have zero energy", "fatigue"),
        ("the weather has been awful", "(nothing)"),
        ("i work night shifts and have two kids", "(nothing)"),
    ]
    for text, expect in cases:
        n = normalize(text)
        hits = M.match(n)
        got = sorted({c for _, _, c, _, _ in hits}) or ["(nothing)"]
        mark = "ok " if expect in got or (expect == "(nothing)" and got == ["(nothing)"]) else "  ?"
        print(f"{mark} {text!r}")
        print(f"      -> {got}")
