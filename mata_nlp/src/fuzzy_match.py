"""
SPELLING CORRECTION - word level, against this project's own vocabulary.

A typo is a WORD-level event. An earlier version fuzzy-matched whole phrases
and produced nonsense: "my leg is red" became `redness in ear` (3 edits from
"my ear is red") and "crushing" became `cough` (2 edits from "coughing"). The
user had not mistyped anything - they wrote something else.

So this corrects individual words and then lets the normal matcher run again.
Two rules keep it honest:

  * ONE edit only, for words up to 11 characters. Two edits is where unrelated
    medical words start colliding: "crushing" is 2 edits from "coughing".
  * Transpositions count as one edit, not two. "headcahe" -> "headache" is the
    single most common kind of typo and plain Levenshtein scores it as 2.

Why not a general spellchecker: correcting against an English dictionary turns
`melena` into "melon" and `dysuria` into "dysentery", silently. The project's
own vocabulary is the dictionary.

Uses rapidfuzz when installed, otherwise a bounded Damerau-Levenshtein from
the standard library.

Owner: Aljoury.
"""

import gzip
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

# Words shorter than this are left alone - at 4 characters nearly everything
# is one edit from something else ("ear"/"eat"/"era", "pain"/"rain"/"pail").
MIN_LEN = 5

# NEVER correct these. The dictionary is a MEDICAL vocabulary, so any ordinary
# English word that happens to sit one edit from a medical term gets mangled:
# "mother" became "other" (from "not growing like other children"), which also
# destroyed the word ConText needs to spot family history.
#
# Everything a context rule depends on is protected, plus the common words a
# patient sentence is built from.
PROTECTED = {
    # family - ConText reads these
    "mother", "father", "brother", "sister", "daughter", "son", "wife",
    "husband", "child", "children", "baby", "friend", "mum", "mom", "dad",
    "grandmother", "grandfather", "parents", "family", "partner", "aunt",
    "uncle", "cousin", "nephew", "niece",
    # time - ConText reads these
    "today", "tonight", "yesterday", "week", "weeks", "month", "months",
    "year", "years", "night", "nights", "morning", "evening", "day", "days",
    "hour", "minute", "minutes", "ago", "since", "before", "after",
    "recently", "lately", "always", "never", "often", "sometimes", "usually",
    "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
    "sunday", "january", "february", "march", "april", "june", "july",
    "august", "september", "october", "november", "december",
    # certainty - ConText reads these
    "worried", "worry", "think", "thought", "wonder", "wondering", "maybe",
    "could", "might", "sure", "unsure", "possibly", "probably", "seems",
    # ordinary words a complaint is built from
    "about", "other", "another", "around", "because", "been", "being",
    "better", "worse", "every", "going", "happens", "having", "hours",
    "little", "makes", "making", "much", "myself", "really", "right",
    "should", "something", "still", "their", "there", "these",
    "thing", "things", "those", "through", "until", "very", "want", "went",
    "were", "what", "when", "where", "which", "while", "would", "please",
    "doctor", "hospital", "clinic", "nurse", "appointment", "medicine",
    "tablet", "tablets", "work", "working", "school", "sleep", "eating",
    "drinking", "walking", "sitting", "standing", "moving", "started",
    "starts", "stopped", "getting", "gotten", "comes", "coming", "goes",
}

try:
    from rapidfuzz.distance import DamerauLevenshtein as _RF
    _BACKEND = "rapidfuzz"
except ImportError:
    _RF = None
    _BACKEND = "stdlib"


def backend():
    return _BACKEND


def _transposed(a, b):
    """
    True when `a` becomes `b` by swapping one pair of adjacent letters.

    "headcahe" -> "headache". Distinguished from a substitution because a
    transposition uses the same letters, so reversing the swap is forced
    rather than guessed - there is nothing to get wrong.
    """
    if len(a) != len(b) or a == b:
        return False
    d = [i for i, (x, y) in enumerate(zip(a, b)) if x != y]
    return (len(d) == 2 and d[1] == d[0] + 1
            and a[d[0]] == b[d[1]] and a[d[1]] == b[d[0]])


def edit_budget(n):
    """One edit, except for long words where two is still safe."""
    if n < MIN_LEN:
        return 0
    return 1 if n <= 11 else 2


def _distance(a, b, cutoff):
    """Damerau-Levenshtein, abandoning the comparison once it passes cutoff."""
    if _RF is not None:
        d = _RF.distance(a, b, score_cutoff=cutoff)
        return d if d <= cutoff else cutoff + 1

    if abs(len(a) - len(b)) > cutoff:
        return cutoff + 1
    prev2 = None
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        best = i
        for j, cb in enumerate(b, 1):
            d = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb))
            # transposition: "ab" -> "ba" is one edit, not two
            if (i > 1 and j > 1 and ca == b[j - 2] and a[i - 2] == cb):
                d = min(d, prev2[j - 2] + 1)
            cur.append(d)
            best = min(best, d)
        if best > cutoff:
            return cutoff + 1
        prev2, prev = prev, cur
    return prev[-1]


def load_english(path=None):
    """
    Every ordinary English word, used only to say "do not touch this one".

    The hand-written PROTECTED list above was whack-a-mole: "mother" became
    "other", then "stand" became "sand", then "climb" became "limb" and
    "though" became "through" - three more in a single session of real use.
    The medical vocabulary contains "other", "sand", "limb" and "through" as
    incidental words inside longer phrases, so any everyday word one edit away
    was at risk.

    The rule that actually works: never correct a word that is already a real
    English word. 74,000 base words, shipped gzipped.
    """
    if path is None:
        path = Path(__file__).resolve().parent.parent / "data" / "english_words.txt.gz"
    try:
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return {w.strip() for w in f if w.strip()}
    except Exception:
        return set()


class SpellCorrector:
    """
    correct(word) -> corrected word, or None if it is already known / too far.

    The dictionary of TARGETS is every word in the vocabulary. The list of
    words to LEAVE ALONE is ordinary English.
    """

    def __init__(self, phrases, min_len=MIN_LEN, english=None):
        self.min_len = min_len
        self.english = load_english() if english is None else english
        words = set()
        for p in phrases:
            for w in p.split():
                if len(w) >= 3:
                    words.add(w)
        self.words = words
        self.by_len = {}
        for w in words:
            self.by_len.setdefault(len(w), []).append(w)

    def is_english(self, w):
        """Real word, or a real word with a common ending on it."""
        if w in self.english:
            return True
        for suf in ("s", "es", "ed", "ing", "ly", "er", "est"):
            if w.endswith(suf) and len(w) - len(suf) >= 3:
                if w[: -len(suf)] in self.english:
                    return True
        # Doubled consonant before -ing/-ed. English doubles for a one-syllable
        # stem ("stop" -> "stopping") but not for a longer one ("vomit" ->
        # "vomiting"), so "vomitting" is a typo while "stopping" is correct.
        # Counting vowels is a rough syllable count, and good enough here.
        for suf in ("ing", "ed"):
            if w.endswith(suf) and len(w) - len(suf) >= 4:
                base = w[: -len(suf)]
                if len(base) >= 3 and base[-1] == base[-2] and base[:-1] in self.english:
                    stem = base[:-1]
                    if sum(1 for ch in stem if ch in "aeiou") <= 1:
                        return True      # "stop" -> "stopping", correct

        # SILENT-E RESTORATION, October 2026. The single biggest cause of the
        # speller damaging correct text.
        #
        # `data/english_words.txt.gz` is essentially a list of BASE forms:
        # `give` is in it, `giving` is not; `squeeze` is, `squeezed` is not.
        # English drops the final e before -ing/-ed/-es, so stripping the
        # suffix leaves `giv`, `squeez`, `settl`, `leav`, `sneez`, `hiv` -
        # none of which are words, so every one of these ordinary inflections
        # was declared a misspelling and then "corrected" to whatever lexicon
        # word sat one edit away. That is how
        #     "my cheeks feel like theyre GIVING off heat"
        # became "... HIVING off heat" and reported a fabricated `skin rash`.
        #
        # Putting the e back fixes the whole class in four lines.
        for suf in ("ing", "ed", "es", "er", "est"):
            if w.endswith(suf) and len(w) - len(suf) >= 2:
                if (w[: -len(suf)] + "e") in self.english:
                    return True

        # y -> ies, the other regular ending the base-form list cannot cover:
        # `grocery` is in the list, `groceries` is not.
        if w.endswith("ies") and len(w) >= 5:
            if (w[:-3] + "y") in self.english:
                return True

        return False

    def correct(self, word):
        w = (word or "").strip()
        if len(w) < self.min_len or w in self.words or w in PROTECTED:
            return None                      # too short, already known, or protected
        if self.is_english(w):
            return None                      # a real word - the user meant it
        budget = edit_budget(len(w))
        if budget == 0:
            return None
        best, best_d = None, budget + 1
        ties = 0
        for length in range(len(w) - budget, len(w) + budget + 1):
            for cand in self.by_len.get(length, ()):
                d = _distance(w, cand, budget)
                if d < best_d:
                    best, best_d, ties = cand, d, 1
                elif d == best_d and cand != best:
                    ties += 1
        if best is None or best_d > budget:
            return None
        if ties > 1:
            return None                      # ambiguous - do not guess

        # TWO GUARDS, October 2026. `is_english` is now morphology-aware, but
        # the word list still has genuine gaps (`box`, `refuse`, `disappear`
        # are simply absent), so a correct word can still arrive here. These
        # two refuse the two shapes of damage that gap produces.
        #
        # GUARD 1 - an inflection is not a typo. `refuse` is missing from the
        # list, so it reached here and was "corrected" to the lexicon word
        # `refuses`; likewise `settled` -> `settle` and `sneezed` -> `sneeze`.
        # Turning a word into another tense or number of ITSELF never fixes a
        # spelling mistake, whichever direction it goes.
        for suf in ("s", "es", "d", "ed", "ing", "ies"):
            # A doubled final letter is a typo, not an inflection:
            # "shortnes" -> "shortness" adds an s to a word already ending in
            # s, which is someone missing a keystroke, whereas "refuse" ->
            # "refuses" adds an s to a word ending in e, which is a plural.
            # Without this the guard refused `shortnes of breth` and cost a
            # regression sentence.
            doubling = len(suf) == 1 and w[-1:] == suf
            # The same holds the other way round: "hurtss" -> "hurts" removes
            # a doubled final letter, which is a typo, not an inflection.
            undoubling = len(suf) == 1 and best[-1:] == suf
            if ((best == w + suf and not doubling)
                    or (w == best + suf and not undoubling)):
                return None
            # ... and the same across a restored silent e, so `giving`/`give`
            # and `bones`/`bone` are both caught. Each side applies only if an
            # `e` was actually there to drop: `rstrip` on a word that does not
            # end in e returns it unchanged, which made this clause a second
            # copy of the one above without the doubling exemption, and that
            # is what refused `shortnes` -> `shortness`.
            w_e, b_e = w.rstrip("e"), best.rstrip("e")
            if w_e != w and best == w_e + suf:
                return None
            if b_e != best and w == b_e + suf:
                return None

        # GUARD 2 - never change the first letter. `giving` -> `hiving` is the
        # worst correction the speller made: it invented a symptom from a word
        # the user spelled perfectly. People mistype middles and endings; a
        # wrong first letter is rare enough that accepting the miss is far
        # cheaper than accepting that class of false positive. Every
        # correction the speller gets RIGHT keeps its first letter -
        # coughin->coughing, puffyy->puffy, frezing->freezing, shakin->shaking,
        # throt->throat - so this costs nothing measurable.
        if best[:1] != w[:1]:
            return None

        # GUARD 3 - no same-length single substitutions. This closes the last
        # gap case, `boxes` -> `bones` (`box` is absent from the word list).
        #
        # Every correction the speller gets right in this corpus changes the
        # word's LENGTH, because the typos people actually make when typing
        # about symptoms are dropped letters ("coughin", "shakin", "frezing",
        # "throt") and doubled ones ("puffyy"). A same-length one-letter swap
        # is a different animal: it turns one real word into another real word
        # and so is indistinguishable from a word the dictionary is merely
        # missing. Measured cost of refusing them across 903 regression
        # sentences and both gold sets: nothing, ONCE TRANSPOSITIONS ARE
        # EXEMPTED. The first version of this guard refused them too and cost
        # two regression sentences - "i have a bad HEADCAHE" and one other,
        # both adjacent-letter swaps, which are among the commonest real typos
        # and are unambiguous: swapping two letters back yields a word, so
        # there is no guessing involved. Only a true substitution is refused.
        if len(best) == len(w) and best_d == 1 and not _transposed(w, best):
            return None

        return best

    def correct_text(self, text):
        """Return (corrected_text, [(original, correction), ...])."""
        out, changes = [], []
        for w in (text or "").split():
            c = self.correct(w)
            if c:
                out.append(c)
                changes.append((w, c))
            else:
                out.append(w)
        return " ".join(out), changes


if __name__ == "__main__":
    import csv
    from normalize import normalize

    data = Path(__file__).resolve().parent.parent / "data"
    phrases = set()
    with open(data / "vocabulary.csv", newline="", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            if r["keep"] == "1" and r["alive"] == "1":
                phrases.add(normalize(r["column"]))
    with open(data / "lexicon.csv", newline="", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            if r["status"] == "active":
                phrases.add(normalize(r["phrase"]))

    sc = SpellCorrector(phrases)
    print(f"backend: {backend()}   ({len(sc.words)} vocabulary words, "
          f"{len(sc.english):,} English words protected)\n")

    should_fix = ["nausia", "diarhea", "headcahe", "vomitting", "feaver",
                  "dizzyness", "throt", "constipaton", "nausious", "stomache",
                  "swolen", "breth", "shortnes", "chils", "bloting",
                  "painfull", "urinaton"]
    should_leave = ["crushing", "weather", "awful", "monday", "school",
                    "brother", "working", "morning", "nothing", "walking",
                    # the one that caught us: "mother" is one edit from "other"
                    "mother", "father", "sister", "daughter", "another",
                    "better", "worse", "doctor", "water", "under", "after",
                    "winter", "letter", "matter", "weeks", "night",
                    # the three that real use caught after PROTECTED was added
                    "stand", "climb", "though", "marathon", "pizza",
                    "bathroom", "products", "relaxed", "random", "episodes"]

    print("--- typos (should be corrected) ---")
    ok = 0
    for w in should_fix:
        c = sc.correct(w)
        ok += bool(c)
        print(f"  {w:<14} -> {c or 'NOT CORRECTED'}")
    print(f"  {ok}/{len(should_fix)} corrected")

    print("\n--- ordinary words (should be LEFT ALONE) ---")
    bad = 0
    for w in should_leave:
        c = sc.correct(w)
        bad += bool(c)
        print(f"  {w:<14} -> {c + '   <-- WRONGLY CHANGED' if c else 'left alone'}")
    print(f"  {bad}/{len(should_leave)} wrongly changed")
