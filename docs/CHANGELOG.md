# Changelog

## 0.3.0-dev — Playable systems expansion
- Working recipe panel, inventory panel and six recipes with ingredient costs and ownership checks.
- Added fiber and berries gathering, healing meals, tool bonuses, shield damage reduction and weapon swings.
- Removed empty-action notification spam and disabled irrelevant interaction buttons.
- Added distinct resource visuals, extra 3D world dressing, faceted characters/enemies and 7 original SVG item sprites.
- Existing v0.2 saves load into updated inventory; local progression remains device-only.
- Added GitHub Actions automated 4.7.2 headless import and runtime smoke checks plus playable-system tests.
- Fixed a first-physics-frame teleport to the first boar by placing enemies on a separate collision layer.
- Verified zero gameplay regression assertions failing on GitHub CI for the 4.7.2 engine.
- Still pending Godot 4.7.2 testing on Android; review parser/debugger errors before calling release stable.

## 0.2.1-dev — Android 4.7.2 compatibility hotfix
- Fixed fatal GDScript type inference in scripts/game.gd input registration (line 45).
- Explicitly cast input key values when defining actions.
- Set project feature version to 4.7 for the user's Godot 4.7.2 editor.
- Updated Android setup instructions. No engine runtime validation yet.

## 0.2.0-dev — 2026-11-02
- Created the GitHub source tree and renamed game/branding to Outpost.
- Added 10 original SVG resource/ability/item art assets and integrated them with HUD.
- Reworked screen UI, inventory displays, visible weapon, campsite and low-poly evergreen environment.
- Replaced abstract crawlers with original boar stand-in meshes.
- Rebuilt Android install and test instructions for fresh GitHub repository.
- No claims of runtime or Android-device validation until first import test.

## 0.1.0-dev — initial local prototype
- Built single-player gathering, crafting, combat, mobile controls, and saves.
