# Next UI pipeline: shared item tiles, quantity bubbles, and rarity borders

Alpha-only follow-up to the transparent UI overhaul and the user's Roblox React/Luau MMORPG UI component pattern.

- `scripts/ui/mmorpg_item_tile.gd` supplies a reusable translucent item-button style. Rarity is passed explicitly; item data currently supplies quantities only, **not** per-item rarity.
- `icon_frame(-1)` exposes the same neutral quality border used by loot receipts; never infer a rarity from bag upgrade stars, portal tiers, recipe selection or other unrelated data.
- `add_quantity_badge(button, quantity)` positions one dark circular counter over the icon at bottom-right. Decorative children ignore mouse and touch, leaving the parent item button as the only hit surface.
- Albion-style inventory tiles now use the same border and counter and retain their existing press-to-inspect callbacks.
- Crafting recipe icons receive a neutral rarity panel without altering the original wide recipe button, title-label position, crafting validation, ingredient counts or tooltip.
- The older bag-slot presentation shares the same reusable borders and quantity badges for consistency, though the dedicated Albion inventory remains the default bag page.
- Unknown rarity remains unassigned; gold selection outlines are **selection affordances**, never item quality. A future authoritative gear metadata system can provide real rarity.
- New regression: `tests/mmorpg_item_tile_v2.gd`, added to Godot smoke workflow. Existing game inventories, crafting and HUD tests remain mandatory.
- No main/Stable changes, API/gameplay/save changes or Play Console releases. Screenshot review on a real landscape Android device is required for final pixel-level tuning.

Visual concept/reference art may inform later dedicated icon exports. It is **not** assumed to be installed as game textures; only committed assets appear in Alpha APKs.
