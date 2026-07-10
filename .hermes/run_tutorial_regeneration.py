#!/usr/bin/env python3
from __future__ import annotations

import copy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import generate_tutorial_panels as generator  # noqa: E402


def main() -> int:
    groups = json.loads(
        (ROOT / ".hermes/tutorial_regeneration_groups.json").read_text(encoding="utf-8")
    )
    storyboards = json.loads(generator.STORYBOARDS.read_text(encoding="utf-8"))
    ledger = json.loads(
        (ROOT / ".hermes/tutorial_candidate_review.json").read_text(encoding="utf-8")
    )
    total = sum(len(slugs) for slugs in groups.values())
    failed: list[str] = []
    for panel_key, slugs in groups.items():
        panels = [int(value) for value in panel_key.split(",")]
        directed: dict[str, dict[str, object]] = {}
        for slug in slugs:
            spec = copy.deepcopy(storyboards[slug])
            notes = [
                str(panel.get("note", "")).strip()
                for panel in ledger[slug].get("panels", [])
                if int(panel.get("number", 0)) in panels and not panel.get("pass", False)
            ]
            feedback = "; ".join(note for note in notes if note)
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
