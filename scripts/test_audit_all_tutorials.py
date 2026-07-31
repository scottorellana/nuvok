import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from PIL import Image

import audit_all_tutorials as auditor


class AuditAllTutorialsTest(unittest.TestCase):
    def _checks(self, **overrides):
        checks = {
            "photorealism": True,
            "anatomy": True,
            "object_integrity": True,
            "physical_logic": True,
            "continuity": True,
            "instruction_match": True,
            "safety": True,
            "text_free": True,
        }
        checks.update(overrides)
        return checks

    def _panel(self, number, passed=True, **check_overrides):
        return {
            "number": number,
            "pass": passed,
            "checks": self._checks(**check_overrides),
            "note": "Clear" if passed else "Visible defect",
        }

    def test_parses_strict_approved_response(self):
        payload = {
            "status": "approved",
            "panels": [self._panel(number) for number in (1, 2, 3)],
            "note": "All actions are visible",
            "risks": [],
        }
        raw = f"```json\n{json.dumps(payload)}\n```"
        result = auditor.parse_audit_response(raw)
        self.assertEqual(result["status"], "approved")
        self.assertEqual(len(result["panels"]), 3)
        self.assertEqual(
            set(result["panels"][0]["checks"]),
            set(auditor.REQUIRED_PANEL_CHECKS),
        )

    def test_rejects_approved_when_a_panel_fails(self):
        raw = json.dumps(
            {
                "status": "approved",
                "panels": [
                    self._panel(1),
                    self._panel(2, False, anatomy=False),
                    self._panel(3),
                ],
                "note": "wrong verdict",
                "risks": ["bad hand"],
            }
        )
        with self.assertRaisesRegex(ValueError, "cannot be approved"):
            auditor.parse_audit_response(raw)

    def test_rejects_panel_pass_when_any_logic_check_is_false(self):
        raw = json.dumps(
            {
                "status": "approved",
                "panels": [
                    self._panel(1, True, physical_logic=False),
                    self._panel(2),
                    self._panel(3),
                ],
                "note": "wrong panel verdict",
                "risks": ["object contact is impossible"],
            }
        )

        with self.assertRaisesRegex(ValueError, "must equal all required checks"):
            auditor.parse_audit_response(raw)

    def test_rejects_missing_required_visual_check(self):
        panel = self._panel(1)
        del panel["checks"]["anatomy"]
        raw = json.dumps(
            {
                "status": "approved",
                "panels": [panel, self._panel(2), self._panel(3)],
                "note": "missing anatomy inspection",
                "risks": [],
            }
        )

        with self.assertRaisesRegex(ValueError, "exact required checks"):
            auditor.parse_audit_response(raw)

    def test_rejects_missing_or_duplicate_panel_numbers(self):
        raw = json.dumps(
            {
                "status": "regenerate",
                "panels": [
                    self._panel(1),
                    self._panel(1, False, anatomy=False),
                    self._panel(3),
                ],
                "note": "bad",
                "risks": [],
            }
        )
        with self.assertRaisesRegex(ValueError, "exactly 1, 2, 3"):
            auditor.parse_audit_response(raw)

    def test_cli_accepts_explicit_storyboard_snapshot(self):
        args = auditor.build_parser().parse_args(
            [
                "rcp_adulto",
                "--image-dir",
                "/tmp/candidates",
                "--ledger",
                "/tmp/candidate-qa.json",
                "--storyboards",
                "/tmp/resolved-storyboards.json",
            ]
        )

        self.assertEqual(args.storyboards, auditor.Path("/tmp/resolved-storyboards.json"))
        self.assertEqual(args.image_dir, auditor.Path("/tmp/candidates"))
        self.assertEqual(args.ledger, auditor.Path("/tmp/candidate-qa.json"))

    def test_audit_metadata_binds_hash_and_rubric_version(self):
        result = {
            "status": "approved",
            "panels": [
                self._panel(1),
                self._panel(2),
                self._panel(3),
            ],
            "note": "ok",
            "risks": [],
            "inspections": {
                "blind": {"status": "approved"},
                "criteria": {"status": "approved"},
            },
        }

        record = auditor.bind_audit_metadata(
            result,
            digest="abc123",
            image=Path("/tmp/candidate.png"),
            dimensions=(1544, 768),
            criteria_digest="def456",
        )

        self.assertEqual(record["sha256"], "abc123")
        self.assertEqual(record["rubric_version"], auditor.RUBRIC_VERSION)
        self.assertEqual(record["inspector_version"], auditor.INSPECTOR_VERSION)
        self.assertEqual(record["inspection_mode"], "independent-two-stage-full-resolution")
        self.assertEqual(record["inspected_dimensions"], {"width": 1544, "height": 768})
        self.assertEqual(record["image"], "/tmp/candidate.png")
        self.assertEqual(record["criteria_sha256"], "def456")
        self.assertIn("reviewed_at", record)

    def test_snapshot_remains_bound_to_reviewed_bytes_when_candidate_changes(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            candidate = root / "candidate.png"
            snapshots = root / "snapshots"
            Image.new("RGB", (1544, 768), "red").save(candidate)

            snapshot, digest, dimensions = auditor.create_audit_snapshot(
                candidate,
                snapshots,
                "guide",
            )
            Image.new("RGB", (1544, 768), "blue").save(candidate)

            self.assertEqual(auditor.sha256(snapshot), digest)
            self.assertEqual(dimensions, (1544, 768))
            self.assertFalse(
                auditor.candidate_matches_snapshot(candidate, digest, dimensions)
            )

    def test_each_inspection_stage_rejects_a_changed_snapshot(self):
        for mutate_on_call in (1, 2):
            with self.subTest(mutate_on_call=mutate_on_call), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                candidate = root / "candidate.png"
                Image.new("RGB", (1544, 768), "red").save(candidate)
                snapshot, digest, dimensions = auditor.create_audit_snapshot(
                    candidate,
                    root / "snapshots",
                    "guide",
                )
                calls = 0

                def fake_inspection(image, _prompt, required_checks):
                    nonlocal calls
                    calls += 1
                    if calls == mutate_on_call:
                        image.chmod(0o644)
                        Image.new("RGB", (1544, 768), "blue").save(image)
                    return {
                        "status": "approved",
                        "panels": [
                            {
                                "number": number,
                                "pass": True,
                                "checks": {check: True for check in required_checks},
                                "note": "clear",
                            }
                            for number in (1, 2, 3)
                        ],
                        "note": "clear",
                        "risks": [],
                    }

                with mock.patch.object(
                    auditor,
                    "_run_inspection_stage",
                    side_effect=fake_inspection,
                ):
                    with self.assertRaisesRegex(RuntimeError, "audit snapshot changed"):
                        auditor.run_audit(
                            snapshot,
                            "guide",
                            {"panels": ["one", "two", "three"]},
                            expected_digest=digest,
                            expected_dimensions=dimensions,
                        )

                self.assertEqual(calls, mutate_on_call)

    def test_full_resolution_validation_rejects_jpeg_disguised_as_png(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            image_path = Path(temp_dir) / "disguised.png"
            Image.new("RGB", (1544, 768), "white").save(image_path, format="JPEG")

            with self.assertRaisesRegex(ValueError, "PNG"):
                auditor.validate_full_resolution(image_path)

    def test_reusable_record_is_invalid_when_storyboard_criteria_change(self):
        result = {
            "status": "regenerate",
            "panels": [
                self._panel(1),
                self._panel(2, False, anatomy=False),
                self._panel(3),
            ],
            "note": "visible defect",
            "risks": ["bad hand"],
            "inspections": {
                "blind": {
                    "status": "regenerate",
                    "panels": [
                        {
                            **self._panel(number),
                            "checks": {
                                key: value
                                for key, value in self._panel(number)["checks"].items()
                                if key != "instruction_match"
                            },
                        }
                        for number in (1, 2, 3)
                    ],
                    "note": "defect",
                    "risks": ["bad hand"],
                },
                "criteria": {
                    "status": "regenerate",
                    "panels": [
                        self._panel(1),
                        self._panel(2, False, anatomy=False),
                        self._panel(3),
                    ],
                    "note": "defect",
                    "risks": ["bad hand"],
                },
            },
        }
        record = auditor.bind_audit_metadata(
            result,
            digest="a" * 64,
            image=Path("/tmp/candidate.png"),
            dimensions=(1544, 768),
            criteria_digest="b" * 64,
        )

        self.assertFalse(
            auditor.is_reusable_audit_record(
                record,
                digest="a" * 64,
                dimensions=(1544, 768),
                criteria_digest="c" * 64,
            )
        )

    def test_reusable_record_requires_exact_auditor_identity(self):
        blind_panels = []
        for number in (1, 2, 3):
            panel = self._panel(number)
            del panel["checks"]["instruction_match"]
            blind_panels.append(panel)
        result = {
            "status": "approved",
            "panels": [self._panel(number) for number in (1, 2, 3)],
            "note": "approved",
            "risks": [],
            "inspections": {
                "blind": {
                    "status": "approved",
                    "panels": blind_panels,
                    "note": "approved",
                    "risks": [],
                },
                "criteria": {
                    "status": "approved",
                    "panels": [self._panel(number) for number in (1, 2, 3)],
                    "note": "approved",
                    "risks": [],
                },
            },
        }
        record = auditor.bind_audit_metadata(
            result,
            digest="a" * 64,
            image=Path("/tmp/candidate.png"),
            dimensions=(1544, 768),
            criteria_digest="b" * 64,
        )

        for invalid_auditor in (None, "different-inspector"):
            with self.subTest(auditor=invalid_auditor):
                candidate = dict(record)
                if invalid_auditor is None:
                    candidate.pop("auditor")
                else:
                    candidate["auditor"] = invalid_auditor
                self.assertFalse(
                    auditor.is_reusable_audit_record(
                        candidate,
                        digest="a" * 64,
                        dimensions=(1544, 768),
                        criteria_digest="b" * 64,
                    )
                )

    def test_full_resolution_validation_rejects_non_shipping_dimensions(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            image_path = Path(temp_dir) / "small.png"
            Image.new("RGB", (772, 384), "white").save(image_path)

            with self.assertRaisesRegex(ValueError, "1544x768"):
                auditor.validate_full_resolution(image_path)

    def test_blind_prompt_does_not_reveal_storyboard_actions(self):
        prompt = auditor.blind_prompt_for("rcp_adulto")

        self.assertIn("Do not infer the intended tutorial", prompt)
        self.assertIn("photorealism", prompt)
        self.assertNotIn("compress", prompt.lower())

    def test_combined_verdict_requires_blind_and_criteria_pass(self):
        blind = {
            "status": "regenerate",
            "panels": [
                self._panel(1),
                self._panel(2, False, anatomy=False),
                self._panel(3),
            ],
            "note": "blind inspector found malformed anatomy",
            "risks": ["malformed hand"],
        }
        criteria = {
            "status": "approved",
            "panels": [self._panel(number) for number in (1, 2, 3)],
            "note": "procedure appears to match",
            "risks": [],
        }

        combined = auditor.combine_inspections(blind, criteria)

        self.assertEqual(combined["status"], "regenerate")
        self.assertFalse(combined["panels"][1]["pass"])
        self.assertFalse(combined["panels"][1]["checks"]["anatomy"])
        self.assertEqual(combined["inspections"]["blind"], blind)
        self.assertEqual(combined["inspections"]["criteria"], criteria)

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
