import hashlib
import json
from pathlib import Path
import re
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "lib/modules/emergency/emergency_guide_tutorials.dart"
IMAGE_DIR = ROOT / "assets/emergency_guides/tutorials"
LEDGER = ROOT / "scripts/guide_tutorial_qa.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class TutorialProductionGateTest(unittest.TestCase):
    def test_every_runtime_tutorial_has_hash_bound_visual_approval(self):
        runtime_slugs = set(
            re.findall(
                r'^\s*"([^"]+)": EmergencyGuideTutorial\(',
                REGISTRY.read_text(encoding="utf-8"),
                re.MULTILINE,
            )
        )
        images = {path.stem: path for path in IMAGE_DIR.glob("*.png")}
        ledger = json.loads(LEDGER.read_text(encoding="utf-8"))

        self.assertEqual(len(runtime_slugs), 67)
        self.assertEqual(set(images), runtime_slugs)
        self.assertEqual(set(ledger), runtime_slugs)

        for slug in sorted(runtime_slugs):
            with self.subTest(slug=slug):
                image_path = images[slug]
                self.assertGreater(image_path.stat().st_size, 50_000)
                with Image.open(image_path) as image:
                    width, height = image.size
                    # The runtime renders the whole triptych with BoxFit.contain
                    # and offers 5x zoom. Accept both the legacy 2:1 composites
                    # and the current 1544x768 compositor output, but require
                    # enough pixels for each panel to remain inspectable.
                    self.assertGreaterEqual(width, 1500)
                    self.assertGreaterEqual(height, 768)
                    self.assertGreater(width / height, 1.45)
                    self.assertLess(width / height, 2.30)
                review = ledger[slug]
                self.assertEqual(review.get("status"), "approved")
                self.assertEqual(review.get("sha256"), sha256(image_path))
                self.assertEqual(
                    [panel.get("number") for panel in review.get("panels", [])],
                    [1, 2, 3],
                )
                self.assertTrue(all(panel.get("pass") for panel in review["panels"]))


if __name__ == "__main__":
    unittest.main()
