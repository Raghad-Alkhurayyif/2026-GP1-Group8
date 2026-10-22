"""
ConText trigger rules written for PATIENT language.

Why this file exists. ConText ships a default rule set built for clinical
notes: "history of", "status post", "s/p", "rule out", "r/o", "differential
includes". Run against patient-written text those triggers never fire - this
project measured exactly zero modifiers found in "I had a fever last week, now
just tired", where "last week" should mark the fever as historical.

That is not a defect in ConText. ConText is an ALGORITHM - scope, direction,
termination - plus a rule set for one domain. Adapting the rule set to a new
domain is the intended way to use it, and it is what this file does.

Direction, which is easy to get backwards:
    FORWARD   the trigger comes BEFORE the symptom   "my mother has asthma"
    BACKWARD  the trigger comes AFTER the symptom    "a fever last week"

Categories used here match ConText's own:
    HISTORICAL           the patient's, but not now
    FAMILY               somebody else's
    POSSIBLE_EXISTENCE   mentioned, not asserted

Owner: Aljoury.
"""

# (literal, category, direction)
PATIENT_RULES = [
    # ---- HISTORICAL: it happened, but it is not happening now --------------
    ("last week", "HISTORICAL", "BACKWARD"),
    # "last week" does not match inside "last weekend" - the word boundary
    # falls between "week" and "end" - so the weekend needed its own rule.
    # Aljoury's sentence 3 lost it: "I had a fever last weekend, it's gone now".
    ("last weekend", "HISTORICAL", "BACKWARD"),
    ("over the weekend", "HISTORICAL", "BACKWARD"),
    # Seasons. Found by src/find_trigger_gaps.py: "last winter" appears 13
    # times across the test sentences and nothing covered it, while every
    # other "last <period>" did.
    ("last winter", "HISTORICAL", "BACKWARD"),
    ("last summer", "HISTORICAL", "BACKWARD"),
    ("last spring", "HISTORICAL", "BACKWARD"),
    ("last autumn", "HISTORICAL", "BACKWARD"),
    ("last fall", "HISTORICAL", "BACKWARD"),
    ("a couple of days ago", "HISTORICAL", "BACKWARD"),
    ("a couple days ago", "HISTORICAL", "BACKWARD"),
    ("the other day", "HISTORICAL", "BACKWARD"),
    ("last month", "HISTORICAL", "BACKWARD"),
    ("last year", "HISTORICAL", "BACKWARD"),
    ("last night", "HISTORICAL", "BACKWARD"),
    ("a few days ago", "HISTORICAL", "BACKWARD"),
    ("a week ago", "HISTORICAL", "BACKWARD"),
    ("a month ago", "HISTORICAL", "BACKWARD"),
    ("years ago", "HISTORICAL", "BACKWARD"),
    ("months ago", "HISTORICAL", "BACKWARD"),
    ("days ago", "HISTORICAL", "BACKWARD"),
    ("but it is gone now", "HISTORICAL", "BACKWARD"),
    ("they are gone now", "HISTORICAL", "BACKWARD"),
    ("but that is gone", "HISTORICAL", "BACKWARD"),
    ("cleared up now", "HISTORICAL", "BACKWARD"),
    ("that has gone", "HISTORICAL", "BACKWARD"),
    ("which went away", "HISTORICAL", "BACKWARD"),
    ("used to have", "HISTORICAL", "FORWARD"),
    ("i used to get", "HISTORICAL", "FORWARD"),
    ("in the past", "HISTORICAL", "FORWARD"),
    ("previously", "HISTORICAL", "FORWARD"),
    ("when i was younger", "HISTORICAL", "FORWARD"),
    ("as a child", "HISTORICAL", "FORWARD"),
    # NOT a bare "i had" - it is how people open almost any complaint
    # ("I had a fever and sore throat last week but... this cough"), and it
    # marked the CURRENT symptom historical. Real use caught this.
    ("i used to have", "HISTORICAL", "FORWARD"),
    ("i had it", "HISTORICAL", "FORWARD"),
    # From the gold set's dev half. Seven status errors were a symptom the
    # person says plainly is over, in a shape none of the rules above carried:
    #
    #   "i had terrible migraines in high school but HAVE NOT HAD ONE IN YEARS"
    #   "i had awful back spasms during finals and HAVE NOT HAD THEM SINCE"
    #   "my hand USED TO go numb when i cycled but it stopped"
    #   "a horrible sore throat TWO WEEKS AGO but its COMPLETELY CLEARED now"
    #   "a fever and body aches at the start of the month, RECOVERED FULLY"
    #
    # "have not had X since/in years" is the important one: it is a denial of
    # the symptom NOW, which the negation axis reads correctly as a denial, and
    # the sentence it sits in is reporting the symptom in the PAST. Historical
    # is the honest reading of the pair, and it is scored on its own axis
    # rather than counted as a current complaint.
    ("have not had one in", "HISTORICAL", "BACKWARD"),
    ("have not had them since", "HISTORICAL", "BACKWARD"),
    ("have not had one since", "HISTORICAL", "BACKWARD"),
    ("have not had it since", "HISTORICAL", "BACKWARD"),
    ("have not had any since", "HISTORICAL", "BACKWARD"),
    ("has not happened again", "HISTORICAL", "BACKWARD"),
    ("never happened again", "HISTORICAL", "BACKWARD"),
    ("weeks ago", "HISTORICAL", "BACKWARD"),
    ("completely cleared", "HISTORICAL", "BACKWARD"),
    ("cleared now", "HISTORICAL", "BACKWARD"),
    ("recovered fully", "HISTORICAL", "BACKWARD"),
    ("fully recovered", "HISTORICAL", "BACKWARD"),
    ("and it stopped", "HISTORICAL", "BACKWARD"),
    ("but it stopped", "HISTORICAL", "BACKWARD"),
    ("it has healed", "HISTORICAL", "BACKWARD"),
    ("its healed", "HISTORICAL", "BACKWARD"),
    # Bare "used to", generalising the three templates above. "my hand used to
    # go numb" is not "i used to have" or "i used to get", and the symptom is
    # as over as in either.
    ("used to", "HISTORICAL", "FORWARD"),

    # ---- DEPENDENT: the person being described may BE the patient ----------
    # A parent typing "my son has a fever" is almost always asking about the
    # son, not reporting a relative's illness - the son is the patient and the
    # app is being used by proxy. ConText has no such category; it would call
    # this FAMILY and drop the symptom, which is how three paediatric test
    # cases broke. These are reported separately so the app can confirm who the
    # complaint is about rather than guessing.
    ("my son", "DEPENDENT", "FORWARD"),
    ("my daughter", "DEPENDENT", "FORWARD"),
    ("my child", "DEPENDENT", "FORWARD"),
    ("my kid", "DEPENDENT", "FORWARD"),
    ("my baby", "DEPENDENT", "FORWARD"),
    ("my toddler", "DEPENDENT", "FORWARD"),
    ("my newborn", "DEPENDENT", "FORWARD"),

    # ---- FAMILY: the symptom belongs to someone else -----------------------
    ("my mother", "FAMILY", "FORWARD"),
    ("my mum", "FAMILY", "FORWARD"),
    ("my mom", "FAMILY", "FORWARD"),
    ("my father", "FAMILY", "FORWARD"),
    ("my dad", "FAMILY", "FORWARD"),
    ("my sister", "FAMILY", "FORWARD"),
    ("my brother", "FAMILY", "FORWARD"),
    ("my wife", "FAMILY", "FORWARD"),
    ("my husband", "FAMILY", "FORWARD"),
    ("my friend", "FAMILY", "FORWARD"),
    ("my grandmother", "FAMILY", "FORWARD"),
    ("my granddad", "FAMILY", "FORWARD"),
    ("my grandad", "FAMILY", "FORWARD"),
    ("my grandpa", "FAMILY", "FORWARD"),
    ("my grandma", "FAMILY", "FORWARD"),
    ("my nan", "FAMILY", "FORWARD"),
    ("my grandfather", "FAMILY", "FORWARD"),
    # Relatives the first pass missed. Found while fixing the two scope bugs
    # above: the rule list only had the obvious nouns, so "my partner has a
    # cough" recorded the cough as the patient's own. A relative who is not a
    # child is FAMILY (not the patient's symptom); a child is DEPENDENT, which
    # additionally makes the app ask whose complaint this is.
    ("my partner", "FAMILY", "FORWARD"),
    ("my boyfriend", "FAMILY", "FORWARD"),
    ("my girlfriend", "FAMILY", "FORWARD"),
    ("my aunt", "FAMILY", "FORWARD"),
    ("my uncle", "FAMILY", "FORWARD"),
    ("my cousin", "FAMILY", "FORWARD"),
    ("my niece", "FAMILY", "FORWARD"),
    ("my nephew", "FAMILY", "FORWARD"),
    ("my parents", "FAMILY", "FORWARD"),
    ("my sibling", "FAMILY", "FORWARD"),
    ("my girl", "DEPENDENT", "FORWARD"),
    ("my boy", "DEPENDENT", "FORWARD"),
    ("my little one", "DEPENDENT", "FORWARD"),
    ("my grandson", "DEPENDENT", "FORWARD"),
    ("my granddaughter", "DEPENDENT", "FORWARD"),
    ("runs in my family", "FAMILY", "BACKWARD"),
    ("in my family", "FAMILY", "BACKWARD"),
    ("family history of", "FAMILY", "FORWARD"),
    # Explicit and unambiguous: whatever was just described is not theirs.
    ("not me", "FAMILY", "BACKWARD"),
    ("not mine", "FAMILY", "BACKWARD"),

    # ---- POSSIBLE: raised as a worry, not asserted -------------------------
    ("i was worried it was", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("i am worried it is", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("worried it might be", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("i thought it was", "POSSIBLE_EXISTENCE", "FORWARD"),
    # "I thought I had a swollen eyelid" - raised, not asserted. Where a
    # retraction follows ("...but actually I don't") the denial still wins,
    # because `assess` tests denial before the certainty axis.
    ("i thought i had", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("i think it might be", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("i wonder if it is", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("wondering if i have", "POSSIBLE_EXISTENCE", "FORWARD"),
    # The two above are the same thought with the subject moved, and between
    # them they missed "wondering if it could be X" - which the Layer 2
    # calibration run turned up repeatedly in real leftovers. Without this,
    # Layer 2 reads a DIAGNOSIS the person is guessing at ("I'm wondering if
    # it could be vertigo, but that's just a guess") and files the symptom as
    # asserted. These two generalise the pair rather than matching a template.
    ("wondering if", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("i wonder if", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("could it be", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("might be", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("maybe", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("not sure if it is", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("is this", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("do i have", "POSSIBLE_EXISTENCE", "FORWARD"),
    # From the gold set's dev half. "i think im short of breath? i can talk
    # fine" and "i might have a fever my forehead feels warm but the
    # thermometer keeps changing" are both people weighing a symptom, not
    # reporting one, and both were filed as asserted. The wordings that carry
    # a negator ("not sure if", "cant tell if") are HEDGED_NEGATORS in
    # normalize.py instead - see the note there.
    ("i think i am", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("i think i have", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("i might have", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("i may have", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("it could be", "POSSIBLE_EXISTENCE", "FORWARD"),

    # ---- HYPOTHETICAL: a risk described, not a symptom reported ------------
    # From the LLM layer's output on real forum text. A patient quoting what
    # a doctor or a leaflet told them to expect is not reporting it:
    #
    #   "the doctor did say to only take it 5 days because it CAN CAUSE
    #    extreme stomach pain if taken too long"
    #
    # was read as an assertion of stomach pain. The symptom belongs to a
    # warning about the future, and the right status is uncertain: not
    # counted, but offered for confirmation rather than silently dropped.
    ("can cause", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("could cause", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("may cause", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("might cause", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("can lead to", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("may lead to", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("known to cause", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("side effects include", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("side effects are", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("warned me about", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("told me to watch for", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("watch out for", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("risk of", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("in case of", "POSSIBLE_EXISTENCE", "FORWARD"),

    # ---- COUNTERFACTUAL: something they did NOT have ----------------------
    # "I would rather have had A MIGRAINE than the pain I suffered after
    # taking one of these pills" asserted `headache`. They did not have one;
    # the migraine is the thing they would have preferred. Note the second
    # half of that sentence - "the pain I suffered" - is real, which is why
    # `than` has to stop the scope rather than the whole sentence being
    # discarded.
    ("would rather have had", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("would rather have", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("would have preferred", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("i would take", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("better than having", "POSSIBLE_EXISTENCE", "FORWARD"),
    ("than", "TERMINATE", "TERMINATE"),

    # ---- TERMINATE: where a modifier's reach stops -------------------------
    # Patients separate complaints with these, which the clinical rule set
    # does not expect.
    ("but now", "TERMINATE", "TERMINATE"),
    # The sentence break after a resolved complaint. Without these, a
    # HISTORICAL modifier ran on into the next sentence's real symptom.
    ("the only thing", "TERMINATE", "TERMINATE"),
    ("what is bothering me", "TERMINATE", "TERMINATE"),
    ("bothering me is", "TERMINATE", "TERMINATE"),
    ("right now i have", "TERMINATE", "TERMINATE"),
    ("currently", "TERMINATE", "TERMINATE"),
    ("now just", "TERMINATE", "TERMINATE"),
    ("but it is just", "TERMINATE", "TERMINATE"),
    ("whereas", "TERMINATE", "TERMINATE"),
]


def build(ConTextRule):
    """
    Turn the table above into ConTextRule objects.

    Takes the class as an argument so this module imports with no dependencies
    and can be read, tested and reviewed without medspaCy installed.
    """
    out = []
    for literal, category, direction in PATIENT_RULES:
        try:
            out.append(ConTextRule(literal, category, direction=direction))
        except TypeError:
            # Older medspaCy used `rule=` rather than `direction=`.
            out.append(ConTextRule(literal, category, rule=direction))
    return out


if __name__ == "__main__":
    import collections
    c = collections.Counter(cat for _, cat, _ in PATIENT_RULES)
    print(f"{len(PATIENT_RULES)} patient-language ConText rules")
    for k, v in c.most_common():
        print(f"  {k:<20} {v}")
