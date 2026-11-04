# Chunk streaming (Phase 4)

The Outpost Fields prototype is now **finite 192 × 192 studs** with chunk loading/unloading. 12 × 12 voxel meshes and real collision chunks load in a 7 × 7 neighbourhood around the current avatar. When moving into another chunk, terrain and decorations beyond that radius are removed, while new cells generate from the same world seed.

- `chunk_streaming_enabled` exported in `scripts/game.gd`; default **true**, set false to recover original fully-loaded 96×96 Fields mode for comparison.
- One shared 16×16 pixel-art atlas material, nearest filtering; one batched grass/trees mesh per loaded chunk. 
- `scripts/voxel/voxel_biome.gd` exposes `update_streaming_for(world_position)`, `has_chunk_at(x,z)`, `loaded_chunk_count()` for tests, live co-op and future save/network integrations.
- Dungeon teleports outside world bounds do not trigger unload.
- Origin camp stays flat; other crafts, stations, enemy AI, loot, dungeon clear history and save schema remain unchanged.
- Existing world boundary now matches ±96 when streaming.

**Limitations:** This is NOT an infinite procedural world or a persisted editable terrain system; chunks are regenerated deterministically and not changed by players. Persistent resource nodes and their own despawns still use the original gameplay mechanism. The current synchronous 7×7 prewarm is an Android test candidate, not final asynchronous load budgeting. Future multiplayer should stream client visuals independently while the host owns resource/enemy state.

**Tests:** `tests/chunk_streaming.gd` checks unload/reload and identical geometry, bounded active count, colliders/decor and fallback full-map mode. Android thermal/frame pacing, walking across chunk borders and display of far background scenery still need physical testing.
