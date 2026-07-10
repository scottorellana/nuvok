#!/usr/bin/env python3
"""Promote only hash-verified, visually approved tutorial candidates."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CANDIDATE_DIR = ROOT / ".hermes/tutorial_candidates"
DEFAULT_CANDIDATE_LEDGER = ROOT / ".hermes/tutorial_candidate_review.json"
DEFAULT_PRODUCTION_DIR = ROOT / "assets/emergency_guides/tutorials"
DEFAULT_PRODUCTION_LEDGER = ROOT / "scripts/guide_tutorial_qa.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_ledger(path: Path, *, required: bool) -> dict[str, object]:
    if not path.is_file():
        if required:
            raise ValueError(f"ledger does not exist: {path}")
        return {}
    loaded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(loaded, dict):
        raise ValueError(f"ledger must contain a JSON object: {path}")
    return loaded


def _validate_entry(slug: str, image: Path, entry: object) -> dict[str, object]:
    if not isinstance(entry, dict):
        raise ValueError(f"{slug}: candidate review is missing")
    if entry.get("status") != "approved":
        raise ValueError(f"{slug}: candidate is not approved")
    panels = entry.get("panels")
    if not isinstance(panels, list) or len(panels) != 3:
        raise ValueError(f"{slug}: candidate review must contain three panels")
    numbers: list[int] = []
    for panel in panels:
        if not isinstance(panel, dict) or panel.get("pass") is not True:
            continue
        number = panel.get("number")
        if isinstance(number, int):
            numbers.append(number)
    numbers.sort()
    if numbers != [1, 2, 3]:
        raise ValueError(f"{slug}: all three candidate panels must pass")
    if not image.is_file():
        raise ValueError(f"{slug}: candidate image does not exist: {image}")
    expected_digest = entry.get("sha256")
    actual_digest = sha256(image)
    if expected_digest != actual_digest:
        raise ValueError(
            f"{slug}: SHA-256 mismatch: ledger={expected_digest!r} actual={actual_digest}"
        )
    return dict(entry)


def _display_path(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def _write_ledger(path: Path, ledger: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(ledger, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def promote(
    *,
    slugs: list[str],
    candidate_dir: Path,
    candidate_ledger_path: Path,
    production_dir: Path,
    production_ledger_path: Path,
    root: Path = ROOT,
) -> list[str]:
    if not slugs:
        return []
    if len(slugs) != len(set(slugs)):
        raise ValueError("duplicate candidate slugs")
    for slug in slugs:
        if not slug or Path(slug).name != slug:
            raise ValueError(f"invalid candidate slug: {slug!r}")

    candidate_ledger = _load_ledger(candidate_ledger_path, required=True)
    production_ledger = _load_ledger(production_ledger_path, required=False)

    approved: dict[str, dict[str, object]] = {}
    for slug in slugs:
        image = candidate_dir / f"{slug}.png"
        approved[slug] = _validate_entry(slug, image, candidate_ledger.get(slug))

    production_dir.mkdir(parents=True, exist_ok=True)
    for slug in slugs:
        source = candidate_dir / f"{slug}.png"
        target = production_dir / f"{slug}.png"
        temporary = target.with_suffix(target.suffix + ".tmp")
        shutil.copyfile(source, temporary)
        temporary.replace(target)

        entry = approved[slug]
        entry["image"] = _display_path(target, root)
        entry["promoted_at"] = datetime.now(timezone.utc).isoformat()
        production_ledger[slug] = entry

    _write_ledger(production_ledger_path, production_ledger)
    return list(slugs)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("slugs", nargs="*", help="Approved candidate slugs; defaults to all approved reviews")
    parser.add_argument("--candidate-dir", type=Path, default=DEFAULT_CANDIDATE_DIR)
    parser.add_argument("--candidate-ledger", type=Path, default=DEFAULT_CANDIDATE_LEDGER)
    parser.add_argument("--production-dir", type=Path, default=DEFAULT_PRODUCTION_DIR)
    parser.add_argument("--production-ledger", type=Path, default=DEFAULT_PRODUCTION_LEDGER)
    args = parser.parse_args()

    candidate_ledger = _load_ledger(args.candidate_ledger, required=True)
    slugs = args.slugs or sorted(
        slug
        for slug, entry in candidate_ledger.items()
        if isinstance(slug, str)
        and isinstance(entry, dict)
        and entry.get("status") == "approved"
    )
    promoted = promote(
        slugs=slugs,
        candidate_dir=args.candidate_dir,
        candidate_ledger_path=args.candidate_ledger,
        production_dir=args.production_dir,
        production_ledger_path=args.production_ledger,
    )
    print(f"Promoted {len(promoted)} tutorial candidates: {', '.join(promoted)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
