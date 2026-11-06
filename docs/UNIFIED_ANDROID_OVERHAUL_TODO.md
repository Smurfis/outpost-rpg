# Outpost — unified Android overhaul register
Updated: 6 November 2026. Integration source: current `main` plus selected, tested Alpha #55/#56 UI changes.

## Branch / release rule
- `main` is the stable **single APK** source, preserving stable Android signing, saved data, launcher, title screen and world loading.
- `alpha` is a separate experimental build and is **not** wholesale merged into main: it contains fork-specific updater/workflow changes and is behind current main title/exit work.
- Feature PRs #4–#31 are partly experimental/stacked and may overlap content that later shipped through #33. Do **not** bulk merge them. Cherry-pick missing functionality only after comparing actual main scripts, in new small PRs with Godot smoke tests.
- This integration applies only approved Alpha #55/#56 character portrait, ornate radial XP, compact bag/craft UI and regression assertions; keeps current main exit-door and title/loading improvements (#54).

## P0 — Android release and regressions
- [ ] Build the final **main** APK and verify GitHub Actions smoke check + export succeed on the **same merged commit**.
- [ ] Install over existing signed main APK; launch offline, Play, Continue with valid save, cancel loading, quit through exit door, re-enter without lost saves.
- [ ] Verify wide and narrow Android landscape safe areas (including gesture/navigation insets), no clipping or accidental tap pass-through.
- [ ] Capture in-device screenshots for title, HUD, inventory, crafting, dungeon entry and minimap, then fix mismatches.

## Home / loading / settings
- [x] Approved layered pixel art and title buttons; gold selected treatment; visual fixes to crest/splash; loading cancel; in-game save/return door in main (#48–#54).
- [ ] Recheck real-device glow/rays track the currently selected button, menu art stays luminous while the other buttons dim, and version plaque is aligned on ultra-wide Android.
- [ ] Themed settings, save/adventure selection and co-op dialogs should remain legible with long text and touch sliders; validate menu keyboard/controller focus.
- [ ] Confirm loader progress reflects actual chunk work and no early Play/Continue interaction causes a soft lock.

## HUD / XP / controls
- [x] Square touch icons, compact 3×2 menu, minimap/day widget, floating joystick options and Bag/Gear modal flow on main (#42, #45–#47, #51–#52).
- [x] Alpha portrait, HP/status card, actual level radial and separate bottom XP bar integrated here (#55/#56).
- [ ] Visually verify jewel is visible above its art, its purple ring changes with level progress, and portrait/HP remain readable without moving joystick/abilities.
- [ ] Test multi-touch joystick + three skill buttons + held tool + world drag camera on Android; resolve any lost orbit gesture.
- [ ] Reserve mana display only until there is a real mana game system; do not show fabricated values.

## Crafting / bags / equipment
- [x] Parchment panel workbench, forge, recipe progression and tiered carrying bags already on main (#36, #40, #43).
- [x] Alpha Select / Prepare / Work / Collect strip, resource readiness, bag category filters, selected item outlines and themed equip actions integrated here (#55).
- [ ] Review font sizes, scroll regions, oversized inventories and ingredient loading on a phone, plus crafting/cancellation and unique-item checks.
- [ ] Complete salvage/decompiling unwanted items into recipe materials as a fully tested economic loop; confirm item-level equipment persistence.
- [ ] Skill books and forging: red physical; yellow critical/attack speed; blue mana/healing; up to three gear slots, legendary any-colour gem socket. Keep core stats Damage, Attack Speed, Crit, Ability Power.
- [ ] Improve icons for each real recipe/resource and finish action affordances without enlarging the HUD.

## Terrain, art, world and minimap
- [x] Pixel voxel atlas, coastal beach, streamed terrain, world art/minimap and camera-drag performance fixes exist in main (#33, #39, #47, #51).
- [ ] Verify compass/terrain rotation tracks actual camera yaw, player remains centered, marker scale readable, dungeon floor data can be re-used without breaking gestures.
- [ ] Profile minimap update frequency and chunk mesh/collider streaming on budget Android; no blocking frame spikes or constant per-rotation resampling.
- [ ] Expand biome/island variety, cut repeated tree silhouettes and terrain bands, polish voxel stations/character and their walk/attack/jump animations.
- [ ] Placeable offhand torches on the ground, walls and trees within touch radius; test lighting budget, day/night readability and portal emissive glow.

## Dungeons / progression / loot
- [ ] Audit original #4/#5/#13–#17/#25 content against actual main before incorporating still-missing mechanics.
- [ ] Test five portal rarity colours/monuments, spawn/vanish, enter/cancel prompts, deterministic seeds and room connectivity; ensure no gaps or camera lock.
- [ ] Expand archetypes and layout patterns (linear, branching, circular, hub, labyrinth), floors and rarity rewards; verify end chest and one-time loot ownership.
- [ ] Confirm salvage, item level, quality/crafting tiers and floor rewards work together without exploits.

## Character, combat and co-op
- [ ] Cute compact voxel hero with coherent sword/tool grip, full directional walk/step/jump/attack and sensible touchscreen action animations.
- [ ] Basic character creation and optional Human / Orc / Goblin / Gnome races after movement/combat stability.
- [ ] Test damage/attack speed/crit/AP abilities, healing and mob AI; remove stale collisions, accidental knocks and invisible weapons.
- [ ] Audit old draft LAN party/guardian authority PRs #6/#19/#25/#26 before porting; regression-test 2 Android devices, party isolation, dungeon host authority, knockdowns, revive and need/greed loot.
- [ ] Online relay/NAT traversal and iOS packaging are later milestones, not included in this APK.

## Shipping criteria
- Every merge to main should preserve Godot 4.7.2 headless checks, stable signed APK generation and saved-game migration.
- A green CI build is not equivalent to Android visual/touch QA; do not mark an untested experience complete.
