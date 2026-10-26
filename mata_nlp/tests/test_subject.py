"""
Whose symptom is it, once the user has said who the assessment is for.

    python3 -m unittest discover mata_nlp/tests
"""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from pipeline import Pipeline


def columns(findings):
    return sorted(f["column"] for f in findings)


class ForSubject(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = Pipeline(use_followup=False)

    def view(self, text, who):
        result = self.p.run(text)
        self.assertTrue(result["confirm_subject"], text)
        return self.p.for_subject(result, who)

    # --- the reported case ----------------------------------------------
    def test_sisters_fever_is_not_mine(self):
        v = self.view("my sister has a fever but I don't, I only feel hot",
                      "self")
        self.assertEqual(columns(v["symptoms"]), ["feeling hot"])
        # "but I don't" is the user denying it, so it is recorded as denied.
        self.assertEqual(columns(v["negated"]), ["fever"])
        self.assertFalse(v["confirm_subject"])

    def test_my_symptom_is_not_my_sisters(self):
        v = self.view("my sister has a fever but I don't, I only feel hot",
                      "other")
        self.assertEqual(columns(v["symptoms"]), ["fever"])
        self.assertEqual(columns(v["negated"]), [])

    # --- nothing is dropped without being shown -------------------------
    def test_left_out_symptoms_are_set_aside_for_review(self):
        text = "I have a headache and my daughter has a rash"
        self.assertEqual(columns(self.view(text, "self")["set_aside"]),
                         ["skin rash"])
        self.assertEqual(columns(self.view(text, "other")["set_aside"]),
                         ["headache"])

    def test_a_denied_symptom_is_not_also_set_aside(self):
        # "but I don't" already puts fever in front of the user as denied.
        v = self.view("my sister has a fever but I don't, I only feel hot",
                      "self")
        self.assertEqual(columns(v["set_aside"]), [])
        self.assertEqual(columns(self.view(
            "my sister has a fever but I don't, I only feel hot",
            "other")["set_aside"]), ["feeling hot"])

    # --- two people, one sentence ---------------------------------------
    def test_each_clause_keeps_its_own_person(self):
        text = "I have a headache and my daughter has a rash"
        self.assertEqual(columns(self.view(text, "self")["symptoms"]),
                         ["headache"])
        self.assertEqual(columns(self.view(text, "other")["symptoms"]),
                         ["skin rash"])

    def test_my_head_after_my_son(self):
        # The son's scope used to run to the end of the sentence and take the
        # user's own headache with it.
        text = "my son has a fever and my head hurts"
        self.assertEqual(columns(self.view(text, "self")["symptoms"]),
                         ["headache"])
        self.assertEqual(columns(self.view(text, "other")["symptoms"]),
                         ["fever"])

    def test_a_relatives_list_stays_theirs(self):
        text = "my mother has a fever, a cough, and a headache"
        self.assertEqual(columns(self.view(text, "self")["symptoms"]), [])
        self.assertEqual(columns(self.view(text, "other")["symptoms"]),
                         ["cough", "fever", "headache"])

    def test_pronoun_carries_the_other_person(self):
        v = self.view("my son has a fever. he is also vomiting", "other")
        self.assertEqual(columns(v["symptoms"]), ["fever", "vomiting"])

    def test_shared_symptom_belongs_to_both(self):
        text = "my sister has a fever and I have one too"
        self.assertEqual(columns(self.view(text, "self")["symptoms"]),
                         ["fever"])
        self.assertEqual(columns(self.view(text, "other")["symptoms"]),
                         ["fever"])

    def test_denied_with_the_symptom_named(self):
        v = self.view("my sister has a fever but i do not have a fever. "
                      "i have a headache", "self")
        self.assertEqual(columns(v["symptoms"]), ["headache"])
        self.assertEqual(columns(v["negated"]), ["fever"])

    def test_denial_of_something_else_is_not_ellipsis(self):
        # "but i do not feel hot" denies feeling hot, not the sister's fever.
        v = self.view("my sister has a fever but i do not feel hot", "self")
        self.assertEqual(columns(v["negated"]), ["feeling hot"])

    # --- "not me" -----------------------------------------------------------
    def test_not_me_is_restored_for_them(self):
        text = "my sister has a fever, not me"
        self.assertEqual(columns(self.view(text, "other")["symptoms"]),
                         ["fever"])
        self_view = self.view(text, "self")
        self.assertEqual(columns(self_view["symptoms"]), [])
        self.assertEqual(columns(self_view["negated"]), ["fever"])

    def test_restored_family_is_a_question_and_keeps_its_red_flag(self):
        v = self.view("my dad is coughing up blood, not me", "other")
        self.assertIn("hemoptysis", columns(v["symptoms"]))
        self.assertIn("hemoptysis", columns(v["red_flags"]))
        v = self.view("my dad has crushing chest pain, not me", "other")
        self.assertEqual(v["symptoms"], [])
        self.assertEqual([c["family"] for c in v["clarify"]], ["chest-pain"])

    # --- red flags follow the person ------------------------------------
    def test_red_flag_of_the_other_person_does_not_escalate_me(self):
        text = "my dad is coughing up blood and I feel dizzy"
        self.assertEqual(columns(self.view(text, "self")["red_flags"]), [])
        self.assertEqual(columns(self.view(text, "other")["red_flags"]),
                         ["hemoptysis"])

    # --- nothing changes when nobody else is mentioned ------------------
    def test_own_complaint_is_labelled_self(self):
        r = self.p.run("i have a headache and a fever")
        self.assertFalse(r["confirm_subject"])
        self.assertEqual({s["subject"] for s in r["symptoms"]}, {"self"})

    def test_a_denial_follows_the_person_before_it(self):
        # "no cough" has no subject of its own; the son was named last.
        text = "my son has a fever but no cough"
        self.assertEqual(columns(self.view(text, "self")["negated"]), [])
        self.assertEqual(columns(self.view(text, "other")["negated"]),
                         ["cough"])

    def test_unclear_finding_is_kept_for_both(self):
        # Nobody named before it, nobody after it in its sentence.
        r = self.p.run("fever and a cough. my son is two")
        self.assertEqual(columns(r["symptoms"]), ["cough", "fever"])
        self.assertTrue(r["confirm_subject"])
        for who in ("self", "other"):
            self.assertEqual(
                columns(self.p.for_subject(r, who)["symptoms"]),
                ["cough", "fever"])

    def test_findings_from_later_layers_are_labelled_too(self):
        # Layers 2 and 3 add findings without a `subject`.
        r = self.p.run("my sister has a fever and she is coughing")
        r["symptoms"] = [s for s in r["symptoms"] if s["column"] != "cough"]
        r["symptoms"].append({"column": "cough", "matched_text": "coughing",
                              "layer": "llm"})
        self.assertEqual(columns(self.p.for_subject(r, "self")["symptoms"]),
                         [])
        self.assertEqual(columns(self.p.for_subject(r, "other")["symptoms"]),
                         ["cough", "fever"])

    def test_rejects_an_unknown_subject(self):
        with self.assertRaises(ValueError):
            self.p.for_subject(self.p.run("my son has a fever"), "sister")


# (text, for me: present, denied), (for the other person: present, denied)
CASES = [
    # one person each, in either order
    ("I have a headache. My sister has a fever.",
     (["headache"], []), (["fever"], [])),
    ("My sister has a fever. I have a headache.",
     (["headache"], []), (["fever"], [])),
    ("my wife is vomiting and i have diarrhea",
     (["diarrhea"], []), (["vomiting"], [])),
    ("my husband has a cough, i have a sore throat",
     (["sore throat"], []), (["cough"], [])),
    ("i feel dizzy and my mom has a headache and a fever",
     (["dizziness"], []), (["fever", "headache"], [])),
    ("my mom has a headache, I feel nauseous and dizzy",
     (["dizziness", "nausea"], []), (["headache"], [])),
    ("my daughter has a fever and a rash and i have a cough",
     (["cough"], []), (["fever", "skin rash"], [])),
    ("my baby has diarrhea. I am exhausted",
     (["fatigue"], []), (["diarrhea"], [])),
    ("my son has a fever, i have a cough, and he has a rash",
     (["cough"], []), (["fever", "skin rash"], [])),
    ("my son has a fever and won't eat, and i have a headache",
     (["headache"], []), (["decreased appetite", "fever"], [])),
    ("my father is short of breath and I have a cough",
     (["cough"], []), (["shortness of breath"], [])),
    ("my daughter has a fever of 39 and is very sleepy, i have a headache "
     "from worrying",
     (["headache"], []), (["fever", "sleepiness"], [])),
    # pronouns carry the other person on
    ("she has a fever and i have a headache",
     (["headache"], []), (["fever"], [])),
    ("he has had diarrhea for 3 days and I have nausea",
     (["nausea"], []), (["diarrhea"], [])),
    ("my son has vomiting and i have nausea. he also has a fever",
     (["nausea"], []), (["fever", "vomiting"], [])),
    ("my sister has a fever. her throat is sore. i feel fine but i have a "
     "headache",
     (["headache"], []), (["fever", "sore throat"], [])),
    ("my son's head hurts and he is vomiting",
     ([], []), (["headache", "vomiting"], [])),
    ("my son has had a fever since yesterday and he is coughing",
     ([], []), (["cough", "fever"], [])),
    ("i think my son has a fever", ([], []), (["fever"], [])),
    # only other people
    ("my sister has a cough but my brother has a fever",
     ([], []), (["cough", "fever"], [])),
    ("my dad has back pain, my mom has a headache",
     ([], []), (["back pain", "headache"], [])),
    # the same symptom for both
    ("my sister has a fever and so do i", (["fever"], []), (["fever"], [])),
    ("my sister has a fever, and i have the same",
     (["fever"], []), (["fever"], [])),
    ("both me and my son have a fever", (["fever"], []), (["fever"], [])),
    ("my son and i both have a cough", (["cough"], []), (["cough"], [])),
    ("my brother and I have a rash",
     (["skin rash"], []), (["skin rash"], [])),
    ("me and my wife have diarrhea", (["diarrhea"], []), (["diarrhea"], [])),
    ("my son has a cough. i also have a cough",
     (["cough"], []), (["cough"], [])),
    ("i have a fever like my sister", (["fever"], []), (["fever"], [])),
    ("i have a sore throat, my sister has one too",
     (["sore throat"], []), (["sore throat"], [])),
    ("i have a cough and my son does too", (["cough"], []), (["cough"], [])),
    ("My head hurts and my sister's head hurts too",
     (["headache"], []), (["headache"], [])),
    ("I have a cough. My son has the same cough and a fever",
     (["cough"], []), (["cough", "fever"], [])),
    ("my sister has a cough and a fever but i only have the cough",
     (["cough"], []), (["cough", "fever"], [])),
    # one has it, the other says they do not
    ("my mother is dizzy, I am not", ([], ["dizziness"]), (["dizziness"], [])),
    ("my kid has a rash, not me, i just have a headache",
     (["headache"], ["skin rash"]), (["skin rash"], [])),
    ("my son has a fever, he also has a cough, i have neither",
     ([], ["cough", "fever"]), (["cough", "fever"], [])),
    ("my son has a cough, i do not have a cough but i have a fever",
     (["fever"], ["cough"]), (["cough"], [])),
    ("I don't have a fever but my son does", ([], ["fever"]), (["fever"], [])),
    ("no fever for me, but my daughter has one",
     ([], ["fever"]), (["fever"], [])),
    ("i don't have a cough but my mom has one",
     ([], ["cough"]), (["cough"], [])),
    ("my son has no fever but i do", (["fever"], []), ([], ["fever"])),
    # a relative's past illness, the user's present one
    ("my sister had a fever last week and now i have one",
     (["fever"], []), ([], [])),
]


class EveryVariation(unittest.TestCase):
    """Each sentence answered both ways: for me, and for the other person."""

    @classmethod
    def setUpClass(cls):
        cls.p = Pipeline(use_followup=False)

    def test_cases(self):
        for text, mine, theirs in CASES:
            r = self.p.run(text)
            with self.subTest(text=text):
                self.assertTrue(r["confirm_subject"], "question not asked")
            for who, (present, denied) in (("self", mine), ("other", theirs)):
                v = self.p.for_subject(r, who)
                with self.subTest(text=text, who=who):
                    self.assertEqual(columns(v["symptoms"]), present)
                    self.assertEqual(columns(v["negated"]), denied)
                    # Nothing found is lost: each finding is kept, denied
                    # or set aside for the user to see.
                    shown = set(columns(v["symptoms"]) + columns(v["negated"])
                                + columns(v["set_aside"]))
                    self.assertTrue(set(columns(r["symptoms"])) <= shown)


if __name__ == "__main__":
    unittest.main()
