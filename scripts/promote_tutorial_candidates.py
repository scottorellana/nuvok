#!/usr/bin/env python3
"""Promote only hash-verified, visually approved tutorial candidates."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

from audit_all_tutorials import (
    AUDITOR_ID,
    BLIND_PANEL_CHECKS,
    EXPECTED_FINAL_SIZE,
    INSPECTION_MODE,
    INSPECTOR_VERSION,
    REQUIRED_PANEL_CHECKS,
    RUBRIC_VERSION,
    STORYBOARDS,
    criteria_sha256,
    parse_audit_response,
    validate_full_resolution,
)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CANDIDATE_DIR = ROOT / ".hermes/tutorial_candidates"
DEFAULT_CANDIDATE_LEDGER = ROOT / ".hermes/tutorial_candidate_review.json"
DEFAULT_PRODUCTION_DIR = ROOT / "assets/emergency_guides/tutorials"
DEFAULT_PRODUCTION_LEDGER = ROOT / "scripts/guide_tutorial_qa.json"
DEFAULT_STORYBOARDS = STORYBOARDS


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


def _load_storyboards(path: Path) -> dict[str, object]:
    if not path.is_file():
        raise ValueError(f"storyboard registry does not exist: {path}")
    loaded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(loaded, dict):
        raise ValueError(f"storyboard registry must contain a JSON object: {path}")
    return loaded


def _validate_entry(
    slug: str,
    image: Path,
    entry: object,
    *,
    expected_criteria_digest: str,
) -> dict[str, object]:
    if not isinstance(entry, dict):
        raise ValueError(f"{slug}: candidate review is missing")
    if entry.get("status") != "approved":
        raise ValueError(f"{slug}: candidate is not approved")
    if entry.get("rubric_version") != RUBRIC_VERSION:
        raise ValueError(f"{slug}: candidate was not approved by the current visual rubric")
    if (
        entry.get("auditor") != AUDITOR_ID
        or entry.get("inspector_version") != INSPECTOR_VERSION
        or entry.get("inspection_mode") != INSPECTION_MODE
    ):
        raise ValueError(f"{slug}: candidate lacks the required independent inspector")
    criteria_digest = entry.get("criteria_sha256")
    if (
        not isinstance(criteria_digest, str)
        or len(criteria_digest) != 64
        or any(character not in "0123456789abcdef" for character in criteria_digest)
    ):
        raise ValueError(f"{slug}: candidate lacks a valid storyboard criteria SHA-256")
    if criteria_digest != expected_criteria_digest:
        raise ValueError(f"{slug}: candidate does not match current storyboard criteria")
    if entry.get("inspected_dimensions") != {
        "width": EXPECTED_FINAL_SIZE[0],
        "height": EXPECTED_FINAL_SIZE[1],
    }:
        raise ValueError(f"{slug}: candidate lacks full-resolution inspection evidence")
    reviewed_at = entry.get("reviewed_at")
    if not isinstance(reviewed_at, str):
        raise ValueError(f"{slug}: candidate lacks an inspector timestamp")
    try:
        reviewed_datetime = datetime.fromisoformat(reviewed_at)
    except ValueError as exc:
        raise ValueError(f"{slug}: candidate inspector timestamp is invalid") from exc
    if reviewed_datetime.tzinfo is None:
        raise ValueError(f"{slug}: candidate inspector timestamp must include a timezone")

    inspections = entry.get("inspections")
    if not isinstance(inspections, dict):
        raise ValueError(f"{slug}: candidate lacks both independent inspections")
    blind = inspections.get("blind")
    criteria = inspections.get("criteria")
    if not isinstance(blind, dict) or not isinstance(criteria, dict):
        raise ValueError(f"{slug}: candidate lacks both independent inspections")
    try:
        parsed_final = parse_audit_response(
            json.dumps(entry),
            required_checks=REQUIRED_PANEL_CHECKS,
        )
        parsed_blind = parse_audit_response(
            json.dumps(blind),
            required_checks=BLIND_PANEL_CHECKS,
        )
        parsed_criteria = parse_audit_response(
            json.dumps(criteria),
            required_checks=REQUIRED_PANEL_CHECKS,
        )
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        raise ValueError(f"{slug}: required visual checks are invalid: {exc}") from exc
    if (
        parsed_final["status"] != "approved"
        or parsed_blind["status"] != "approved"
        or parsed_criteria["status"] != "approved"
    ):
        raise ValueError(f"{slug}: both independent inspections must approve every panel")
    if not image.is_file():
        raise ValueError(f"{slug}: candidate image does not exist: {image}")
    try:
        actual_dimensions = validate_full_resolution(image)
    except ValueError as exc:
        raise ValueError(f"{slug}: candidate is not a full-resolution tutorial: {exc}") from exc
    if actual_dimensions != EXPECTED_FINAL_SIZE:
        raise ValueError(f"{slug}: candidate dimensions changed after inspection")
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
    storyboards_path: Path | None = None,
    root: Path = ROOT,
) -> list[str]:
    if not slugs:
        return []
    if len(slugs) != len(set(slugs)):
        raise ValueError("duplicate candidate slugs")
    if len(slugs) > 1:
        raise ValueError(
            "promote exactly one tutorial per invocation; multi-file replacement "
            "cannot be crash-atomic"
        )
    for slug in slugs:
        if not slug or Path(slug).name != slug:
            raise ValueError(f"invalid candidate slug: {slug!r}")

    candidate_ledger = _load_ledger(candidate_ledger_path, required=True)
    production_ledger = _load_ledger(production_ledger_path, required=False)
    storyboards = _load_storyboards(storyboards_path or DEFAULT_STORYBOARDS)

    approved: dict[str, dict[str, object]] = {}
    for slug in slugs:
        storyboard = storyboards.get(slug)
        if not isinstance(storyboard, dict):
            raise ValueError(f"{slug}: current storyboard criteria are missing")
        image = candidate_dir / f"{slug}.png"
        approved[slug] = _validate_entry(
            slug,
            image,
            candidate_ledger.get(slug),
            expected_criteria_digest=criteria_sha256(slug, storyboard),
        )

    for slug in slugs:
        target = production_dir / f"{slug}.png"
        legacy_target = production_dir / f"{slug}.jpg"
        if legacy_target.exists() or legacy_target.is_symlink():
            raise ValueError(
                f"{slug}: published asset uses .jpg ({legacy_target}); refusing to "
                "create an unused .png until the application asset path is migrated"
            )
        if target.is_symlink() or (target.exists() and not target.is_file()):
            raise ValueError(
                f"{slug}: production target must be a regular file or absent: {target}"
            )
    production_dir.mkdir(parents=True, exist_ok=True)
    # El staging vive FUERA del directorio público (en su padre): si viviera
    # adentro, un build lanzado a mitad de una promoción empaquetaría los
    # archivos a medio escribir. El padre está en el mismo filesystem, así
    # que replace() sigue siendo atómico.
    transaction_dir = Path(
        tempfile.mkdtemp(prefix=".tutorial-promotion-", dir=production_dir.parent)
    )
    preserve_transaction = False
    try:
        staged: dict[str, Path] = {}
        for slug in slugs:
            source = candidate_dir / f"{slug}.png"
            staged_image = transaction_dir / f"{slug}.png"
            shutil.copyfile(source, staged_image)
            staged_digest = sha256(staged_image)
            expected_digest = approved[slug].get("sha256")
            if staged_digest != expected_digest:
                raise ValueError(
                    f"{slug}: staged SHA-256 mismatch: "
                    f"ledger={expected_digest!r} actual={staged_digest}"
                )
            staged[slug] = staged_image

        next_ledger = dict(production_ledger)
        promoted_at = datetime.now(timezone.utc).isoformat()
        for slug in slugs:
            target = production_dir / f"{slug}.png"
            entry = approved[slug]
            entry["image"] = _display_path(target, root)
            entry["promoted_at"] = promoted_at
            next_ledger[slug] = entry

        backup_dir = transaction_dir / "backups"
        backup_dir.mkdir()
        applied: list[tuple[Path, Path, bool]] = []
        try:
            for slug in slugs:
                target = production_dir / f"{slug}.png"
                backup = backup_dir / f"{slug}.png"
                had_original = target.is_file()
                if had_original:
                    original_digest = sha256(target)
                    shutil.copyfile(target, backup)
                    if sha256(backup) != original_digest:
                        raise OSError(f"{slug}: rollback backup verification failed")
                applied.append((target, backup, had_original))
                staged[slug].replace(target)
            _write_ledger(production_ledger_path, next_ledger)
        except Exception as original_error:
            rollback_errors: list[str] = []
            for target, backup, had_original in reversed(applied):
                try:
                    if had_original:
                        if not backup.is_file():
                            raise OSError(f"rollback backup is missing: {backup}")
                        backup.replace(target)
                    else:
                        target.unlink(missing_ok=True)
                except Exception as rollback_error:
                    rollback_errors.append(f"{target}: {rollback_error}")
            if rollback_errors:
                preserve_transaction = True
                raise RuntimeError(
                    f"promotion failed: {original_error}; rollback failed: "
                    f"{' ; '.join(rollback_errors)}; recovery files preserved at "
                    f"{transaction_dir}"
                ) from original_error
            raise
    finally:
        if not preserve_transaction:
            shutil.rmtree(transaction_dir, ignore_errors=True)
    return list(slugs)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("slugs", nargs="*", help="Approved candidate slugs; defaults to all approved reviews")
    parser.add_argument("--candidate-dir", type=Path, default=DEFAULT_CANDIDATE_DIR)
    parser.add_argument("--candidate-ledger", type=Path, default=DEFAULT_CANDIDATE_LEDGER)
    parser.add_argument("--storyboards", type=Path, default=DEFAULT_STORYBOARDS)
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
        storyboards_path=args.storyboards,
    )
    print(f"Promoted {len(promoted)} tutorial candidates: {', '.join(promoted)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
