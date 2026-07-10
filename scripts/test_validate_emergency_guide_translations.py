import tempfile
import unittest
from pathlib import Path

import validate_emergency_guide_translations as validator


class ValidateEmergencyGuideTranslationsTest(unittest.TestCase):
    def test_reports_invalid_target_without_network(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "es").mkdir()
            (root / "en").mkdir()
            source = "---\npriority: 1\n---\n# Agua\n\n- Hervir 10 min.\n"
            (root / "es" / "agua.md").write_text(source, encoding="utf-8")
            (root / "en" / "agua.md").write_text(
                "---\npriority: 1\n---\n# Water\n\nBoil 5 min.\n",
                encoding="utf-8",
            )

            report = validator.validate_tree(root, ["en"])

            self.assertEqual(report["translated_files"], 1)
            self.assertEqual(report["invalid"], 1)
            self.assertIn("agua", report["languages"]["en"]["errors"])

    def test_accepts_structurally_equivalent_translation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "es").mkdir()
            (root / "en").mkdir()
            (root / "es" / "agua.md").write_text(
                "# Agua\n\n- Hervir 10 min.\n", encoding="utf-8"
            )
            (root / "en" / "agua.md").write_text(
                "# Water\n\n- Boil 10 min.\n", encoding="utf-8"
            )

            report = validator.validate_tree(root, ["en"])

            self.assertEqual(report["invalid"], 0)


if __name__ == "__main__":
    unittest.main()
