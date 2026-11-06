# Outpost — mobile HUD wallet, consolidated menu & floating movement controls

**Feature:** `feature/mobile-hud-wallet-floating-joystick` — Godot 4.7.2, Android landscape. Based on latest `main`.

## What actually ships

- The character XP meter spans the lower edge with its level badge at the **left** of the bar. The top-left hero label now shows a locally configurable display name (default **Adventurer**) instead of "OUTPOST"; HP remains live. A blue **MP —** meter is reserved but explicitly shows no fictitious mana total because the game has no mana stat yet.
- Real `coins` and the last increased inventory resource appear in a small horizontal top wallet. The leftmost control collapses it; the **actual Bag button remains attached to the wallet** in both collapsed and expanded layouts. Real carrying load, specialty satchels and tiered bags continue inside Bag, unchanged.
- Existing three (exactly three) unlocked weapon-masteries still form an arc beside the smart-interact action. Actual cooldown and unlock logic is unchanged. The two owned consumable radials, offhand torch and hold-to-select tool selector remain operational.
- One upper-right **MENU** control has press-to-toggle and long-press-to-open behavior. Its popup offers real **Craft, Gear, Co-op, Skills, Journal and Settings** actions; releasing a long press does not close it. The skills summary reports the real equipped weapon and rank, not imagined powers.
- **Controls** include a persisted fixed/floating movement joystick switch, backed by `user://outpost_controls.cfg` (kept separate from gameplay saves and title-menu preferences), and an optional **local character display name** field. Floating mode captures touches in the lower-left playfield, plants the joystick under the finger, follows movement outside a 55 px radius, and resets/hides after release, menu opens or focus loss.
- Existing real item counts, skill slots, co-op, crafting and save data stay untouched. Existing game world is **not replaced with a mock-up**.

## Intentionally deferred

- Separate Gold / Copper / Silver / Gems wallet balances are **not** represented because those distinct currency accounts and purchasable balances do not yet exist in gameplay. Only real `coins` and a genuinely tracked resource are displayed. Do not introduce fake currencies or save migrations as a cosmetic change.
- Mana and offhand-granted abilities require a gameplay/skill design decision; the HUD does not award mana or imaginary skills. The existing three mastery slots remain valid until real slot assignment rules are developed.
- A circular minimap and elite targeting frames require actual world position/target data and are not implemented in this UI patch.
- Character name currently remains device-local, not multiplayer identity. Character creator is a separate future feature.

## QA acceptance

Run the full Godot workflow `.github/workflows/godot-smoke.yml`, including new `tests/mobile_hud_wallet_floating_joystick.gd` along with `approved_ui_visual_layout.gd`, `pixel_ui_integration.gd`, `island_smart_action_camera_knockback.gd`, `carry_bags_camera.gd` and `rpg_movement_enchant_abilities.gd`. Validate on a physical Android device: joystick placement/movement/finger IDs with two-finger combat, system gesture margins, camera hold/orbit, dropdown opens on hold and tap, actual Bag/Craft/Gear/Co-op navigation, settings input focus, and no content overlapping at 16:9, 19.5:9 or 20:9 landscape.

The reviewed image concept is *direction*, not a pixel-perfect claim. New title/menu art remains committed in source and the existing six-module UI system is reusable for future extensions.
