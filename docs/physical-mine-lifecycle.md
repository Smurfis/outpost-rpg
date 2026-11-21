# Physical Goblin Mineshaft lifecycle

The dungeon save keeps one world-site record per physical mine. Its stable ID, world seed, entrance, owned chunks, layout seed, cycle, encounter IDs and reward receipts survive streaming. The nested world-site schema is now 2. On reading schema 1, the loader identifies the existing physical mine by its original ID prefix and preserves the values from disk. Portal sites keep their original lifecycle. Loading validates the records before replacing the live registry. The outer dungeon save is still version 4.

| Current state | Event | Result |
|---|---|---|
| Undiscovered / discovered | Approach, then enter the mine | Discovered / active |
| Active | Defeat both the miner and foreman, in either order | Cleared |
| Cleared | Empty the strongbox, ore deposits and supply crates, leave, then explicitly seal | Sealed |
| Sealed | Explicitly mark the unoccupied site eligible | Ready for renewal |

Sealed and renewal-ready sites retain the same layout, cycle, inventory and defeat receipts. The player save holds delivered items and remaining contents. The seal checks the player’s ledger for every branch, including unloaded chunks. A fully emptied strongbox reconciles a missing site receipt on load, and an existing site receipt prevents a second payout.

The development trigger is `mine.advance_for_test("sealed")` or `mine.advance_for_test("ready_for_renewal")` with `OUTPOST_TEST_MINE_LIFECYCLE=1`. It checks the live solo player, the actual connected mine footprint plus a capsule margin, and pending movement. The transition must save successfully before the world places barriers. Streaming reproduces each barrier from the persisted state and the cave's exterior openings. The timber geometry and static collision occupy the same cells. The original cave voxels remain available for future cycles.

## Milestone 6B handoff

- The read-only `renewal_proposal` returns the site ID, expected old cycle, next cycle, deterministic next layout seed, event ID, generator version, entrance and chunk keys. A ready site remains sealed until a future successful publication. 6A supports building cycle zero only.
- Treat chunk keys as an outer bound. Derive a candidate voxel write set from the old and proposed connected footprints. Include all affected boundary faces, collision and navigation data. Reject cross-site edits. Persist a voxel revision and the proposed bounds before publishing.
- A future authoritative host must lock the site and compare its current cycle and voxel revision with the proposal. Recheck player capsules, return locations, other occupants, active encounters, routes, open loot UI, unresolved rewards, graves and critical pickups immediately before replacement. Unloaded chunks provide no evidence of vacancy.
- Read persisted player modifications and protected builds for **every** affected chunk, including unloaded ones. Reject or trim changes that overlap protected voxels or their required support. Missing protection or occupancy data blocks regeneration.
- Publish new geometry, navigation, encounter slots and reward IDs as one recoverable generation. New loot and encounter IDs must include the new cycle. Preserve past receipts and historical claims. Cycle-zero player-side strongbox, ore and crate IDs must keep their existing names when loading old saves.
- A retry must reconcile the same generation and receipts without paying a reward twice. A failed publication must leave the old generation intact and safely closed. Broadcast the committed revision only after durable publication. Networking, cooldown scheduling and terrain replacement belong to 6B.

## Verified checkpoint

Seed 64013 completed active → cleared → sealed → ready for renewal on Windows with Godot 4.7.2. The process exited after sealing and again after marking the site ready. Both graphical reloads retained the cycle-zero layout, both guard defeats, inventory and strongbox receipt. The six branch deposits/crates were emptied before sealing. The capsule and screen picker hit the timber face at (187.0, 3.6, 64.5), including after chunk unloading and reloading. The same fixture rejected movement through the gate. [Sealed entrance capture](../artifacts/cave_render/mine-lifecycle/sealed.png)

All 16 archived 5B physical-site records from the isolated stability runs imported through Godot. Removing the newly assigned site kind from each exported record reproduced its original progression dictionary. Device testing on Android and multiplayer lifecycle authority remain outstanding.

## Runtime verification

To exercise full process restarts, run the lifecycle fixture three times with the same isolated user-data directory. Pass `-- --seal-and-quit` to the first invocation, `-- --load-sealed` to the second, and `-- --load-ready` to the third. The latter two compare the reconstructed topology, inventory and site record to the first process’s checkpoint. In graphical mode the fixture saves the entrance view under `user://` after checking the player capsule and screen pick against the timber.

Run `tests/world_site_registry.gd` for migration, transition ordering, receipt retention and the proposal contract. Run `tests/mine_lifecycle.gd` with isolated user data for actual combat, active/cleared/sealed/renewal-ready reloads, chunk streaming, blocked floor paths and visible timber collision. Existing `physical_mineshaft.gd`, `mine_stability.gd`, `fractal_isometric_cave_picking.gd`, `fractal_camera_cutaway.gd` and `world_site_streaming.gd` cover the playable mine and legacy portals. Run one engine instance at a time.
