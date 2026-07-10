#!/usr/bin/env python3
"""Build labeled contact sheets for manual QA of all guide tutorial PNGs."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets/emergency_guides/tutorials"
SPECS = ROOT / "scripts/guide_tutorial_storyboards.json"
OUTPUT_DIR = Path("/tmp/nuvok_tutorial_qa")
COLS, ROWS = 2, 3
TILE_W, IMAGE_H, LABEL_H = 768, 512, 42


def font(size: int):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/SFNS.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def main() -> None:
    slugs = list(json.loads(SPECS.read_text()).keys())
    missing = [slug for slug in slugs if not (ASSET_DIR / f"{slug}.png").exists()]
    if missing:
        raise SystemExit(f"Missing tutorial images: {missing}")
    if len(slugs) != 34:
        raise SystemExit(f"Expected 34 storyboards, found {len(slugs)}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    label_font = font(25)
    produced = []
    per_sheet = COLS * ROWS
    for start in range(0, len(slugs), per_sheet):
        subset = slugs[start:start + per_sheet]
        sheet = Image.new("RGB", (COLS * TILE_W, ROWS * (IMAGE_H + LABEL_H)), "#11130f")
        draw = ImageDraw.Draw(sheet)
        for index, slug in enumerate(subset):
            image = Image.open(ASSET_DIR / f"{slug}.png").convert("RGB")
            image.thumbnail((TILE_W, IMAGE_H), Image.Resampling.LANCZOS)
            tile_x = (index % COLS) * TILE_W
            tile_y = (index // COLS) * (IMAGE_H + LABEL_H)
            paste_x = tile_x + (TILE_W - image.width) // 2
            paste_y = tile_y + (IMAGE_H - image.height) // 2
            sheet.paste(image, (paste_x, paste_y))
            draw.text((tile_x + 12, tile_y + IMAGE_H + 7), slug, fill="white", font=label_font)
        output = OUTPUT_DIR / f"tutorial_contact_sheet_{start // per_sheet + 1}.jpg"
        sheet.save(output, quality=91, optimize=True)
        produced.append(output)
    print(f"validated={len(slugs)} sheets={len(produced)}")
    for path in produced:
        print(path)


if __name__ == "__main__":
    main()
