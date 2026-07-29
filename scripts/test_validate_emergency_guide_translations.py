import tempfile
import unittest
from pathlib import Path

import validate_emergency_guide_translations as validator
from validate_emergency_guide_translations import validate_runtime_contract


class ValidateRuntimeContractTest(unittest.TestCase):
    def test_rejects_english_example_with_noncanonical_heading_and_marker(self):
        text = """# Guide

## Practical example: Water

**Situation:** Flood.
**Do:** 1. Collect water.
**Avoid:** Mud.
**Scale:** Call for help.
"""

        errors = validate_runtime_contract("agua", text, "en")

        self.assertIn("agua: missing runtime heading '## Example'", errors)
        self.assertIn("agua: missing runtime example marker '**Escalate:**'", errors)

    def test_rejects_changed_aha_numeric_token(self):
        text = "100〜120 30:2 15:2 4 cm 5 cm 片手の手掌基部"

        errors = validate_runtime_contract("rcp_nino_bebe", text, "ja")

        self.assertIn("rcp_nino_bebe: missing AHA token '100–120'", errors)
    def test_rejects_pluralized_example_heading(self):
        text = """## Examples
**Situation:** Flood.
**Do:** Collect water.
**Avoid:** Mud.
**Escalate:** Call for help.
"""

        errors = validate_runtime_contract("agua", text, "en")

        self.assertIn("agua: missing runtime heading '## Example'", errors)

    def test_rejects_markers_embedded_in_unrelated_prose(self):
        text = """## Example
This paragraph mentions **Situation:**, **Do:**, **Avoid:**, and **Escalate:** labels.
"""

        errors = validate_runtime_contract("agua", text, "en")

        self.assertIn("agua: missing runtime example marker '**Situation:**'", errors)
    def test_rejects_markers_outside_the_example_section(self):
        text = """## Example: Water
No structured runtime fields are present here.

## Appendix
**Situation:** Flood.
**Do:** Collect water.
**Avoid:** Mud.
**Escalate:** Call for help.
"""

        errors = validate_runtime_contract("agua", text, "en")

        self.assertIn("agua: missing runtime example marker '**Situation:**'", errors)


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
                "# Agua\n\n## Ejemplo\n\n**Situación:** Inundación.\n"
                "**Haz:** Hierve 10 min.\n**Evita:** Lodo.\n**Escala:** Pide ayuda.\n",
                encoding="utf-8",
            )
            (root / "en" / "agua.md").write_text(
                "# Water\n\n## Example\n\n**Situation:** Flood.\n"
                "**Do:** Boil 10 min.\n**Avoid:** Mud.\n**Escalate:** Get help.\n",
                encoding="utf-8",
            )

            report = validator.validate_tree(root, ["en"])

            self.assertEqual(report["invalid"], 0)

    def test_reports_missing_translation_in_counts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "es").mkdir()
            (root / "en").mkdir()
            (root / "es" / "agua.md").write_text("# Agua\n", encoding="utf-8")

            report = validator.validate_tree(root, ["en"])

            self.assertEqual(report["source_files"], 1)
            self.assertEqual(report["translated_files"], 0)
            self.assertEqual(report["invalid"], 1)
            self.assertIn("agua", report["languages"]["en"]["errors"])


if __name__ == "__main__":
    unittest.main()
