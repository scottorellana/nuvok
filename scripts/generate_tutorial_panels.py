#!/usr/bin/env python3
"""Generate each tutorial panel separately, then compose a deterministic triptych."""
from __future__ import annotations

import argparse
import copy
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import subprocess
import sys
import time

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
STORYBOARDS = ROOT / "scripts/guide_tutorial_storyboards.json"
GENERATOR = ROOT / "scripts/generate_guide_image.py"
DEFAULT_OUT_DIR = ROOT / ".hermes/tutorial_candidates"
PANEL_DIR = ROOT / ".hermes/tutorial_panels"
PYTHON = Path.home() / ".hermes/hermes-agent/venv/bin/python3"
PANEL_SIZE = (512, 768)
DIVIDER = 4

BASE_PROMPT = """Create ONE single vertical portrait photorealistic emergency field-manual training photograph, indistinguishable from a real high-resolution documentary photograph made by a professional safety instructor with a full-frame camera. This must look captured in the physical world, never illustrated or computer-generated. This is one still image, not a sequence: absolutely no triptych, split screen, collage, inset, before-and-after view, repeated pose, multiple exposure, motion trail or ghosting. Show only the one action specified below, frozen sharply with deep focus and physically plausible hand and tool placement. Use real locations, realistic commercially available equipment, and a static training setup with a clearly artificial medical mannequin or simulator when the context requests one. Keep people minimal; frame only the body parts needed to teach the action. Every visible hand, limb and tool must be fully formed and anatomically correct. Neutral documentary lighting, natural skin and material texture, accurate scale and perspective, no dramatic cinema effects.

Continuity cast lock: Across all three panels, whenever the specified action needs an adult helper, show the same adult instructor: a 38-year-old Latin American woman with medium-brown skin, dark-brown hair tied in a low bun, and an olive long-sleeve field shirt. Whenever it needs an adult casualty, show the same casualty or training mannequin: a 45-year-old Latin American man with medium-brown skin, short black hair, and a plain navy shirt, or the identical clearly artificial adult training mannequin when simulation is required. For pediatric training, always use the identical clearly artificial tan child or infant mannequin with the same clothing and equipment. Never substitute a different person, mannequin, clothing color, age, sex, skin tone, hairstyle, injury location, or equipment between panels. Do not add any member of this cast unless the specified action requires them.

Continuity description: {context}
Only action to show: {action}

Do not show earlier or later steps. No words, letters, captions, labels, logos, icons, arrows, numbers or watermarks. No gore. No CGI, 3D render, vector art, drawing, painting, comic, infographic, plastic-looking human skin or synthetic scenery. Avoid: {avoid}."""


def regeneration_groups_from_ledger(
    ledger: dict[str, object],
) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    for slug, raw_entry in ledger.items():
        if not isinstance(raw_entry, dict) or raw_entry.get("status") != "regenerate":
            continue
        raw_panels = raw_entry.get("panels")
        if not isinstance(raw_panels, list):
            raise ValueError(f"{slug}: regenerate ledger entry has no panel verdicts")
        if len(raw_panels) != 3 or any(not isinstance(panel, dict) for panel in raw_panels):
            raise ValueError(f"{slug}: regenerate ledger entry must contain exactly panels 1, 2, and 3")
        numbers = [panel.get("number") for panel in raw_panels]
        if any(type(number) is not int for number in numbers) or sorted(numbers) != [1, 2, 3]:
            raise ValueError(f"{slug}: regenerate ledger entry must contain exactly panels 1, 2, and 3")
        if any(type(panel.get("pass")) is not bool for panel in raw_panels):
            raise ValueError(f"{slug}: each panel must contain a boolean pass verdict")
        failed = sorted(
            int(panel["number"])
            for panel in raw_panels
            if panel.get("pass") is False
        )
        if not failed:
            raise ValueError(f"{slug}: regenerate ledger entry has no failed panels")
        key = ",".join(str(number) for number in failed)
        groups.setdefault(key, []).append(slug)
    return groups


def apply_panel_overrides(
    spec: dict[str, object],
    overrides: dict[str, str],
    selected_panels: list[int],
) -> dict[str, object]:
    updated = copy.deepcopy(spec)
    panels = updated.get("panels")
    if not isinstance(panels, list) or len(panels) != 3:
        raise ValueError("storyboard must contain exactly three panels")
    for number in selected_panels:
        replacement = overrides.get(str(number))
        if replacement:
            panels[number - 1] = replacement
    return updated


def apply_panel_feedback(
    spec: dict[str, object],
    feedback: dict[int, str],
    selected_panels: list[int],
) -> dict[str, object]:
    """Attach strict-review feedback to the corresponding failed action only."""
    updated = copy.deepcopy(spec)
    panels = updated.get("panels")
    if not isinstance(panels, list) or len(panels) != 3:
        raise ValueError("storyboard must contain exactly three panels")
    for number in selected_panels:
        note = feedback.get(number, "").strip()
        if note:
            panels[number - 1] = (
                f"{panels[number - 1]} Mandatory visible correction from the strict "
                f"reviewer: {note}"
            )
    return updated


def panel_prompt(spec: dict[str, object], index: int) -> str:
    panels = spec["panels"]
    assert isinstance(panels, list) and len(panels) == 3
    return BASE_PROMPT.format(
        context=spec["context"],
        action=panels[index],
        avoid=spec["avoid"],
    )


def generate_panel(
    slug: str,
    spec: dict[str, object],
    index: int,
    force: bool,
    quality: str,
    panel_dir: Path = PANEL_DIR,
) -> tuple[int, bool, str]:
    output = panel_dir / slug / f"panel_{index + 1}.png"
    if not force and output.exists() and output.stat().st_size > 100_000:
        return index, True, f"SKIP panel {index + 1}"
    output.parent.mkdir(parents=True, exist_ok=True)
    prompt = panel_prompt(spec, index)
    last_error = ""
    for attempt in range(1, 3):
        started = time.monotonic()
        try:
            result = subprocess.run(
                [str(PYTHON), str(GENERATOR), prompt, str(output), "1024x1536", quality],
                capture_output=True,
                text=True,
                timeout=360,
            )
        except subprocess.TimeoutExpired:
            last_error = "timeout after 360s"
        else:
            elapsed = time.monotonic() - started
            if result.returncode == 0 and output.exists() and output.stat().st_size > 100_000:
                return index, True, f"OK panel {index + 1} ({output.stat().st_size:,} bytes, {elapsed:.0f}s)"
            last_error = (result.stderr or result.stdout or "unknown error").strip()[-400:]
        if attempt == 1:
            time.sleep(3)
    return index, False, f"FAIL panel {index + 1}: {last_error}"


def compose(
    slug: str,
    *,
    panel_dir: Path = PANEL_DIR,
    output_dir: Path = DEFAULT_OUT_DIR,
) -> Path:
    canvas = Image.new("RGB", (PANEL_SIZE[0] * 3 + DIVIDER * 2, PANEL_SIZE[1]), "#ddd8ca")
    x = 0
    for index in range(3):
        source = Image.open(panel_dir / slug / f"panel_{index + 1}.png").convert("RGB")
        fitted = ImageOps.fit(source, PANEL_SIZE, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))
        canvas.paste(fitted, (x, 0))
        x += PANEL_SIZE[0]
        if index < 2:
            canvas.paste(Image.new("RGB", (DIVIDER, PANEL_SIZE[1]), "#ddd8ca"), (x, 0))
            x += DIVIDER
    output = output_dir / f"{slug}.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=True)
    return output


def generate_slugs(
    slugs: list[str],
    data: dict[str, dict[str, object]],
    *,
    selected_panels: list[int],
    force: bool,
    quality: str,
    workers: int,
    panel_dir: Path = PANEL_DIR,
    output_dir: Path = DEFAULT_OUT_DIR,
) -> list[str]:
    results_by_slug: dict[str, list[tuple[int, bool, str]]] = {
        slug: [] for slug in slugs
    }
    with ThreadPoolExecutor(max_workers=max(1, min(workers, 3))) as pool:
        futures = {
            pool.submit(
                generate_panel,
                slug,
                data[slug],
                index - 1,
                force,
                quality,
                panel_dir,
            ): slug
            for slug in slugs
            for index in selected_panels
        }
        for future in as_completed(futures):
            slug = futures[future]
            result = future.result()
            results_by_slug[slug].append(result)
            print(f"[{slug}] {result[2]}", flush=True)

    failed: list[str] = []
    for slug in slugs:
        results = results_by_slug[slug]
        if not all(ok for _, ok, _ in results):
            failed.append(slug)
            continue
        missing = [
            index
            for index in range(1, 4)
            if not (panel_dir / slug / f"panel_{index}.png").is_file()
        ]
        if missing:
            print(f"[{slug}] FAIL missing panels required to compose: {missing}", flush=True)
            failed.append(slug)
            continue
        output = compose(slug, panel_dir=panel_dir, output_dir=output_dir)
        print(f"[{slug}] COMPOSED {output} ({output.stat().st_size:,} bytes)", flush=True)
    return failed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("slugs", nargs="+", help="Exact tutorial slugs")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--quality", choices=["low", "medium", "high"], default="medium")
    parser.add_argument("--workers", type=int, default=3)
    parser.add_argument(
        "--storyboards",
        type=Path,
        default=STORYBOARDS,
        help="Exact storyboard snapshot used for this generation run",
    )
    parser.add_argument(
        "--panel-dir",
        type=Path,
        default=PANEL_DIR,
        help="Staging directory for independently generated source panels",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUT_DIR,
        help="Staging directory for composed candidates (never production by default)",
    )
    parser.add_argument(
        "--panels",
        type=int,
        nargs="+",
        choices=[1, 2, 3],
        default=[1, 2, 3],
        help="One-based panels to regenerate; existing others are reused",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    data = json.loads(args.storyboards.read_text(encoding="utf-8"))
    unknown = sorted(set(args.slugs) - set(data))
    if unknown:
        parser.error(f"unknown slugs: {', '.join(unknown)}")

    selected_panels = sorted(set(args.panels))
    print(
        f"Queueing {len(args.slugs)} tutorials × {len(selected_panels)} panels "
        f"with {max(1, min(args.workers, 3))} global workers",
        flush=True,
    )
    failed = generate_slugs(
        args.slugs,
        data,
        selected_panels=selected_panels,
        force=args.force,
        quality=args.quality,
        workers=args.workers,
        panel_dir=args.panel_dir,
        output_dir=args.output_dir,
    )

    print(f"Done: {len(args.slugs) - len(failed)}/{len(args.slugs)} composed; {len(failed)} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
