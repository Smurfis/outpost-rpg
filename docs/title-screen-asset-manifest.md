# Outpost — pixel-perfect title UI asset checklist

**Status:** ART FREEZE / VISUAL RECONSTRUCTION. **Approved reference:** user's 1536 x 864 (16:9) Outpost menu screenshot from 3 November 2026: tent over the Outpost wordmark, lavender/peach sunset, tree+lantern left, tower/ruins, waterfall, purple cave right, four vertically stacked planks, angled yellow hand-drawn splash, corner banners and border, small version plaque. Do not replace this with a different layout or an invented screenshot.

**Studio sequence:** FIVE STAR interactive splash (inverted/gold central star, four supporting corner stars) -> Outpost title screen -> Play/Continue/Settings/Quit, and optional loading transition. Godot 4.7.2 Android landscape; reference coordinates are 1536 x 864, game design size is 1280 x 720, factor 5/6.

## Rules (no more functional implementation until visual signoff)

- Each logo, button board, icon, yellow splash, banner, frame, version plaque and tip plaque is a separate transparent asset. Keep background **free of all UI**.
- Original full-screen image is a **flattened visual reference only**. Cropping buttons from it would retain scenery pixels; rebuilding the occluded scene and artwork independently is required. Never advertise an automatic cut-out as pixel perfect.
- PNGs: genuine 8-bit RGBA alpha, with clean contours and **no checkerboard baked into pixels**, no matte, no blur/halo. Provide full-size source and transparent exports. Keep pixel-art line weight, bevels, highlights, ropes and silhouettes consistent.
- Native Godot render: nearest-neighbour pixel sampling for pixel art; avoid unintentional stretching that breaks contours. Prefer 9-slice for resizable button boards/panels. Graphics sized at **2x the display dimensions** (or nearest exact integer multiple) where practical.
- No text baked into the title background. **Do not use the old mockup version v0.1.0-dev**: actual project version is `v0.5.0-dev` (prefer read from project config). Splash is an independent transparent graphic or independently styled glyphs.
- Preserve existing world/gear/save data. No startup scene or gameplay edits until Godot scene preview passes visual signoff and Android touch checks.

## Approved asset inventory

| Priority | File (beneath `res://assets/ui/title/`) | Export canvas target | Required appearance/behaviour |
| --- | --- | --- | --- |
| P0 | `outpost_logo.png` | 1000 x 620 transparent | Exact tent, crossed poles, hanging lantern, flag, fire, rope, leaves, slate, cream beveled **Outpost** letters; no scenery behind crest. Render approx. 450 x 280 at 1280 x 720. |
| P0 | `five_star_logo.png` | 1000 x 600 transparent | Gold studio wordmark **FIVE STAR**, smaller **interactive** under it, distinctive central/inverted star emblem, four smaller corner stars; readable on dark splash backdrop. |
| P0 | `title_background.png` | 2560 x 1440 opaque | Reconstruct **unobscured** sunset world only: left tree+lantern, watchtower, foreground campsite/map, cliffs, waterfall, arch, purple crystals. **No menu, logo, splash words, frame, version, or tip text.** |
| P0 | `btn_play.png` | 900 x 184 transparent | Amber/gold highlighted wood plank, gold edge, ropes/ivy/nails; **no 'Play' text**, no embedded play icon. |
| P0 | `btn_continue.png` | 900 x 184 transparent | Walnut/dark polished wood with bevel, ropes/ivy/nails; no text/icon. |
| P0 | `btn_settings.png` | 900 x 184 transparent | Dark lavender-grey carved stone plank, nails/leaves; no text/icon. |
| P0 | `btn_quit.png` | 900 x 184 transparent | Pale parchment/sanded wooden plank, nails/leaves; no text/icon. |
| P0 | `icon_play.png` | 128 x 128 transparent | Cream ivory triangle with brown ink outline and tiny bevel, not a system UI emoji. |
| P0 | `icon_continue.png` | 128 x 128 transparent | Cream floppy/save glyph with same outline/highlights. |
| P0 | `icon_settings.png` | 128 x 128 transparent | Cream carved cog with same outline/highlights. |
| P0 | `icon_quit.png` | 128 x 128 transparent | Cream power glyph with same outline/highlights. |
| P0 | `splash_deeper_dungeons.png` | 840 x 230 transparent | Exact original feeling of yellow, slightly irregular **“Now with deeper dungeons!”**, black/brown shadow/outline, underline, exclamation strokes. Keep this separate; position/rotation/scale animated in Godot. |
| P1 | `title_frame.png` | 2560 x 1440 transparent | Full perimeter timber/metal corner frame and edge vines, with transparent hole in centre so backdrop remains visible. |
| P1 | `banner_star.png` | 240 x 320 transparent | Burgundy hanging gold-rimmed banner with cream four-point star insignia; independently place left/right. |
| P1 | `version_badge.png` | 360 x 96 transparent | Brown inset plaque with diamond corner accents; **no version baked in**; Godot label reads `v0.5.0-dev`. |
| P1 | `tip_panel.png` | 1180 x 92 transparent | Narrow dark wood + gold diamond bordered tooltip bar for bottom-centre, independent of map/table props and version badge; no words baked in. |
| P2 | `studio_splash_background.png` | 2560 x 1440 opaque | Dark navy/indigo starry gradient with subtle shimmer; studio emblem above wordmark and optional small animated glow, distinct from game's sunset menu. |
| P2 | `splash_text_style/README.md` | text specification | Record lettering weights, gold fill, dark stroke, dropshadow, approximate -10° tilt and bouncy motion. New rotating phrases must match the approved hand-drawn look, via custom pixel font/glyph atlas or separately authored artwork (do **not** change one phrase by writing with an arbitrary default font). |

The sizes above are **export targets**, not fixed UI control bounds. Exact on-screen sizing/positions should be visually calibrated against the 1536 x 864 approved screenshot; responsive anchors preserve structure at Android landscape ratios. The source art can be larger with transparent padding as long as trim bounds and anchors are documented.

## Reference layout (1280 x 720 canvas)

- Main Outpost crest: centred in upper third, tent visible at top, no collision with yellow angled splash on upper right.
- Yellow rotated splash: right of crest, only one message at a time; subtle pulse; never drawn as a permanent layer of the background.
- Four plank buttons: centred column; order **Play**, **Continue**, **Settings**, **Quit**; same width and approximately 65-72 px high at reference size, consistent vertical spacing.
- Banner/frame: corners and trim must not intercept focusable controls.
- Tiny real version badge: bottom-right, within safe margins.
- Tip panel: bottom-centre **above the frame**, avoid version badge and cover as little foreground as possible; optional hide/shorten on smaller screen. Show one or two lines depending on width.

## Rotating tips and personal easter egg

Approved personal, in-world tip (rare in rotation):

> **Tip: Keep the campfire burning — Chloe and Iyla need a safe outpost after dark.**

This references a game-world safety/settlement mechanic rather than an unexplained name-drop. Keep the personal message infrequent (e.g. one entry among >=12 tips). Other tips should teach real/current mechanics where possible, e.g. **“Tip: Gather wood and stone before visiting the workbench.”** and **“Tip: Equipped tools can increase your resource yields.”** Never promise dungeon features as implemented until they are.

## Visual acceptance gate

- [ ] Every exported transparent asset alpha inspected on light, dark and checkerboard backgrounds; no contamination from the screenshot's landscape.
- [ ] A layered composition of assets at 1536 x 864 matches approved silhouettes/positions/colours, not just 'similar theme'. Compare overlays and inspect typography at 100% zoom.
- [ ] Buttons remain separately interactive and have clearly authored normal/hover/focus/pressed/disabled states; text and icons remain separate.
- [ ] Yellow hand-lettered phrase matches approved treatment, not a generic default Godot font.
- [ ] Startup studio splash displays FIVE STAR / interactive correctly before Outpost.
- [ ] Godot 4.7.2 editor loads assets without parsing/resource errors; standalone scene preview verified.
- [ ] Android landscape visual test: safe areas, readable text, >=48 px comfortable touch-targets, no overlaps.
- [ ] Continue is disabled if no valid save exists (save path currently `user://outpost_progress_v02.json`), and Play/start transitions are tested **before** changing `project.godot`.
- [ ] Existing smoke tests pass and no game/save logic changed accidentally.

## Existing implementation status (3 November 2026)

- Draft PR #7 and branch `feature/title-screen-overhaul` exist.
- Standalone script/scenes and transparent **SVG placeholder boards/icons** exist, but these are **not** verified pixel-perfect with the approved screenshot. Existing `title_backdrop.svg` is schematic and **must not** be treated as final artwork.
- A company splash script/scene and vector star mark exist; its final branded PNG and artwork verification remain outstanding.
- The user-approved screenshot is the master reference. Prior generated concept boards, new compositions, or automatic background removal are **not** substitutes for approved final exports.
- Asset preparation/design review first; then UI wiring and merge review. **Keep `main` unchanged.**
