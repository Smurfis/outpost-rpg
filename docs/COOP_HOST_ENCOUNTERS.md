# Phase 5A — host-owned LAN dungeon encounters

Branch: `feature/coop-host-encounters` stacked on `integration/greedy-nightfall-android-review` (PR #24). **Do not merge into main without review.**

## Shipped in this branch

- Every generated guardian gets a deterministic `encounter_slot`; each private run/floor has one authoritative guardian HP ledger on the ENet host. Separate parties receive distinct ledgers, including when the host is not in the party's dungeon.
- Clients request attacks by run ID, floor and target slot; **only the host** resolves hits. The host checks connected membership, current run/floor, range against the most recently reported player position, cooldown (550 ms) and guardian life. Weapon damage is a temporary fixed 8 HP for fairness until equipment is securely replicated.
- Guardian HP and deaths replicate via the host; exit/chest remains locked until the host ledger confirms all guardians died. Tapping the dungeon exit or using the leader's LAN menu advances floors or claims final treasure. Only the party leader may progress. Leaving a run without claiming pays nothing.
- The host computes a seeded final chest reward through the existing `dungeon_loot.gd`; each current participant receives one copy, with an immutable per-run receipt persisted in the v5 JSON save to reject replay. One reward per participant, **not** one per hit or client-local kill.
- Original solo dungeon combat and saved inventory remain intact. Unknown saved inventory keys (such as new skill books and gem fragments) are retained on load.
- New `coop_host_encounters.gd` tests run/floor/range/cooldown/replay protection and a live host-only dungeon clear with rewards, added to the Godot 4.7.2 CI.

## Honest limits (not final co-op combat)

- Guardians intentionally remain *stationary* and do not attack players in LAN mode. Next follow-up: authoritative AI movement/target selection, player damage, knockouts/revives, synchronized abilities and animation feedback.
- Client-reported positions are still approximate and not host-simulated movement. Range checking is an early guard, **not complete anti-cheat**. Client inventories are local saves: the host decides the reward payload, but inventories are not yet persistent authoritative server records.
- Single-party LAN and separate-party tests need **physical multi-device Android** validation on one Wi-Fi. A relay/Noray, remote torch lighting and shared PvP are not included. Full final economy should define pooled vs per-character loot and Need/Greed before tradable items.
- The receipt key incorporates host session ID plus run ID; it prevents duplicate reward messages and survived restarts, but this prototype does not guarantee exactly-once payout on a disconnected client during run closure. A later server acknowledgement/recovery system is needed.
- No alteration to the day/night or greedy renderer choices from PR #24.

## Review/test

1. Check GitHub Actions full Godot 4.7.2 workflow.
2. On two Android devices connected to the same LAN, Host LAN and Join IP; enter the same private dungeon. Both should see guardian HP fall and corpses disappear on hits. Spamming ATTACK should not bypass the host cooldown.
3. Defeat every guardian, tap stairs to progress; leave early and verify no completion payout. On final floor claim treasure, check that both players receive coins, XP and materials once.
4. Force-close and reload after reward; ensure the item balances survive the `user://outpost_progress_v02.json` v5 save. Run the host and client in separate parties if available.
5. Profile Android CPU/GPU and server jitter. Do not label gameplay fully synchronized until the remaining AI/damage features ship.
