"""
LAYER 1 - lexicon, compositional and loose matching.

Spelling is corrected FIRST, word by word, so a corrected word can take part in
any of the passes below (fuzzy_match.py; correcting afterwards only ever
recovered single words). Then four ways a column is reached, in this order:

  1. exact     the user typed the column name itself          score 1.00
  2. synonym   a phrase from lexicon.csv                      score 0.95
  3. composed  a body site + a sensation from compositional.csv, assembled
               into a column name                             score 0.85
  4. loose     every content word of a phrase present, in any order, inside
               one clause (loose_match.py)                    score 0.78

There is no "fuzzy pass". An early version fuzzy-matched whole phrases and
turned "my leg is red" into `redness in ear`; spelling correction is now a
word-level step before matching, and the fourth pass handles word ORDER, not
typos.

Every match is then assessed in context by the local rules in
local_context.py, across all four ConText axes - denied, somebody else's, in
the past, or only a maybe - plus `dependent` for a complaint written about a
child, and `age_mismatch` where an age rules the column out. medspaCy, where
it is installed, may only ESCALATE a verdict and never clear one. Only a
symptom that is asserted, about the patient and current becomes a 1 in the
feature vector.

Longest phrases are matched first, so "lower abdominal pain" wins over
"abdominal pain", and a matched span is consumed so one piece of text never
produces two symptoms.

Output follows the agreed /extract contract. Layers 2 and 3 receive whatever
text this layer did not consume, in `unmatched`.

    from layer1_lexicon import Layer1
    Layer1().extract("my tummy is killing me but no fever")

Owner: Aljoury.
"""

import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

# Every import below is after the sys.path line above, which is what makes
# `python3 src/layer1_lexicon.py` work from any directory. E402 is expected.
from normalize import normalize, normalize_with_map
from context_assess import ContextAssessor
# The status constants are imported from local_context, which DEFINES them,
# rather than through context_assess, which only passed them along. The
# indirection made them look like an unused import in context_assess and hid
# which module actually owns them.
from normalize import scope_spans
from local_context import (PRESENT, NEGATED, FAMILY, HISTORICAL,
                           UNCERTAIN, DEPENDENT)
from fuzzy_match import SpellCorrector, backend as fuzzy_backend
from loose_match import LooseMatcher
from vocab_utils import (split_compositional, anatomical_root,
                         FAMILY_GENERIC, FAMILY_GLUE, FAMILY_SYNONYMS)
import modifiers as mods_mod

# Not a context status: the match is real and the patient's age rules it out.
AGE_MISMATCH = "age_mismatch"

SCORE_EXACT = 1.00
SCORE_SYNONYM = 0.95
SCORE_COMPOSED = 0.85

# How a site and a sensation are assembled into a column name. Most are
# "<site> <sensation>", but the qualifier sensations sit before the site.
QUALIFIER_SENSATIONS = {"sharp", "burning"}


class Layer1:
    # use_medspacy defaults to False: see the note on ContextAssessor.
    # The shipped behaviour must not change because an optional package
    # happens to be installed on one machine and not another.
    def __init__(self, data_dir="data", use_fuzzy=True, use_medspacy=False):
        d = Path(data_dir)
        self.data_dir = d
        # Display labels are loaded on first use, not here: they are needed
        # only to show a finding to a person, and a component that cannot
        # extract because a label file is missing would be the wrong trade.
        self._labels = None
        self.vocab = self._load_vocab(d / "vocabulary.csv")
        self.phrases = self._load_lexicon(d / "lexicon.csv")
        self.sites, self.sensations = self._load_compositional(d / "compositional.csv")

        # Every live column name is itself an exact phrase, and an exact name
        # ALWAYS beats a synonym. Without this, a synonym that happens to be
        # another column's name steals it: "rectal bleeding" was authored as a
        # synonym for `blood in stool`, but `rectal bleeding` is its own column,
        # so the real column became unreachable. Found by the floor-recall test.
        # Column names go through the SAME normalisation as the user's text.
        # Without this, a column containing a comma - "skin dryness, peeling,
        # scaliness, or roughness" - could never match, because the two sides
        # punctuated differently.
        self.shadowed = []
        for col in self.vocab:
            key = normalize(col)
            prior = self.phrases.get(key)
            if prior and prior[0] != col:
                self.shadowed.append((col, prior[0]))
            self.phrases[key] = (col, "exact")

        # Longest first so specific phrases beat the general ones they contain.
        self._ordered = sorted(self.phrases, key=len, reverse=True)
        self._site_ordered = sorted(self.sites, key=len, reverse=True)
        self._sens_ordered = sorted(self.sensations, key=len, reverse=True)

        # Some families have NO bare column: there is no `abdominal pain` and no
        # `chest pain`, only qualified members. Without this map "my tummy is
        # killing me" and "chest pain" match nothing at all - and for chest that
        # is a safety failure. Derived from the data, not hard-coded.
        self.family_roots = self._derive_family_roots()

        # Context assessment and fuzzy matching both degrade gracefully: if the
        # library is missing they fall back to a standard-library version, so
        # the project still runs on a machine with nothing installed.
        self.context = ContextAssessor(prefer_medspacy=use_medspacy)
        self.speller = SpellCorrector(self.phrases) if use_fuzzy else None
        self.loose = LooseMatcher(self.phrases)

    def engines(self):
        """What is actually running - worth printing in any results table."""
        return {
            "context": self.context.engine,
            "context_note": self.context.unavailable_reason,
            "context_rules": self.context.rules_note,
            "fuzzy": fuzzy_backend() if self.speller else "off",
            "loose_phrases": len(self.loose.index),
        }

    # ---------------------------------------------------------------- loading
    @staticmethod
    def _rows(path):
        with open(path, newline="", encoding="utf-8-sig") as f:
            yield from csv.DictReader(f)

    def _load_vocab(self, path):
        v = {}
        for r in self._rows(path):
            if r["keep"] != "1" or r["alive"] != "1":
                continue
            v[r["column"]] = {
                "kind": r["kind"],
                "family": r["family"],
                "clarify": r["clarify"],
                "question": r["clarify_question"],
                "rows": int(r["positive_rows"] or 0),
                # One canonical escalation list, in the vocabulary every
                # component already reads. Before this there were three lists
                # that could disagree without anyone noticing - see
                # src/add_red_flags.py.
                "red_flag": r.get("red_flag", ""),
                "red_flag_reason": r.get("red_flag_reason", ""),
                "age_min": int(r["age_min"]) if r.get("age_min") else None,
                "age_max": int(r["age_max"]) if r.get("age_max") else None,
            }
        return v

    def _load_lexicon(self, path):
        out = {}
        for r in self._rows(path):
            if r["status"] != "active":
                continue
            out[normalize(r["phrase"])] = (r["column"], r["type"])
        return out

    def _load_compositional(self, path):
        sites, sens = {}, {}
        for r in self._rows(path):
            if r["status"] != "active":
                continue
            p = normalize(r["phrase"])
            (sites if r["part"] == "site" else sens)[p] = r["canonical"]
        return sites, sens

    def _derive_family_roots(self):
        """
        Map (anatomical root, sensation) -> family, for families whose members
        all share one root. Only those families need it: `leg pain` already
        exists as a column, so "my leg hurts" resolves directly.
        """
        by_family = {}
        for col, meta in self.vocab.items():
            fam = meta["family"]
            if not fam:
                continue
            site, sensation = split_compositional(col)
            if site is None:
                continue
            by_family.setdefault(fam, set()).add((anatomical_root(site), sensation))

        roots = {}
        for fam, pairs in by_family.items():
            if len(pairs) == 1:          # every member shares one root
                roots[next(iter(pairs))] = fam
        return roots

    # --------------------------------------------------------------- matching
    def _family_of(self, column):
        return self.vocab.get(column, {}).get("family", "")

    def display_label(self, column):
        """
        The words to show a person for this column, or the column itself.

        Loaded lazily and never fatal: a missing or unreadable
        display_labels.csv degrades to the column name rather than stopping
        the component, because a label is a presentation detail and the
        extraction must not depend on it.
        """
        if self._labels is None:
            try:
                from vocab_utils import load_display_labels
                self._labels = load_display_labels(self.data_dir / "display_labels.csv")
            except Exception:
                self._labels = {}
        return self._labels.get(column, column)

    def _members(self, family):
        return [c for c, m in self.vocab.items() if m["family"] == family]

    def _compose(self, site, sensation):
        """
        Resolve a site + sensation to ('column', name) or ('family', name).

        A family result means the wording was too vague to pick a member -
        "my tummy hurts" cannot choose between four abdominal pain columns.
        That becomes a clarify, never a guess.
        """
        if sensation in QUALIFIER_SENSATIONS:
            for cand in (f"{sensation} {site} pain", f"{site} {sensation}"):
                if cand in self.vocab:
                    return ("column", cand)
            return None

        cand = f"{site} {sensation}"
        if cand in self.vocab:
            return ("column", cand)

        fam = self.family_roots.get((site, sensation))
        if fam:
            return ("family", fam)
        return None

    def _distinguishing(self, column, family):
        """
        The words that make this member different from its siblings.

        `knee pain` in lower-limb-pain -> {"knee"}: every member ends in
        "pain", so "pain" says nothing about which one. Glue words are dropped
        too, or `foot or toe pain` would count "or" as distinguishing and fire
        on almost any sentence.
        """
        members = self._members(family)
        if not members:
            return set()
        shared = set.intersection(*(set(m.split()) for m in members))
        return {w for w in set(column.split()) - shared if w not in FAMILY_GLUE}

    @staticmethod
    def _says(words, text):
        low = set(re.findall(r"[a-z]+", text.lower()))
        return any(w in low or w.rstrip("s") in low or w + "s" in low
                   for w in words)

    # Where a qualifier stops counting as part of the same complaint. A comma
    # or a conjunction starts a new one: in "sharp pain in my knee and pain in
    # my belly", the "sharp" belongs to the knee and must not resolve the
    # abdominal family.
    _CLAUSE_BREAK = re.compile(
        r"[,;.!?]|\b(?:and|but|however|although|though|except|yet|instead|"
        r"rather|also|plus|then|while)\b")

    def _qualifier_window(self, text, span):
        """
        The words around a match that could say which family member it is.

        The matched span alone is too narrow. `pain in my upper belly` matches
        as one phrase and resolves to `upper abdominal pain`, but `upper right
        belly pain` matches only the `belly pain` part - the word that answers
        the question sits just outside the span, and the question was asked
        anyway. Same symptom, different word order, different answer.

        So the window is the clause the match sits in, not the match. It stops
        at the nearest clause break on each side, which keeps a qualifier
        belonging to a different complaint from leaking in.
        """
        start, end = span
        left = text[:start]
        breaks = [m.end() for m in self._CLAUSE_BREAK.finditer(left)]
        lo = breaks[-1] if breaks else 0
        m = self._CLAUSE_BREAK.search(text, end)
        hi = m.start() if m else len(text)
        return text[lo:hi]

    def _selected_members(self, family, window):
        """
        Members the text has already picked out.

        The ambiguity families exist because their members point to measurably
        different diseases, so asking is right when the part is unknown. It is
        not right when the person has just told us: "my knee is really sore"
        was being met with "which part - hip, knee, ankle, foot, or the leg
        generally?". Never ask a question the text has answered.

        A family marked `always` is never resolved this way. That is the
        chest-pain case, where burning is 61.5% heart attack against 1.8% for
        sharp: it was decided that the app asks even when the person has said
        which, because the cost of reading it wrong is a missed heart attack.

        The family's GENERIC member is resolved only by one of the part names
        in FAMILY_SYNONYMS, never by its own word. "my leg hurts" really is
        the vague case the question was written for, so `leg` keeps asking;
        `calf` does not, because the calf is a part and the person named it.
        """
        generic = FAMILY_GENERIC.get(family)
        picked = set()
        for m in self._members(family):
            if self.vocab[m]["clarify"] != "ask":
                continue
            words = set(FAMILY_SYNONYMS.get((family, m), ()))
            if m != generic:
                words |= self._distinguishing(m, family)
            if words and self._says(words, window):
                picked.add(m)
        return picked

    def _already_answered(self, column, family, window):
        return column in self._selected_members(family, window)

    def _denied_members(self, family, denied_text):
        """
        Members the person has already ruled out, so the question can stop
        offering them. "my leg hurts, not my knee" should not come back asking
        whether it is the knee.
        """
        if not denied_text:
            return set()
        return {m for m in self._members(family)
                if self._says(self._distinguishing(m, family), denied_text)}

    def extract(self, text, age=None):
        norm, idx_map = normalize_with_map(text)

        # Correct typos BEFORE matching, so a corrected word can take part in
        # an ordinary exact, synonym or compositional match. Correcting
        # afterwards only ever recovered single words.
        corrections = []
        if self.speller:
            fixed, corrections = self.speller.correct_text(norm)
            if corrections and len(fixed) == len(norm):
                norm = fixed          # same length: the index map still holds
            elif corrections:
                norm, idx_map = fixed, self._rebuild_map(norm, fixed, idx_map)
        consumed = [False] * len(norm)

        # Matches are COLLECTED first and judged afterwards. An earlier version
        # decided negation inline, which made it impossible to use a context
        # engine that needs to see every span at once.
        cands = []
        about_dependent = False
        seen_columns = set()

        def free(s, e):
            return not any(consumed[s:e])

        def take(s, e):
            for i in range(s, e):
                consumed[i] = True

        def add(kind, name, span, matched, score, how, assess_span=None):
            # Deduplicated by (kind, name, span), NOT by name alone. One column
            # can legitimately appear twice with different contexts: "My sister
            # had a dull ache behind my eyes, but I don't. I'm the one with a
            # pounding headache" mentions `headache` for the sister and again
            # for the patient. Keying on the name alone let the sister's
            # mention claim the column and the patient's own headache vanished.
            # The best status per column is chosen after assessment, below.
            key = (kind, name, span)
            if key in seen_columns:
                return
            seen_columns.add(key)
            cands.append({"kind": kind, "name": name, "span": span,
                          "matched": matched, "score": score, "method": how,
                          # Where the context engine should stand to judge
                          # this match. Normally the match itself; see the
                          # compositional pass for the one case where the two
                          # differ.
                          "assess_span": assess_span or span})

        # --- pass 1 and 2: exact column names and lexicon synonyms ----------
        for phrase in self._ordered:
            if not phrase:
                continue
            for m in re.finditer(rf"(?<!\w){re.escape(phrase)}(?!\w)", norm):
                if not free(m.start(), m.end()):
                    continue
                column, how = self.phrases[phrase]
                if column not in self.vocab:
                    continue
                take(m.start(), m.end())
                add("column", column, (m.start(), m.end()), m.group(),
                    SCORE_EXACT if how == "exact" else SCORE_SYNONYM,
                    "exact" if how == "exact" else "synonym")

        # --- pass 3: compositional, site + sensation within a short window --
        site_hits, sens_hits = [], []
        # A trailing plural is allowed on a body part. 32 of the 85 sites had
        # no plural form listed, so "my knuckles hurt" and "pain in my heels"
        # matched nothing at all while the singular matched fine. A site only
        # becomes a finding once a sensation pairs with it inside 40
        # characters, so the extra letter cannot produce a symptom on its own.
        for p_ in self._site_ordered:
            for m in re.finditer(rf"(?<!\w){re.escape(p_)}s?(?!\w)", norm):
                site_hits.append((m.start(), m.end(), self.sites[p_]))
        for p_ in self._sens_ordered:
            for m in re.finditer(rf"(?<!\w){re.escape(p_)}(?!\w)", norm):
                sens_hits.append((m.start(), m.end(), self.sensations[p_]))

        # Each SENSATION pairs with its NEAREST site only. Without this, one
        # "pain" in "crushing pain in my chest and my left arm" paired with
        # chest, arm, elbow, wrist, hand and shoulder at once - six symptoms
        # from one word.
        #
        # A site is claimed by one sensation only. "pain in my knee and pain in
        # my belly" has two "pain"s, and the second one's nearest site is still
        # the knee - four characters away, against eleven for the belly. It
        # paired with the knee, composed to `knee pain` a second time, was
        # dropped as a duplicate, and the belly was never looked at: the whole
        # second complaint vanished. Claiming makes the second "pain" move on
        # to the next site it can reach instead of giving up.
        # A QUALIFIER does not reach across a clause break. In "sharp pain in
        # my knee and pain in my belly" the belly is 32 characters from
        # "sharp" - inside the window - and "sharp abdominal pain" is a real
        # column, so the qualifier jumped the conjunction and reported a sharp
        # abdominal pain nobody described.
        #
        # A PLAIN sensation does reach across one, and must. Patients list
        # body parts: "pain in my legs, arms and hips" is one "pain" governing
        # three sites, and refusing to cross the comma cost 2.5 points of
        # recall on CADEC. Only the qualifier is restricted, because only the
        # qualifier decides which member of a family the finding is.
        pairs = []
        claimed = set()
        for ns, ne, sensation in sorted(sens_hits):
            options = sorted(
                (min(abs(ns - se), abs(ss - ne)), ss, se, site)
                for ss, se, site in site_hits
                if min(abs(ns - se), abs(ss - ne)) <= 40)
            for _gap, ss, se, site in options:
                if (ss, se) in claimed:
                    continue
                if (sensation in QUALIFIER_SENSATIONS
                        and self._CLAUSE_BREAK.search(
                            norm, min(ne, se), max(ns, ss))):
                    continue
                # A site is only claimed by a sensation it can actually
                # compose with. Claiming it on a composition that fails
                # ("sharp" plus the knee is not a column) left the site
                # unavailable to the sensation that would have resolved it.
                if not self._compose(site, sensation):
                    continue
                claimed.add((ss, se))
                pairs.append((ss, se, site, ns, ne, sensation))
                break

        for ss, se, site, ns, ne, sensation in pairs:
            resolved = self._compose(site, sensation)
            if not resolved:
                continue
            kind, name = resolved
            # `seen_columns` holds (kind, name, span) now, so the old
            # `name in seen_columns` test could never be true - dead since the
            # dedup was re-keyed. The best-status pass collapsed the duplicate
            # anyway, so behaviour was right and the check was a lie.
            if any(c["kind"] == kind and c["name"] == name for c in cands):
                continue
            lo, hi = min(ss, ns), max(se, ne)
            if not free(lo, hi) and not (free(ss, se) or free(ns, ne)):
                continue
            take(lo, hi)
            # Judged at the SENSATION, not across the whole pairing.
            #
            # A composed span runs from the site to the sensation, so in "my
            # knee isnt sore" it starts at "knee" and ends at "sore" - with
            # the negator sitting inside it. Negation scope runs forward from
            # the negator, the span began before it, and the denial never
            # applied: `knee pain`, asserted. The same held for "my chest is
            # not tight" and "my stomach isnt swollen". It is the sensation
            # that is being denied, so that is where the engine has to stand.
            add(kind, name, (lo, hi), norm[lo:hi], SCORE_COMPOSED, "composed",
                assess_span=(ns, ne))

        # --- pass 4: loose, same words in another order ---------------------
        taken = []
        run_s = None
        for i, c in enumerate(consumed):
            if c and run_s is None:
                run_s = i
            elif not c and run_s is not None:
                taken.append((run_s, i))
                run_s = None
        if run_s is not None:
            taken.append((run_s, len(consumed)))

        for lo, hi, column, _phrase, score in self.loose.match(norm, taken):
            if column not in self.vocab:
                continue
            if any(c["name"] == column for c in cands):
                continue              # a tighter pass already found this one
            if not free(lo, hi):
                continue
            take(lo, hi)
            add("column", column, (lo, hi), norm[lo:hi], score, "loose")

        # --- judge every match in context, all at once ----------------------
        statuses = self.context.assess(
            norm, [c["assess_span"] for c in cands],
            original=text, idx_map=idx_map)

        # The same column may have been matched twice with different contexts.
        # Keep the strongest claim: a symptom the patient asserts about
        # themselves now outranks the same symptom mentioned as a relative's,
        # as past history, or as a maybe.
        rank = {PRESENT: 0, DEPENDENT: 1, UNCERTAIN: 2, HISTORICAL: 3,
                FAMILY: 4, AGE_MISMATCH: 5, NEGATED: 6}
        best = {}
        for i, c in enumerate(cands):
            key = (c["kind"], c["name"])
            r = rank.get(statuses.get(i, PRESENT), 9)
            if key not in best or r < best[key][0]:
                best[key] = (r, i)
        keep = {i for _, i in best.values()}
        cands = [c for i, c in enumerate(cands) if i in keep]
        statuses = {n: statuses.get(i, PRESENT)
                    for n, i in enumerate(sorted(keep))}

        symptoms, negated, clarify, excluded, confirm = [], [], [], [], []
        found_spans = []
        # Everything the person denied, as text. Used to stop a family question
        # offering an option they have already ruled out.
        denied_text = " ".join(
            norm[s:e] for s, e, kind in scope_spans(norm) if kind == "negated")
        for i, c in enumerate(cands):
            status = statuses.get(i, PRESENT)
            # "my son has a fever" - the son is almost certainly who the app is
            # being used for, so the symptom is KEPT and the result asks the app
            # to confirm whose complaint this is. Dropping it (which is what
            # ConText's FAMILY axis would do) lost three paediatric cases.
            if status in (DEPENDENT, FAMILY) and age is None:
                # Whenever the complaint is written about somebody else, the app
                # should ask who it is for rather than Layer 1 guessing. A
                # parent typing "my son has a fever" is asking about the son; a
                # carer typing "my granddad is more confused than usual" is
                # asking about the granddad; someone typing "my mother has
                # asthma" is giving background. Layer 1 cannot tell those
                # apart, so it reports and the app asks. An `age` means the app
                # already knows, so there is nothing to confirm.
                about_dependent = True
            if status == DEPENDENT:
                status = PRESENT

            # An age the column cannot apply to. A 34-year-old does not have
            # `irritable infant`; an 8-year-old does not have `vaginal bleeding
            # after menopause`. Reported, never silently dropped - if the age
            # is wrong, the symptom is still visible in `excluded`.
            if age is not None and c["kind"] == "column" and status == PRESENT:
                meta = self.vocab.get(c["name"], {})
                lo, hi = meta.get("age_min"), meta.get("age_max")
                if (lo is not None and age < lo) or (hi is not None and age > hi):
                    status = AGE_MISMATCH
            if c["kind"] == "family":
                members = sorted(self._members(c["name"]))
                if status == NEGATED:
                    # Denying the family denies every member of it.
                    for m in members:
                        negated.append({"column": m, "matched_text": c["matched"],
                                        "layer": "lexicon"})
                elif status != PRESENT:
                    for m in members:
                        excluded.append({"column": m, "matched_text": c["matched"],
                                         "layer": "lexicon", "status": status})
                else:
                    left = [m for m in members
                            if m not in self._denied_members(c["name"], denied_text)]
                    if len(left) == 1:
                        # The denial answered the question outright.
                        symptoms.append({"column": left[0],
                                         "matched_text": c["matched"],
                                         "layer": "lexicon", "method": "family",
                                         "score": 0.90})
                        found_spans.append((left[0], c["span"]))
                        continue
                    # The wording may answer the question even though the match
                    # came through as a family: `upper right belly pain` matches
                    # on `belly pain`, and "upper" sits outside that span. Only
                    # the clause counts, and only one surviving member resolves
                    # it - two mean the person named two things at once, which
                    # narrows the question instead of answering it.
                    picked = [m for m in self._selected_members(
                        c["name"], self._qualifier_window(norm, c["span"]))
                        if m in left]
                    if len(picked) == 1:
                        symptoms.append({"column": picked[0],
                                         "matched_text": c["matched"],
                                         "layer": "lexicon",
                                         "method": "family-qualified",
                                         "score": 0.90})
                        found_spans.append((picked[0], c["span"]))
                        continue
                    clarify.append({
                        "matched_text": c["matched"],
                        "candidates": picked or left or members,
                        "question": self.vocab[members[0]]["question"],
                        "family": c["name"],
                    })
                    # A modifier can attach to a family too: "severe" plus the
                    # abdominal pain family IS the acute-abdomen case, and it
                    # would be lost if only resolved columns were offered.
                    found_spans.append((c["name"], c["span"]))
                continue

            base = {"column": c["name"], "matched_text": c["matched"],
                    "layer": "lexicon"}
            if status == NEGATED:
                negated.append(base)
            elif status == UNCERTAIN:
                # "I might be getting a cough, or maybe it's just
                # constipation?" - the person is weighing two possibilities.
                # Neither is asserted, so neither is a 1 in the vector, but
                # both are worth one question. Returning them only under
                # `excluded` made a whole template of sentences look like
                # Layer 1 had found nothing at all.
                confirm.append({**base, "status": status,
                                "question": f"Do you have {c['name']}?"})
                excluded.append({**base, "status": status})
            elif status != PRESENT:
                excluded.append({**base, "status": status})
            else:
                fam = self._family_of(c["name"])
                if (fam and self.vocab[c["name"]]["clarify"] in ("always", "ask")
                        and not self._already_answered(
                            c["name"], fam,
                            self._qualifier_window(norm, c["span"]))):
                    cands_ = [m for m in sorted(self._members(fam))
                              if m not in self._denied_members(fam, denied_text)]
                    if len(cands_) == 1:
                        symptoms.append({**base, "method": "family", "score": 0.90})
                        found_spans.append((cands_[0], c["span"]))
                        continue
                    clarify.append({
                        "matched_text": c["matched"],
                        "candidates": cands_ or sorted(self._members(fam)),
                        "question": self.vocab[c["name"]]["question"],
                        "family": fam,
                    })
                    found_spans.append((fam, c["span"]))
                else:
                    symptoms.append({**base, "method": c["method"],
                                     "score": c["score"]})
                    # Where in the sentence this symptom was found, so a
                    # severity or onset word can be attached to the nearest
                    # one. Not part of the published contract - stripped
                    # below before the result is returned.
                    found_spans.append((c["name"], c["span"]))

        # Never record a member of a family and ask which member it is.
        # "sharp pain low down in my belly" matched twice - once compositionally
        # on sharp + belly, once on the phrase `pain low down in my belly` - and
        # came back having resolved `sharp abdominal pain` while still asking
        # "where is the pain, and does it feel sharp or burning?". The app would
        # have stored the answer and then asked the question. Whichever match
        # resolved wins; a question about a family already answered is dropped.
        resolved_families = {self._family_of(s["column"]) for s in symptoms}
        resolved_families.discard("")
        clarify = [c for c in clarify if c["family"] not in resolved_families]

        # The offsets come free from _fragments and used to be discarded.
        # Layer 2 needs them: to judge whether a fragment it places is denied
        # or somebody else's, it has to ask the SAME context assessor where
        # that fragment sits, and the assessor works in offsets. Without these
        # Layer 2 would have to find the fragment by string search, or keep
        # its own copy of the context engine - which is exactly the
        # duplication this contract exists to prevent.
        _frags = [(f, a, b) for f, a, b in self._fragments(norm, consumed)
                  if len(f.split()) >= 2]
        unmatched = [f for f, _, _ in _frags]
        unmatched_spans = [(a, b) for _, a, b in _frags]
        covered = len(norm) - consumed.count(False)

        # A human-readable label on every finding.
        #
        # `column` is the vocabulary's own name, and some of those names are
        # unusable in front of a person: `coryza`, `melena`, `paresthesia`,
        # `skin dryness, peeling, scaliness, or roughness`. data/display_labels
        # .csv already carries the words to show instead - "head cold", "black
        # poo", "tingly" - and the follow-up logic has been using them for its
        # buttons all along, while every other finding came out with the raw
        # column name. An app rendering a symptom summary would have shown the
        # patient "melena".
        #
        # Added as an extra key, never replacing `column`: the measurements,
        # the feature vector and the classifier all key on the column name and
        # must keep seeing it unchanged.
        for group in (symptoms, negated, excluded, confirm):
            for f in group:
                f["display"] = self.display_label(f["column"])
        for c in clarify:
            c["candidate_displays"] = [self.display_label(m)
                                       for m in c["candidates"]]
        return {
            "text": text,
            "normalized": norm,
            "symptoms": symptoms,
            "negated": negated,
            "excluded": excluded,
            "clarify": clarify,
            # Matched, but not asserted - ask before using. Uncertain
            # mentions and anything about a dependent land here.
            "confirm": confirm,
            # Severity, onset, duration and progression - the words no column
            # can hold. Reported, never acted on: whether "severe abdominal
            # pain" means the emergency department is a clinical judgement and
            # belongs in the clinic layer. See src/modifiers.py.
            "modifiers": mods_mod.attach(mods_mod.find(norm), found_spans),
            # Escalation facts, from the vocabulary's own `red_flag` column.
            # ONLY asserted symptoms count: a denied or historical red flag
            # must not escalate anyone. The clinic layer should read this
            # instead of running its own regexes over the raw text.
            "red_flags": [
                {"column": s["column"], "level": self.vocab[s["column"]]["red_flag"],
                 "reason": self.vocab[s["column"]]["red_flag_reason"],
                 "matched_text": s["matched_text"],
                 "display": self.display_label(s["column"])}
                for s in symptoms if self.vocab[s["column"]]["red_flag"]
            ],
            "unmatched": unmatched,
            "unmatched_spans": unmatched_spans,
            "coverage": round(covered / len(norm), 3) if norm else 0.0,
            "n_found": len(symptoms) + len(negated) + len(clarify) + len(excluded),
            "n_actionable": len(symptoms) + len(clarify) + len(confirm),
            "layers_run": ["lexicon"],
            "context_engine": self.context.engine,
            "corrections": corrections,
            # True when the complaint was written about a child or other
            # dependent. The app should confirm who it is for before
            # acting on the symptoms.
            "confirm_subject": about_dependent,
        }

    @staticmethod
    def _rebuild_map(old, new, idx_map):
        """
        Re-align the original-text index map after spelling correction changed
        word lengths. Maps each corrected word back to where its misspelling
        started in the user's text.
        """
        out, oi = [], 0
        for ow, nw in zip(old.split(), new.split()):
            start = idx_map[min(oi, len(idx_map) - 1)] if idx_map else 0
            if out:
                out.append(start)
            out.extend([start] * len(nw))
            oi += len(ow) + 1
        return out

    @staticmethod
    def _fragments(norm, consumed):
        """Unconsumed runs of text, as (fragment, start, end)."""
        out, buf, start = [], [], None
        for i, ch in enumerate(norm):
            if consumed[i]:
                if buf:
                    out.append(("".join(buf).strip(), start, i))
                    buf, start = [], None
            else:
                if start is None:
                    start = i
                buf.append(ch)
        if buf:
            out.append(("".join(buf).strip(), start, len(norm)))
        return [(f, s, e) for f, s, e in out if f]


if __name__ == "__main__":
    L = Layer1(Path(__file__).resolve().parent.parent / "data")
    e = L.engines()
    print(f"context engine : {e['context']}")
    if e["context_note"]:
        print(f"                 (medspaCy unavailable -> {e['context_note']})")
    if e.get("context_rules"):
        print(f"                 {e['context_rules']}")
    print(f"fuzzy backend  : {e['fuzzy']}")

    cases = [
        "I've had a cough and fever for three days and I'm exhausted",
        "my tummy is killing me since yesterday and I feel sick, but no fever",
        "runny nose, watery eyes and I keep sneezing",
        "coughing blood and short of breath",
        "my left knee is swollen and stiff",
        "I don't have chest pain, just a sore throat",
        "no fever, my head hurts",
        "feeling nauseus with dizzyness and vomitting",
        "my mother has asthma but I just have a cough",
        "I had a fever last week, now just tired",
    ]
    for c in cases:
        r = L.extract(c)
        print(f"\n{'='*72}\n{c}")
        for s_ in r["symptoms"]:
            print(f"   + {s_['column']:<30} '{s_['matched_text']}'  [{s_['method']} {s_['score']}]")
        for n in r["negated"]:
            print(f"   - {n['column']:<30} '{n['matched_text']}'  DENIED")
        for x in r["excluded"]:
            print(f"   ~ {x['column']:<30} '{x['matched_text']}'  {x['status'].upper()}")
        for c2 in r["clarify"]:
            print(f"   ? {c2['family']:<30} '{c2['matched_text']}'")
        if r["unmatched"]:
            print(f"   ...unmatched: {r['unmatched']}")
