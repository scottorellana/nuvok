from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest import mock

from PIL import Image

import generate_tutorial_panels as generator


class GenerateTutorialPanelsTest(unittest.TestCase):
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

            def fake_generate(slug, spec, index, force, quality):
                nonlocal active, max_active
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
            self.assertTrue(
                all((output_dir / f"{slug}.png").is_file() for slug in slugs)
            )


if __name__ == "__main__":
    unittest.main()
