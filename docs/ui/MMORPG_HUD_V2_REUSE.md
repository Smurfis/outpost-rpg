# Outpost mobile MMORPG UI framework — V2 implementation notes

**Source project:** `Smurfis/outpost-rpg` (Godot 4.7.2, Android). The separate *Roblox* React/Luau slime experiment, `Smurfis/MMORPG_Framework`, supplies presentation inspiration only. Outpost does not require Roblox React, Roblox runtime assets or Roblox service APIs.

## Reusable patterns and exact existing source references

- Roblox `ReplicatedStorage/UI/Components/FramedImageButton.lua` → Outpost `scripts/ui/hud_v2_components.gd`: framed item icons with a **single** interactive hit surface, border showing an actual rarity field, plus a bottom-right numerical quantity medallion.
- Roblox `ReplicatedStorage/UI/Components/HUD/CurrencyPill.lua` and `MapZoneBar.lua` → Outpost Wallet flyout, actual currency fields and the new minimap zone pill. Do not invent amounts.
- Roblox `ReplicatedStorage/UI/Components/Interaction/MouseOverTooltip.lua` → touch-first tooltip anchored *inside the viewport*, independent of an item's icon/surface.
- Roblox `ReplicatedStorage/UI/Components/HUD/ExperienceBar.lua` → preserve full-width segmented character XP strip at bottom Y.
- The experience has actual slimes and is the Roblox MMORPG experiment, **not** the Spark ocean project or a web React project.

## Godot item model

`scripts/ui/outpost_item_view.gd` owns display name, known rarity text/colour and description lookup from real crafting recipe entries. It is a presentation-only view; it does not assign actual loot rarity. Unassigned item rarity is `-1` and rendered neutrally, distinct from Common (0). Do not infer item rarity from portal tier, monster tier or equipped bag stars.

`HUD_V2.loot_icon_border(quality)` is a reusable stylebox. `HUD_V2.loot_quantity_badge()` is a separate small circular badge; labels and icons are subordinate to the single framed icon touch target.

`HUD.record_loot(id,quantity,rarity=-1)` records real accepted item grants. `HUD.record_combat_event(message)` records succinct verified combat events. Current feed shows three entries beneath Last Gathered; status effects remain independently driven by game state, and floating damage text remains world-space.

**Tooltip:** tapping an item icon shows rarity-tinted item name, rarity label (including "Rarity not assigned" if metadata is absent), and recipe description or explicit absence notice. Tapping again closes it. Do not grab the joystick/camera/ability touch surface.

## Input priorities

1. Leave Outpost confirmation modal.
2. Game Menu modal.
3. Top-right single-touch Menu/Wallet/Bag (first finger-down, no hold, no duplicate synthetic mouse activation).
4. Loot item tooltip icon clicks.
5. Smart action / combat wheel, station selection, free-world camera drag, movement joystick.

All decorative child nodes use `MOUSE_FILTER_IGNORE`. Only one event handler activates an action; never attach a second `pressed` listener that duplicates input routing. Android's mouse echo must be swallowed **before** the newly opened Menu modal receives it, or it may interpret the echo as a click outside and close on the first tap.

## Future work

- Shared framed icons and item tooltips in Albion-style inventory, bank, skills, character equipment.
- Authoritative per-item rarity from generated gear and chest rolls, with truly assigned metadata.
- Persisted combat/loot history and filtering if desired; the current HUD feed intentionally stays compact.
- Integrate new art atlas, nine-slice sprites and final font decisions only after Android screenshot review.

Tested regressions live in `tests/hud_loot_feed_tooltip_v2.gd`, `tests/hud_topbar_camera_zone_v2.gd`, and `tests/android_hud_reflow.gd`. Stable/main changes are out of scope.
