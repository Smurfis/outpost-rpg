# Flat translucent UI rollout (Alpha)

## Goal
Replace remaining legacy nine-sliced, sometimes holey pixel backings with Godot StyleBoxFlat surfaces that preserve the established wood/parchment/bronze visual language, touch areas and text contrast. Do not flatten artwork used for portraits, objects, buttons/icons or title scenery.

## Shared API

`SKIN.translucent_surface(light=false, selected=false, compact=false)` is a geometry-only background with an opaque-enough alpha to maintain text contrast. Dark (cream/gold text) and light parchment (INK text) variants are explicit. `SKIN.apply_translucent_button(button, kind)` preserves Button sizes, focus behavior and signals but swaps all background state textures for flat backgrounds. Selected states have a stronger border, and disabled states are dimmed.

## Scope

- Gameplay HUD: default utility panels, expanded Quest journal, toast, right-side tool and consumable selection trays, rectangular action states and selected tool rows, top-right/menu navigation buttons.
- Crafting station: light ingredient/recipe surface, item cards, selected borders, stage and details sections, navigation buttons.
- Albion inventory: light equipment and bag areas, empty tile frames and interactive category/equipment/item backgrounds.
- Co-op LAN: main lobby is a dark translucent frame with a less intrusive dimmer; navigation buttons share styles.
- Title: old nine-slice focus/normal input fields replaced; current main Menu, Changelog, Loading, Skills, Leave Outpost flat frames are left intact.

## Non-goals

No change to crafting, inventory, input routing, coin math, data model, saves, enemy logic, map, icon sprites or Play Store publication. Continue verifying text legibility and actual 16:9/20:9 Android screenshots; this is not a claim of final illustration parity. Existing Android smoke tests remain and `tests/ui_translucent_panels_v2.gd` explicitly checks the real panel style classes and interactive paths.
