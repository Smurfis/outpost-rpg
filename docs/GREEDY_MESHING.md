# Greedy plane meshing for streamed voxel Fields
- Purpose: merge neighbouring horizontal top faces **only when exact height and atlas tile match**; this is shared groundwork for future biome-specific generation.
- Original 16×16 pixels in the existing 64×64 atlas stay crisp. A tiny Godot 4 spatial shader reads per-quad tile index from vertex color and uses repeating UVs **within that tile**, avoiding texture stretching and atlas bleed.
- Exposed cliff side faces remain per voxel in this first pass (later optimize by direction and vertical span). Collision uses the resulting mesh and retains streamed chunk budgets.
- Exported `greedy_meshing_enabled` defaults true. Disable for exact original geometry/material comparison.
- Runtime test: `tests/greedy_meshing.gd`, and all existing stream, field, dungeon and LAN tests.
- Limitations: texture edge sampling must still be checked visually on Android. Drawing one terrain mesh per chunk already minimized draw calls; this mainly reduces triangles/physics triangles, not the number of render objects. No infinite terrain promise; Fields remains finite and streamed.
