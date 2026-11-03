# Outpost — Pixel-voxel art direction (experimental)

**Status:** visual experiment on `feature/voxel-art-direction` (branched from `main`). **Not intended to merge until Android visual review.** Inspired by the colourful fantasy atmosphere of Cube World and detailed blocky fantasy environments; all shapes and pixel textures here are procedurally authored for Outpost.

## What's included

- Original deterministic **64×64 atlas**: sixteen 16×16 pixel-art tiles, one shared nearest-neighbour material (`scripts/voxel/voxel_palette.gd`). No third-party art, texture licence, external download, or imported GPU-heavy material.
- The 46×46 gameplay ground is rendered with **8×8-cell chunked meshes** and winding path tiles, replacing the previously flat green slab only visually. The original collision ground and wall boundaries remain.
- Stepped grass/dirt/stone hills are generated **outside existing collision bounds** for depth without changing gameplay heights or blocking resources.
- Modular voxel-inspired **oak trees, stone/ore deposits, berry bushes, crates and stepped tent** (`scripts/voxel/voxel_props.gd`).
- A warm sky and late-afternoon key light using inexpensive ambient light with shadows disabled for this first Android-first pass.
- Original interactions, resource types, harvesting cooldowns, equipment, crafting stations and game saves remain in place.
- `@export var voxel_art_enabled: bool = true` in `scripts/game.gd` can be unchecked in the scene inspector to restore the original terrain and decorative models. The default on this feature branch is ON, but `main` is unchanged.

## Why not a cube per terrain tile?

Each terrain chunk produces an `ArrayMesh` with a single shared atlas material, not a scene tree of thousands of physics cubes. The ground itself remains collision-flat so the 0.5 prototype movement/crafting design remains valid. This is a **visual skin and atmosphere experiment**, not an editable voxel engine and not actual Minecraft terrain physics.

## Testing

- `tests/smoke.gd`: existing crafting, equipment, HUD, gathering, combat and saves.
- `tests/voxel_art_smoke.gd`: nearest-neighbour pixel atlas, landscape mesh, resources, decorative props and legacy toggle.
- GitHub Actions runs Godot 4.7.2 resource import/startup then both regressions.

## Known limitations and proposed next art pass

- Trees/rocks/camp tent are deliberately simple and procedural; the character mesh, forge, loom, campfire, and most plants still use the prototype models.
- First pass uses one shared atlas and a small number of authored tile patterns; it is not yet final artistic-quality 3D pixel art. A proper palette/art pass would add ivy, grass clumps, tile variation, atlas-authored timber, forge details, crystal light and a consistent character skin.
- No destruction, raising terrain, world editor, smooth LOD transitions, multiplayer replication, block collisions, or endless streaming yet.
- The standalone title-screen feature is on another **draft PR**, not included here. Avoid merging either branch into the other until both are reviewed.

## Manual visual sign-off

1. Switch to `feature/voxel-art-direction` and run Outpost using Godot 4.7.2.
2. Compare the **terrain, paths, tree silhouette, rocks, tent and sunset sky** to the previous prototype on the same Android device.
3. Verify station proximity, harvesting, collisions, combat and crafting.
4. If visual improvements are worthwhile, refine the character, stations and foliage **within this branch** and test performance before merging.
5. Leave `main` and the previous title-screen PR untouched until approval.
