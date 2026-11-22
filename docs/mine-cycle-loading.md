# Mine cycle loading

## Repeatable physical mine

Cycle zero retains its original object IDs. Later cycles use the site ID, cycle number and slot ID in each loot object ID. Defeated guard slots are archived by cycle at publication, while strongbox receipts remain in the existing reward ledger. The first renewed cycle completes the Goblin Reoccupation investigation when its strongbox is claimed. That strongbox provides the cycle-one completion reward. There is no separate quest-only payout. Later cycles retain the completed event and award their own strongbox contents.

After defeating both guards and collecting all strongbox, ore and crate contents, leave the mine and use `.mine report`, `.mine ready` and `.mine renew`. Each renewal request advances one journal checkpoint. These explicit player commands do not require a development flag. The mine stays sealed during publication and reopens on the fourth renewal request. The site record limits generation numbers to one million, and each generation uses the existing stable cycle seed.

The loader migrates existing 8B.2 cycle-one open saves to an active cycle with fresh encounters while retaining cycle-zero defeats and rewards. Existing committed but unopened cycle-one saves continue to open through the renewal command. Chunks and player constructions remain subject to the existing publication and startup protection checks.

The dungeon manager loads and validates its existing site registry before the game constructs the world. The archipelago now creates its base terrain and defers mine generation. The game then loads the player save and restores constructions. Only after both sources are available does the archipelago select the matching physical site's generation seed and carve the mine. Streaming remains stopped while this is pending or if reconstruction fails.

Previously the mine was carved with cycle zero during world construction. The player save was loaded afterwards, and the dungeon record was only consulted when a mine chunk populated. That order could combine cycle-one progression with cycle-zero terrain.

Cycle zero retains its original seed and geometry. Each record must identify the same world and site and use the deterministic seed for its cycle. Mismatched IDs, non-integral values, unsupported cycle numbers and inconsistent seeds or event states are rejected. Schema-one portal and mine records migrate through the existing registry loader.

For renewed cycles, the player save must contain a complete valid construction list. The loader reconstructs the original and proposed layouts separately, rejects changes overlapping saved blocks or other registered sites' chunks, then constructs the selected layout. On failure it stops remote island streaming and emits an error while retaining the saves.

## Verification

Seed 64012 cycle-one startup was run in independent Godot processes using isolated saves. Both produced occupancy signature `1837af8d15b1678eea5d74b266a72bb818e821bf26d343f05545e0593bb6c666` and seed 1477028102. The layout differed from cycle zero, and the fixture raycast the floor collision in multiple generated chambers. A GL Compatibility run captured the sealed entrance. The cycle-zero receipt, defeated guards and ready event remained intact.

Six malformed dungeon records were loaded in separate processes and rejected without changing their saved bytes. A saved player block on a changed column also prevented reconstruction. The registry imported 16 archived 5B mine records. The existing lifecycle, save, picking, camera, streaming and natural-cave fixtures cover cycle-zero compatibility.

## Resident publication and recovery

Clear the guards, empty the strongbox and all supplies, and walk outside. In chat use `.mine report` to seal the site, then `.mine ready`. Each `.mine renew` requests the next checkpoint. The chat response reports the checkpoint or the reason for refusal. The fourth successful request opens the mine.

| Checkpoint returned by the request | Authoritative terrain on restart | Entrance |
|---|---|---|
| prepared | The previous cycle. The journal identifies the candidate by seed and occupancy-change digest. | Sealed |
| publishing | The previous cycle. A retry regenerates the candidate and checks the digest and safety gates again. | Sealed |
| committed | The new cycle. A restart reconstructs the candidate using the saved cycle and seed. | Sealed |
| open | The new cycle, with a persisted reopening receipt. Repeating the command returns open. | Open |

`mine_renewal.advance` owns publication. It compares solid-column masks in the union of the two connected footprints. The affected chunks include adjacent faces at the seams. The build ledger covers unloaded chunks. Changed supports, other sites, graves, actors, current navigation, selected interactions and modal UI can prevent a swap.

The streamer uses `_build_chunk_geometry` for normal loads and staging. Candidate visual nodes, shadows and their trimesh collision shapes remain outside the scene tree until validated. The durable cycle commit is the dungeon manager's successful temporary-file replacement. Failure discards the staged nodes. After success, the same main-thread call removes old owners from the tree, swaps cave topology, installs the staged members and reconstructs the sealed props. Streaming and camera updates cannot interleave with this synchronous exchange. A queued chunk key builds against the new topology when serviced. This can cost a frame on a slow device.

Path planning reads the current cave floor map and access footprint. Publication requires idle movement. Section geometry invalidation releases visibility masks, mesh variants, source face pages and pick bodies. The ordinary player-camera update then selects rooms using the new topology. The final reopen request checks the committed seed, connectivity, occupancy and resident collision shapes, persists reopening, and detaches the blocking visual and physics bodies together. Historical defeats and reward IDs remain in the site record.

The nested registry remains schema 2. Earlier cycle-one saves without a reopening receipt load sealed and can use the same reopen request. Portal migration is unchanged. With no committed file or backup, an orphaned temporary dungeon save blocks reconstruction.

Run `tests/mine_renewal_recovery.ps1 -Godot <path-to-Godot-GUI-executable>` on Windows to verify abrupt termination and recovery. It uses a fresh temporary user directory and one process at a time. For the resident walkthrough, run `tests/mine_renewal.gd` in fresh isolated data with arguments `prepare`, `publish`, `live`, then `walk` in sequence. Use GL Compatibility to capture the entrance and chamber. World seed 64012 and the cycle-one occupancy signature above are the regression fixture.

### Desktop verification

On Windows with Godot 4.7.2, seed 64012 completed resident publication, reopen, movement from the entrance to a changed branch, a floor click, camera rotation and manual backtracking to the surface in one running game. The same walkthrough passed after restart. The Windows recovery fixture killed a separate process at prepared, publishing, failed staged save, committed and reopened checkpoints. A final restart retained the cycle-one signature, inventory, defeats and historical receipts.

The registry imported 16 archived 5B records. The mine lifecycle, stability, physical mine, portal streaming, cave picking, natural network generation and walkthrough, building, save, startup and gameplay fixtures passed. The GL walkthrough captured a cold camera cutaway update of 31 ms. Testing used a desktop integrated GPU. Android runtime verification remains outstanding.

[Entrance](../artifacts/cave_render/renewal/live/open-entrance.png) · [Changed chamber](../artifacts/cave_render/renewal/live/open-chamber.png) · [Rotated chamber](../artifacts/cave_render/renewal/live/open-rotated.png)
