#!/usr/bin/env python3
"""Prepare actual transparent title buttons + clean scenery for Android Alpha.

Source art had four screenshot-shaped shadow voids behind the buttons and baked
Play sparkles in the Play button PNG. Those can't be repaired by adding a shader
on top. The original image dimensions are retained to keep Godot hitboxes in
sync with the artwork.

Run only on a fresh checkout (or restore tracked PNGs before rerunning):
  python tools/clean_title_art.py
The Alpha Android workflow runs this before Godot imports the artwork. Main
(Stable) is never changed.
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "ui" / "title"
MARKER = ROOT / ".godot" / "alpha_title_art_prepared.flag"


def clamp01(value: float) -> float:
    return min(1.0, max(0.0, value))


def smooth(value: float) -> float:
    t = clamp01(value)
    return t * t * (3.0 - 2.0 * t)


def repair_background() -> None:
    path = ART / "title_background.png"
    image = Image.open(path).convert("RGB")
    assert image.size == (1280, 720), "Unexpected Outpost title composition"
    src = image.load()
    result = image.copy()
    dst = result.load()

    # The legacy scenery has large, flat, dark shadow rectangles where
    # the four buttons used to be. Reconstruct the centre by borrowing
    # actual painted trees/campfire on the LEFT and waterfall/terrain on
    # the RIGHT. Feather all four edges so no new opaque rectangle appears.
    # Source pixels are read from the unaltered original image.
    for y in range(275, 718):
        vertical = smooth((y - 283.0) / 78.0) * smooth((710.0 - y) / 68.0)
        if vertical <= 0.0:
            continue
        for x in range(358, 910):
            horizontal = smooth((x - 365.0) / 58.0) * smooth((909.0 - x) / 54.0)
            amount = vertical * horizontal
            if amount <= 0.0:
                continue
            t = (x - 393.0) / 490.0
            mixing = smooth((t - 0.41) / 0.18)
            # At the bottom the centre should be grass/river rather than
            # repeating the tabletop and timber in the left foreground.
            mixing = max(mixing, smooth((y - 555.0) / 105.0) * 0.93)
            left_x = max(5, min(1274, int(393.0 - (x - 393.0) * 0.30)))
            right_x = max(5, min(1274, int(883.0 + (883.0 - x) * 0.30)))
            left = src[left_x, y]
            right = src[right_x, y]
            reconstructed = tuple(int(left[c] * (1.0 - mixing) + right[c] * mixing) for c in range(3))
            old = src[x, y]
            dst[x, y] = tuple(int(old[c] * (1.0 - amount) + reconstructed[c] * amount) for c in range(3))
    result.save(path, optimize=True)


def clean_button(kind: str) -> None:
    path = ART / ("btn_" + kind + ".png")
    image = Image.open(path).convert("RGBA")
    expected = {
        "play": ((422, 92), (43.0, 383.0, 6.0, 86.0)),
        "continue": ((360, 79), (24.0, 338.0, 8.0, 74.0)),
        "settings": ((336, 76), (19.0, 317.0, 7.0, 70.0)),
        "quit": ((296, 76), (18.0, 278.0, 8.0, 70.0)),
    }
    expected_size, (left, right, top, bottom) = expected[kind]
    assert image.size == expected_size, "Unexpected button artwork size: " + kind
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            curve = abs(y - (top + bottom) * 0.5) / ((bottom - top) * 0.5)
            corner = max(0.0, curve - 0.55) * 10.0
            alpha = (
                smooth((x - left - corner) / 3.0)
                * smooth((right - corner - x) / 3.0)
                * smooth((y - top) / 3.0)
                * smooth((bottom - y) / 3.0)
            )
            r, g, b, old_alpha = pixels[x, y]
            pixels[x, y] = (r, g, b, int(old_alpha * alpha))
    image.save(path, optimize=True)
    # Once cleaned, the painted rays at Play's outer corners must be absent.
    assert image.getpixel((0, image.height // 2))[3] == 0
    assert image.getpixel((image.width - 1, image.height // 2))[3] == 0


def main() -> None:
    if MARKER.exists():
        print("Outpost title already prepared; keeping original one-pass artwork")
        return
    repair_background()
    for button in ("play", "continue", "settings", "quit"):
        clean_button(button)
    MARKER.parent.mkdir(parents=True, exist_ok=True)
    MARKER.write_text("Background shadows and static rays removed from generated Alpha art.\n")
    print("Outpost Alpha title: replaced baked scenery shadows and static Play rays; separate button PNGs retain original hitbox sizes.")


if __name__ == "__main__":
    main()
