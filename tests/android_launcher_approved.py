#!/usr/bin/env python3
"""Regression guard for approved Outpost launcher art and adaptive safe zone."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
assets = ROOT / "assets" / "branding"
original = Image.open(assets / "outpost_launcher_approved.png").convert("RGBA")
assert original.size == (512, 512)
assert original.getpixel((0, 0))[3] == 0, "Badge corners must be transparent"
assert original.getpixel((256, 256))[3] > 230, "Approved badge is missing"

output = assets / "generated"
main = Image.open(output / "outpost_main_192.png").convert("RGBA")
fg = Image.open(output / "outpost_adaptive_foreground_432.png").convert("RGBA")
bg = Image.open(output / "outpost_adaptive_background_432.png").convert("RGBA")
mono = Image.open(output / "outpost_adaptive_monochrome_432.png").convert("RGBA")
assert main.size == (192, 192)
assert all(im.size == (432, 432) for im in (fg, bg, mono))
assert main.getpixel((96, 96))[0] > 80, "Main badge not visible"
assert fg.getpixel((216, 216))[3] > 230, "Adaptive foreground badge not visible"
for x, y in ((0, 0), (24, 216), (216, 24), (407, 216), (216, 407)):
    assert fg.getpixel((x, y))[3] == 0, "Adaptive badge exceeds safe zone"
assert bg.getpixel((0, 0))[3] > 230, "Adaptive background should be opaque"
assert mono.getchannel("A").getbbox(), "Themed icon is empty"
print("PASS: approved circular Android launcher and adaptive safe zone")
