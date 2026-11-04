# Greedy voxel terrain meshing — performance feature

Based on PR #19's multiplayer/streaming branch, preserving the title screen, pixel HUD, equipment, portalled dungeons, inventory and old save records.

The prior terrain builder generated one 2-triangle face for every terrain tile, plus individual vertical cliff faces. This version greedily merges adjacent coplanar top faces sharing the same atlas tile and runs of exposed side faces sharing the same high/low elevations. It never merges across chunk boundaries, so terrain still streams independently.

**Pixel atlas correctness:** Merging faces with the old per-quad atlas UV would stretch the painting, destroying the pixel look. This feature adds `greedy_atlas.gdshader` and `greedy_mesher.gd`: UVs repeat once per world stud, UV2.x identifies the 16x16 source tile, and a nearest-filtered atlas lookup samples each repetition with a half-texel safety inset. The shader shares the same checked-in 64x64 texture from `voxel_palette.gd`. Existing props, player, creature and dungeon decor still use the standard shared material.

Collision continues to derive directly from the merged visual mesh; `tests/greedy_meshing.gd` compares merged vertex counts with the previous per-cell algorithm, checks UV2 indices and atlas texture, then reruns the entire Godot smoke workflow.

**Extendable biomes:** A future Snow/Oasis/Oblivion biome can select different tile IDs and quantized heights without changing the greedy surface emitter; do not add biomes without their separate water/collision/material design.

This is an optimisation pass, **not** infinite terrain or asynchronous generation. Android rendering and GPU-side visual quality must still be compared on a real device.
