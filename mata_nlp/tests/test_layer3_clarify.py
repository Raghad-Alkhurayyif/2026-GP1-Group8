"""
Layer 3 must not ask a "which kind?" question Layer 1 already asks.

    python3 -m unittest discover mata_nlp/tests
"""

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from pipeline import Pipeline
import layer3_llm


def fake_model(ambiguous):
    return lambda _instruction, _text: json.dumps(
        {"matches": [], "ambiguous": ambiguous})


class NoDuplicateQuestion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layer1 = Pipeline(use_followup=False).layer1

    def run_with(self, text, ambiguous):
        layer3 = layer3_llm.Layer3(self.layer1, client=fake_model(ambiguous))
        return layer3.extend(self.layer1.extract(text))

    def test_misspelling_does_not_ask_twice(self):
        # Seen in the app: Layer 1 asked on the corrected "belly hurts", the
        # model asked again on the raw "belly hurtss".
        r = self.run_with("my belly hurtss so bad", [{
            "matched_text": "belly hurtss",
            "candidates": ["lower abdominal pain", "upper abdominal pain"]}])
        self.assertEqual([c["family"] for c in r["clarify"]],
                         ["abdominal-pain"])

    def run_matches(self, text, matches):
        layer3 = layer3_llm.Layer3(self.layer1, client=lambda _i, _t:
                                   json.dumps({"matches": matches,
                                               "ambiguous": []}))
        return layer3.extend(self.layer1.extract(text))

    def test_vague_leg_is_asked_not_assumed(self):
        # Seen in the app: the model named `leg pain` for "my leg too" and it
        # went in as asserted, where "my leg hurts" alone asks which part.
        r = self.run_matches("my stomach hurts, and my leg too, and my feet", [
            {"column": "leg pain", "matched_text": "leg"},
            {"column": "foot or toe pain", "matched_text": "feet"}])
        self.assertNotIn("leg pain", [s["column"] for s in r["symptoms"]])
        self.assertIn("foot or toe pain", [s["column"] for s in r["symptoms"]])
        self.assertEqual(sorted(c["family"] for c in r["clarify"]),
                         ["abdominal-pain", "lower-limb-pain"])

    def test_a_new_question_is_still_asked(self):
        r = self.run_with("my belly hurtss so bad", [{
            "matched_text": "so bad",
            "candidates": ["sharp chest pain", "burning chest pain"]}])
        self.assertEqual(len(r["clarify"]), 2)


if __name__ == "__main__":
    unittest.main()
