#!/usr/bin/env python3
"""Render deterministic clinical tutorial diagrams for procedures AI imagery cannot depict safely."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/emergency_guides/tutorials/rcp_nino_bebe.png"
PANEL_W, HEIGHT, GAP, SCALE = 512, 1024, 4, 3
BG = "#F6F3EA"
INK = "#24312B"
MANNEQUIN = "#EBC7A5"
MANNEQUIN_DARK = "#C89A72"
GLOVE = "#168B9C"
GLOVE_DARK = "#0B5F6C"
TARGET = "#C53B32"
MAT = "#DCE7DF"


def sc(box):
    return tuple(int(v * SCALE) for v in box)


def line(draw, points, fill=INK, width=5):
    draw.line([(int(x * SCALE), int(y * SCALE)) for x, y in points], fill=fill, width=width * SCALE, joint="curve")


def ellipse(draw, box, **kwargs):
    draw.ellipse(sc(box), **kwargs)


def rounded(draw, box, radius, **kwargs):
    draw.rounded_rectangle(sc(box), radius=radius * SCALE, **kwargs)


def polygon(draw, points, **kwargs):
    draw.polygon([(int(x * SCALE), int(y * SCALE)) for x, y in points], **kwargs)


def mannequin_top(draw, *, torso_top=265, torso_bottom=700):
    # Mat and neutral head alignment.
    rounded(draw, (72, 85, 440, 925), 28, fill=MAT, outline="#A7B8AC", width=3 * SCALE)
    ellipse(draw, (190, 120, 322, 252), fill=MANNEQUIN, outline=INK, width=5 * SCALE)
    # Artificial mannequin face markers.
    ellipse(draw, (224, 170, 235, 181), fill=INK)
    ellipse(draw, (277, 170, 288, 181), fill=INK)
    line(draw, [(256, 183), (256, 211)], fill=MANNEQUIN_DARK, width=4)
    rounded(draw, (158, torso_top, 354, torso_bottom), 60, fill=MANNEQUIN, outline=INK, width=5 * SCALE)
    # Arms.
    line(draw, [(170, 310), (95, 500), (116, 650)], fill=MANNEQUIN_DARK, width=40)
    line(draw, [(342, 310), (417, 500), (396, 650)], fill=MANNEQUIN_DARK, width=40)
    # Legs and feet.
    line(draw, [(205, torso_bottom - 5), (180, 850)], fill=MANNEQUIN_DARK, width=48)
    line(draw, [(307, torso_bottom - 5), (332, 850)], fill=MANNEQUIN_DARK, width=48)
    rounded(draw, (132, 830, 198, 902), 25, fill=MANNEQUIN, outline=INK, width=4 * SCALE)
    rounded(draw, (314, 830, 380, 902), 25, fill=MANNEQUIN, outline=INK, width=4 * SCALE)


def draw_gloved_hand_tapping_foot(draw):
    # One gloved hand, wrist entering from lower left, fingertips touching sole.
    polygon(draw, [(12, 875), (68, 875), (155, 850), (170, 888), (78, 935), (12, 935)], fill=GLOVE, outline=INK)
    # Five distinct short fingertips aimed at sole.
    for i, y in enumerate((842, 851, 861, 872, 884)):
        rounded(draw, (142 + i * 2, y - 9, 192 + i * 2, y + 8), 8, fill=GLOVE, outline=GLOVE_DARK, width=2 * SCALE)
    ellipse(draw, (168, 850, 190, 875), fill="#F4D35E", outline=INK, width=2 * SCALE)


def panel_response() -> Image.Image:
    image = Image.new("RGB", (PANEL_W * SCALE, HEIGHT * SCALE), BG)
    draw = ImageDraw.Draw(image)
    mannequin_top(draw)
    # Phone is distinct and fully inside the mat.
    rounded(draw, (352, 715, 414, 825), 10, fill="#1B2421", outline=INK, width=3 * SCALE)
    rounded(draw, (360, 730, 406, 800), 5, fill="#8FB8AA")
    draw_gloved_hand_tapping_foot(draw)
    return image.resize((PANEL_W, HEIGHT), Image.Resampling.LANCZOS)


def draw_one_hand_heel(draw):
    # The wrist enters horizontally from the right, entirely above the abdomen.
    rounded(draw, (330, 470, 530, 555), 28, fill=GLOVE, outline=INK, width=5 * SCALE)
    polygon(
        draw,
        [(250, 452), (300, 405), (382, 420), (405, 486), (360, 545), (286, 530)],
        fill=GLOVE,
        outline=INK,
    )
    # A small dark heel is the only contact area, centered on the sternum target.
    ellipse(draw, (231, 445, 281, 495), fill=GLOVE_DARK, outline="#FFFFFF", width=5 * SCALE)
    # Four distinct fingers arch above the chest; pale shadows make the air gap explicit.
    for index, x in enumerate((382, 410, 438, 466)):
        rounded(draw, (x + 7, 288 + index * 5, x + 35, 420 + index * 5), 14, fill="#FFFFFF", outline="#B6C8C3", width=2 * SCALE)
        rounded(draw, (x, 270 + index * 5, x + 28, 395 + index * 5), 14, fill=GLOVE, outline=INK, width=3 * SCALE)
    # One raised thumb, also separated from the chest by a pale gap.
    rounded(draw, (260, 376, 311, 421), 20, fill="#FFFFFF", outline="#B6C8C3", width=2 * SCALE)
    rounded(draw, (248, 354, 302, 399), 20, fill=GLOVE, outline=INK, width=3 * SCALE)


def panel_compression() -> Image.Image:
    image = Image.new("RGB", (PANEL_W * SCALE, HEIGHT * SCALE), BG)
    draw = ImageDraw.Draw(image)
    # Tight chest crop: head, nipple landmarks, sternum, upper abdomen; no diaper.
    ellipse(draw, (194, 58, 318, 182), fill=MANNEQUIN, outline=INK, width=5 * SCALE)
    rounded(draw, (122, 200, 390, 820), 86, fill=MANNEQUIN, outline=INK, width=5 * SCALE)
    ellipse(draw, (158, 320, 180, 342), fill=MANNEQUIN_DARK, outline=INK, width=2 * SCALE)
    ellipse(draw, (332, 320, 354, 342), fill=MANNEQUIN_DARK, outline=INK, width=2 * SCALE)
    line(draw, [(256, 330), (256, 545)], fill=MANNEQUIN_DARK, width=5)
    # Lower-half sternum target, clearly above abdomen.
    ellipse(draw, (226, 430, 286, 490), fill="#F6B2AA", outline=TARGET, width=5 * SCALE)
    draw_one_hand_heel(draw)
    return image.resize((PANEL_W, HEIGHT), Image.Resampling.LANCZOS)


def panel_breath() -> Image.Image:
    image = Image.new("RGB", (PANEL_W * SCALE, HEIGHT * SCALE), BG)
    draw = ImageDraw.Draw(image)
    # Infant mannequin side profile, torso horizontal and head only slightly extended.
    rounded(draw, (218, 540, 490, 770), 85, fill=MANNEQUIN, outline=INK, width=5 * SCALE)
    ellipse(draw, (215, 350, 395, 535), fill=MANNEQUIN, outline=INK, width=5 * SCALE)
    # Two distinct mannequin landmarks sit inside one shared adult-lip seal.
    polygon(draw, [(228, 414), (190, 438), (230, 452)], fill=MANNEQUIN, outline=INK)
    line(draw, [(195, 470), (227, 470)], fill=INK, width=5)
    # Adult face profile from left, ending at one continuous oval mouth seal.
    ellipse(draw, (-110, 245, 170, 555), fill="#C9875E", outline=INK, width=5 * SCALE)
    ellipse(draw, (158, 397, 248, 500), outline="#9F3545", width=15 * SCALE)
    ellipse(draw, (168, 408, 238, 489), outline="#E9A3A9", width=4 * SCALE)
    # One hand supports the forehead; it stays away from chest and abdomen.
    rounded(draw, (255, 205, 310, 390), 22, fill=GLOVE, outline=INK, width=4 * SCALE)
    ellipse(draw, (230, 325, 330, 415), fill=GLOVE, outline=INK, width=4 * SCALE)
    # Chest contour is slightly raised but no arrows or text are embedded.
    line(draw, [(280, 553), (335, 525), (405, 548)], fill=TARGET, width=6)
    return image.resize((PANEL_W, HEIGHT), Image.Resampling.LANCZOS)


def main() -> None:
    panels = [panel_response(), panel_compression(), panel_breath()]
    canvas = Image.new("RGB", (PANEL_W * 3 + GAP * 2, HEIGHT), "#D8D2C5")
    x = 0
    for index, panel in enumerate(panels):
        canvas.paste(panel, (x, 0))
        x += PANEL_W
        if index < 2:
            x += GAP
    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT, optimize=True)
    print(f"rendered {OUT} {canvas.width}x{canvas.height} {OUT.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
