# Alpha v1035 portrait/Quest polish — separate visual change

The baseline Alpha APK contains PyroLux Lite, animated coastal pixel water, the corrected full-width layout, true 35-point skill MP, real workstation crafting and Character/Resources scrollable inventory.

This *next* portrait pass affects only `scripts/hud.gd` styles and pixel placements:
- Player display name uses `SKIN.GOLD` from the inventory design system, dark outlined for grass/sand contrast.
- Status panel is a subtle black-alpha surface (18% opacity, very faint gold border) instead of a large opaque panel.
- Player portrait art gets a 9%-opacity background so its gold perimeter stays visible without an opaque square.
- Character bars (actual HP, actual MP) start 5px beyond portrait edge, share a left edge and match compact widths. Real values remain unchanged.
- Quest background becomes 20%-opacity, with gold Quests toggle and gold outlined objective text matching the character and inventory typographic treatment.
- Character rank remains beside portrait, bottom-width XP, status effects, mobile buttons, quest tap expansion and all gameplay logic remain unchanged.

Verification: `tests/hud_portrait_gold_quest_glass.gd` asserts styling, HP/MP geometry, quest toggle behavior, preserved inventory/MP and bottom XP. The full Godot smoke suite runs on PR.
