# Outpost visual-world pass v0.1

**Branch:** `feature/voxel-world-visual-minimap`  
**Source:** user's approved screenshot (direction only — no extracted third-party game art).

## What is connected to the game now

- **Live circular overworld minimap:** `scripts/ui/live_world_minimap.gd` is instantiated by `scripts/hud.gd` in the upper-right footprint already reserved for the map. The minimap samples the existing streamed `VoxelAtmosphere` coastal zone and ground tile, not an invented map. It shows the player heading and nearby real crafting stations. The sampling texture is only 48×48 and refreshes every 0.5 seconds; it is nearest-filtered and ignores touch input.
- **Voxel material atlas:** `assets/voxel/outpost_visual_atlas_16px.svg` is a newly drawn 64×64 source with sixteen 16px tiles. `voxel_palette.gd` loads it as the primary atlas for terrain, trees, creatures, character, and all matching voxel props. Its tile indices and shader contract are unchanged, so the greedy mesher, coast atlas, and Android opaque-ground logic continue to work.
- **Trees:** `voxel_props.gd` replaces the old stubby canopy with nested cube layers and bark branches, retaining one mesh/draw call. `pine_tree()` is an optional variation; existing authored tree positions are preserved.
- **Workstations:** `station.gd` has a larger-detail wood workbench with mounted implements and shelf, plus a masonry/chimney forge with original emissive ember boxes. Recipe data and station interaction ranges are unchanged.
- **Hero:** `player.gd` scales the visual rig, enlarges the modular voxel head, and preserves the existing collision/stepping code. Quick selecting an owned axe or pickaxe swaps the right-hand model instead of leaving a sword visible. The same pivot hierarchy drives walking, attacks, gathering, and an airborne tuck; keyboard **J** is a small jump (mobile jump button is not yet exposed). Offhand torch, shield, cape, combat stats, saved quick-tool IDs, and existing crafting APIs remain.
- **CI:** `tests/visual_world_minimap.gd` is now included in the Godot smoke workflow.

## Android visual QA (still required before merge)

Open the game in **Godot 4.7.2 Compatibility**, play on a landscape Android device, and check:
1. The circular minimap fits above the clock and menu, and does not cover the three ability buttons.
2. Moving from grass to coast changes map colours; station dots remain consistent.
3. Forest trees look denser but do not obstruct traversal or gathering.
4. Pickaxe and axe actually appear in the right hand from the quick selector; switching to sword restores the blade.
5. The smaller rig and head do not clip the ground while walking, hopping over terrain, or swinging.
6. The forge has visible ember shapes at night; no unwanted transparency of opaque terrain/water.
7. Check frame pacing and streamed-chunk loading on low-spec Android hardware.

## Deliberately not included

- This is **not** a full texture-copy of the screenshot and not a finished hand-painted art set.
- No new crafting recipes, station inventory service, new furnace gameplay, character creator, or mobile jump action.
- No claim that the Android build was tested on a physical phone.
- The existing dungeon minimap remains separate; this feature covers the overworld.

## Follow-up implementation roadmap

1. Inspect a real phone screenshot and adjust palette / leaf silhouette, shoreline transition, player visual scale.
2. Add simple contextual mining/chopping impacts and an explicit on-screen jump control if the small jump feels useful.
3. Bring torch placement and portal light emitters into the same art palette with mobile light-budget testing.
4. Add optional generated pines and biome-specific vegetation; avoid introducing excessive extra draw calls.
