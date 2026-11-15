#!/usr/bin/env python3
"""Remove the original title screenshot's painted grey/black button slots.

PR #66 already handles independent button PNG transparency and their moving
glints. This repairs the *different* problem underneath them: the approved
1280x720 background PNG contains large baked dark/blurred slot rectangles.
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
    if MARKER.exists():
        print("Already prepared clean Alpha title background")
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

    clean.save(FILE, optimize=True)
    MARKER.parent.mkdir(parents=True, exist_ok=True)
    MARKER.write_text("Inpainted baked button backdrop slots for this Alpha build.\n")
    print("Alpha title background regenerated: no permanent shadow rectangles behind reusable buttons.")


if __name__ == "__main__":
    repair()
