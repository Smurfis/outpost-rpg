# Mine cycle loading

The dungeon manager loads and validates its existing site registry before the game constructs the world. The archipelago now creates its base terrain and defers mine generation. The game then loads the player save and restores constructions. Only after both sources are available does the archipelago select the matching physical site's generation seed and carve the mine. Streaming remains stopped while this is pending or if reconstruction fails.

Previously the mine was carved with cycle zero during world construction. The player save was loaded afterwards, and the dungeon record was only consulted when a mine chunk populated. That order could combine cycle-one progression with cycle-zero terrain.

Cycle zero retains its original seed and geometry. The supported cycle-one record must identify the same world and site, have the deterministic initial-event seed for cycle one, retain its cycle-zero receipts and defeats, and remain ready for renewal with the recorded reoccupation event. Other cycles, mismatched IDs, non-integral values and inconsistent seeds or event states are rejected. Schema-one portal and mine records migrate through the existing registry loader.

For cycle one, the player save must contain a complete valid construction list. The loader reconstructs the original and proposed layouts separately, rejects changes overlapping saved blocks or other registered sites' chunks, then constructs the selected layout. On failure it stops remote island streaming and emits an error while retaining the saves. This initial-load mechanism does not publish live terrain changes.

## Verification

Seed 64012 cycle-one startup was run in independent Godot processes using isolated saves. Both produced occupancy signature `1837af8d15b1678eea5d74b266a72bb818e821bf26d343f05545e0593bb6c666` and seed 1477028102. The layout differed from cycle zero, and the fixture raycast the floor collision in multiple generated chambers. A GL Compatibility run captured the sealed entrance. The cycle-zero receipt, defeated guards and ready event remained intact.

Six malformed dungeon records were loaded in separate processes and rejected without changing their saved bytes. A saved player block on a changed column also prevented reconstruction. The registry imported 16 archived 5B mine records. The existing lifecycle, save, picking, camera, streaming and natural-cave fixtures cover cycle-zero compatibility.

## Handoff to 8B.2

Live renewal needs a durable transaction or journal, generation revision and immutable candidate. It must recheck all player locations, construction protection and other site ownership at commit time. Build replacement chunk meshes and collision while the old world stays authoritative. Atomically publish the selected generation, invalidate navigation and every affected cutaway/picking cache, then release the barrier. Recovery must reconstruct either the old sealed generation or the fully committed new one after every interruption. Cycle-one enemies, reward IDs and event completion remain separate later work. Android is untested.

## 8B.2 unloaded-chunk publication

With the lifecycle development flag enabled, call `advance_mine_renewal_for_test()` on the archipelago. Each successful call advances one checkpoint. The registry holds a digest of the sorted changed occupancy columns and the target cycle and seed. On restart both prepared and publishing records reconstruct the committed cycle zero. The next explicit request regenerates the candidate and checks its digest and safety conditions again. The final atomic dungeon-save replacement commits cycle one. The live data swap runs on the main thread in that same call. A restart after the replacement takes the existing cycle-one startup path.

Publication requires all chunks containing either mine footprint, plus neighbours with affected mesh faces, to have streamed out. The caller receives `awaiting_unload` while they are resident. The ordinary streamer builds the next meshes and physical shapes on demand. No player navigation request may be pending. The mine stays sealed. Behind-seal screenshots use the normal section renderer invoked directly from the test. The next increment needs staged replacement of resident meshes and colliders, followed by verified reopening and traversal.

For the recovery fixture use a fresh isolated Godot user directory and run `tests/mine_renewal.gd` with user arguments `prepare`, `publish`, `commit`, then `reload` in separate processes sharing that directory. Adding `interrupt` to any of the first three writes a PID checkpoint after the assertions and waits for the harness to terminate that process. The reload run also checks physical and pickable floor heights. Use GL Compatibility for the two chamber captures.
