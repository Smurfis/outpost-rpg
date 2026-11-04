# Official-agent handoff — Outpost Android voxel test, future combat/loot systems
**Date:** 3 November 2026
**Repository:** https://github.com/Smurfis/outpost-rpg
**Proposed Android test PR:** https://github.com/Smurfis/outpost-rpg/pull/8
**Head branch:** `feature/voxel-art-direction`; **base:** `main`. PR is DRAFT; don't silently merge.
**Parallel title/UI PR:** https://github.com/Smurfis/outpost-rpg/pull/7, `feature/title-screen-overhaul`.

## Phase A: integrate voxel prototype for Android visual testing (current scope)
1. Fetch current `main` and PR #8; verify current base before merge. It was mergeable against `main` at handoff, but GitHub mergeability is not proof of Android quality.
2. Bring in just the voxel feature after reviewing the diff (or create a short-lived `integration/android-voxel-test` branch from the current main, merge voxel branch there first, inspect on device, then merge only with explicit owner approval). Do not merge PR #7 implicitly; it is a separate WIP.
3. Keep original gameplay and save formats: `scripts/game.gd`, `scripts/player.gd`, `scripts/station.gd`, `scripts/resource_node.gd` are adapted by PR #8; check conflicts with other agents carefully. Default `project.godot` startup in PR #8 remains gameplay scene.
4. Pixel-art rendering: `scripts/voxel/voxel_palette.gd` creates original **64 × 64** atlas of **16 × 16** colour-dithered tiles, shared `StandardMaterial3D` with `BaseMaterial3D.TEXTURE_FILTER_NEAREST`; voxel terrain/props/character/station meshes use atlas UVs. Preserve nearest-neighbour sampling, disable smoothing for atlas imports, do not put unwanted bilinear, mipmap or anisotropic blur on retro textures. Keep UI separately crisp rather than aggressively pixelating every Godot Control.
5. Existing old OBJ equipment and some models lack UVs/atlas support and will **not** pixelate just by changing project settings. Convert or selectively replace them in a later visual-art pass; do not assume this branch already has consistent pixel textures on all meshes.
6. Run Godot 4.7.2 CI (headless import, startup, `tests/smoke.gd`, `tests/voxel_art_smoke.gd`); inspect an actual Android landscape build/phone for colour/atlas UV seams, fps, overdraw, resource use, tap targets and camera.
7. Toggle `voxel_art_enabled` on `scripts/game.gd` to compare original vs voxel appearance. The prototype collision plane remains FLAT, with distant stepped cliffs outside bounds: visual terrain only, not editable or true Minecraft terrain. No physics/heightmap migration in Phase A.
8. If the UI agent has separate changes, integrate through independent PRs and resolve changed `game.gd` / `project.godot` hunks intentionally; then repeat CI/device QA. Do not overwrite UI agent's work.

**Phase A acceptance:** all old gameplay tests pass; no save loss; comparable or better Android FPS; visibly pixelated terrain/props/character/stations; no major bad seams; author approves visual direction; separate feature reviewed before merge.

## Phase B: visual combat feedback (NEW PROPOSAL — NOT IMPLEMENTED)
- On an enemy hit, brief **white flash** ~0.08–0.12 s followed by the underlying material fading toward a **reddish tint** as health approaches zero. Maintain pixel texture detail under tint; no hard-to-read white foggy silhouette.
- On death, spawn ~16–40 pooled square voxel/pixel fragments that burst outward and arc/fall with lerped/tweened velocity and fade within ~0.5–1.0 s. The enemy collision/HP transitions only once; avoid per-pixel Node3D spam on Android (MultiMeshInstance3D or pooled particles where possible). A reduced-effects option should reduce count.
- Show XP as a small cluster of gold/azure pixel orbs flying from the defeated enemy to the player with curved interpolation (ease-out); **award XP immediately through gameplay authority**, not when a cosmetic orb arrives. Cosmetic travel must not change ledger/accounting or duplicate awards.
- Introduce a simple effects API (e.g. `EnemyVisualFeedback.flash_hit(current_hp_ratio)`, `burst_death()`, `XpOrbFx.fly(from,to,value)`), and keep scripts independent from loot/XP business logic.

## Phase C: physical loot bags + Need/Greed (NEW PROPOSAL — NOT IMPLEMENTED)
- Replace automatic visually invisible drops with **one loot bag per defeated enemy** rather than one physics entity per item; the bag preview displays grouped material stacks, coins, and gear. Use deterministic bag IDs and clear pickup feedback. Decide ownership/persistence, expiry and save handling before changing reward logic.
- First implement **single-player** ground loot bag interaction: no party roll when there is only one player.
- With actual multiplayer, allow **Need / Greed / Pass** on eligible shared equipment, ideally uncommon+ or rare+; materials/coins can auto-share or use a defined party distribution rule. Recommended default: 20-second choice timer; Pass when no response; Need outranks Greed; highest server-generated 1–100 roll wins, tie rerolled; award once, log outcome, prevent duplicate claims/disconnect races. Server validates eligibility, inventory space and party membership.
- Do not fake server-authoritative Need/Greed while Outpost is still single-player; build data models/UI as a later online-ready feature, not a blocker for Phase A.

## Phase D: temporary XP-scroll buffs + gold-highlighted hero (NEW PROPOSAL — NOT IMPLEMENTED)
- Pickup/consume a rarity-labelled scroll and activate a visible gold glow/rim highlight on the player for the full buff window. HUD shows `XP ×N` and remaining duration. Keep costume colours and pixel texture legible; use an inexpensive gold rim/emission or restrained particles, not permanently tinting all armor yellow. Support reduced-effects.
- **Suggested tunable rarity ladder** (not locked, balance later):
  - Common: **2.0× XP, 10 min**
  - Uncommon: **2.25×, 20 min**
  - Rare: **2.5×, 30 min**
  - Epic: **3.0×, 45 min**
  - Legendary: **4.0×, 60 min**
- Name the category **XP Blessing Scrolls** (not all 'Double XP', because higher rarities grant >2×). Consider 2× base as the common scroll and stronger scrolls as separate rarities.
- **One active personal XP scroll at a time** for initial balancing. Re-consuming a scroll should require an explicit rule: recommended replace only if better or on confirmation; do not stack multipliers or multiply repeatedly.
- Centralize XP at `award_xp(base_amount: int, source: String) -> int` or shared XP service. Current XP awards in `scripts/game.gd` are **gather** `experience += 2 * amount`, **craft** `experience += 8`, **enemy kill** `experience += 12`. Apply the multiplier here so `base=12` with 2× grants 24 actual XP; animations display actual amount.
- Store active scroll's rarity, multiplier and expiry as data, not visual flags. In a future multiplayer build validate server-side and use server time/expiry; client must not extend buff by clock changes. For current offline prototype choose/document pause/resume policy, don't let application restart duplicate or silently extend.
- XP increment, loot awards and loot-roll settlement must remain **authoritative and idempotent**, separate from cosmetic animations.

## Suggested order / isolation
1. Merge/review voxel visuals for Android on their **own branch/PR**, after testing and owner authorization.
2. New independent `feature/combat-pixel-feedback` (hit flash, red damage, pixel burst, XP orbs).
3. New `feature/loot-bags` (ground items and grouping with single-player functionality).
4. New `feature/xp-blessing-scrolls` (buff durations, gold aura, centralized XP math).
5. Later `feature/party-loot-rolls` only after multiplayer/party authority exists; UI agent can prototype the interface earlier.

**Coordination:** UI-overhaul agent should own HUD layout, scroll badge/timer display, bag inventories and Need/Greed modals; gameplay agent should own damage state, server-/game-authoritative XP, loot ownership and settled rolls. Do not overwrite each other's interfaces; define signals/contracts before merging.

**Status:** Only voxel visuals/CI from Phase A are in PR #8. Phases B–D are ideas/specifications in this document; do not report them as implemented.
