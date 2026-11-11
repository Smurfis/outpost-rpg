#!/usr/bin/env python3
"""Install Quaternius' 2023 Cube World Kit glTF assets from a pinned CC0 mirror.

Run after checking out the pinned source mirror in scripts/workflows. Does not
change gameplay, third-party files, or user progress. Fails closed when missing
models or unanticipated external glTF dependencies are found.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

PROJECT = Path(__file__).resolve().parents[2]
DESTINATION = PROJECT / "assets" / "third_party" / "quaternius_cube_world"
PACK_FOLDER = "Cube World - Aug 2023"
SOURCE_REPO = "https://github.com/agentkaerf/FreeModels"
SOURCE_SHA = "db3df04d1e4714298a09510b26fb6de6645138a2"
AUTHOR_URL = "https://quaternius.com/packs/cubeworldkit.html"
LICENSE_URL = "https://creativecommons.org/publicdomain/zero/1.0/"

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mirror-root", required=True, type=Path, help="Pinned checkout of FreeModels repo")
    args = parser.parse_args()
    source_root = args.mirror_root.resolve() / PACK_FOLDER
    if not source_root.is_dir():
        raise RuntimeError(f"Missing expected Cube World Kit folder: {source_root}")
    source_models = sorted(source_root.rglob("*.gltf"))
    if len(source_models) < 100:
        raise RuntimeError(f"Expected 100+ kit glTF models; got {len(source_models)}")
    for key in ["Animals/glTF/Wolf.gltf", "Animals/glTF/Pig.gltf",
                "Enemies/glTF/Skeleton.gltf", "Enemies/glTF/Goblin.gltf"]:
        if not (source_root / key).is_file():
            raise RuntimeError(f"Missing expected creature: {key}")
    assets = []
    animated = 0
    skinned = 0
    for src in source_models:
        data = src.read_bytes()
        gltf = json.loads(data)
        if gltf.get("asset", {}).get("version") != "2.0":
            raise RuntimeError(f"Not a glTF 2.0 model: {src}")
        if not gltf.get("meshes"):
            raise RuntimeError(f"Missing mesh: {src}")
        if any(not str(buf.get("uri", "")).startswith("data:") for buf in gltf.get("buffers", [])):
            raise RuntimeError(f"Unexpected external geometry buffer: {src}")
        if any(image.get("uri") and not str(image["uri"]).startswith("data:") for image in gltf.get("images", [])):
            raise RuntimeError(f"Unexpected external image dependency: {src}")
        clips = [a.get("name", "") for a in gltf.get("animations", [])]
        animated += bool(clips)
        skinned += bool(gltf.get("skins"))
        assets.append({"file": src.relative_to(source_root).as_posix(),
                       "bytes": len(data),
                       "sha256": hashlib.sha256(data).hexdigest(),
                       "animations": clips,
                       "skinned": bool(gltf.get("skins"))})
    for key in ["Animals/glTF/Wolf.gltf", "Animals/glTF/Pig.gltf", "Enemies/glTF/Skeleton.gltf"]:
        clips = next(item["animations"] for item in assets if item["file"] == key)
        if not any(c.lower() == "idle" for c in clips) or not any(c.lower() == "walk" for c in clips):
            raise RuntimeError(f"Missing locomotion animations: {key}: {clips}")
    if animated < 15 or skinned < 15:
        raise RuntimeError(f"Unexpected animation/rig coverage: animated={animated}, skinned={skinned}")
    if DESTINATION.exists():
        shutil.rmtree(DESTINATION)
    shutil.copytree(source_root, DESTINATION, ignore=shutil.ignore_patterns(".DS_Store"))
    notice = {
        "pack": "Cube World Kit (August 2023)",
        "author": "Quaternius",
        "official_kit_page": AUTHOR_URL,
        "license": "Creative Commons CC0 1.0 Universal",
        "license_url": LICENSE_URL,
        "mirror_repository": SOURCE_REPO,
        "pinned_mirror_commit": SOURCE_SHA,
        "note": "Imported from pinned third-party mirror of Quaternius CC0 pack; check official site for newest licensing terms. No character AI/gameplay has been replaced.",
        "model_count_in_mirror": len(source_models),
        "animated_model_count": animated,
        "skinned_model_count": skinned,
        "assets": assets,
    }
    (DESTINATION / "SOURCE_MANIFEST.json").write_text(json.dumps(notice, indent=2) + "\n", encoding="utf-8")
    (DESTINATION / "LICENSE_AND_CREDITS.md").write_text(
        "# Quaternius Cube World Kit (August 2023)\n\n"
        "Creator: **Quaternius** (https://quaternius.com).\n\n"
        "Official pack: " + AUTHOR_URL + "\n\n"
        "Licence as displayed on the official 2023 pack page: **CC0 1.0 Universal**, "
        "including commercial use; credit not required, but given voluntarily.\n\n"
        "Licence: " + LICENSE_URL + "\n\n"
        "Mirrored source: " + SOURCE_REPO + "/tree/" + SOURCE_SHA + "/" + PACK_FOLDER.replace(" ", "%20") + "\n\n"
        "The models and textures are unmodified and remain the artist's work. "
        "See SOURCE_MANIFEST.json for exact hashes, counts and animation names.\n"
        "Do not mistake asset presence for gameplay integration. Replace NPC visual nodes individually "
        "after collision, animation and Android performance tests.\n",
        encoding="utf-8"
    )
    print(f"CUBE WORLD KIT INSTALLED: {len(source_models)} glTF files, {animated} animated, {skinned} skinned")
    print(f"MODEL SOURCE: {SOURCE_REPO}@{SOURCE_SHA}")
    print(f"DESTINATION: {DESTINATION}")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("INSTALL ERROR:", exc, file=sys.stderr)
        sys.exit(1)
