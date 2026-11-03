# LAN Co-op and Party Dungeon Preview (stacked feature)

**Review branch:** `feature/lan-coop-party-instances`  
**Required base:** `feature/v4-dungeon-progression-economy` / draft PR #5  
**Status:** experimental, needs two real Android/desktop devices before merging.

## What works in this pass

- Offline solo mode remains the default. Multiplayer never starts automatically.
- One player hosts with ENet on **UDP port 30115**. A friend on the same LAN enters the host's IPv4 address in **MENU → CO-OP** and presses Join IP.
- Players provide a 1–20 character display name. The session creates cosmetic remotely visible low-poly avatars with nameplates.
- Up to **4 peers per party** (host and three clients). The host is authoritative for party membership, party IDs, leader election, run IDs, and run floor state. Players can create and join independent parties.
- A party leader can open a **walkable, seeded, multi-floor dungeon preview**. Each party gets a different run ID. Members in the same party build the same deterministic rooms locally; other parties remain independent.
- Closing the preview returns to the previous overworld location. Disconnecting reverts to solo.
- New `tests/coop_parties.gd` checks membership limits, isolation, request permissions, deterministic seeds, floor progression, host startup, local preview and return.

## Deliberately NOT implemented here

This branch **does not** ship a complete synchronized combat/loot system. Guardians inside the preview are frozen, no dungeon loot/rewards are given, and the regular solo dungeon system remains independent. Only cosmetic peer position updates are exchanged; the host does **not** yet validate or simulate combat hits, resource gathering or item transactions for clients. No PvP, revive, inventory trading, character creator or persistence of online sessions.

Noray NAT traversal/relay is **not integrated** in this pass. It can be added as a separate transport after LAN connection and 2-device tests are proven. Do not assume `tomfol.io:8890` or any other relay is a production dependency.

## How to test

1. Build from this branch (not main) with Godot 4.7.2 and landscape Android compatibility renderer. On Android export enable the **INTERNET permission**; local Wi-Fi access/firewalls may also affect UDP connections.
2. Open on host and friend device with the same build. Start Outpost, tap **MENU → CO-OP**, enter a player name, tap **HOST LAN**.
3. Find the host's LAN IPv4 address in Android Wi-Fi connection details or OS network settings. On friend device, enter that IP and tap **JOIN IP**. Ensure both are on same Wi-Fi, with local device-to-device traffic allowed.
4. Confirm both players appear and names are visible. Move and verify the other player's low-poly avatar moves. Try Create Party, Join Party number, and ensure avatars are only shown to relevant parties.
5. As the party leader, choose a rarity and tap **ENTER PRIVATE DUNGEON PREVIEW**. Confirm all members enter walkable matching floor layouts. Use the CO-OP menu to advance/leave. Check that members of other parties do not enter the same preview.
6. Disconnect and confirm the original solo game is still playable; test the original solo dungeon and crafting menus unchanged.

## Architecture

- `scripts/network/party_registry.gd`: pure host-owned party/run service; no scene ownership.
- `scripts/network/coop_session.gd`: ENet LAN host/join, RPC admission, cosmetic position updates, local dungeon preview creation and cleanup.
- `scripts/network/coop_ui.gd`: optional touch-friendly co-op lobby.
- `tests/coop_parties.gd`: structural and in-process LAN startup tests.

## Safety and integration gates

**Do not merge into main before PR #5**, since this branch directly depends on that code. Keep this as a stacked PR with base `feature/v4-dungeon-progression-economy`. After PR #5 is merged into main, retarget/rebase this PR against main and rerun all CI checks.

Before calling this feature production-ready: test at least 2 real devices on LAN; add host authority for enemy movement, damage, resource transactions, independent loot and dungeon completion; protect RPCs against malformed/fast input, and test reconnects. The host currently validates run membership, but position sync is cosmetic, not cheat-resistant.

Godot documentation: https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html
