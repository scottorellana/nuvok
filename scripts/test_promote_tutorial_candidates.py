import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from PIL import Image

import audit_all_tutorials as auditor
import promote_tutorial_candidates as promoter


class PromoteTutorialCandidatesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.candidates = self.root / "candidates"
        self.production = self.root / "production"
        self.candidate_ledger = self.root / "candidate-review.json"
        self.production_ledger = self.root / "production-review.json"
        self.storyboards_path = self.root / "storyboards.json"
        self.storyboards = {}
        self.storyboards_patcher = mock.patch.object(
            promoter,
            "DEFAULT_STORYBOARDS",
            self.storyboards_path,
        )
        self.storyboards_patcher.start()
        self.addCleanup(self.storyboards_patcher.stop)
        self.candidates.mkdir()
        self.production.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def _approved_entry(self, slug: str, content: bytes = b"candidate") -> dict[str, object]:
        storyboard: dict[str, object] = {
            "panels": ["first", "second", "third"]
        }
        self.storyboards[slug] = storyboard
        self.storyboards_path.write_text(json.dumps(self.storyboards))
        image = self.candidates / f"{slug}.png"
        color_seed = hashlib.sha256(content).digest()
        Image.new("RGB", (1544, 768), tuple(color_seed[:3])).save(image)
        image_bytes = image.read_bytes()
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
        blind_checks = {
            name: value for name, value in checks.items() if name != "instruction_match"
        }

        def inspection(check_values: dict[str, bool]) -> dict[str, object]:
            return {
                "status": "approved",
                "panels": [
                    {
                        "number": number,
                        "pass": True,
                        "checks": dict(check_values),
                        "note": "clear",
                    }
                    for number in (1, 2, 3)
                ],
                "note": "all clear",
                "risks": [],
            }

        return {
            "status": "approved",
            "sha256": hashlib.sha256(image_bytes).hexdigest(),
            "image": str(image),
            "panels": [
                {
                    "number": number,
                    "pass": True,
                    "checks": dict(checks),
                    "note": "clear",
                }
                for number in (1, 2, 3)
            ],
            "note": "all clear",
            "risks": [],
            "auditor": "nuvok-independent-visual-inspector-gpt-5.5-codex",
            "rubric_version": "nuvok-photorealistic-logic-safety-v3",
            "inspector_version": "nuvok-independent-visual-inspector-v1",
            "inspection_mode": "independent-two-stage-full-resolution",
            "criteria_sha256": auditor.criteria_sha256(slug, storyboard),
            "inspected_dimensions": {"width": 1544, "height": 768},
            "inspections": {
                "blind": inspection(blind_checks),
                "criteria": inspection(checks),
            },
            "reviewed_at": "2026-07-10T00:00:00+00:00",
        }

    def test_promotes_only_hash_verified_approved_candidate(self):
        entry = self._approved_entry("agua")
        expected_bytes = (self.candidates / "agua.png").read_bytes()
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))

        promoted = promoter.promote(
            slugs=["agua"],
            candidate_dir=self.candidates,
            candidate_ledger_path=self.candidate_ledger,
            production_dir=self.production,
            production_ledger_path=self.production_ledger,
            root=self.root,
        )

        self.assertEqual(promoted, ["agua"])
        self.assertEqual((self.production / "agua.png").read_bytes(), expected_bytes)
        ledger = json.loads(self.production_ledger.read_text())
        self.assertEqual(ledger["agua"]["status"], "approved")
        self.assertEqual(ledger["agua"]["sha256"], entry["sha256"])
        self.assertEqual(ledger["agua"]["image"], "production/agua.png")

    def test_hash_mismatch_aborts_before_touching_production(self):
        entry = self._approved_entry("agua")
        entry["sha256"] = "0" * 64
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))

        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            promoter.promote(
                slugs=["agua"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

        self.assertFalse((self.production / "agua.png").exists())
        self.assertFalse(self.production_ledger.exists())

    def test_rejected_candidate_cannot_be_promoted(self):
        entry = self._approved_entry("agua")
        entry["status"] = "regenerate"
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))

        with self.assertRaisesRegex(ValueError, "not approved"):
            promoter.promote(
                slugs=["agua"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

    def test_missing_independent_inspector_metadata_cannot_be_promoted(self):
        entry = self._approved_entry("agua")
        del entry["inspector_version"]
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))

        with self.assertRaisesRegex(ValueError, "independent inspector"):
            promoter.promote(
                slugs=["agua"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

    def test_failed_physical_logic_check_cannot_be_promoted(self):
        entry = self._approved_entry("agua")
        entry["panels"][1]["checks"]["physical_logic"] = False
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))

        with self.assertRaisesRegex(ValueError, "required visual checks"):
            promoter.promote(
                slugs=["agua"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

    def test_stale_photorealism_rubric_cannot_be_promoted(self):
        entry = self._approved_entry("agua")
        entry["rubric_version"] = "nuvok-photorealistic-safety-v2"
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))

        with self.assertRaisesRegex(ValueError, "current visual rubric"):
            promoter.promote(
                slugs=["agua"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

    def test_missing_storyboard_criteria_digest_cannot_be_promoted(self):
        entry = self._approved_entry("agua")
        del entry["criteria_sha256"]
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))

        with self.assertRaisesRegex(ValueError, "storyboard criteria"):
            promoter.promote(
                slugs=["agua"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

    def test_stale_valid_storyboard_digest_cannot_be_promoted(self):
        entry = self._approved_entry("agua")
        entry["criteria_sha256"] = "c" * 64
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))

        with self.assertRaisesRegex(ValueError, "current storyboard criteria"):
            promoter.promote(
                slugs=["agua"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                storyboards_path=self.storyboards_path,
                root=self.root,
            )

        self.assertFalse((self.production / "agua.png").exists())
        self.assertFalse(self.production_ledger.exists())

    def test_candidate_mutation_between_validation_and_staging_aborts(self):
        entry = self._approved_entry("agua", b"approved-bytes")
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))
        original_copyfile = promoter.shutil.copyfile

        def mutate_then_copy(source, destination):
            Path(source).write_bytes(b"changed-after-validation")
            return original_copyfile(source, destination)

        with mock.patch.object(promoter.shutil, "copyfile", side_effect=mutate_then_copy):
            with self.assertRaisesRegex(ValueError, "staged SHA-256 mismatch"):
                promoter.promote(
                    slugs=["agua"],
                    candidate_dir=self.candidates,
                    candidate_ledger_path=self.candidate_ledger,
                    production_dir=self.production,
                    production_ledger_path=self.production_ledger,
                    root=self.root,
                )

        self.assertFalse((self.production / "agua.png").exists())
        self.assertFalse(self.production_ledger.exists())

    def test_multiple_candidates_are_rejected_before_production_changes(self):
        entries = {
            "agua": self._approved_entry("agua", b"new-agua"),
            "fuego": self._approved_entry("fuego", b"new-fuego"),
        }
        self.candidate_ledger.write_text(json.dumps(entries))
        (self.production / "agua.png").write_bytes(b"old-agua")
        (self.production / "fuego.png").write_bytes(b"old-fuego")
        old_ledger = {"existing": {"status": "approved"}}
        self.production_ledger.write_text(json.dumps(old_ledger))

        with self.assertRaisesRegex(ValueError, "one tutorial per invocation"):
            promoter.promote(
                slugs=["agua", "fuego"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

        self.assertEqual((self.production / "agua.png").read_bytes(), b"old-agua")
        self.assertEqual((self.production / "fuego.png").read_bytes(), b"old-fuego")
        self.assertEqual(json.loads(self.production_ledger.read_text()), old_ledger)

    def test_legacy_jpg_published_target_blocks_unused_png_promotion(self):
        entry = self._approved_entry("guide")
        self.candidate_ledger.write_text(json.dumps({"guide": entry}))
        legacy_target = self.production / "guide.jpg"
        legacy_target.write_bytes(b"published-jpeg-bytes")
        old_legacy = legacy_target.read_bytes()

        with self.assertRaisesRegex(ValueError, "published asset uses .jpg"):
            promoter.promote(
                slugs=["guide"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

        self.assertEqual(legacy_target.read_bytes(), old_legacy)
        self.assertFalse((self.production / "guide.png").exists())
        self.assertFalse(self.production_ledger.exists())

    def test_ledger_failure_restores_existing_target_without_unlinking_it(self):
        entry = self._approved_entry("agua", b"new-agua")
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))
        target = self.production / "agua.png"
        target.write_bytes(b"old-agua")
        old_ledger = {"existing": {"status": "approved"}}
        self.production_ledger.write_text(json.dumps(old_ledger))
        original_replace = Path.replace
        original_unlink = Path.unlink
        restoration_target_presence = []
        target_unlinks = []

        def observe_replace(source, destination):
            if source.parent.name == "backups" and Path(destination) == target:
                restoration_target_presence.append(target.is_file())
            return original_replace(source, destination)

        def observe_unlink(path, *args, **kwargs):
            if path == target:
                target_unlinks.append(path)
            return original_unlink(path, *args, **kwargs)

        with (
            mock.patch.object(
                promoter,
                "_write_ledger",
                side_effect=OSError("ledger failure"),
            ),
            mock.patch.object(Path, "replace", new=observe_replace),
            mock.patch.object(Path, "unlink", new=observe_unlink),
        ):
            with self.assertRaisesRegex(OSError, "ledger failure"):
                promoter.promote(
                    slugs=["agua"],
                    candidate_dir=self.candidates,
                    candidate_ledger_path=self.candidate_ledger,
                    production_dir=self.production,
                    production_ledger_path=self.production_ledger,
                    root=self.root,
                )

        self.assertEqual(target.read_bytes(), b"old-agua")
        self.assertEqual(json.loads(self.production_ledger.read_text()), old_ledger)
        self.assertEqual(target_unlinks, [])
        self.assertEqual(restoration_target_presence, [True])

    def test_failed_rollback_preserves_verified_backup_for_recovery(self):
        entry = self._approved_entry("agua", b"new-agua")
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))
        target = self.production / "agua.png"
        target.write_bytes(b"old-agua")
        old_ledger = {"existing": {"status": "approved"}}
        self.production_ledger.write_text(json.dumps(old_ledger))
        original_replace = Path.replace

        def fail_backup_restore(source, destination):
            if source.parent.name == "backups" and Path(destination) == target:
                raise OSError("rollback restore failed")
            return original_replace(source, destination)

        with (
            mock.patch.object(
                promoter,
                "_write_ledger",
                side_effect=OSError("ledger failure"),
            ),
            mock.patch.object(Path, "replace", new=fail_backup_restore),
        ):
            with self.assertRaisesRegex(
                RuntimeError,
                "rollback failed.*recovery files preserved",
            ):
                promoter.promote(
                    slugs=["agua"],
                    candidate_dir=self.candidates,
                    candidate_ledger_path=self.candidate_ledger,
                    production_dir=self.production,
                    production_ledger_path=self.production_ledger,
                    root=self.root,
                )

        recovery_dirs = list(self.production.parent.glob(".tutorial-promotion-*"))
        self.assertEqual(len(recovery_dirs), 1)
        self.assertEqual(
            (recovery_dirs[0] / "backups" / "agua.png").read_bytes(),
            b"old-agua",
        )
        self.assertTrue(target.is_file())
        self.assertEqual(json.loads(self.production_ledger.read_text()), old_ledger)

    def test_existing_target_remains_available_until_atomic_replace(self):
        entry = self._approved_entry("agua", b"new-agua")
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))
        target = self.production / "agua.png"
        target.write_bytes(b"old-agua")
        original_replace = Path.replace
        target_presence = []
        staging_inside_public_dir = []

        def observe_staged_replace(source, destination):
            if (
                source.name == "agua.png"
                and source.parent.name.startswith(".tutorial-promotion-")
            ):
                target_presence.append(Path(destination).is_file())
                staging_inside_public_dir.append(self.production in source.parents)
            return original_replace(source, destination)

        with mock.patch.object(Path, "replace", new=observe_staged_replace):
            promoter.promote(
                slugs=["agua"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

        self.assertEqual(target_presence, [True])
        self.assertEqual(staging_inside_public_dir, [False])

    def test_directory_target_is_rejected_before_any_production_change(self):
        entry = self._approved_entry("fuego", b"new-fuego")
        self.candidate_ledger.write_text(json.dumps({"fuego": entry}))
        (self.production / "fuego.png").mkdir()
        old_ledger = {"existing": {"status": "approved"}}
        self.production_ledger.write_text(json.dumps(old_ledger))

        with self.assertRaisesRegex(ValueError, "regular file or absent"):
            promoter.promote(
                slugs=["fuego"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

        self.assertTrue((self.production / "fuego.png").is_dir())
        self.assertEqual(json.loads(self.production_ledger.read_text()), old_ledger)

    def test_dangling_symlink_target_is_rejected_before_production_change(self):
        entry = self._approved_entry("agua", b"new-agua")
        self.candidate_ledger.write_text(json.dumps({"agua": entry}))
        target = self.production / "agua.png"
        target.symlink_to(self.production / "missing.png")

        with self.assertRaisesRegex(ValueError, "regular file or absent"):
            promoter.promote(
                slugs=["agua"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

        self.assertTrue(target.is_symlink())
        self.assertFalse(self.production_ledger.exists())


if __name__ == "__main__":
    unittest.main()
