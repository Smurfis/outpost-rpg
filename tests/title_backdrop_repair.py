#!/usr/bin/env python3
"""Standalone regression for the top-edge Alpha title repair. Requires Pillow."""
from __future__ import annotations

from pathlib import Path
from tempfile import TemporaryDirectory
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import clean_title_background as repair_module  # noqa: E402


def main() -> None:
    with TemporaryDirectory() as directory:
        fake_png = Path(directory) / "title_background.png"
        flag = Path(directory) / "repair.flag"
        original = Image.new("RGB", (1280, 720), (90, 145, 204))
        brush = ImageDraw.Draw(original)
        # Simulate the exact upper-left/right opaque patches seen on a 20:9
        # landscape screenshot, plus untouched distant scenery.
        brush.rectangle((409, 0, 489, 63), fill=(90, 64, 42))
        brush.rectangle((807, 0, 868, 63), fill=(90, 64, 42))
        brush.rectangle((430, 345, 825, 585), fill=(25, 22, 30))
        original.save(fake_png)
        old_path, old_marker = repair_module.FILE, repair_module.MARKER
        try:
            repair_module.FILE, repair_module.MARKER = fake_png, flag
            repair_module.repair()
        finally:
            repair_module.FILE, repair_module.MARKER = old_path, old_marker
        clean = Image.open(fake_png).convert("RGB")
        for x in (450, 831):
            r, g, b = clean.getpixel((x, 33))
            assert b > g > r, f"Upper matte still visible at x={x}: {(r, g, b)}"
        assert clean.getpixel((1000, 32)) == original.getpixel((1000, 32)), (
            "Unrelated title scenery was changed"
        )
        assert flag.read_text().strip() == "alpha-title-clean-v2", (
            "A stale first-generation marker would skip the fix"
        )
        assert clean.size == original.size
    print("TITLE BACKDROP REPAIR RESULT: 0 failures")


if __name__ == "__main__":
    main()
