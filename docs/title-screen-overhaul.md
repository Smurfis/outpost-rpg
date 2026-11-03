# Outpost — Title screen design lock

**Design reference:** Approved second title-screen showcase, 3 November 2026.
**Branch:** `feature/title-screen-overhaul`.
**Existing game version:** `v0.5.0-dev` — do not copy the mockup's `v0.1.0-dev` label.

## Design direction (approved)

- Rustic canvas **tent above “Outpost”** wordmark; rope, wood, grassy stones and warm campfire light.
- Sunset world backdrop: frontier watchtower, trees, cliffs, waterfall, distant ruins and a glowing dungeon entrance.
- Yellow angled rotating splash lines, inspired by playful game start screens, but using original copy and original graphics.
- Central wood-and-stone menu buttons: Play, Continue, Settings, Quit.
- Responsive, Android-landscape-first layout (1280 × 720 design resolution) with PC input support.
- All art and controls as independent nodes/assets, **not** a flattened background screenshot.

## Component build sequence

1. **TitleLogo** — ✅ standalone control and preview. It supports a finalized PNG with a graceful drawn fallback.
2. **TitleBackground** — layered scenery, optional slow parallax and low-motion fallback.
3. **TitleSplash** — editable, rotating update/slogan strings.
4. **TitleMenuButton** — reusable touch-friendly highlighted button component.
5. **TitleMenu** — four actions, save-aware Continue, focus and navigation.
6. **TitleScreen** — composition, settings and game transitions; replace startup scene only when ready.

## Current preview

Open `res://scenes/ui/title_screen_preview.tscn` in Godot 4.7.2 and run **Current Scene** (F6).
It does not change `project.godot` or the playable game's `main.tscn`.

## Approved logo PNG

Put the separately supplied generated asset at:

`res://assets/ui/title/outpost_logo.png`

The logo control detects and displays this exact image automatically, keeping the
source image's aspect ratio. Without the PNG, it draws a lightweight tent-and-sign
placeholder so the feature branch stays runnable.

The generated full-screen showcase is **visual reference only**, not one interactive
asset. Buttons, slogans and scenery will have their own layers and scenes.

## Integration rule

Develop and review changes on this branch. Do not merge to `main` or switch the
project's startup scene until the standalone title screen and mobile navigation
have been checked. Existing inventory, saves, gameplay and tests must remain intact.

## Implementation update — 3 November 2026 (art review stage)

**Godot 4.7.2:** GitHub Actions startup + title-screen + gameplay smoke tests are passing on the feature branch. **Never interpret green CI as visual approval.**

- Startup scene in **feature branch only** is `scenes/ui/company_splash.tscn`, then it opens `scenes/ui/title_screen.tscn`. Existing gameplay still lives in `scenes/main.tscn`.
- The new title menu has four touch-friendly buttons, local save-aware Continue, a confirmation before starting a new adventure, settings/tip toggles and real `v0.5.0-dev` label.
- `scripts/game.gd` respects a one-shot new-adventure flag, skipping old saved state on Play but preserving it for Continue.
- Dynamic yellow splash lines can cycle; the hero phrase uses `splash_deeper_dungeons.png` if imported, with an outlined Label fallback for other messages. The hero art already contains its rotation.
- Transparent PNGs take priority automatically, using `res://assets/ui/title/{outpost_logo.png,five_star_logo.png,btn_*.png,icon_*.png,splash_deeper_dungeons.png,banner_star.png,tip_panel.png}`. Missing PNGs render using the committed reusable SVG placeholders instead.
- `version_badge_textless.png` is optional; **do not import a version plaque with v0.1.0-dev baked in**. The branch includes a textless SVG fallback.
- The personal world-tip line `Tip: Keep the campfire burning — Chloe and Iyla need a safe outpost after dark.` appears as a rare tip in the cycle (one of 13).

### Art acceptance is still pending

The separately prepared asset review ZIP is a **ChatGPT attachment**, not yet committed to GitHub; it contains transparent draft cutouts, a contact sheet and the exact reference screenshot. The imported PNGs must be visually reviewed against the approved 1536 × 864 screen and explicitly committed to this branch before a merge is considered. In particular, a clean full-resolution UI-free `title_background.png` matching the approved landscape has **not** been produced or committed. The current `title_backdrop.svg` is a schematic functional placeholder.

Do **not** mark PR #7 ready for review, merge it into `main`, or start the in-game HUD overhaul until final artwork and Android landscape visual review are approved.
