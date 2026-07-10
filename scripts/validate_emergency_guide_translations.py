#!/usr/bin/env python3
"""Validate every localized emergency guide against the Spanish source tree."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from translate_emergency_guides import GUIDES_DIR, LANGUAGE_NAMES, validate_translation


def validate_tree(root: Path, languages: list[str]) -> dict[str, Any]:
    sources = sorted((root / "es").glob("*.md"))
    report: dict[str, Any] = {
        "source_files": len(sources),
        "translated_files": 0,
        "invalid": 0,
        "languages": {},
    }
    for language in languages:
        errors: dict[str, list[str]] = {}
        existing = 0
        for source_path in sources:
            target_path = root / language / source_path.name
            if not target_path.is_file():
                errors[source_path.stem] = [f"{source_path.stem}: missing translation"]
                continue
            existing += 1
            guide_errors = validate_translation(
                source_path.stem,
                source_path.read_text(encoding="utf-8"),
                target_path.read_text(encoding="utf-8"),
                language,
            )
            if guide_errors:
                errors[source_path.stem] = guide_errors
        report["translated_files"] += existing
        report["invalid"] += len(errors)
        report["languages"][language] = {
            "files": existing,
            "invalid": len(errors),
            "errors": errors,
        }
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--languages",
        nargs="+",
        choices=sorted(LANGUAGE_NAMES),
        default=sorted(LANGUAGE_NAMES),
    )
    parser.add_argument("--root", type=Path, default=GUIDES_DIR)
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()

    report = validate_tree(args.root, args.languages)
    if args.summary:
        summary = {
            "source_files": report["source_files"],
            "translated_files": report["translated_files"],
            "invalid": report["invalid"],
            "languages": {
                language: {
                    "files": result["files"],
                    "invalid": result["invalid"],
                }
                for language, result in report["languages"].items()
            },
        }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    else:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if report["invalid"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
