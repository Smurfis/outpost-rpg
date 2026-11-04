# Phase 5B-1 — host-controlled guardian pursuit, knockouts and revives

**Parent:** `feature/coop-host-encounters` (PR #25). This branch builds upon the chosen Android/voxel/nightfall integration chain, not `main`.

## Implemented and automated

- The ENet host simulates each party dungeon's guardian movement (up to 1.45 units/sec, 7-unit aggro) and melee damage (1.75-unit reach, 1.7-second attack cooldown). Guardian pursuit is **tethered to a 2.5-unit circle around each spawn point** so that the simple AI does not run through adjacent room walls. Advanced navigation/pathfinding remains future work.
- Host-controlled per-run/floor 0–100 participant health appears in encounter snapshots. Knocked-out characters cannot move or attack; LAN combat does not apply solo-world regen/respawn rules. Health is reset at entry and the prior solo-world health is restored on leaving a run.
- The host chooses the enemy's nearest living same-party target from received positions and computes HP updates; clients never choose NPC damage or guardian path. Other parties' players cannot be targeted.
- Live guardian positions, enemy HP and participant health replicate through existing host-authority RPC snapshots. The current implementation uses the same reliable channel at the 120ms LAN tick interval: confirm mobile data volume before expanding parties or enemies.
- Close-by teammates (within 2.75 units) can click **REVIVE NEARBY ALLY** from the CO-OP panel to restore a knocked-out player to 35 HP; the host checks membership, alive/downed states, run/floor and distance before accepting. No self-revives or repeat revive rewards.
- Existing final treasure claims, saved receipts and the solo AI/combat flow remain unchanged.
- New Godot 4.7.2 script `tests/coop_guardian_ai.gd` checks pursuit bounds, health authority, cooldown, knockouts and proximity revives. CI includes it alongside the real two-process ENet tests.

## Unfinished before full multiplayer

- Remote player **movement remains client-reported and is not a cheat-resistant host simulation**. A tampered peer can still spoof a plausible in-run position. Current NPC chase is intentionally room-local, not physics-based pathfinding around pillars.
- Knockouts/revives need additional Android HUD treatment, downed timer/protection rules, UX feedback, latency handling and disconnect/rejoin recovery.
- Player equipment has not yet been replicated to the host; player damage is still the fixed testing value from Phase 5A. Client-side inventories and reward receipt storage are not a full server economy.
- Other animations, PvP, online relay, torch visual synchronization, multi-device Android FPS, packet loss recovery and mobile memory remain to be tested.

## Deferred new character creator

`docs/CHARACTER_CREATOR_BACKLOG.md` records user-approved **Humans, Goblins, Gnomes and Orcs**; use the human model as the default. User instructed us to **implement later**, not in this co-op branch.

## Signoff

1. Verify Godot 4.7.2 CI checks are green, including `coop_guardian_ai.gd` and host/client multi-process reward tests.
2. With two Android devices on the same Wi-Fi: verify guardians visibly pursue near players, neither phone sees desynchronized location/HP, and host applies identical strike damage.
3. Knock out one player; check that movement/ATTACK locks and the other player can use CO-OP → REVIVE NEARBY ALLY from range. Test enemy attack spam, stair floor transitions and player leaving mid-combat.
4. Report packet/frame-time overhead on Android; do not merge into `main` until owner approves the complete integration stack.
