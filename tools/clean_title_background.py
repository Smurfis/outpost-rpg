#!/usr/bin/env python3
"""Repair the approved title background's baked-in screenshot mattes.

PR #66 already handles independent button PNG transparency and their moving
glints. This repairs the *different* problem underneath them: the approved
1280x720 background PNG contains large baked dark/blurred slot rectangles,
plus two top-edge brown smudges beside the separately rendered crest.
The Alpha Android build runs this once before Godot imports the textures.
Stable is unaffected, and all original source art stays in Git.
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FILE = ROOT / "assets/ui/title/title_background.png"
MARKER = ROOT / ".godot/alpha_backdrop_repaired.flag"


def smooth(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def repair() -> None:
    if MARKER.exists() and MARKER.read_text().strip() == "alpha-title-clean-v2":
        print("Already prepared clean Alpha title background v2")
        return
    image = Image.open(FILE).convert("RGB")
    if image.size != (1280, 720):
        raise RuntimeError("Title art dimensions changed: repair boundaries need revision")
    original = image.load()
    clean = image.copy()
    pixels = clean.load()

    # Synthesise only the 4 old dark/grey button placeholders using nearby
    # authentic painted forest on the left and waterfall/terrain on the right.
    # Feather every edge: no new rectangular patch or hard matte.
    for y in range(275, 718):
        vertical = smooth((y - 283.0) / 78.0) * smooth((710.0 - y) / 68.0)
        if vertical <= 0:
            continue
        for x in range(358, 910):
            horizontal = smooth((x - 365.0) / 58.0) * smooth((909.0 - x) / 54.0)
            mix_amount = horizontal * vertical
            if mix_amount <= 0:
                continue
            transition = (x - 393.0) / 490.0
            right_mix = smooth((transition - 0.41) / 0.18)
            # Bottom left source art contains a large tabletop: favour
            # grassy/waterfall pixels from the right in the lower button rows.
            right_mix = max(right_mix, smooth((y - 555.0) / 105.0) * 0.93)
            left_x = max(5, min(1274, int(393.0 - (x - 393.0) * 0.30)))
            right_x = max(5, min(1274, int(883.0 + (883.0 - x) * 0.30)))
            left = original[left_x, y]
            right = original[right_x, y]
            donor = [int(left[c] * (1.0 - right_mix) + right[c] * right_mix) for c in range(3)]
            old = original[x, y]
            pixels[x, y] = tuple(int(old[c] * (1.0 - mix_amount) + donor[c] * mix_amount) for c in range(3))

    # The approved title background also has two *baked-in*, blurry matte
    # rectangles at the top, just outside the separately drawn Outpost crest.
    # These are visible in the 20:9 Android screenshot as opaque brown bands
    # beside the logo (the wide panorama horizontally stretches the PNG).
    # Work in native 1280x720 source pixels, not phone screenshot pixels.
    # Each patch borrows actual scenery from either side of the affected area;
    # feathering all edges keeps the painted border and sky continuous.
    # This is a build-time art repair; the original PNG stays tracked in Git.
    for x0, x1 in ((393, 505), (790, 885)):
        for y in range(0, 91):
            vertical = smooth((90.0 - y) / 27.0)
            for x in range(x0, x1):
                horizontal = smooth((x - x0) / 16.0) * smooth((x1 - 1 - x) / 16.0)
                amount = horizontal * vertical
                if amount <= 0.0:
                    continue
                t = smooth((x - x0) / float(x1 - x0))
                # Sample well outside the original matte. Using different
                # columns retains the underlying pixel-art texture, instead
                # of introducing another single-colour rectangle.
                donor_left_x = max(0, x0 - 3 - int((x - x0) * 0.50))
                donor_right_x = min(1279, x1 + 3 + int((x1 - x) * 0.50))
                left = original[donor_left_x, y]
                right = original[donor_right_x, y]
                old = original[x, y]
                donor = tuple(round(left[c] * (1.0 - t) + right[c] * t) for c in range(3))
                pixels[x, y] = tuple(round(old[c] * (1.0 - amount) + donor[c] * amount) for c in range(3))

    clean.save(FILE, optimize=True)
    MARKER.parent.mkdir(parents=True, exist_ok=True)
    MARKER.write_text("alpha-title-clean-v2")
    print("Alpha title background regenerated: repaired button shadows and two upper logo-side mattes.")


if __name__ == "__main__":
    repair()
