from pathlib import Path
import tempfile
import unittest

import generate_guide_tutorials as generator


class GenerateGuideTutorialsTest(unittest.TestCase):
    def test_generate_uses_explicit_staging_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staging = root / "candidates"
            production = root / "production"
            staging.mkdir()
            candidate = staging / "test_guide.png"
            candidate.write_bytes(b"x" * 100_001)
            spec = {
                "context": "test context",
                "panels": ["one", "two", "three"],
                "avoid": "nothing",
            }

            ok, message = generator.generate(
                "test_guide",
                spec,
                force=False,
                output_dir=staging,
            )

            self.assertTrue(ok)
            self.assertIn("SKIP", message)
            self.assertEqual(candidate.stat().st_size, 100_001)
            self.assertFalse((production / "test_guide.png").exists())


if __name__ == "__main__":
    unittest.main()
