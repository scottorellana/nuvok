import unittest

import audit_all_tutorials as auditor


class AuditAllTutorialsTest(unittest.TestCase):
    def test_parses_strict_approved_response(self):
        raw = '''```json
{
  "status": "approved",
  "panels": [
    {"number": 1, "pass": true, "note": "Clear"},
    {"number": 2, "pass": true, "note": "Clear"},
    {"number": 3, "pass": true, "note": "Clear"}
  ],
  "note": "All actions are visible",
  "risks": []
}
```'''
        result = auditor.parse_audit_response(raw)
        self.assertEqual(result["status"], "approved")
        self.assertEqual(len(result["panels"]), 3)

    def test_rejects_approved_when_a_panel_fails(self):
        raw = '''{
          "status": "approved",
          "panels": [
            {"number": 1, "pass": true, "note": "ok"},
            {"number": 2, "pass": false, "note": "bad"},
            {"number": 3, "pass": true, "note": "ok"}
          ],
          "note": "wrong verdict",
          "risks": ["bad hand"]
        }'''
        with self.assertRaisesRegex(ValueError, "cannot be approved"):
            auditor.parse_audit_response(raw)

    def test_rejects_missing_or_duplicate_panel_numbers(self):
        raw = '''{
          "status": "regenerate",
          "panels": [
            {"number": 1, "pass": true, "note": "ok"},
            {"number": 1, "pass": false, "note": "bad"},
            {"number": 3, "pass": true, "note": "ok"}
          ],
          "note": "bad",
          "risks": []
        }'''
        with self.assertRaisesRegex(ValueError, "exactly 1, 2, 3"):
            auditor.parse_audit_response(raw)

    def test_prompt_evaluates_visual_together_with_runtime_caption(self):
        prompt = auditor.prompt_for(
            "agua",
            {
                "panels": ["measure 30 drops", "wait", "drink"],
                "render_style": "field_photo",
            },
        )
        self.assertIn("exact localized caption", prompt)
        self.assertIn("invisible quantities", prompt)
        self.assertNotIn("without relying on captions", prompt)

    def test_prompt_keeps_hands_on_technique_geometry_non_negotiable(self):
        prompt = auditor.prompt_for(
            "rcp",
            {
                "panels": ["hand contact", "compress", "ventilate"],
                "render_style": "clinical_diagram",
            },
        )
        self.assertIn("contact points, body landmarks, tool placement", prompt)
        self.assertIn("must still be exact", prompt)

    def test_prompt_requires_documentary_photorealism(self):
        prompt = auditor.prompt_for(
            "refugio",
            {"panels": ["prepare", "build", "finish"]},
        )
        self.assertIn(
            "indistinguishable from a real documentary training photograph",
            prompt,
        )
        self.assertIn("CGI, 3D render, vector art, drawing, painting", prompt)


if __name__ == "__main__":
    unittest.main()
