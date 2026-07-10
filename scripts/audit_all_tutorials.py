#!/usr/bin/env python3
"""Audit tutorial images individually and persist hash-bound visual QA verdicts."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
STORYBOARDS = ROOT / "scripts/guide_tutorial_storyboards.json"
AUDITOR = ROOT / "scripts/audit_tutorial_image.py"
DEFAULT_IMAGE_DIR = ROOT / "assets/emergency_guides/tutorials"
DEFAULT_LEDGER = ROOT / "scripts/guide_tutorial_qa.json"
PYTHON = Path.home() / ".hermes/hermes-agent/venv/bin/python3"
VALID_STATUSES = {"approved", "regenerate"}


def parse_audit_response(raw: str) -> dict[str, object]:
    text = raw.strip()
    if text.startswith("```"):
        lines = text.splitlines()[1:]
        if lines and lines[-1].strip() == "```":
            lines.pop()
        text = "\n".join(lines).strip()
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError("audit response must be a JSON object")
    status = data.get("status")
    if status not in VALID_STATUSES:
        raise ValueError(f"invalid audit status: {status!r}")
    panels = data.get("panels")
    if not isinstance(panels, list) or len(panels) != 3:
        raise ValueError("audit must contain three panel verdicts")
    numbers: list[int] = []
    all_pass = True
    normalized_panels: list[dict[str, object]] = []
    for panel in panels:
        if not isinstance(panel, dict):
            raise ValueError("each panel verdict must be an object")
        number = panel.get("number")
        passed = panel.get("pass")
        note = panel.get("note")
        if not isinstance(number, int) or not isinstance(passed, bool) or not isinstance(note, str) or not note.strip():
            raise ValueError("panel verdict requires integer number, boolean pass, and non-empty note")
        numbers.append(number)
        all_pass = all_pass and passed
        normalized_panels.append({"number": number, "pass": passed, "note": note.strip()})
    if sorted(numbers) != [1, 2, 3]:
        raise ValueError("panel numbers must be exactly 1, 2, 3")
    if status == "approved" and not all_pass:
        raise ValueError("audit cannot be approved while a panel fails")
    if status == "regenerate" and all_pass:
        raise ValueError("regenerate verdict must identify at least one failed panel")
    note = data.get("note")
    risks = data.get("risks")
    if not isinstance(note, str) or not note.strip():
        raise ValueError("audit requires a non-empty overall note")
    if not isinstance(risks, list) or not all(isinstance(risk, str) for risk in risks):
        raise ValueError("audit risks must be a list of strings")
    return {
        "status": status,
        "panels": sorted(
            normalized_panels,
            key=lambda panel: panel["number"] if isinstance(panel["number"], int) else 0,
        ),
        "note": note.strip(),
        "risks": [risk.strip() for risk in risks if risk.strip()],
    }


def prompt_for(slug: str, spec: dict[str, object]) -> str:
    panels = spec["panels"]
    if not isinstance(panels, list) or len(panels) != 3:
        raise ValueError(f"{slug}: storyboard must have exactly three panels")
    expected = "\n".join(f"Panel {index}: {action}" for index, action in enumerate(panels, 1))
    return f"""Audit the full-resolution image for tutorial {slug!r}, left to right.
Expected visible actions:
{expected}

Every panel must be indistinguishable from a real documentary training photograph captured in the physical world. Fail CGI, 3D render, vector art, drawing, painting, infographic styling, synthetic scenery, implausibly plastic human skin, or other visibly generated/illustrated appearance. Artificial medical training manikins and simulators are required where specified and must themselves look like real photographed training equipment, not real patients.

The app always pairs each panel with its exact localized caption. Judge whether the visual clearly supports that caption and never contradicts it; do not require the image alone to encode invisible quantities, elapsed time, chronology, or abstract planning. For hands-on medical or physical techniques, contact points, body landmarks, tool placement, direction and cause-and-effect must still be exact. Fail impossible anatomy or tool geometry, duplicated or merged people/equipment, contradiction of the expected technique, or any unsafe ambiguity that could cause a learner to act incorrectly. Also fail extra embedded panels, readable text, arrows, or labels. Do not excuse defects because this is generated art.

Return only JSON with this exact shape:
{{"status":"approved|regenerate","panels":[{{"number":1,"pass":true,"note":"..."}},{{"number":2,"pass":true,"note":"..."}},{{"number":3,"pass":true,"note":"..."}}],"note":"overall concise finding","risks":["specific visible risk"]}}
Use approved only when all three panel pass values are true. Use regenerate when any panel fails."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_ledger(path: Path, ledger: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def run_audit(image: Path, slug: str, spec: dict[str, object]) -> dict[str, object]:
    prompt = prompt_for(slug, spec)
    last_error = ""
    for _attempt in range(2):
        result = subprocess.run(
            [str(PYTHON), str(AUDITOR), str(image), prompt],
            capture_output=True,
            text=True,
            timeout=420,
        )
        if result.returncode != 0:
            last_error = (result.stderr or result.stdout).strip()[-1000:]
            continue
        try:
            return parse_audit_response(result.stdout)
        except (ValueError, json.JSONDecodeError) as exc:
            last_error = f"invalid audit JSON: {exc}; output={result.stdout[-800:]}"
    raise RuntimeError(last_error or "audit failed without output")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("slugs", nargs="*", help="Optional exact tutorial slugs")
    parser.add_argument("--image-dir", type=Path, default=DEFAULT_IMAGE_DIR)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--workers", type=int, default=1)
    args = parser.parse_args()
    if args.workers < 1 or args.workers > 3:
        parser.error("--workers must be between 1 and 3")

    storyboards = json.loads(STORYBOARDS.read_text(encoding="utf-8"))
    selected = args.slugs or list(storyboards)
    unknown = sorted(set(selected) - set(storyboards))
    if unknown:
        parser.error(f"unknown slugs: {', '.join(unknown)}")
    ledger: dict[str, object] = {}
    if args.ledger.is_file():
        loaded = json.loads(args.ledger.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            ledger = loaded

    failures: list[str] = []
    audit_jobs: list[tuple[int, str, Path, str]] = []
    for index, slug in enumerate(selected, 1):
        image = args.image_dir / f"{slug}.png"
        if not image.is_file():
            print(f"[{index}/{len(selected)}] MISSING {slug}", flush=True)
            ledger[slug] = {
                "status": "missing",
                "image": str(image.relative_to(ROOT)) if image.is_relative_to(ROOT) else str(image),
                "note": "Tutorial image does not exist in the audited directory.",
            }
            write_ledger(args.ledger, ledger)
            failures.append(slug)
            continue
        digest = sha256(image)
        previous = ledger.get(slug)
        if (
            not args.force
            and isinstance(previous, dict)
            and previous.get("sha256") == digest
            and previous.get("status") in VALID_STATUSES
            and isinstance(previous.get("panels"), list)
        ):
            print(f"[{index}/{len(selected)}] SKIP {slug} ({previous['status']}, unchanged)", flush=True)
            if previous["status"] != "approved":
                failures.append(slug)
            continue
        print(f"[{index}/{len(selected)}] QUEUE {slug}", flush=True)
        audit_jobs.append((index, slug, image, digest))

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {
            pool.submit(run_audit, image, slug, storyboards[slug]): (
                index,
                slug,
                image,
                digest,
            )
            for index, slug, image, digest in audit_jobs
        }
        for future in as_completed(futures):
            index, slug, image, digest = futures[future]
            print(f"[{index}/{len(selected)}] AUDIT {slug}", flush=True)
            try:
                result = future.result()
            except (RuntimeError, subprocess.TimeoutExpired) as exc:
                print(f"  ERROR {exc}", flush=True)
                failures.append(slug)
                continue
            result.update(
                {
                    "sha256": digest,
                    "image": str(image.relative_to(ROOT))
                    if image.is_relative_to(ROOT)
                    else str(image),
                    "auditor": "gpt-5.5-codex-vision",
                    "reviewed_at": datetime.now(timezone.utc).isoformat(),
                }
            )
            ledger[slug] = result
            write_ledger(args.ledger, ledger)
            print(f"  {str(result['status']).upper()}: {result['note']}", flush=True)
            if result["status"] != "approved":
                failures.append(slug)

    print(f"Done: {len(selected) - len(failures)}/{len(selected)} approved; {len(failures)} unresolved")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
