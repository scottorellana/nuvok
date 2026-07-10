import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "lib/modules/emergency/emergency_guide_tutorials.dart"
STORYBOARDS = ROOT / "scripts/guide_tutorial_storyboards.json"


class GuideTutorialStoryboardsTest(unittest.TestCase):
    def test_storyboards_match_every_runtime_tutorial(self):
        registry_text = REGISTRY.read_text(encoding="utf-8")
        runtime_slugs = set(
            re.findall(
                r'^\s*"([^"]+)": EmergencyGuideTutorial\(',
                registry_text,
                re.MULTILINE,
            )
        )
        storyboards = json.loads(STORYBOARDS.read_text(encoding="utf-8"))
        self.assertEqual(len(runtime_slugs), 67)
        self.assertEqual(set(storyboards), runtime_slugs)
        for slug, storyboard in storyboards.items():
            with self.subTest(slug=slug):
                self.assertIsInstance(storyboard.get("context"), str)
                self.assertTrue(storyboard["context"].strip())
                self.assertEqual(len(storyboard.get("panels", [])), 3)
                self.assertTrue(all(str(panel).strip() for panel in storyboard["panels"]))
                self.assertIsInstance(storyboard.get("avoid"), str)
                self.assertTrue(storyboard["avoid"].strip())
                self.assertNotIn("render_style", storyboard)


if __name__ == "__main__":
    unittest.main()
