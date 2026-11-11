# Outpost: Blockbench creatures and prop import

## Installed importer
The editor-only **BBModel Importer** v1.0 (MIT, copyright Marco Zepeda 2025)
is vendored in `addons/bbmodel-importer/` from:
https://github.com/marcozee03/bbmodel-importer/tree/1ed150d56be3b8ff293a733cd918336a5a0af799

The upstream MIT licence is preserved at `addons/bbmodel-importer/LICENSE.txt`.
Source files are included unchanged, not loaded at runtime by creature gameplay.
It is **experimental**, with animation features less scrutinised by the author.
The pipeline test in `tests/blockbench_import_pipeline.gd` exercises a basic original source model.

## Workflow for animals
1. Create/import a Blockbench *Generic Model*. Keep the editable `.bbmodel`.
2. Paint a small texture atlas (16/32/64px as needed; nearest-neighbour filtering).
3. Use separate bone/group pivots and keyframes: idle, walk, run, attack, hit, death.
4. Save the working source under `assets/models/blockbench/source/<species>.bbmodel`.
5. For editor convenience, enable `Project > Project Settings > Plugins > BBModel Importer`.
   Godot imports the `.bbmodel` into a scene; test scale, faces, textures and animation.
6. **For shipped animals, prefer Blockbench > File > Export > glTF/GLB**, save
   `assets/models/blockbench/exported/<species>.glb`, and instance the imported
   scene (AnimationPlayer) under Outpost's existing CharacterBody3D.
   This uses Godot's native importer and avoids experimental animation conversions.
7. Keep original gameplay code: AI, health, loot, collision and movement should not
   be moved inside the art scene. Only replace the animal's visual child.
   Confirm origin/pivot, scaling, facing and foot contact; assign a fixed collision shape.
8. Test on PC and a real Android Compatibility-renderer build.
   Budget animated meshes and particles; use shared materials where possible.

## Licensing for free community assets
**Free to download does not imply permission for commercial reuse.**
For each externally authored model record: author, exact source URL, name,
license version, whether derivatives are allowed, whether commercial use is allowed,
and the attribution text. Add the entry to `assets/models/blockbench/ASSET_CREDITS.md`.
Keep a copy of the licence where distribution requires it.
CC0 generally requires no credit (still document provenance). CC BY requires
attribution; CC BY-SA has share-alike requirements and needs separate review.
Avoid noncommercial, no-derivatives and IP-infringing Minecraft/fan-model content.
Do not import a new model into shipping Alpha without verifying its precise terms.

## Planned replacements
1. Wild boar: match existing voxel boar dimensions and walk/charge/death timing
2. Wolf: idle/walk/attack/death, with a separate collision and AI setup
3. Deer and rabbit: ambient wildlife and reactions
4. Dungeon guardian variants: same imported scene pipeline, existing rarity/affix VFX

The fixture in tests is a **project-original single cube** purely for verifying
the importer. It is not intended to be used as finished game art.

## Commands
```sh
godot --headless --editor --path . --quit
godot --headless --path . -s res://tests/blockbench_import_pipeline.gd
```

Godot Editor: the plug-in imports source assets on development machines.
Android/PC runtime: Godot packages imported scenes and dependencies. A phone
does **not** need the Blockbench editor or the importer installed to play.
