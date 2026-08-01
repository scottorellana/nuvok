#!/usr/bin/env python3
"""Validate every localized emergency guide against the Spanish source tree."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
from typing import Any

from translate_emergency_guides import GUIDES_DIR, LANGUAGE_NAMES, validate_translation


_INFANT_CPR_TECHNIQUE = {
    "en": "two thumbs side by side",
    "fr": "deux pouces côte à côte",
    "ht": "de gwo pous kòtakòt",
    "ja": "並べた両母指",
    "pt": "dois polegares lado a lado",
    "zh": "并排的双拇指",
}
_INFANT_CHOKING_TECHNIQUE = {
    "en": "heel of one hand",
    "fr": "talon d’une main",
    "ht": "baz pla yon men",
    "ja": "片手の手掌基部",
    "pt": "base de uma mão",
    "zh": "单手掌根",
}
_BACK_BLOWS = {
    "en": "5 back blows",
    "fr": "5 claques dans le dos",
    "ht": "5 frap nan do",
    "ja": "背部叩打を5回",
    "pt": "5 golpes nas costas",
    "zh": "5 次背部拍击",
}


def validate_runtime_contract(slug: str, text: str, language: str) -> list[str]:
    errors: list[str] = []
    if language == "en":
        example_heading = re.search(
            r"^## Example(?:\s*:\s*[^\n]+)?\s*$", text, flags=re.MULTILINE
        )
        if example_heading is None:
            errors.append(f"{slug}: missing runtime heading '## Example'")
            example_section = ""
        else:
            section_start = example_heading.end()
            next_heading = re.search(
                r"^##\s+", text[section_start:], flags=re.MULTILINE
            )
            section_end = (
                section_start + next_heading.start() if next_heading is not None else len(text)
            )
            example_section = text[section_start:section_end]
        for marker in ("**Situation:**", "**Do:**", "**Avoid:**", "**Escalate:**"):
            if re.search(
                rf"^{re.escape(marker)}(?:\s|$)", example_section, flags=re.MULTILINE
            ) is None:
                errors.append(f"{slug}: missing runtime example marker '{marker}'")

    required: list[str] = []
    if slug == "rcp_adulto":
        required = ["100–120", "5–6 cm", "30:2", "10"]
    elif slug == "rcp_nino_bebe":
        required = [
            "100–120",
            "30:2",
            "15:2",
            "4 cm",
            "5 cm",
            _INFANT_CPR_TECHNIQUE[language],
        ]
    elif slug == "atragantamiento":
        required = [_BACK_BLOWS[language], _INFANT_CHOKING_TECHNIQUE[language]]
    lowered = text.lower()
    for token in required:
        if token.lower() not in lowered:
            errors.append(f"{slug}: missing AHA token '{token}'")
    return errors


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
            target_text = target_path.read_text(encoding="utf-8")
            guide_errors = validate_translation(
                source_path.stem,
                source_path.read_text(encoding="utf-8"),
                target_text,
                language,
            )
            guide_errors.extend(
                validate_runtime_contract(source_path.stem, target_text, language)
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
