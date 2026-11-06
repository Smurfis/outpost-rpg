# Outpost workshop, bag and gear UI polish (follow-up to PR #42)

This feature leaves all crafting economics, equipment/quality rules, skill costs, item IDs and save formats unchanged. It improves the visual hierarchy and legibility of the already-compact 768×526 workshop flow on Android.

## Implementation

- Updated `scripts/ui/outpost_skin.gd` so `SKIN.apply_button(button, "wood_selected")` actually uses the dedicated transparent gold-edged frame PNG rather than silently rendering the ordinary wood button. Selected crafting-station and menu-navigation tabs now look selected.
- `scripts/menu.gd`: header BAG / GEAR / CRAFT tabs visibly reflect the active page; the 4-stage subtitle shows current workshop step and real station context without a long tutorial sentence.
- Recipe card names, ingredient text and readiness badges use dark readable ink over light parchment instead of pale cream on cream. The selected recipe receives its own separate gold frame; the original tappable Button remains intact.
- New tiny true-transparent original resource-state SVGs: `assets/ui/icons/ingredient_ready.svg` and `ingredient_missing.svg`. The already-existing item illustrations remain unchanged.
- Bag carry progress and active manual-crafting progress use actually filled green bars rather than transparent decorative framing.
- All asset imports committed, no downloadable ZIP required.

## QA

Run `tests/pixel_ui_integration.gd` and `tests/approved_ui_visual_layout.gd` and the full `.github/workflows/godot-smoke.yml`. Checks cover selected tab textures, status icons, real crafting receipt, bag meter, readable cards, staged navigation and manual work progress.

The smart-action/gear/consumable long-press sliders and HUD from PR #42 remain intact. Android phone appearance is still subject to screenshot and finger-gesture testing after the APK is built; CI only validates structure, imported assets and gameplay integration.
