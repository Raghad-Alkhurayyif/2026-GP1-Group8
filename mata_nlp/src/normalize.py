"""
Text normalisation and negation scope for Layer 1.

Deliberately conservative: it lowercases, expands contractions, collapses
stretched spelling ("sooo" -> "so"), strips punctuation except the clause
separators, and collapses whitespace. It does NOT stem or lemmatise, because
stemming destroys distinctions the vocabulary depends on - "burning" and "burn"
must stay separable from "burns", and "sharp" must not collapse into anything.

It also works out which parts of a sentence sit inside a denial, which the
matcher needs in order to mark a matched symptom as denied rather than present.

Owner: Aljoury.
"""

import re

CONTRACTIONS = {
    "can't": "cannot", "cant": "cannot", "won't": "will not",
    "don't": "do not", "dont": "do not", "doesn't": "does not",
    "doesnt": "does not", "didn't": "did not", "didnt": "did not",
    "isn't": "is not", "isnt": "is not", "aren't": "are not",
    "arent": "are not", "wasn't": "was not", "wasnt": "was not",
    "weren't": "were not", "werent": "were not",
    "hasn't": "has not", "hasnt": "has not", "haven't": "have not",
    "havent": "have not", "hadn't": "had not", "hadnt": "had not",
    "wont": "will not",
    # The apostrophe forms of these were missing, so "Suddenly couldn't get the
    # words out" kept the token "couldn't" and never reached `difficulty
    # speaking` - a red-flag symptom lost to one missing dictionary key.
    "couldn't": "could not", "couldnt": "could not",
    "shouldn't": "should not", "shouldnt": "should not",
    "wouldn't": "would not", "wouldnt": "would not",
    "mustn't": "must not", "mustnt": "must not",
    "needn't": "need not", "neednt": "need not",
    "ain't": "is not", "aint": "is not",
    "i'm": "i am", "im": "i am", "i've": "i have", "ive": "i have",
    "i'd": "i would", "i'll": "i will",
    "it's": "it is", "its'": "it is", "there's": "there is",
    "theres": "there is", "that's": "that is", "thats": "that is",
    "what's": "what is", "whats": "what is", "who's": "who is",
    "he's": "he is", "hes": "he is", "she's": "she is",
    "they're": "they are", "theyre": "they are", "we're": "we are",
    "were'": "we are", "you're": "you are", "youre": "you are",
    "they've": "they have", "theyve": "they have",
    "we've": "we have", "you've": "you have", "youve": "you have",
    "they'd": "they would", "we'd": "we would", "he'd": "he would",
    "she'd": "she would", "you'd": "you would", "it'd": "it would",
    "let's": "let us", "lets": "let us",
}

# Common misspellings seen in consumer health text.
SPELLING = {
    "diarrhoea": "diarrhea", "diarhea": "diarrhea", "diarrhea": "diarrhea",
    "nauseos": "nauseous", "nauseus": "nauseous", "nausious": "nauseous",
    "stomache": "stomach", "stomac": "stomach", "stomak": "stomach",
    "headach": "headache", "headeche": "headache",
    "feaver": "fever", "feever": "fever", "temprature": "temperature",
    "breathe": "breath", "breathless": "breathless",
    "vommiting": "vomiting", "vomitting": "vomiting",
    "tireness": "tiredness", "tiredness": "tired",
    "disy": "dizzy", "dizzyness": "dizziness",
    "coff": "cough", "coughf": "cough",
    "payne": "pain", "paine": "pain",
    "swolen": "swollen", "swollan": "swollen",
    "acheing": "aching", "akeing": "aching",
}

# Phrases that negate what follows.
NEGATORS = [
    "no", "not", "never", "without", "denies", "denied", "free of",
    "do not have", "does not have", "did not have", "have not had",
    "has not had", "had not had", "cannot say i have", "nothing like",
    "have not noticed", "did not notice", "have not thrown up",
]

# Negators that need a pattern rather than a literal, because a belief verb
# can sit between the denial and its target:
#
#   "I don't THINK I've had a fever at all"
#   "I don't BELIEVE I have a rash"
#
# NegEx handles the clinical equivalent ("no evidence of"); this is the
# patient-language form, and it is one pattern rather than six strings. Before
# this, "I don't think I've had a fever" recorded the fever as PRESENT - the
# exact opposite of what was said - and it appears as a template throughout the
# 500-sentence set.
REGEX_NEGATORS = [
    r"do not (?:think|believe|feel like|reckon) (?:i )?(?:have|had|have had)",
    r"have not (?:really )?(?:noticed|had|felt|seen)",
    r"(?:there|that) (?:is|has been|was) (?:really )?no",
]

# Negators that only soften. "not exactly dizzy but close" is a person saying
# they ARE nearly dizzy, so recording a flat denial throws the symptom away.
# These produce UNCERTAIN, which Layer 2 can still ask about.
# These must live HERE rather than as POSSIBLE_EXISTENCE rules, because most of
# them contain a negator. "not sure if its weakness or im just distracted" was
# read as a DENIAL of weakness - the bare "not" fired, and `assess` tests denial
# before the certainty axis, so a POSSIBLE_EXISTENCE rule could never have won.
# Listing them as hedged negators both stops the denial and marks the span
# uncertain, which is what the person meant: they are weighing it, not ruling it
# out. Eleven of the 23 status errors on the dev half of the gold set were this
# one shape, in ten different wordings.
HEDGED_NEGATORS = ["not exactly", "not really", "not sure if i have",
                   "i would not say",
                   "not sure if", "cannot tell if", "cannot tell whether",
                   "do not know if", "do not know whether", "idk if",
                   "idk whether", "no idea if", "cannot work out if",
                   "hard to tell if", "cannot decide if"]

# A denial stops dead at these - they introduce what the person DOES have.
HARD_STOPS = [
    "but", "however", "although", "though", "except", "apart from",
    "and i do have", "yet", "just", "only", "instead", "rather",
    "mainly", "mostly",
]

# A new subject usually starts a new complaint: "no fever and my head hurts".
# But only when a verb follows it - "no swelling of my lips or trouble
# breathing" has "my" in the middle of one noun phrase, and stopping there lost
# the denial of `difficulty breathing`.
SUBJECT_STOPS = [" my ", " i ", " he ", " she ", " it ", " we ", " they "]

# A bare "not" after a modal negates an ABILITY, not a symptom:
#   "couldn't get the words out"   <- the person HAS difficulty speaking
#   "haven't vomited"              <- the person does NOT have vomiting
# Without this guard the first was read as a denial and a red-flag symptom was
# thrown away. Found by sentence 21 of Aljoury's 200.
MODALS = {"could", "would", "will", "shall", "should", "must", "can",
          "might", "may", "cannot"}

# A negator followed by one of these is denying that something HELPED, not
# denying the symptom. Found by reading what the LLM layer added on real
# forum text:
#
#   "severe osteoarthritis in the knees ... but it doesn't seem to relieve
#    that pain at all"      ->  `knee pain` was being marked NEGATED
#
# The person plainly has the pain; the "doesn't" belongs to the medication.
# That error is worse than a miss, because a denial is recorded as an
# explicit 0 in the feature vector rather than as unknown - so it actively
# tells the classifier something false.
#
# The same shape covers "nothing touches it", "hasn't helped the headache"
# and "didn't do anything for my back". Note that suppressing the negation
# here is right even in the awkward readings: in "I haven't worked since the
# pain started", today's rules negate `pain`, which is also wrong.
EFFICACY_AFTER = re.compile(
    r"^\W*(?:seem(?:s|ed)?\s+to\s+|appear(?:s|ed)?\s+to\s+|really\s+)?"
    r"(?:relieve|reliev\w+|help|help\w+|ease|eas\w+|touch|touch\w+|"
    r"work|work\w+|reduce|reduc\w+|improve|improv\w+|fix|fix\w+|"
    r"cure|cur\w+|settle|settl\w+|stop|stop\w+|"
    r"do\s+anything|do\s+a\s+thing|make\s+any\s+difference)\b",
    re.I)

# Words that mark a clause as a NEW statement rather than one more item in a
# denied list. See `_is_new_assertion`.
NEW_SUBJECTS = {"my", "i", "he", "she", "it", "we", "they", "the", "this",
                "that", "there", "his", "her", "their", "mom", "mother",
                "dad", "father", "sister", "brother", "son", "daughter"}
CLAUSE_VERBS = {"is", "are", "was", "were", "have", "has", "had", "do",
                "does", "did", "am", "feel", "feels", "felt", "hurts",
                "hurt", "keeps", "keep", "started", "get", "gets", "got",
                "been", "being", "will", "would", "can", "cannot", "could"}

# A retraction takes back what was just said: "I thought I had nausea after
# meals, but actually I don't". It sits AFTER the symptom, so its scope runs
# backwards to the start of the sentence.
RETRACTIONS = [
    # "I was worried about vomiting, but that hasn't happened." The denial
    # comes last and reaches back over the thing it takes back. Same mechanism
    # as the "but actually I don't" forms below, different wording, and a
    # template throughout the 500.
    "that has not happened", "that did not happen", "it never happened",
    "that has not been happening", "but that has not happened",
    "but that did not happen",
    "but actually i do not", "actually i do not", "but i do not",
    "but actually i am not", "actually i am not",
    "but actually i have not", "actually i have not",
    "but actually no", "but i was wrong", "turns out i do not",
    "but that was wrong",
]

# Commas, semicolons and full stops are KEPT, as separate tokens. They mark
# where one clause ends and the next begins. An earlier version stripped them
# before negation ran, so "no fever, my head hurts" marked the headache as
# denied - the person has a headache and the system recorded the opposite.
_TOKEN = re.compile(r"[\w'-]+|[,;.]")

# Three or more of the same letter is emphasis, not spelling: "peeing sooo
# much" never reached `frequent urination` because "sooo" is not a word and the
# speller refuses to touch anything that long a distance away.
_STRETCH = re.compile(r"(.)\1{2,}")


def destretch(word: str) -> str:
    """'sooo' -> 'so', 'ahhhh' -> 'ah', 'paiiin' -> 'pain'."""
    return _STRETCH.sub(r"\1", word)


def normalize(text: str) -> str:
    """
    Lowercase, expand contractions, fix misspellings, collapse stretched
    letters, strip punctuation except the clause separators , ; . which become
    their own space-separated tokens.

    Applied to the user's text AND to every lexicon phrase and column name, so
    both sides always agree.
    """
    return normalize_with_map(text)[0]


def normalize_with_map(text: str):
    """
    Return (normalised_text, index_map) where index_map[i] is the position in
    the ORIGINAL text that normalised character i came from.

    Why this exists: medspaCy's ConText reads real sentences - capitalisation,
    punctuation, clause structure. Normalised text has none of that, so the map
    lets matching happen on normalised text while context is judged on the
    original.
    """
    if not text:
        return "", []

    out, idx = [], []
    for m in _TOKEN.finditer(text):
        raw = m.group().lower()
        tok = CONTRACTIONS.get(raw, raw)
        if tok == raw:
            squashed = destretch(raw)
            if squashed != raw:
                tok = CONTRACTIONS.get(squashed, squashed)
        tok = " ".join(SPELLING.get(w, w) for w in tok.split())
        if not tok:
            continue
        if out:
            out.append(" ")
            idx.append(m.start())
        out.append(tok)
        idx.extend([m.start()] * len(tok))
    return "".join(out), idx


_WORDCHAR = re.compile(r"[\w'-]")


def to_original_span(idx_map, start, end, original):
    """
    Translate a span in normalised coordinates back into the original text.

    The map points at the START of each source token, so the end is extended to
    cover the whole of the last word - otherwise a span would stop mid-word and
    spaCy would not align it to a token.
    """
    if not idx_map or not original:
        return 0, 0
    last = len(idx_map) - 1
    s = idx_map[min(max(start, 0), last)]
    e = idx_map[min(max(end - 1, 0), last)]
    while e < len(original) and _WORDCHAR.match(original[e]):
        e += 1
    return s, max(e, s + 1)


# --------------------------------------------------------------- denial scope
WORD_CAP = 12          # a backstop, not the main mechanism


def _clauses(text, start):
    """
    Split text[start:] into (clause_text, abs_start, abs_end, separator) at the
    , ; . tokens, which normalisation left standing as their own tokens.
    """
    out = []
    buf_start = start
    toks = list(re.finditer(r"[,;.]", text))
    seps = [m for m in toks if m.start() >= start]
    for m in seps:
        out.append((text[buf_start:m.start()].strip(), buf_start, m.start(),
                    m.group()))
        buf_start = m.end()
    if buf_start < len(text):
        out.append((text[buf_start:].strip(), buf_start, len(text), ""))
    return out


def _is_new_assertion(clause: str) -> bool:
    """
    After a comma, is this a new statement or one more item in a denied list?

    "not dizziness, nausea, or sensitivity to light"  -> list, keep denying
    "no fever, my head hurts"                         -> new statement, stop

    The test is whether the clause brings its own subject or verb. A bare noun
    phrase is a list item; anything with "my", "i" or a verb in it is someone
    making a fresh claim. Both of the cases above were real bugs, in opposite
    directions, and this is what reconciles them.
    """
    toks = clause.split()
    if not toks:
        return True
    if toks[0] in NEW_SUBJECTS:
        return True
    if any(t in CLAUSE_VERBS for t in toks[:4]):
        return True
    if any(t in NEW_SUBJECTS for t in toks[:3]):
        return True
    return False


def _starts_new_clause(after_subject: str) -> bool:
    """
    A subject word begins a new clause only if a verb follows it closely.

    "my head HURTS"              -> yes, a fresh claim
    "my lips or trouble breathing" -> no, still the same noun phrase
    """
    return any(t in CLAUSE_VERBS for t in after_subject.split()[:4])


def _scope_end(text: str, start: int, subject_stops: bool = True) -> int:
    """
    Where the denial that begins at `start` stops.

    `subject_stops=False` for a HEDGE. A new subject ends a denial - "no fever
    and my head hurts" denies only the fever - but a hedge is followed by its
    own subject, and stopping there left it with nothing in scope at all: "not
    sure if I AM actually dizzy" broke at " i " and the dizziness stayed
    asserted. Four of the gold set's uncertain errors were this, and the words
    that triggered it were "i" and "my" - the two most likely words to follow
    "not sure if".
    """
    rest = text[start:]

    # A hard stop or a new subject ends it immediately, wherever it falls.
    end_rel = len(rest)
    for stop in HARD_STOPS:
        m = re.search(rf"\b{re.escape(stop)}\b", rest)
        if m:
            end_rel = min(end_rel, m.start())
    for stop in (SUBJECT_STOPS if subject_stops else []):
        i = 0
        while True:
            i = rest.find(stop, i)
            if i == -1:
                break
            if _starts_new_clause(rest[i + len(stop):]):
                end_rel = min(end_rel, i)
                break
            i += len(stop)
    hard_end = start + end_rel

    # Walk clause by clause, continuing through a comma-separated list.
    #
    # `reach` starts at the FIRST clause end, not at hard_end. Starting it at
    # hard_end meant the `max()` below could never shrink it, so a denial ran
    # straight past the full stop that was supposed to end it: "there's been no
    # a fever. Yesterday was better, then it came back" denied everything after
    # the fever too. Found on the 500.
    reach = start
    for clause, c_start, c_end, sep in _clauses(text, start):
        if c_start >= hard_end:
            break
        if c_start > start and _is_new_assertion(clause):
            break
        reach = min(max(reach, c_end), hard_end)
        # A semicolon or a full stop separates independent clauses, so a denial
        # can never carry across one. "bruises appearing WITHOUT a clear
        # reason; bleeding gums when brushing" denied the bleeding gums -
        # `without` was modifying the manner, not denying a symptom, and the
        # scope should not have left the clause in the first place.
        if sep in (".", ";"):
            break
    reach = max(reach, start)

    # Backstop, so a sentence with no punctuation at all cannot run away.
    words = text[start:reach].split()
    if len(words) > WORD_CAP:
        capped = " ".join(words[:WORD_CAP])
        reach = start + text[start:reach].find(capped) + len(capped)
    return reach


def _retraction_spans(text):
    """
    "I thought I had nausea after meals, but actually I don't" - the denial
    comes last and reaches backwards over the claim it takes back.

    Scope runs back to the previous full stop or semicolon, NOT the previous
    comma, because the comma is what separates the retraction from the claim.

    A retraction only counts when NOTHING follows it. "but I don't have a
    fever" names what is denied and is an ordinary forward negation; "but
    actually I don't." denies the sentence behind it. Treating both as
    retractions denied a red flag - "a tiny bit of blood when I coughed this
    morning, but I don't have a fever" threw away the hemoptysis.
    """
    spans = []
    for pat in RETRACTIONS:
        for m in re.finditer(rf"\b{re.escape(pat)}\b", text):
            tail = text[m.end():].strip(" .;,")
            if tail:
                continue              # something follows: a normal negation
            back = max(text.rfind(".", 0, m.start()),
                       text.rfind(";", 0, m.start()))
            spans.append((back + 1 if back != -1 else 0, m.start()))
    return spans


def scope_spans(text: str):
    """
    Return [(start, end, kind)] where kind is "negated" or "uncertain".

    Separated from negation_spans so a hedge ("not exactly dizzy") can soften a
    symptom instead of deleting it.
    """
    out, triggers = [], []
    for neg in HEDGED_NEGATORS:
        for m in re.finditer(rf"\b{re.escape(neg)}\b", text):
            triggers.append((m.start(), m.end()))
            out.append((m.end(),
                        _scope_end(text, m.end(), subject_stops=False),
                        "uncertain"))

    for pat in REGEX_NEGATORS:
        for m in re.finditer(pat, text):
            if EFFICACY_AFTER.match(text[m.end():m.end() + 40]):
                continue          # denying that it HELPED, not the symptom
            out.append((m.end(), _scope_end(text, m.end()), "negated"))

    for neg in NEGATORS:
        for m in re.finditer(rf"\b{re.escape(neg)}\b", text):
            # "not exactly" is already handled above as a hedge; the bare "not"
            # inside it must not also produce a flat denial.
            if any(ts <= m.start() < te for ts, te in triggers):
                continue
            before = text[:m.start()].split()
            if before and before[-1] in MODALS:
                continue              # "could not get the words out" - ability
            if EFFICACY_AFTER.match(text[m.end():m.end() + 40]):
                continue          # denying that it HELPED, not the symptom
            out.append((m.end(), _scope_end(text, m.end()), "negated"))

    for s, e in _retraction_spans(text):
        out.append((s, e, "negated"))
    return out


def merge(spans):
    if not spans:
        return []
    spans = sorted(spans)
    out = [list(spans[0])]
    for s, e in spans[1:]:
        if s <= out[-1][1]:
            out[-1][1] = max(out[-1][1], e)
        else:
            out.append([s, e])
    return [tuple(x) for x in out]


if __name__ == "__main__":
    tests = [
        "I've had a really bad headache and I can't sleep",
        "my stomach hurts but no fever",
        "I don't have chest pain, just a cough",
        "no cough, no fever, but my throat is killing me",
        "no fever, my head hurts",
        # the two that Aljoury's 200 sentences caught
        "I have a headache but NOT dizziness, nausea, or sensitivity to light.",
        "I thought I had nausea after meals, but actually I don't.",
        "I have a rash on my hands; no swelling of my lips or trouble breathing.",
        "Suddenly couldn't get the words out right",
        "been peeing sooo much lately",
        "not exactly dizzy but close",
    ]
    for t in tests:
        n = normalize(t)
        print(f"\nin  : {t}")
        print(f"norm: {n}")
        for s, e, kind in sorted(scope_spans(n)):
            txt = n[s:e].strip()
            if txt:
                print(f"  {kind:<10} -> '{txt}'")
