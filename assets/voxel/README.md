# Outpost pixel-voxel assets — included in Feature B

**Everything required for the present Feature B visual test is in this Git branch.** No separate ChatGPT download, generated ZIP, external art pack, or private asset location is required.

## Included binary artwork

- `outpost_atlas_16px.png` — original **64 × 64 RGB PNG**, containing **16 different 16 × 16 pixel-art material tiles** laid out in a 4 × 4 grid:
  - Row 0: grass, light grass, deep grass, soil
  - Row 1: stone, path, gravel, moss
  - Row 2: bark, leaves, dark leaves, timber planks
  - Row 3: masonry, crystal, berries, coal
- Runtime material: `res://scripts/voxel/voxel_palette.gd` imports the PNG at `res://assets/voxel/outpost_atlas_16px.png` with nearest-neighbour filtering. A deterministic procedural backup remains in the script only for resilience.
- UV coordinates reference this exact four-column grid. When making replacement art, preserve tile indices and the 64 × 64 dimensions until the UV layout is deliberately revised.

## Included geometry, not separate images/models

These renderable assets are **created directly from code already tracked in this feature branch**, so you will not find a matching individual PNG or OBJ for each item:

- `scripts/voxel/voxel_biome.gd` — tiled terrain, paths, stepped distant cliffs, grass details.
- `scripts/voxel/voxel_props.gd` — voxel trees, rocks, ore, bushes, crates, tent.
- `scripts/voxel/voxel_character.gd` — modular pixel-textured adventurer body/head/limbs.
- `scripts/station.gd` — pixel-textured workbench, forge, loom and campfire blocks when voxel skin is enabled.

Other original placeholder OBJ models such as weapons/shield/cloak are already checked into the repository under `assets/models/`. They still need a later proper pixel-texture/UV art pass, but they are **not missing files**.

## Branch boundaries

Feature B does **not** include title-screen graphics from Feature A / PR #7, nor assets created by the independent in-game UI agent. Merge those features intentionally if a combined Android test needs them. **Do not try to substitute flattened ChatGPT concept boards as final assets.**

## Verify from a fresh checkout

Run Godot 4.7.2's editor import, then `tests/voxel_art_smoke.gd`. The test asserts the PNG exists and is imported as a 64 × 64 texture, that atlas filtering is nearest, and that world and legacy visual paths work. CI runs the same test.

No artwork needs to be manually downloaded or copied to make the current voxel feature render.
