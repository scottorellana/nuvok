#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import generate_tutorial_panels as generator  # noqa: E402

OVERRIDES = ROOT / "scripts/tutorial_panel_regeneration_overrides.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ledger",
        type=Path,
        required=True,
        help="Exact SHA-bound audit ledger that selects failed panels.",
    )
    parser.add_argument(
        "--image-dir",
        type=Path,
        required=True,
        help="Candidate image directory bound to the audit ledger.",
    )
    args = parser.parse_args()
    if not args.ledger.is_file():
        parser.error(f"audit ledger does not exist: {args.ledger}")
    storyboards = json.loads(generator.STORYBOARDS.read_text(encoding="utf-8"))
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    if set(ledger) != set(storyboards):
        parser.error("audit ledger must cover exactly every tutorial storyboard")
    for slug, entry in ledger.items():
        image = args.image_dir / f"{slug}.png"
        if not image.is_file():
            parser.error(f"candidate image does not exist: {image}")
        actual_digest = hashlib.sha256(image.read_bytes()).hexdigest()
        expected_digest = entry.get("sha256") if isinstance(entry, dict) else None
        if actual_digest != expected_digest:
            parser.error(
                f"candidate SHA-256 mismatch for {slug}: "
                f"ledger={expected_digest!r} actual={actual_digest}"
            )
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8"))
    groups = generator.regeneration_groups_from_ledger(ledger)
    total = sum(len(slugs) for slugs in groups.values())
    failed: list[str] = []
    for panel_key, slugs in groups.items():
        panels = [int(value) for value in panel_key.split(",")]
        directed: dict[str, dict[str, object]] = {}
        for slug in slugs:
            spec = generator.apply_panel_overrides(
                storyboards[slug], overrides.get(slug, {}), panels
            )
            panel_feedback = {
                int(panel.get("number", 0)): str(panel.get("note", "")).strip()
                for panel in ledger[slug].get("panels", [])
                if int(panel.get("number", 0)) in panels and not panel.get("pass", False)
            }
            spec = generator.apply_panel_feedback(spec, panel_feedback, panels)
            feedback = "; ".join(note for note in panel_feedback.values() if note)
            if feedback:
                spec["avoid"] = (
                    f"{spec['avoid']}. The previous candidate was rejected for these visible "
                    f"defects; explicitly correct them: {feedback}"
                )
            directed[slug] = spec
        print(f"\n=== panels {panels}: {len(slugs)} tutorials ===", flush=True)
        failed.extend(
            generator.generate_slugs(
                slugs,
                directed,
                selected_panels=panels,
                force=True,
                quality="high",
                workers=3,
            )
        )
    unique_failures = sorted(set(failed))
    print(
        f"Regeneration complete: {total - len(unique_failures)}/{total} composed; "
        f"failures={unique_failures}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
