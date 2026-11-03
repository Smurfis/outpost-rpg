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
