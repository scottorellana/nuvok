import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import promote_tutorial_candidates as promoter


class PromoteTutorialCandidatesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.candidates = self.root / "candidates"
        self.production = self.root / "production"
        self.candidate_ledger = self.root / "candidate-review.json"
        self.production_ledger = self.root / "production-review.json"
        self.candidates.mkdir()
        self.production.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def _approved_entry(self, slug: str, content: bytes = b"candidate") -> dict[str, object]:
        image = self.candidates / f"{slug}.png"
        image.write_bytes(content)
        return {
            "status": "approved",
            "sha256": hashlib.sha256(content).hexdigest(),
            "image": str(image),
            "panels": [
                {"number": number, "pass": True, "note": "clear"}
                for number in (1, 2, 3)
            ],
            "note": "all clear",
            "auditor": "test-auditor",
            "reviewed_at": "2026-07-10T00:00:00+00:00",
        }

    def test_promotes_only_hash_verified_approved_candidate(self):
        entry = self._approved_entry("agua")
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
        self.assertEqual((self.production / "agua.png").read_bytes(), b"candidate")
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

    def test_replacement_failure_rolls_back_all_images_and_ledger(self):
        entries = {
            "agua": self._approved_entry("agua", b"new-agua"),
            "fuego": self._approved_entry("fuego", b"new-fuego"),
        }
        self.candidate_ledger.write_text(json.dumps(entries))
        (self.production / "agua.png").write_bytes(b"old-agua")
        (self.production / "fuego.png").write_bytes(b"old-fuego")
        old_ledger = {"existing": {"status": "approved"}}
        self.production_ledger.write_text(json.dumps(old_ledger))
        original_replace = Path.replace

        def fail_second_staged_replace(source, destination):
            if source.name == "fuego.png" and source.parent.name.startswith(
                ".tutorial-promotion-"
            ):
                raise OSError("simulated replacement failure")
            return original_replace(source, destination)

        with mock.patch.object(Path, "replace", new=fail_second_staged_replace):
            with self.assertRaisesRegex(OSError, "simulated replacement failure"):
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
    def test_directory_target_is_rejected_before_any_production_change(self):
        entries = {
            "agua": self._approved_entry("agua", b"new-agua"),
            "fuego": self._approved_entry("fuego", b"new-fuego"),
        }
        self.candidate_ledger.write_text(json.dumps(entries))
        (self.production / "agua.png").write_bytes(b"old-agua")
        (self.production / "fuego.png").mkdir()
        old_ledger = {"existing": {"status": "approved"}}
        self.production_ledger.write_text(json.dumps(old_ledger))

        with self.assertRaisesRegex(ValueError, "regular file or absent"):
            promoter.promote(
                slugs=["agua", "fuego"],
                candidate_dir=self.candidates,
                candidate_ledger_path=self.candidate_ledger,
                production_dir=self.production,
                production_ledger_path=self.production_ledger,
                root=self.root,
            )

        self.assertEqual((self.production / "agua.png").read_bytes(), b"old-agua")
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
