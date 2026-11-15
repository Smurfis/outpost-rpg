#!/usr/bin/env python3
"""Generate Android launcher icons from the approved circular Outpost artwork.

Source: assets/branding/outpost_launcher_approved.png (the user's chosen icon).
The main icon uses the complete badge; adaptive icons keep the full badge
inside a safe central area so phone launchers can crop it without cutting text.
"""
from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding"
OUTPUT = SOURCE / "generated"
APPROVED = SOURCE / "outpost_launcher_approved.png"
OUTPUT.mkdir(parents=True, exist_ok=True)


def rasterize_background(dimension: int) -> Image.Image:
    png = cairosvg.svg2png(
        url=str(SOURCE / "outpost_icon_background.svg"),
        output_width=dimension,
        output_height=dimension,
    )
    return Image.open(BytesIO(png)).convert("RGBA")


if not APPROVED.is_file():
    raise SystemExit(f"Approved Android launcher image missing: {APPROVED}")
badge = Image.open(APPROVED).convert("RGBA")
if badge.size != (512, 512) or badge.getpixel((0, 0))[3] > 8:
    raise SystemExit("Approved launcher badge must be a transparent 512x512 PNG")

# Legacy/standard icon uses the complete chosen badge over the old scenic
# background in the tiny transparent corner regions.
main = Image.alpha_composite(rasterize_background(512), badge)
main.convert("RGB").save(OUTPUT / "outpost_launcher_preview_512.png", optimize=True)
main.resize((192, 192), Image.Resampling.LANCZOS).save(
    OUTPUT / "outpost_main_192.png", optimize=True
)

# Android adaptive icons have a masked safe zone. Keep the original badge,
# wordmark, campfire and gold rim together, not separately cropped.
safe_size = 320
foreground = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
safe_badge = badge.resize((safe_size, safe_size), Image.Resampling.LANCZOS)
foreground.alpha_composite(safe_badge, ((432 - safe_size) // 2, (432 - safe_size) // 2))
foreground.save(OUTPUT / "outpost_adaptive_foreground_432.png", optimize=True)
rasterize_background(432).save(
    OUTPUT / "outpost_adaptive_background_432.png", optimize=True
)

# Android 13+ themed icon: high-contrast single-colour extraction of the
# chosen logo, keeping the same placement and safe size.
luminance = foreground.convert("RGB").convert("L")
mask = luminance.point(lambda level: 255 if level >= 112 else 0)
mask = ImageChops.multiply(mask, foreground.getchannel("A"))
monochrome = Image.new("RGBA", (432, 432), (255, 255, 255, 0))
monochrome.putalpha(mask)
monochrome.save(OUTPUT / "outpost_adaptive_monochrome_432.png", optimize=True)

for name, dimensions in (
    ("outpost_main_192.png", (192, 192)),
    ("outpost_adaptive_foreground_432.png", (432, 432)),
    ("outpost_adaptive_background_432.png", (432, 432)),
    ("outpost_adaptive_monochrome_432.png", (432, 432)),
):
    image = Image.open(OUTPUT / name)
    if image.size != dimensions:
        raise SystemExit(f"Launcher icon dimensions wrong: {name} {image.size}")
    print(f"Generated approved launcher icon: {name} ({image.width}x{image.height})")
