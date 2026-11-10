# Outpost Alpha — Enemy Target Portrait (implementation handoff)

**Scope:** actual Godot 4.7.2 Alpha implementation; no Stable/main changes.

## What is in this branch

- `scripts/ui/enemy_target_portrait.gd` builds a reusable, compact, circular enemy portrait + name + real HP display. It mirrors the existing player's circular mask and HUD styling but has a distinct hostile frame.
- `assets/ui/icons/enemy_boar_portrait.svg`: original pixel-art boar face aligned with Outpost's player portrait.
- `assets/ui/icons/enemy_unknown_portrait.svg`: original pixel-art fallback for species without dedicated artwork.
- `scripts/hud.gd`: mounts `EnemyTargetHUD` as a touch-transparent independent HUD control and positions it top centre above the zone banner; exposes `update_enemy_target(enemy, display_name)`.
- `scripts/game.gd`: shows the **actual nearest living enemy** used by Interact/Attack when within combat range; clears when the enemy is no longer the current combat target or the game menu is open. No new targeting mechanic or fake encounter.
- `scripts/enemy.gd`: exposes existing boar HP cap as `max_hp`, initialized to 32 (unchanged gameplay value), and an opt-in `rarity_tier` field defaulting to `"normal"`. Respawn restores the same max HP.
- `tests/enemy_target_portrait_rarity.gd` + smoke CI: checks normal/rare/elite, silver/gold frame colours, live damage readout, unknown-health fallback, hide-on-death/loss, overlap avoidance and touch passthrough.

## Rarity contract

| `rarity_tier` or `enemy_rarity` | Frame | Label |
| --- | --- | --- |
| `normal` (default) | dark iron/neutral | none |
| `rare` | **silver** `#C7D6E5` | RARE |
| `elite` | **gold** `#EFBE68` | ELITE |

The component accepts `enemy_rarity` metadata, `rarity` metadata/script property, `rarity_tier` script property, or explicit `rare_enemies`/`elite_enemies` groups; the groups take priority. It does **not** infer rarity from item drops and does not create rare/elite spawns. A mob-specific `enemy_portrait` Texture2D property/metadata overrides the generic portrait.

Existing wild boars remain normal. To test silver/gold with live enemies in a future enemy-spawning feature, set `mob.rarity_tier = "rare"` or `mob.rarity_tier = "elite"` before combat. This changes the frame only; combat stats and loot are unaffected.

## Health contract

The widget reads the real `hp`, `health`, or `current_health` value, and `max_hp`, `max_health`, or `maximum_health` where available. Unknown HP is hidden rather than fabricated. The boar uses real `hp/max_hp`. The portrait disappears immediately if the enemy is marked dead, hidden, freed, or not in the actual near-enemy selection.

## Layout/interaction contract

- Place: top centre around **324 × 84 px at 1280 × 720**, height/position scaled by existing HUD conventions. No overlap with existing player portrait, left quest tracker, top-right minimap, right-side combat buttons or the centre zone alert.
- Transparent background, circular art mask, and a dark red HP fill with a thin themed frame; no large solid tooltip boxes.
- Root and all children use `MOUSE_FILTER_IGNORE`, so Android taps/drag gestures keep reaching normal gameplay controls.
- Reuse current player portrait mask shader; do not add new ad hoc input listeners.
- The enemy target HUD is presentation-only; authority for target choice, damage, loot and respawn remains in existing gameplay.

## Validation / next ownership

1. Check the PR's **Godot 4.7.2 smoke check**, including `Verify live enemy portrait, silver/gold tiers and real HP`.
2. Review an **actual Android landscape screenshot** after merging to Alpha. Test visual density on 16:9 and wider handsets.
3. Give any new enemy species its own portrait asset and its true max/current HP fields. For co-op dungeon guardians, confirm those fields match replicated/host-authoritative health before enabling a health bar. Do not invent an HP max.
4. If a larger target-selection system is later added, only switch the enemy supplied to `hud.update_enemy_target`; keep the view reusable.

No Roblox MMORPG UI asset was required for this implementation: the live player portrait and Outpost pixel art are the reference. It remains possible to import appropriately licensed/custom source assets later.
