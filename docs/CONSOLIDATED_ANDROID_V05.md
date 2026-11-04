# Outpost v0.5.0-dev — consolidated main integration

Source: head of `feature/android-playtest-combat-resources-vfx` at c93207843b77e148fe5ec412bd9457c97f12fd46, rebased as a full Git tree onto main at f6704a3a9305de1d439835991701d406f8358469, restoring the main-only title roadmap.

## Intended shipped UI (DO NOT REVERT)
- Main splash / menu (from title-screen PR #7, title art PR #29, main fix PR #32): Five Star Interactive ident; live Outpost tent wordmark; layered illustrated sunset background; standalone Play, Continue, Settings, Quit buttons; rotating tips; save-aware Play vs Continue; v0.5.0-dev.
- Compact in-game parchment / wood HUD, health/XP inventory (PR #9, title/menu art nine-slice assets in `assets/ui/frames/`, `assets/ui/buttons/` and `assets/ui/icons/`): use the textured assets from `scripts/ui/outpost_skin.gd` and `scripts/menu.gd`, **never** fall back to the earlier generic dark-rectangle UI.
- Phone crafting: stepwise tap recipe -> inspect -> load materials -> craft -> collect with swipeable scrolling `scripts/ui/touch_scroll_container.gd`, not a large full-screen two-column list. Item IDs, gear, recipes, saves remain compatible.
- Android actual installed app: Outpost tent launcher icon via adaptive layers and source SVG generator; separate from engine boot splash.
- Title `_launch_game()` must enter `world_loading.tscn`, not launch `main.tscn` directly; preserves New Adventure / Continue one-shot intent.
- The current vector title backdrop is an **SVG recreation of the user's approved concept**, not the actual original transparent pixel PNG cutouts, which still require per-element artwork extraction and Android visual sign-off. Do not claim final concept is identical.

## Consolidated systems
- Chunked, greedy-meshed voxel world with starter outpost, day/night offhand torch, deterministic outer chunk resources/enemies and dungeons; world is still finite, with water horizon rather than true infinite coastline.
- Dungeons, host-driven LAN co-op guardian AI, loot receipt, knockouts/revive.
- Android exploration fixes: downhill camp descent, no fake stone perimeter, contextual station/portal labels, forward sword, high-contrast readable text, silver-white iron, pixel hit/death bursts.
- New regression tests for phone UI, chunk streaming, real Play -> progressive world loader, LAN, title assets, and hit effects.

## Required merge validation
- Godot 4.7.2 full smoke CI (including `tests/android_phone_feedback.gd` and `tests/android_world_feedback_vfx.gd`) must be green at final commit. The earlier PR #30/#31 CI failed the forward swing test; this integration sets the arm pose synchronously to resolve that timing issue.
- Android ARM64 APK build and manifest icon tests should run on the final commit. Real phone QA: menu artwork, touch scroll, Play/Continue, loading, terrain traversal, attack animation, resources, portals and VFX. Do not assert physical-device testing happened.
- Keep old branches open as references until the full integration passes; merging the integration squash into main makes their overlapping diffs stale. Do not merge old UI code again.
- Do not delete `docs/TITLE_SCREEN_TODO_ROADMAP.md`; it documents the approved visual target and remaining original artwork work.

Deferred: infinite procedural world, long-term resource depletion, final exact transparent PNG title art, full LAN authoritative VFX, four-race character creation.
