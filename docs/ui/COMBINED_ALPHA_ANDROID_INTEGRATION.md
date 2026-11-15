# Outpost Alpha combined Android integration — HUD, inventory, pixel water, PyroLux

## Baseline
Merge commit `a74ff93824525ae4de696d63cdfa79506a55abfe` contains PyroLux Lite (via official source, bundled by Android export) and the pixel-coastal-water shader from PRs #93–95, including Android-friendly fallbacks. All these features are preserved by the integration tree.

## This integration
- Both loading screen and gameplay restore Godot's expanded content scale so ultrawide Android devices fill their viewport.
- Zone pill sits closer to the top of the minimap; Interact lowered to the XP bar but remains above the hitbox, and Food/Potion/Torch tightened as distinct touch controls. Tool swipe tray follows the moved action.
- Remove only the generic CRAFT menu entry; the real crafting-station interface stays. MENU's SETTINGS item remains functional.
- Character has a real 35/35 mana pool: active combat skills spend 6/9/12 MP (by slot); 2.5 MP/s regeneration, persisted in player save, an actual blue bar under HP and informative insufficient-MP message. Basic attack, gathering, and other abilities are unchanged.
- Inventory tabs **CHARACTER** (weapons, tools, armour, jewellery, consumables) and **RESOURCES** (craft/gather resources) with independent scrollbars for avatar/equipment and item grid.
- Chest layout is an **honest read-only preview** alongside the player's full bag: no avatar, no fake transfers, no persistence until a separate authoritative chest/storage service exists. An ALL filter is available only in the storage layout.
- One-touch Android inventory close X routed before native GUI consumes the touch event, including in storage view.
- Existing XP at bottom, PyroLux, pixel-water, transparent HUD and crafting station behaviour retained.

## Follow-up outside this PR
User requested portrait polish **after** a first combined APK: gold name, more transparent frame/Quest card, tightened bars. Treat that as its own reviewable visual branch so regression/binary testing is attributable.
