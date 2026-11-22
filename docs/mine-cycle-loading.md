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
