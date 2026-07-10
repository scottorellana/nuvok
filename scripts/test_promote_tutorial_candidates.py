import hashlib
import json
from pathlib import Path
import tempfile
import unittest

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


if __name__ == "__main__":
    unittest.main()
