# Quaternius Cube World Kit: original voxel creature / environment assets

**Status:** asset-import preparation for Outpost Alpha; do not replace working
boar/guardian/world renderer blindly.

Official source: https://quaternius.com/packs/cubeworldkit.html

Original artist: **Quaternius**.

Licence displayed for the August 2023 kit: **CC0 1.0 Universal** (commercial
use permitted; attribution not required). We include credit voluntarily.
https://creativecommons.org/publicdomain/zero/1.0/

Because the official download is a Google Drive folder rather than a
machine-friendly single archive, the repository installer uses a pinned,
public glTF mirror of the **Cube World - Aug 2023** asset set:

- Mirror: https://github.com/agentkaerf/FreeModels
- Immutable mirror commit: db3df04d1e4714298a09510b26fb6de6645138a2
- Installer: scripts/tools/install_quaternius_cube_world.py
- Contents installed at: assets/third_party/quaternius_cube_world/
- Exact SHA-256, source, asset animation names: SOURCE_MANIFEST.json

The mirrored glTF collection has **107 files** (the official page advertises
108 models, so this mirror may be missing a model). Verify against the
official release before describing the mirrored collection as a perfect
byte-for-byte copy of all 108 original assets. It includes 9 animals,
9 enemies, humanoid characters, environment models and voxel blocks.
The files are glTF 2.0 with embedded geometry and image data.

## Godot pipeline

Native Godot 4.7.2 glTF importer supports these \`.gltf\` models; importing
a model does not require the Blockbench \`.bbmodel\` editor plugin. The latter
remains available for separately authored Blockbench projects. Keep nearest
texture sampling to match Outpost's pixel style.

The priority visual swaps:
- **Pig** is not a boar; use it only as a temporary placeholder or make a
  boar variant in Blockbench while preserving our existing boar AI.
- **Wolf** is an appropriate future hostile wildlife model.
- **Skeleton**, **Goblin** and other enemies can be reused for dungeon
  archetypes, preserving existing encounter slots, HP, affixes, and drops.
- The modular cube-world props can improve dungeons, but do not block
  collision paths or replace safe hallway floor/door geometry.

To use an animal, instance a glTF scene under the existing
\`CharacterBody3D\` visual container; preserve original collision and AI.
Drive its \`AnimationPlayer\` by the existing animation state instead of
letting animation nodes change physics transforms. Verify orientation,
scale, animation names, clips (idle/walk/run/attack/death), and Android
Compatibility-renderer performance before modifying Alpha gameplay.

The original art files are not altered. Imported Godot engine cache
(\`.godot/imported\`) is generated locally and must not be committed.
