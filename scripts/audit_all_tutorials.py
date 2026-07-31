#!/usr/bin/env python3
"""Audit tutorial images individually and persist hash-bound visual QA verdicts."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, UnidentifiedImageError

ROOT = Path(__file__).resolve().parents[1]
STORYBOARDS = ROOT / "scripts/guide_tutorial_storyboards.json"
AUDITOR = ROOT / "scripts/audit_tutorial_image.py"
DEFAULT_IMAGE_DIR = ROOT / "assets/emergency_guides/tutorials"
DEFAULT_LEDGER = ROOT / "scripts/guide_tutorial_qa.json"
PYTHON = Path.home() / ".hermes/hermes-agent/venv/bin/python3"
VALID_STATUSES = {"approved", "regenerate"}
RUBRIC_VERSION = "nuvok-photorealistic-logic-safety-v3"
INSPECTOR_VERSION = "nuvok-independent-visual-inspector-v1"
INSPECTION_MODE = "independent-two-stage-full-resolution"
AUDITOR_ID = "nuvok-independent-visual-inspector-gpt-5.5-codex"
EXPECTED_FINAL_SIZE = (1544, 768)
REQUIRED_PANEL_CHECKS = (
    "photorealism",
    "anatomy",
    "object_integrity",
    "physical_logic",
    "continuity",
    "instruction_match",
    "safety",
    "text_free",
)
BLIND_PANEL_CHECKS = tuple(
    check for check in REQUIRED_PANEL_CHECKS if check != "instruction_match"
)


def parse_audit_response(
    raw: str,
    *,
    required_checks: tuple[str, ...] = REQUIRED_PANEL_CHECKS,
) -> dict[str, object]:
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
        checks = panel.get("checks")
        if (
            not isinstance(number, int)
            or isinstance(number, bool)
            or not isinstance(passed, bool)
            or not isinstance(note, str)
            or not note.strip()
        ):
            raise ValueError("panel verdict requires integer number, boolean pass, and non-empty note")
        if not isinstance(checks, dict) or set(checks) != set(required_checks):
            raise ValueError("panel checks must contain the exact required checks")
        normalized_checks: dict[str, bool] = {}
        for check in required_checks:
            value = checks[check]
            if not isinstance(value, bool):
                raise ValueError(f"panel check {check} must be boolean")
            normalized_checks[check] = value
        if passed != all(normalized_checks.values()):
            raise ValueError("panel pass must equal all required checks")
        numbers.append(number)
        all_pass = all_pass and passed
        normalized_panels.append(
            {
                "number": number,
                "pass": passed,
                "checks": normalized_checks,
                "note": note.strip(),
            }
        )
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
    normalized_risks = [risk.strip() for risk in risks if risk.strip()]
    if status == "approved" and normalized_risks:
        raise ValueError("approved audit cannot contain unresolved risks")
    return {
        "status": status,
        "panels": sorted(
            normalized_panels,
            key=lambda panel: panel["number"] if isinstance(panel["number"], int) else 0,
        ),
        "note": note.strip(),
        "risks": normalized_risks,
    }


def _response_shape(required_checks: tuple[str, ...]) -> str:
    checks = ",".join(f'"{check}":true' for check in required_checks)
    panel = f'{{"number":1,"pass":true,"checks":{{{checks}}},"note":"..."}}'
    return (
        '{"status":"approved|regenerate","panels":['
        + panel
        + ","
        + panel.replace('"number":1', '"number":2')
        + ","
        + panel.replace('"number":1', '"number":3')
        + '],"note":"overall concise finding","risks":["specific visible risk"]}'
    )


def blind_prompt_for(slug: str) -> str:
    shape = _response_shape(BLIND_PANEL_CHECKS)
    return f"""Independently inspect the exact full-resolution pixels of the three-panel image {slug!r}, left to right. Do not infer the intended tutorial and do not reward an image merely because it looks plausible. Inventory only what is visibly present before judging it.

For every panel, return a separate boolean for every named check:
- photorealism: indistinguishable from a real documentary training photograph; fail illustration, CGI, 3D render, plastic skin, synthetic lighting, or generated-looking scenery.
- anatomy: normal count, proportions, joints, hands, fingers, limbs, faces, posture, and physically valid contact.
- object_integrity: no duplicated, merged, floating, malformed, changing, or impossible people, tools, equipment, clothing, or environmental objects.
- physical_logic: contacts, support, gravity, occlusion, cause-and-effect, spatial relations, and the visible action are physically coherent.
- continuity: people, clothing, equipment, environment, injuries, and state changes remain logically consistent across panels unless a visible action explains the change.
- safety: no visibly unsafe technique, dangerous ambiguity, or action a learner could imitate incorrectly.
- text_free: no readable words, pseudotext, labels, arrows, logos, watermarks, or extra embedded panels.

Use false whenever a required fact is obscured, ambiguous, too small to verify, or only assumed. A panel pass must equal the logical AND of all its checks. The overall status is approved only if every panel passes and risks is empty. Otherwise use regenerate and list concrete visible defects.
Return only JSON with this exact shape:
{shape}"""


def prompt_for(slug: str, spec: dict[str, object]) -> str:
    panels = spec["panels"]
    if not isinstance(panels, list) or len(panels) != 3:
        raise ValueError(f"{slug}: storyboard must have exactly three panels")
    expected = "\n".join(f"Panel {index}: {action}" for index, action in enumerate(panels, 1))
    shape = _response_shape(REQUIRED_PANEL_CHECKS)
    return f"""As a second independent inspection, audit the exact full-resolution image for tutorial {slug!r}, left to right.
Expected visible actions:
{expected}

Every panel must be indistinguishable from a real documentary training photograph captured in the physical world. Fail CGI, 3D render, vector art, drawing, painting, infographic styling, synthetic scenery, implausibly plastic human skin, or other visibly generated/illustrated appearance. Artificial medical training manikins and simulators are required where specified and must themselves look like real photographed training equipment, not real patients.

The app always pairs each panel with its exact localized caption. Judge whether the visual clearly supports that caption and never contradicts it; do not require the image alone to encode invisible quantities, elapsed time, chronology, or abstract planning. For hands-on medical or physical techniques, contact points, body landmarks, tool placement, direction and cause-and-effect must still be exact. Fail impossible anatomy or tool geometry, duplicated or merged people/equipment, contradiction of the expected technique, or any unsafe ambiguity that could cause a learner to act incorrectly. Also fail extra embedded panels, readable text, arrows, labels, logos, watermarks, or pseudotext. Do not excuse defects because this is generated art.

For each panel return exactly these booleans: photorealism, anatomy, object_integrity, physical_logic, continuity, instruction_match, safety, and text_free. Set instruction_match true only when the visible action and all safety-critical geometry unambiguously support the expected action. Use false whenever a fact is obscured, ambiguous, too small to verify, or merely assumed. A panel pass must equal the logical AND of all checks.

Return only JSON with this exact shape:
{shape}
Use approved only when all three panel pass values are true and risks is empty. Use regenerate when any panel fails."""


def _panel_map(result: dict[str, object]) -> dict[int, dict[str, object]]:
    panels = result.get("panels")
    if not isinstance(panels, list):
        raise ValueError("inspection is missing panel results")
    mapped: dict[int, dict[str, object]] = {}
    for panel in panels:
        if not isinstance(panel, dict):
            raise ValueError("inspection panel result must be an object")
        number = panel.get("number")
        if not isinstance(number, int) or isinstance(number, bool):
            raise ValueError("inspection panel number must be an integer")
        mapped[number] = panel
    if set(mapped) != {1, 2, 3}:
        raise ValueError("inspection must contain panels 1, 2, and 3")
    return mapped


def combine_inspections(
    blind: dict[str, object],
    criteria: dict[str, object],
) -> dict[str, object]:
    blind_panels = _panel_map(blind)
    criteria_panels = _panel_map(criteria)
    combined_panels: list[dict[str, object]] = []
    for number in (1, 2, 3):
        blind_panel = blind_panels[number]
        criteria_panel = criteria_panels[number]
        blind_checks = blind_panel.get("checks")
        criteria_checks = criteria_panel.get("checks")
        if not isinstance(blind_checks, dict) or not isinstance(criteria_checks, dict):
            raise ValueError("inspection panel is missing checks")
        checks: dict[str, bool] = {}
        for check in REQUIRED_PANEL_CHECKS:
            criteria_pass = criteria_checks.get(check) is True
            blind_pass = True if check == "instruction_match" else blind_checks.get(check) is True
            checks[check] = blind_pass and criteria_pass
        passed = (
            blind_panel.get("pass") is True
            and criteria_panel.get("pass") is True
            and all(checks.values())
        )
        combined_panels.append(
            {
                "number": number,
                "pass": passed,
                "checks": checks,
                "note": (
                    f"Blind: {str(blind_panel.get('note', '')).strip()} "
                    f"Criteria: {str(criteria_panel.get('note', '')).strip()}"
                ).strip(),
            }
        )

    risks: list[str] = []
    for source, result in (("blind", blind), ("criteria", criteria)):
        source_risks = result.get("risks")
        if isinstance(source_risks, list):
            for risk in source_risks:
                if isinstance(risk, str) and risk.strip():
                    labelled = f"{source}: {risk.strip()}"
                    if labelled not in risks:
                        risks.append(labelled)
    approved = (
        blind.get("status") == "approved"
        and criteria.get("status") == "approved"
        and all(panel["pass"] is True for panel in combined_panels)
        and not risks
    )
    if not approved and not risks:
        risks.append("independent inspections did not reach unanimous approval")
    return {
        "status": "approved" if approved else "regenerate",
        "panels": combined_panels,
        "note": "Both independent inspections approved every panel."
        if approved
        else "Independent inspections found or could not rule out visible defects.",
        "risks": risks,
        "inspections": {"blind": blind, "criteria": criteria},
    }


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def criteria_sha256(slug: str, spec: dict[str, object]) -> str:
    payload = json.dumps(
        {"slug": slug, "storyboard": spec},
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def validate_full_resolution(image: Path) -> tuple[int, int]:
    try:
        with Image.open(image) as opened:
            opened.load()
            dimensions = opened.size
            image_format = opened.format
    except (OSError, UnidentifiedImageError) as exc:
        raise ValueError(f"unreadable tutorial image: {image}") from exc
    if image_format != "PNG":
        raise ValueError(f"tutorial image must be a real PNG, got {image_format!r}: {image}")
    if dimensions != EXPECTED_FINAL_SIZE:
        raise ValueError(
            f"tutorial inspector requires full shipping resolution "
            f"{EXPECTED_FINAL_SIZE[0]}x{EXPECTED_FINAL_SIZE[1]}, got "
            f"{dimensions[0]}x{dimensions[1]}"
        )
    return dimensions


def create_audit_snapshot(
    image: Path,
    snapshot_dir: Path,
    slug: str,
) -> tuple[Path, str, tuple[int, int]]:
    if not slug or Path(slug).name != slug:
        raise ValueError(f"invalid tutorial slug: {slug!r}")
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    snapshot = snapshot_dir / f"{slug}.png"
    shutil.copyfile(image, snapshot)
    dimensions = validate_full_resolution(snapshot)
    digest = sha256(snapshot)
    snapshot.chmod(0o444)
    return snapshot, digest, dimensions


def candidate_matches_snapshot(
    image: Path,
    digest: str,
    dimensions: tuple[int, int],
) -> bool:
    try:
        return validate_full_resolution(image) == dimensions and sha256(image) == digest
    except (OSError, ValueError):
        return False


def bind_audit_metadata(
    result: dict[str, object],
    *,
    digest: str,
    image: Path,
    dimensions: tuple[int, int],
    criteria_digest: str,
) -> dict[str, object]:
    record = dict(result)
    record.update(
        {
            "sha256": digest,
            "image": str(image.relative_to(ROOT))
            if image.is_relative_to(ROOT)
            else str(image),
            "auditor": AUDITOR_ID,
            "rubric_version": RUBRIC_VERSION,
            "inspector_version": INSPECTOR_VERSION,
            "inspection_mode": INSPECTION_MODE,
            "criteria_sha256": criteria_digest,
            "inspected_dimensions": {
                "width": dimensions[0],
                "height": dimensions[1],
            },
            "reviewed_at": datetime.now(timezone.utc).isoformat(),
        }
    )
    return record


def write_ledger(path: Path, ledger: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def _run_inspection_stage(
    image: Path,
    prompt: str,
    required_checks: tuple[str, ...],
) -> dict[str, object]:
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
            return parse_audit_response(result.stdout, required_checks=required_checks)
        except (ValueError, json.JSONDecodeError) as exc:
            last_error = f"invalid audit JSON: {exc}; output={result.stdout[-800:]}"
    raise RuntimeError(last_error or "audit failed without output")


def _require_unchanged_snapshot(
    image: Path,
    digest: str,
    dimensions: tuple[int, int],
) -> None:
    try:
        writable = bool(image.stat().st_mode & 0o222)
    except OSError as exc:
        raise RuntimeError(f"audit snapshot changed or disappeared: {image}") from exc
    if writable or not candidate_matches_snapshot(image, digest, dimensions):
        raise RuntimeError(f"audit snapshot changed during independent inspection: {image}")


def run_audit(
    image: Path,
    slug: str,
    spec: dict[str, object],
    *,
    expected_digest: str,
    expected_dimensions: tuple[int, int],
) -> dict[str, object]:
    _require_unchanged_snapshot(image, expected_digest, expected_dimensions)
    blind = _run_inspection_stage(
        image,
        blind_prompt_for(slug),
        BLIND_PANEL_CHECKS,
    )
    _require_unchanged_snapshot(image, expected_digest, expected_dimensions)
    criteria = _run_inspection_stage(
        image,
        prompt_for(slug, spec),
        REQUIRED_PANEL_CHECKS,
    )
    _require_unchanged_snapshot(image, expected_digest, expected_dimensions)
    return combine_inspections(blind, criteria)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("slugs", nargs="*", help="Optional exact tutorial slugs")
    parser.add_argument(
        "--storyboards",
        type=Path,
        default=STORYBOARDS,
        help="Exact storyboard snapshot whose criteria must be audited",
    )
    parser.add_argument("--image-dir", type=Path, default=DEFAULT_IMAGE_DIR)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--workers", type=int, default=1)
    return parser


def is_reusable_audit_record(
    record: object,
    *,
    digest: str,
    dimensions: tuple[int, int],
    criteria_digest: str,
) -> bool:
    if not isinstance(record, dict):
        return False
    if (
        record.get("sha256") != digest
        or record.get("auditor") != AUDITOR_ID
        or record.get("rubric_version") != RUBRIC_VERSION
        or record.get("inspector_version") != INSPECTOR_VERSION
        or record.get("inspection_mode") != INSPECTION_MODE
        or record.get("criteria_sha256") != criteria_digest
        or record.get("inspected_dimensions")
        != {"width": dimensions[0], "height": dimensions[1]}
    ):
        return False
    inspections = record.get("inspections")
    if not isinstance(inspections, dict):
        return False
    blind = inspections.get("blind")
    criteria = inspections.get("criteria")
    if not isinstance(blind, dict) or not isinstance(criteria, dict):
        return False
    try:
        parse_audit_response(
            json.dumps(record),
            required_checks=REQUIRED_PANEL_CHECKS,
        )
        parse_audit_response(
            json.dumps(blind),
            required_checks=BLIND_PANEL_CHECKS,
        )
        parse_audit_response(
            json.dumps(criteria),
            required_checks=REQUIRED_PANEL_CHECKS,
        )
    except (TypeError, ValueError, json.JSONDecodeError):
        return False
    return True


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.workers < 1 or args.workers > 3:
        parser.error("--workers must be between 1 and 3")

    storyboards = json.loads(args.storyboards.read_text(encoding="utf-8"))
    selected = args.slugs or list(storyboards)
    if len(selected) != len(set(selected)):
        parser.error("duplicate tutorial slugs")
    unknown = sorted(set(selected) - set(storyboards))
    if unknown:
        parser.error(f"unknown slugs: {', '.join(unknown)}")
    ledger: dict[str, object] = {}
    if args.ledger.is_file():
        loaded = json.loads(args.ledger.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            ledger = loaded

    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="nuvok-tutorial-audit-") as snapshot_name:
        snapshot_dir = Path(snapshot_name)
        audit_jobs: list[
            tuple[int, str, Path, Path, str, tuple[int, int], str]
        ] = []
        for index, slug in enumerate(selected, 1):
            image = args.image_dir / f"{slug}.png"
            criteria_digest = criteria_sha256(slug, storyboards[slug])
            if not image.is_file():
                print(f"[{index}/{len(selected)}] MISSING {slug}", flush=True)
                ledger[slug] = {
                    "status": "missing",
                    "image": str(image.relative_to(ROOT))
                    if image.is_relative_to(ROOT)
                    else str(image),
                    "note": "Tutorial image does not exist in the audited directory.",
                }
                write_ledger(args.ledger, ledger)
                failures.append(slug)
                continue
            try:
                dimensions = validate_full_resolution(image)
            except ValueError as exc:
                print(f"[{index}/{len(selected)}] INVALID {slug}: {exc}", flush=True)
                ledger[slug] = {
                    "status": "invalid",
                    "image": str(image.relative_to(ROOT))
                    if image.is_relative_to(ROOT)
                    else str(image),
                    "note": str(exc),
                }
                write_ledger(args.ledger, ledger)
                failures.append(slug)
                continue
            digest = sha256(image)
            previous = ledger.get(slug)
            if (
                not args.force
                and is_reusable_audit_record(
                    previous,
                    digest=digest,
                    dimensions=dimensions,
                    criteria_digest=criteria_digest,
                )
            ):
                assert isinstance(previous, dict)
                print(
                    f"[{index}/{len(selected)}] SKIP {slug} "
                    f"({previous['status']}, unchanged)",
                    flush=True,
                )
                if previous["status"] != "approved":
                    failures.append(slug)
                continue
            try:
                snapshot, digest, dimensions = create_audit_snapshot(
                    image,
                    snapshot_dir,
                    slug,
                )
            except (OSError, ValueError) as exc:
                print(
                    f"[{index}/{len(selected)}] SNAPSHOT ERROR {slug}: {exc}",
                    flush=True,
                )
                ledger[slug] = {
                    "status": "error",
                    "image": str(image.relative_to(ROOT))
                    if image.is_relative_to(ROOT)
                    else str(image),
                    "note": f"Could not create a stable audit snapshot: {exc}",
                }
                write_ledger(args.ledger, ledger)
                failures.append(slug)
                continue
            if not candidate_matches_snapshot(image, digest, dimensions):
                print(
                    f"[{index}/{len(selected)}] STALE {slug}: changed during snapshot",
                    flush=True,
                )
                ledger[slug] = {
                    "status": "stale",
                    "image": str(image.relative_to(ROOT))
                    if image.is_relative_to(ROOT)
                    else str(image),
                    "sha256": digest,
                    "criteria_sha256": criteria_digest,
                    "note": "Candidate changed while its immutable audit snapshot was created.",
                }
                write_ledger(args.ledger, ledger)
                failures.append(slug)
                continue
            print(f"[{index}/{len(selected)}] QUEUE {slug}", flush=True)
            audit_jobs.append(
                (
                    index,
                    slug,
                    snapshot,
                    image,
                    digest,
                    dimensions,
                    criteria_digest,
                )
            )

        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {
                pool.submit(
                    run_audit,
                    snapshot,
                    slug,
                    storyboards[slug],
                    expected_digest=digest,
                    expected_dimensions=dimensions,
                ): (
                    index,
                    slug,
                    image,
                    digest,
                    dimensions,
                    criteria_digest,
                )
                for (
                    index,
                    slug,
                    snapshot,
                    image,
                    digest,
                    dimensions,
                    criteria_digest,
                ) in audit_jobs
            }
            for future in as_completed(futures):
                index, slug, image, digest, dimensions, criteria_digest = futures[future]
                print(f"[{index}/{len(selected)}] AUDIT {slug}", flush=True)
                try:
                    result = future.result()
                except (RuntimeError, subprocess.TimeoutExpired) as exc:
                    print(f"  ERROR {exc}", flush=True)
                    ledger[slug] = {
                        "status": "error",
                        "image": str(image.relative_to(ROOT))
                        if image.is_relative_to(ROOT)
                        else str(image),
                        "sha256": digest,
                        "criteria_sha256": criteria_digest,
                        "note": f"Independent inspection failed operationally: {exc}",
                    }
                    write_ledger(args.ledger, ledger)
                    failures.append(slug)
                    continue
                if not candidate_matches_snapshot(image, digest, dimensions):
                    print("  STALE: candidate changed after inspection", flush=True)
                    ledger[slug] = {
                        "status": "stale",
                        "image": str(image.relative_to(ROOT))
                        if image.is_relative_to(ROOT)
                        else str(image),
                        "sha256": digest,
                        "criteria_sha256": criteria_digest,
                        "note": (
                            "Candidate bytes no longer match the immutable snapshot "
                            "that was inspected."
                        ),
                    }
                    write_ledger(args.ledger, ledger)
                    failures.append(slug)
                    continue
                result = bind_audit_metadata(
                    result,
                    digest=digest,
                    image=image,
                    dimensions=dimensions,
                    criteria_digest=criteria_digest,
                )
                ledger[slug] = result
                write_ledger(args.ledger, ledger)
                print(f"  {str(result['status']).upper()}: {result['note']}", flush=True)
                if result["status"] != "approved":
                    failures.append(slug)

    print(
        f"Done: {len(selected) - len(failures)}/{len(selected)} approved; "
        f"{len(failures)} unresolved"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
