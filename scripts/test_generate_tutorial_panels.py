from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest import mock

from PIL import Image

import generate_tutorial_panels as generator


class GenerateTutorialPanelsTest(unittest.TestCase):
    def test_cli_defaults_to_high_quality(self):
        args = generator.build_parser().parse_args(["test_guide"])

        self.assertEqual(args.quality, "high")

    def test_panel_prompt_locks_the_same_cast_across_all_panels(self):
        spec = {
            "panels": ["first action", "second action", "third action"],
            "context": "same scene",
            "avoid": "defects",
        }

        prompt = generator.panel_prompt(spec, 0)

        self.assertIn("Continuity cast lock", prompt)
        self.assertIn("same adult instructor", prompt)
        self.assertIn("same casualty or training mannequin", prompt)
        self.assertIn("Never substitute a different person", prompt)

    def test_panel_overrides_change_only_selected_failed_panels(self):
        spec = {
            "panels": ["approved one", "failed two", "approved three"],
            "context": "same scene",
            "avoid": "defects",
        }

        updated = generator.apply_panel_overrides(
            spec,
            {"2": "corrected two", "3": "must not replace approved panel"},
            [2],
        )

        self.assertEqual(
            updated["panels"],
            ["approved one", "corrected two", "approved three"],
        )
        self.assertEqual(spec["panels"], ["approved one", "failed two", "approved three"])

    def test_panel_feedback_is_attached_only_to_its_failed_action(self):
        spec = {
            "panels": ["approved one", "failed two", "failed three"],
            "context": "same scene",
            "avoid": "defects",
        }

        updated = generator.apply_panel_feedback(
            spec,
            {2: "show both straps visibly unclipped", 3: "show the complete seal"},
            [2],
        )

        self.assertEqual(updated["panels"][0], "approved one")
        self.assertIn("failed two", updated["panels"][1])
        self.assertIn("Mandatory visible correction", updated["panels"][1])
        self.assertIn("show both straps visibly unclipped", updated["panels"][1])
        self.assertEqual(updated["panels"][2], "failed three")

    def test_regeneration_groups_are_derived_only_from_current_failed_panels(self):
        ledger = {
            "approved": {
                "status": "approved",
                "panels": [
                    {"number": 1, "pass": True},
                    {"number": 2, "pass": True},
                    {"number": 3, "pass": True},
                ],
            },
            "one_failure": {
                "status": "regenerate",
                "panels": [
                    {"number": 1, "pass": True},
                    {"number": 2, "pass": False},
                    {"number": 3, "pass": True},
                ],
            },
            "two_failures": {
                "status": "regenerate",
                "panels": [
                    {"number": 1, "pass": False},
                    {"number": 2, "pass": True},
                    {"number": 3, "pass": False},
                ],
            },
        }

        groups = generator.regeneration_groups_from_ledger(ledger)

        self.assertEqual(groups, {"2": ["one_failure"], "1,3": ["two_failures"]})

    def test_regeneration_groups_reject_out_of_range_panel_numbers(self):
        ledger = {
            "unsafe": {
                "status": "regenerate",
                "panels": [
                    {"number": 0, "pass": False},
                    {"number": 2, "pass": True},
                    {"number": 3, "pass": True},
                ],
            }
        }

        with self.assertRaisesRegex(ValueError, "exactly panels 1, 2, and 3"):
            generator.regeneration_groups_from_ledger(ledger)

    def test_regeneration_groups_reject_duplicate_or_missing_panel_numbers(self):
        ledger = {
            "unsafe": {
                "status": "regenerate",
                "panels": [
                    {"number": 1, "pass": False},
                    {"number": 1, "pass": False},
                    {"number": 3, "pass": True},
                ],
            }
        }

        with self.assertRaisesRegex(ValueError, "exactly panels 1, 2, and 3"):
            generator.regeneration_groups_from_ledger(ledger)

    def test_regeneration_groups_reject_non_boolean_pass_values(self):
        ledger = {
            "unsafe": {
                "status": "regenerate",
                "panels": [
                    {"number": 1, "pass": False},
                    {"number": 2, "pass": "false"},
                    {"number": 3, "pass": True},
                ],
            }
        }

        with self.assertRaisesRegex(ValueError, "boolean pass verdict"):
            generator.regeneration_groups_from_ledger(ledger)

    def test_generate_panel_writes_only_to_explicit_panel_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            panel_dir = Path(tmp) / "fresh-panels"
            spec = {
                "panels": ["first action", "second action", "third action"],
                "context": "same scene",
                "avoid": "defects",
            }

            def fake_run(command, **_kwargs):
                output = Path(command[3])
                output.parent.mkdir(parents=True, exist_ok=True)
                Image.effect_noise((1024, 1536), 100).convert("RGB").save(output)
                return mock.Mock(returncode=0, stdout="OK", stderr="")

            with mock.patch.object(generator.subprocess, "run", side_effect=fake_run):
                index, ok, _message = generator.generate_panel(
                    "test_guide",
                    spec,
                    0,
                    force=True,
                    quality="high",
                    panel_dir=panel_dir,
                )

            self.assertEqual(index, 0)
            self.assertTrue(ok)
            self.assertTrue((panel_dir / "test_guide/panel_1.png").is_file())
            self.assertFalse(
                (generator.PANEL_DIR / "test_guide/panel_1.png").exists()
            )

    def test_generate_panel_uses_atomic_temporary_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            panel_dir = Path(tmp) / "panels"
            spec = {
                "panels": ["first action", "second action", "third action"],
                "context": "same scene",
                "avoid": "defects",
            }
            provider_outputs = []

            def fake_run(command, **_kwargs):
                provider_output = Path(command[3])
                provider_outputs.append(provider_output)
                Image.effect_noise((1024, 1536), 100).convert("RGB").save(provider_output)
                return mock.Mock(returncode=0, stdout="OK", stderr="")

            with mock.patch.object(generator.subprocess, "run", side_effect=fake_run):
                _index, ok, _message = generator.generate_panel(
                    "test_guide",
                    spec,
                    0,
                    force=True,
                    quality="high",
                    panel_dir=panel_dir,
                )

            final = panel_dir / "test_guide/panel_1.png"
            self.assertTrue(ok)
            self.assertTrue(final.is_file())
            self.assertTrue(provider_outputs)
            self.assertNotEqual(provider_outputs[0], final)
            self.assertFalse(any(path.exists() for path in provider_outputs))

    def test_wrong_provider_dimensions_do_not_replace_existing_panel(self):
        with tempfile.TemporaryDirectory() as tmp:
            panel_dir = Path(tmp) / "panels"
            output = panel_dir / "test_guide/panel_1.png"
            output.parent.mkdir(parents=True)
            Image.effect_noise((1024, 1536), 100).convert("RGB").save(output)
            original = output.read_bytes()
            spec = {
                "panels": ["first action", "second action", "third action"],
                "context": "same scene",
                "avoid": "defects",
            }

            def fake_run(command, **_kwargs):
                Image.effect_noise((864, 1821), 100).convert("RGB").save(Path(command[3]))
                return mock.Mock(returncode=0, stdout="OK", stderr="")

            with mock.patch.object(generator.subprocess, "run", side_effect=fake_run):
                _index, ok, _message = generator.generate_panel(
                    "test_guide",
                    spec,
                    0,
                    force=True,
                    quality="high",
                    panel_dir=panel_dir,
                )

            self.assertFalse(ok)
            self.assertEqual(output.read_bytes(), original)

    def test_source_validation_rejects_jpeg_disguised_as_png(self):
        with tempfile.TemporaryDirectory() as tmp:
            image_path = Path(tmp) / "disguised.png"
            Image.new("RGB", (1024, 1536), "white").save(image_path, format="JPEG")

            with self.assertRaisesRegex(ValueError, "PNG"):
                generator.validate_source_panel(image_path)

    def test_cli_accepts_explicit_fresh_staging_directories(self):
        args = generator.build_parser().parse_args(
            [
                "test_guide",
                "--panel-dir",
                "/tmp/fresh-panels",
                "--output-dir",
                "/tmp/fresh-candidates",
                "--storyboards",
                "/tmp/resolved-storyboards.json",
            ]
        )

        self.assertEqual(args.panel_dir, Path("/tmp/fresh-panels"))
        self.assertEqual(args.output_dir, Path("/tmp/fresh-candidates"))
        self.assertEqual(args.storyboards, Path("/tmp/resolved-storyboards.json"))

    def test_compose_writes_only_to_explicit_staging_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            panel_dir = root / "panels"
            output_dir = root / "candidates"
            production_dir = root / "production"
            slug = "test_guide"
            source_dir = panel_dir / slug
            source_dir.mkdir(parents=True)
            for index, color in enumerate(("red", "green", "blue"), 1):
                Image.new("RGB", (1024, 1536), color).save(
                    source_dir / f"panel_{index}.png"
                )

            result = generator.compose(
                slug,
                panel_dir=panel_dir,
                output_dir=output_dir,
            )

            self.assertEqual(result, output_dir / f"{slug}.png")
            self.assertTrue(result.is_file())
            with Image.open(result) as composed:
                self.assertEqual(composed.size, (1544, 768))
            self.assertFalse((production_dir / f"{slug}.png").exists())

    def test_compose_rejects_wrong_source_dimensions_without_replacing_candidate(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            panel_dir = root / "panels"
            output_dir = root / "candidates"
            source_dir = panel_dir / "test_guide"
            source_dir.mkdir(parents=True)
            output_dir.mkdir()
            candidate = output_dir / "test_guide.png"
            candidate.write_bytes(b"existing-candidate")
            for index in (1, 2):
                Image.new("RGB", (1024, 1536), "white").save(
                    source_dir / f"panel_{index}.png"
                )
            Image.new("RGB", (864, 1821), "white").save(source_dir / "panel_3.png")

            with self.assertRaisesRegex(ValueError, "1024x1536"):
                generator.compose(
                    "test_guide",
                    panel_dir=panel_dir,
                    output_dir=output_dir,
                )

            self.assertEqual(candidate.read_bytes(), b"existing-candidate")

    def test_generate_slugs_rejects_duplicate_writers(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaisesRegex(ValueError, "duplicate tutorial slugs"):
                generator.generate_slugs(
                    ["guide", "guide"],
                    {"guide": {}},
                    selected_panels=[1],
                    force=False,
                    quality="high",
                    workers=2,
                    panel_dir=root / "panels",
                    output_dir=root / "candidates",
                )

    def test_scheduler_keeps_a_global_worker_pool_busy_across_slugs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            panel_dir = root / "panels"
            output_dir = root / "candidates"
            slugs = ["guide_a", "guide_b"]
            for slug in slugs:
                source_dir = panel_dir / slug
                source_dir.mkdir(parents=True)
                for index in (1, 2, 3):
                    Image.new("RGB", (1024, 1536), "white").save(
                        source_dir / f"panel_{index}.png"
                    )

            lock = threading.Lock()
            active = 0
            max_active = 0

            received_panel_dirs = []

            def fake_generate(slug, spec, index, force, quality, panel_dir):
                nonlocal active, max_active
                received_panel_dirs.append(panel_dir)
                with lock:
                    active += 1
                    max_active = max(max_active, active)
                time.sleep(0.05)
                with lock:
                    active -= 1
                return index, True, f"OK {slug}"

            with mock.patch.object(generator, "generate_panel", side_effect=fake_generate):
                failed = generator.generate_slugs(
                    slugs,
                    {slug: {} for slug in slugs},
                    selected_panels=[1],
                    force=False,
                    quality="low",
                    workers=2,
                    panel_dir=panel_dir,
                    output_dir=output_dir,
                )

            self.assertEqual(failed, [])
            self.assertEqual(max_active, 2)
            self.assertEqual(received_panel_dirs, [panel_dir, panel_dir])
            self.assertTrue(
                all((output_dir / f"{slug}.png").is_file() for slug in slugs)
            )


if __name__ == "__main__":
    unittest.main()
