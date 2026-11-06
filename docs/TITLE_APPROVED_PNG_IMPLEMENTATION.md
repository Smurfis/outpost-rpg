# Outpost — approved pixel-art home-screen implementation

**Source of truth:** the user's approved `outpost_deeper_dungeons.png` render (16:9, tent/wood/stone OUTPOST crest, sunset/watchtower/camp, waterfall, portal, gold Play/wood Continue/stone Settings/parchment Quit, yellow hand-drawn slogan, decorative frame and banners).

**Target:** Godot 4.7.2, Android landscape, 1280 × 720 design board, with resize-to-fit letterboxing. Branch: `feature/title-screen-approved-png-art`.

## Shipped images — real PNG files, committed to Git

All paths are under `res://assets/ui/title/`:

| File | Pixels | Use |
| --- | --- | --- |
| `title_background.png` | 1280 × 720 | Pixel-painted valley, watchtower, tent/camp, waterfall, magical portal, edge banners/frame. Previously baked UI areas are filled so these elements can be drawn on independent layers. |
| `outpost_logo.png` | 438 × 350 | Approved tent/rock/campfire **Outpost** crest and hand-lettered wordmark. |
| `splash_deeper_dungeons.png` | 305 × 171 | Yellow **Now with deeper dungeons!** art. Other slogans remain live editable labels. |
| `btn_play.png` | 422 × 92 | Gold plaque and printed label/icon, rendered by the existing real Play button. |
| `btn_continue.png` | 360 × 79 | Wood plaque and printed label/icon, rendered by the save-aware Continue button. |
| `btn_settings.png` | 336 × 76 | Stone plaque and printed label/icon, rendered by Settings. |
| `btn_quit.png` | 296 × 76 | Parchment plaque and printed label/icon, rendered by Quit. |
| `version_badge_original.png` | 177 × 57 | Original `v0.5.0-dev` lettering for the matching project version only. |
| `version_badge_textless.png` | 177 × 57 | Dynamic version fallback: live version text appears on the original style of plaque when the project version changes. |

**No external asset ZIP is needed.** Every image, script, scene and test is stored in this Git branch and included in normal Godot imports and Android exports.

## How visual accuracy is maintained

The artwork was aligned directly against the approved 1280×720 reference. Objects retain the screenshot's original pixel positions; the separate layers reconstruct the approved static view very closely. Native Godot Button controls remain interactive, with their texture replacing fallback icons/font to avoid duplicate printing. Approved PNG artwork uses nearest-neighbour filtering. The old title-light/frame/banner nodes remain present for legacy tests but are not painted twice.

**Tradeoffs/limitations:** The crest cutout includes some original surrounding scenery within its rectangular bounds. The underlying background is filled behind it. Therefore moving/scaling the crest outside its approved position may expose an inpainted seam. This approach is meant to achieve the approved appearance now while retaining a functional menu; a later fully art-directed *independently transparent* crest and a genuinely UI-free landscape should replace it for arbitrary parallax/position changes. Some plaque images currently have printed text/icons, so localization requires replacing those sprites with textless ones plus a pixel font. The slogan background cleanup is not ready for large repositioning or a strong parallax shift.

## Runtime behaviour retained

- Five Star Interactive splash precedes the title screen.
- Real buttons still execute Play, save-aware Continue, Settings, and Quit; no flattened unclickable menu.
- Play continues to `res://scenes/ui/world_loading.tscn` and preserves the one-shot New/Continue intent.
- The Android update-check UI in Settings and conditional update banner remain intact.
- The real version number is available in a hidden live label even when the matching approved painted `v0.5.0-dev` is shown. A different build version automatically uses the textless plaque with live text.
- Rotating tips are **off by default for first-time users** in the approved raster mode (the concept screenshot has no tip plaque). Settings can re-enable them; existing preferences remain respected.
- SVG placeholders remain in-repo for fallback should the PNG artwork be removed in a future integration.

## Tests and integration

- Godot 4.7.2 import/startup.
- Existing full gameplay, co-op, HUD, streaming world, Android updater, and title tests.
- New `tests/title_approved_raster_smoke.gd`: all nine PNG imports/dimensions; nearest filtering; independent real Button signals; actual artwork positions; title scene/version/loader; no duplicate SVG art.
- Updated `tests/title_art_assets.gd` verifies approved PNG rather than SVG fallback.

**Do not ship a new Android APK claiming visual approval until it has been inspected on the target physical phone.** The frame is optimized for 16:9; very wide device aspects will letterbox. Use screenshots to inspect input hit area, text sharpness, image seams, title tip panel when toggled, and startup transitions.

## Future TODO

- [ ] Real-device visual sign-off: safe areas, tap targets, FPS and input focus.
- [ ] Replace extracted crest and background paint under it with a clean UI-free source background and true alpha-only hand-painted crest to permit parallax and motion.
- [ ] Convert plaque sprites to textless images + a licensed, readable pixel-art font for localized labels and configurable Continue state.
- [ ] Finish intentionally separate Five Star Interactive PNG ident, retaining the studio splash fade/skip.
- [ ] Improve animation of campfire, portal and waterfall as independent small texture/sprite-sheet effects, respecting reduced motion.
- [ ] Check optional long rotating slogans against the sky cleanup after the first eight seconds.
- [ ] Coordinate with the UI/voxel and Android-loading agents; do not revert world loading, user saves, Android updater or HUD menus.

This branch changes only title artwork and title UI rendering, not world generation or gameplay.
