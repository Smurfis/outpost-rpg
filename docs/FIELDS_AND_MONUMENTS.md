# Outpost: Fields biome, monumental portals and auto-step

**Branch:** `feature/fields-biome-monument-portals`. Stacked on draft PR #13; NO direct `main` merge and NO changes to the existing title screen or pixel crafting HUD.

## What this implements
- The voxel world expands from 46×46 studs (base camp) to a **96×96 stud Fields biome**, using 64 ground chunks of 12×12 tiles. The game retains the original camp, portal locations, stations and starter resources.
- Deterministic **FastNoiseLite.TYPE_PERLIN** with three fractal octaves chooses terraces beyond the untouched central clearing. Terrain height is deliberately snapped to whole voxel units, 0–3 high. Each tile has top and exposed vertical faces; one concave collision mesh is generated per chunk so characters walk on real geometry.
- Original legacy visual toggle `voxel_art_enabled` still works. `fields_biome_enabled` separately returns to the old small biome for performance comparison. Seed is `64012`; future chunk streamer may consume the same surface function but is **not replaced** here.
- Big rarity portals become roughly **six studs tall** and six wide, with a low-poly pixel-atlas stone monument, rarity-coloured animated emissive core, world-space label, and enlarged touch target. Original rarity, dungeon IDs, entry/exit, saves and rewards remain unchanged.
- `CharacterBody3D` now has `auto_step_enabled` and `max_auto_step_height=1.05`. Walking into a one-unit cliff tries to lift the player onto a walkable surface after testing overhead/headroom, top surface and horizontal clearance. A two-unit wall cannot be bypassed. The floor snap is 1.15, allowing step-down without a jump key. Dungeon movement intentionally **does not auto-step** to avoid exploiting dungeon walls.
- Scattered Fields vegetation shares a single pixel-atlas mesh and decorative props are intentionally **not harvestable**. A small number of further resource nodes are added around the outer fields.

## Android / performance gates
1. Run in Godot 4.7.2 on Android landscape, walk around original centre and into distant Fields. Test one-unit step-up and step-down, 2-unit ledge refusal, cliff corners and boundaries.
2. Check at least 30 FPS on target device, touch control responsiveness and 64 trimesh collision chunks. Compare `fields_biome_enabled=false` for performance diagnosis.
3. Tap the larger portals, complete a dungeon, check movement after leaving, and check save + Play/Continue; test in both voxel and legacy graphics modes.
4. Confirm item collection, combat and crafting were not changed. Use input mode in Android Godot remote run.

## Known limitations
- This is a **finite 96x96 Fields prototype**, not an infinite chunk streamer. Chunks are constructed eagerly once; streaming/persistence remains for a dedicated feature branch.
- Some far scenery is visual-only and does not block characters; natural-prop collision/harvest budgets need a future pass.
- Existing boar visuals are still old geometric models; full pixel voxel boar rework is separate.
- Doorway floor seams within procedurally generated dungeon rooms still need dedicated floor/connector collision tests.
- No physical Android device performance test is claimed by automated Linux CI.

New regression: `tests/fields_step.gd` and updated existing voxel art smoke.
