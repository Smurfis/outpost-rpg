# Outpost — compact in-game HUD and phone-safe panel refinement

Scope: `feature/hud-quest-compact-polish` on Godot 4.7.2. This is a real Godot UI change based on the November 2026 Android screenshot. It is not a regenerated flattened screenshot.

## What changed

- `scripts/hud.gd`: Removed the large hard-coded cartoon `HeroPortrait`. A small original `outpost_sigil.svg` replaces it, while actual HP, character level, equipped weapon and weapon mastery stay live. The avatar itself is still shown using the 3D model in the Equipment screen. The status frame now consumes roughly 23% of width and 11% of height on landscape instead of the old tall box. The resource chip row is compact and a bag-limit warning appears only above 85% load.
- The persistent quest now has one active, ellipsis-safe line. A completed starter quest collapses the oversized banner but keeps a small **QUESTS** journal button; tapping opens a full parchment detail panel. Long objectives remain readable after expansion.
- Context helper text only appears when actual nearby gather/enemy/station affordances exist, not while the game displays generic `Explore...` prose. The prompt is placed above the bottom XP bar, away from the quest display.
- The top quick toolbar, three combat abilities, long-press tool picker, potion/food picker, torch, equipment, camera gestures and co-op UI are all retained; gameplay/crafting/item/save/network scripts were not changed.
- `scripts/menu.gd`: Workbench, forge, loom, enchanting and bag/gear menus share a central responsive modal **capped at 880 × 600**, using approximately 60% viewport width / 73% viewport height (within phone margins), text-overrun ellipsis for subtitles, and contrasting carved wood behind cream/gold inner text. At 1280×720, the actual 768×526 crafting popup was verified by Godot CI.
- Temporary touch-gesture help text fades after 8 seconds of play; the large interaction button keeps a small upward cue showing that holding reveals tools. No input handler was removed.
- `tests/approved_ui_visual_layout.gd`: assertions for the new crest instead of the fixed portrait, real status values, quest collapse / expansion, contextual hints, visible gesture affordance, tooltip timeout and popup width/height.

## Source art / imports

`res://assets/ui/icons/outpost_sigil.svg` is an original transparent gold pixel-style beacon crest. All previously committed sprites and PNG nine-slice panel backgrounds remain in `assets/ui/`. No third-party icons or fonts required; no new binary distribution needed.

## Contract and regression checks

Run the full `.github/workflows/godot-smoke.yml`, particularly:
- `tests/approved_ui_visual_layout.gd`
- `tests/pixel_ui_integration.gd`
- `tests/island_smart_action_camera_knockback.gd`
- `tests/carry_bags_camera.gd`
- `tests/android_phone_feedback.gd`
- `tests/rpg_movement_enchant_abilities.gd`

Touch QA on a physical Android device still matters: 1280×720 and taller landscape ratios, status/quest legibility, nav-bar safety, tap+hold smart-tool chooser with movement, phone viewport when opening a modal, no blocked attacking, no gesture collisions. Automated Godot CI cannot certify exact visuals.

## Deliberate boundaries

This is a focused HUD usability fix and responsive menu pass. More detailed inventory art, new character creation, an animated quest journal and additional settings screens require separate follow-on work. The approved title-screen PNG concept is also distinct from this in-game UI feature. No recipe, XP reward, movement, equipment, dungeon or co-op behaviors were changed.
