#!/usr/bin/env python3
"""Generate 34 three-panel emergency-guide tutorials with Codex gpt-image-2."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
STORYBOARDS = ROOT / "scripts" / "guide_tutorial_storyboards.json"
GENERATOR = ROOT / "scripts" / "generate_guide_image.py"
DEFAULT_OUT_DIR = ROOT / ".hermes" / "tutorial_candidates"
PYTHON = Path.home() / ".hermes" / "hermes-agent" / "venv" / "bin" / "python3"

BASE_PROMPT = """Create one photorealistic emergency field-manual tutorial image composed of exactly THREE equal vertical panels separated by thin neutral dividers, read left to right. The panels must depict one unambiguous chronological sequence with the same people, clothing, equipment, environment, camera height, weather and lighting unless the storyboard explicitly defines two separate scenarios. Each panel must contain one primary action, shown large and clearly with deep focus and physically plausible cause-and-effect. Use crisp freeze-action documentary first-aid or survival training photography, sharp realistic materials, neutral natural color and no dramatic cinema effects. Every hand, limb, face and tool must be fully formed and sharply focused: absolutely no motion blur, ghosting, duplicated bodies or merged anatomy. {context}.

Panel 1: {panel1}.
Panel 2: {panel2}.
Panel 3: {panel3}.

Critical constraints: exactly three panels; no inset images; no before/after duplicates; no words, letters, captions, labels, logos, icons, arrows, numbers or watermarks because captions will be rendered by the app; no gore; no sensational distress; no changing identity or clothing; no duplicated people or tools; no malformed hands, extra fingers or extra limbs. Avoid: {avoid}."""


def prompt_for(spec: dict[str, object]) -> str:
    panels = spec["panels"]
    assert isinstance(panels, list) and len(panels) == 3
    return BASE_PROMPT.format(
        context=spec["context"],
        panel1=panels[0],
        panel2=panels[1],
        panel3=panels[2],
        avoid=spec["avoid"],
    )


def generate(
    slug: str,
    spec: dict[str, object],
    force: bool,
    *,
    output_dir: Path = DEFAULT_OUT_DIR,
) -> tuple[bool, str]:
    output = output_dir / f"{slug}.png"
    if not force and output.exists() and output.stat().st_size > 100_000:
        return True, f"SKIP {slug} ({output.stat().st_size:,} bytes)"

    prompt = prompt_for(spec)
    last_error = ""
    for attempt in range(1, 3):
        started = time.monotonic()
        try:
            result = subprocess.run(
                [str(PYTHON), str(GENERATOR), prompt, str(output), "1536x1024", "high"],
                capture_output=True,
                text=True,
                timeout=360,
            )
        except subprocess.TimeoutExpired:
            last_error = "timeout after 360s"
        else:
            elapsed = time.monotonic() - started
            if result.returncode == 0 and output.exists() and output.stat().st_size > 100_000:
                return True, f"OK {slug} ({output.stat().st_size:,} bytes, {elapsed:.0f}s)"
            last_error = (result.stderr or result.stdout or "unknown error").strip()[-500:]
        if attempt == 1:
            time.sleep(3)
    return False, f"FAIL {slug}: {last_error}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("slugs", nargs="*", help="Optional subset of exact guide slugs")
    parser.add_argument("--force", action="store_true", help="Regenerate existing assets")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUT_DIR,
        help="Staging directory for generated candidates (never production by default)",
    )
    args = parser.parse_args()

    data = json.loads(STORYBOARDS.read_text(encoding="utf-8"))
    selected = args.slugs or list(data)
    unknown = sorted(set(selected) - set(data))
    if unknown:
        parser.error(f"unknown slugs: {', '.join(unknown)}")
    if not PYTHON.exists():
        raise SystemExit(f"Hermes Python not found: {PYTHON}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    failed: list[str] = []
    for index, slug in enumerate(selected, 1):
        print(f"[{index}/{len(selected)}] {slug}", flush=True)
        ok, message = generate(
            slug,
            data[slug],
            args.force,
            output_dir=args.output_dir,
        )
        print(f"  {message}", flush=True)
        if not ok:
            failed.append(slug)

    print(f"Done: {len(selected) - len(failed)}/{len(selected)} succeeded; {len(failed)} failed")
    if failed:
        print("Failed: " + ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
