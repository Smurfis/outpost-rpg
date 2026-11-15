#!/usr/bin/env python3
"""Install licensed PyroLux Lite v1.0.3 locally; do not commit its raw files."""
from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path
import sys
import urllib.request
import zipfile

ASSET_URL = "https://store.godotengine.org/asset/gennai/pyrolux-lite-fire-explosion-vfx/download/7088/"
EXPECTED_SHA256 = "ac9e33779420431a20ae7fe6c52d79350f6e7436eacb0ba2e4e1d1da7b9ab99d"
PREFIXES = ("addons/pyrolux_fx/", "pyrolux_lite_demo/")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="Use a locally downloaded PyroLux Lite v1.0.3 zip")
    parser.add_argument("--destination", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--no-demo", action="store_true", help="Install addon without its demo")
    args = parser.parse_args()

    if args.archive:
        blob = args.archive.read_bytes()
    else:
        req = urllib.request.Request(ASSET_URL, headers={"User-Agent": "Outpost-PyroLux-Installer/1.0"})
        with urllib.request.urlopen(req, timeout=45) as response:
            blob = response.read()

    digest = hashlib.sha256(blob).hexdigest()
    if digest != EXPECTED_SHA256:
        print(f"Refusing unexpected archive: SHA256 {digest}", file=sys.stderr)
        print(f"Expected: {EXPECTED_SHA256}", file=sys.stderr)
        return 1

    destination = args.destination.resolve()
    selected = ("addons/pyrolux_fx/",) if args.no_demo else PREFIXES
    with zipfile.ZipFile(io.BytesIO(blob)) as archive:
        entries = [info for info in archive.infolist() if not info.is_dir()]
        if not entries or not any(info.filename.startswith("addons/pyrolux_fx/") for info in entries):
            raise ValueError("PyroLux addon folder missing")
        for info in entries:
            name = info.filename
            if not any(name.startswith(prefix) for prefix in PREFIXES):
                raise ValueError(f"Unexpected archive entry: {name}")
            if name.startswith(selected):
                target = (destination / name).resolve()
                if not target.is_relative_to(destination):
                    raise ValueError(f"Unsafe archive path: {name}")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(info))

    print("Installed PyroLux Lite 1.0.3 to", destination)
    print("Godot demo: res://pyrolux_lite_demo/lite_demo.tscn" if not args.no_demo else "Demo omitted")
    print("Source files are gitignored per PyroLux redistribution restrictions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
