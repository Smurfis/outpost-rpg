# Outpost title artwork integration — Android visual review (4 Nov 2026)

## Goal and status
This feature resolves the **missing-art fallback** seen on the real Android APK home screen.

- Replaces the schematic dusk silhouette with an original, layered **1280×720 scalable title backdrop** in `assets/ui/title/title_backdrop.svg`. It includes a watchtower, tent, campfire, river, waterfall, distant ruins, and a purple dungeon portal; the composition deliberately leaves space for the editable center buttons.
- Adds `assets/ui/title/outpost_logo_vector.svg` as a **transparent illustrated tent/wood/stone logo layer**, displayed under the live `Outpost` wordmark. A future user-approved `outpost_logo.png` still overrides the vector and hides the duplicate Label.
- Deletes the unimportable tiny `title_background.jpg` that the menu had been trying to load ahead of valid SVG art.
- Improves the title loader to verify each image resource before choosing the PNG or SVG path; it is not necessary to manually import a PNG from ChatGPT.
- Retains the existing four standalone interactive Godot buttons, angled yellow rotating update text, save-aware Continue and Settings, and the live `v0.5.0-dev` version.
- Adds `tests/title_art_assets.gd`, run by the Godot 4.7.2 CI, validating the art is actually imported and used by the interactive menu.

## Visual acceptance note
The illustrated SVG is an **integration-ready original approximation** of the approved pixel-art mockup, **not** a pixel-perfect extraction of the separately generated image. The high-resolution PNG cutouts were previously created as conversation attachments but were never committed to the repository. The art can be replaced with those PNGs on a dedicated reviewed commit without changing any menu interaction or the Android world loader. Do not claim the original mockup was committed or that the visuals were accepted on a phone until the developer explicitly confirms.

## Source hierarchy
- Backdrop: `title_background.png` (if a valid approved image is later committed), else **shipped** `title_backdrop.svg`.
- Logo: `outpost_logo.png` (if a valid image is later committed), else **shipped** `outpost_logo_vector.svg` + live Label.
- Buttons: `btn_*.png` or `buttons/*.png` if committed, else `buttons/*.svg`; all independent Godot button scenes.
- Slogan, version and settings remain live text/controls.

## Integration and Android QA
Branch: `feature/title-art-visual-bridge`, stacked on `feature/android-tent-app-icon` (PR #28), which stacks on the world-loader crash review PR #27. **Do not merge directly to main.**

Use Godot 4.7.2, import the source, inspect `res://scenes/ui/title_screen_preview.tscn`; check legibility on a physical Android device (landscape, small text, different aspect ratios), title/logo artwork source paths, Play loading progress, and Continue behavior. The separate Play-crash report still requires actual on-device validation and should not be considered solved by this visual-only feature.

There are no runtime network image fetches. The new art is committed to this feature branch, and will therefore accompany the APK when this branch is exported.
