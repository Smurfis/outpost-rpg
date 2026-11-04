# Outpost title screen — shipped baseline and future TODO

**Release baseline:** Godot 4.7.2 home-screen flow: Five Star Interactive → Outpost title → Play / Continue / Settings / Quit. The runtime version badge must follow project configuration (currently `v0.5.0-dev`).

**Original concept:** approved layered pixel-art sunset/outpost screenshot with tent-and-campfire wordmark, woodland, watchtower, waterfall, purple dungeon portal and carved menu plaques. The concept screenshot is a visual reference **not** a flattened interactive UI.

## Included with this integration

- Source assets in `assets/ui/title/`, including detailed, original 1280×720 `title_backdrop.svg` and transparent `outpost_logo_vector.svg`. Neither requires a ZIP download or external network at runtime.
- Standalone company splash, illustrated title screen, reusable menu button scenes and icon SVGs, editable tip/rotating update text, live version text, Android-scaled 1280×720 layout.
- Play creates a new-adventure session flag; Continue loads supported saves. Play warns that a saved adventure will be overwritten on its next save. Settings permits reduced menu animation and tips.
- Automated Godot title, logo, artwork and gameplay regression tests.

## Priority TODO / future improvements

- [ ] **P0 Android visual sign-off:** capture a landscape screenshot on target device; test device aspect ratios and notch/safe-area behaviour; check touch targets, text contrast, Play/Continue and settings. Headless CI is not visual approval.
- [ ] **P0 integration with newer world loader:** an existing downstream Android branch has `world_loading.tscn` for large streaming terrain. When that branch is integrated, preserve the working loading transition in `scripts/ui/title_screen.gd::_launch_game()` rather than reverting to immediate gameplay change. Keep the New Adventure/Continue one-shot flag.
- [ ] **P0 save protection:** regression-test invalid/corrupt save file, saved session vs new session, exit during loading and Continue across newer save versions; avoid accidental progress loss.
- [ ] **P1 actual concept-quality pixel art:** replace the SVG approximation with final **clean textless background PNG** and **independent truly transparent** tent logo, button plaques, icons and banners. No screenshot with baked buttons/text, no fake alpha checkerboard. Review edge halos, contrast, resolution and composition.
- [ ] **P1 Five Star Interactive ident:** replace shipped vector fallback with the final transparent studio mark and review fade/skip accessibility.
- [ ] **P1 configurable input:** ensure Android Back / Escape behaviour, controller D-pad focus and a mobile-appropriate Quit behaviour (may be hidden or converted to return-to-OS depending on platform).
- [ ] **P1 align UI style:** coordinate with the independent in-game UI agent on fonts, colours, frames and pixel density, without replacing their gameplay HUD/inventory.
- [ ] **P2 animation and atmosphere:** optional low-cost parallax, campfire flicker, waterfall movement, dungeon-portal glow, and audio; respect reduced motion and low-end Android performance.
- [ ] **P2 responsive access and localization:** longer languages, smaller phones, colour-blind contrast and portrait fallback if supported.
- [ ] **P2 art/source licensing:** keep final images editable and versioned, with source and attribution tracked in-repo.

## Multi-agent merge coordination

- **Title feature PR #7** originates from early `main`, before voxel terrain, UI overhaul, chunk streaming, LAN co-op and the new world loader. A merge of this PR into `main` **does not** merge those newer stacked branches.
- Existing advanced chain under `integration/android-voxel-title-review` and `feature/title-art-visual-bridge` contains descendant copies of some of this title feature. Before integrating the advanced chain, compare files and resolve conflicts intentionally. **Do not** undo newer world loading, gameplay, menus, UI or tests just because their branches diverged from the early title branch.
- For downstream comparison read `docs/ANDROID_TITLE_ART_PASSOVER.md` in the title-art visual bridge branch; it contains a visual art integration history but that whole stacked branch should not be blindly merged into main.
- Asset paths expected by the title screens are under `assets/ui/title/`; fallback scenes stay operational even if optional approved PNGs are not yet present.
- The main agent should run complete Godot 4.7.2 import/startup/gameplay/title tests and build a real Android APK after any later conflict resolution.

**Status:** SVG art is an integration-ready approximation; the original approved rendered concept is not yet reproduced pixel-perfect in the shipped branch.
