#!/usr/bin/env python3
"""Generate the four Godot 4.7 Android launcher assets from checked-in vector art.

All source SVGs live in assets/branding so the icon is reproducible without
requiring temporary image attachments, manual Godot editor state, or secret URLs.
"""
from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding"
OUTPUT = SOURCE / "generated"
OUTPUT.mkdir(parents=True, exist_ok=True)


def rasterize(name: str, dimension: int) -> Image.Image:
    svg = SOURCE / ("outpost_icon_" + name + ".svg")
    png = cairosvg.svg2png(
        url=str(svg), output_width=dimension, output_height=dimension
    )
    return Image.open(BytesIO(png)).convert("RGBA")


background = rasterize("background", 512)
foreground = rasterize("foreground", 512)
main = Image.alpha_composite(background, foreground)
main.convert("RGB").save(OUTPUT / "outpost_launcher_preview_512.png", optimize=True)
main.resize((192, 192), Image.Resampling.LANCZOS).save(
    OUTPUT / "outpost_main_192.png", optimize=True
)
for layer in ("foreground", "background", "monochrome"):
    rasterize(layer, 432).save(OUTPUT / ("outpost_adaptive_" + layer + "_432.png"), optimize=True)

# Pixel tests and missing-image guards run in CI rather than relying on Godot's
# silent fallback to the built-in engine/robot logo.
for name, size in (
    ("outpost_main_192.png", (192, 192)),
    ("outpost_adaptive_foreground_432.png", (432, 432)),
    ("outpost_adaptive_background_432.png", (432, 432)),
    ("outpost_adaptive_monochrome_432.png", (432, 432)),
):
    candidate = Image.open(OUTPUT / name)
    if candidate.size != size:
        raise SystemExit(f"Icon size mismatch for {name}: {candidate.size}")
    print(f"Generated launcher icon: {name} ({candidate.size[0]}x{candidate.size[1]})")
