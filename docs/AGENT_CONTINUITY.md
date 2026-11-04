# Outpost — agent continuity and integration map (4 November 2026)

This document exists so a new main agent can resume without silently resetting reviewed branches.

## Safe merge base and active PR

- `main` (commit `caa86aef`) is the last stable v0.5 base and is deliberately **unchanged**.
- PR #24, `integration/greedy-nightfall-android-review`, combines the *selected* branch paths:
  - Dungeon portals/biomes/room archetypes (#13–#17), finite 192×192 chunk streaming (#18), LAN preview (#19).
  - Atlas-correct greedy top **and cliff** meshing from PR #21, **not** the alternative top-only PR #20.
  - Nightfall/torch from PR #23, **not** the competing clock PR #22.
  - Pixel crafting HUD/title from the earlier integration chain (#7–#12).
- **Current next PR:** #25, `feature/coop-host-encounters` -> PR #24 branch. Phase 5A moves to host-owned guardian HP, validated strikes, cleared exits and one-off seeded rewards. Read `docs/COOP_HOST_ENCOUNTERS.md`.
- PR #24 was green under the Godot 4.7.2 CI on 4 November. PR #25 must pass CI independently after each change; Android device testing is still pending.
- Preserve separate draft PRs and the existing solo gameplay/save data; do not fast-forward or auto-merge `main` merely because CI is green.
- **New stacked branch:** `feature/coop-guardian-ai-phase5b` follows #25 with server-simulated guardian chase/attacks, synchronized knockouts, and range-validated teammate revives. See `docs/COOP_GUARDIAN_AI.md`. Keep it separate from the earlier review branches until phone tests.
- **Deferred character creation:** Human (existing model), Goblin, Gnome, Orc; documented at `docs/CHARACTER_CREATOR_BACKLOG.md`. Do not interrupt Phase 5B work to implement the creator yet.

## User-approved priorities

Proceed in this order: **(2) distinctive dungeons -> (4) chunk streaming -> (5) synchronized co-op combat/rewards -> (1) final illustrated UI**. Dungeon archetypes and initial chunk streaming are already implemented on the branch chain. The user also approved day/night, craftable offhand torch, first-night encouragement, voxel pixel art, and greedy meshing ahead of more biomes.

## Still outstanding

1. **Phase 5B**: synchronize authoritative guardian movement/AI, health/damage dealt to players, targeting, revival, and remote animation/torch FX; securely replicate equipment damage rather than accepting client values. Add actual multi-process and Android tests. Keep each subfeature independently reviewable.
2. **Phase 5C**: acknowledgement + resend of host rewards to disconnected/rejoining players, host-owned player inventory/economy, loot bags and optional Need/Greed/Pass when true shared loot is ready.
3. **World**: move from finite synchronous Fields streamer to budgeted/infinite chunks with biome-aware deterministic surfaces, caves/elevations and long-range visual LOD. Preserve atlas repeats, greedy mesh+collider correctness and performance on Android.
4. **Visual combat**: pixel flash/damage tint, low-cost death fragments, XP orb feedback, without driving XP accounting from animations.
5. **XP Blessing Scrolls**: timed personal 2×–4× buffs with a subtle gold glow, centralized XP arithmetic, durable expiries and rarity.
6. **Final UI pass**: refine illustrated/pixel-fantasy item cards and Android touch layout after combat and streaming systems stabilize. Do not overwrite the existing PR #9 UI files or title artwork casually.
7. **Testing before shipping**: 2-phone LAN, actual Android renderer and memory/FPS, touch target sizes, saved progression migration, disconnects and recovery.

## Integration policy

Inspect `scripts/game.gd`, `scripts/network/coop_session.gd`, `scripts/voxel/voxel_biome.gd`, `scripts/dungeons/dungeon_instance.gd`, `scripts/hud.gd`, `data/recipes.json` and `.github/workflows/godot-smoke.yml` before reconciling parallel PRs. Keep `main` alone until explicit sign-off after visual/mobile checks. Prefer a new short-lived stacked review branch for each actual implementation, with GitHub CI and an accurate draft PR that distinguishes completed from planned work.
