# Alpha transparent world-loading screen

This is **world-loading only**, not a title-screen or gameplay HUD change.

- Full scenic title background remains and is no longer covered by a screen-wide dark tint.
- Replaces the previous brown `PanelContainer` with a floating stack (no panel backplate).
- Loads the independently generated, alpha-transparent `assets/ui/title/outpost_loading_logo.png` (640 × 480, 63 KB), with nearest-neighbour filtering and aspect-preserving sizing.
- Leaves the real `_progress`, `_stage`, and `_detail` controls connected to the existing chunk generation ratio. Percentage is **not** baked into the artwork.
- Keeps cancellation, but renders it as a small transparent text button instead of a chunky wood button.
- Uses `StretchMode.KEEP_ASPECT_COVERED` for scenery and aspect-preserving centering for the crest on landscape and ultrawide phones.

## Verify

Run Godot 4.7.2 imports then:

```sh
godot --headless --path . -s res://tests/world_loading_transparent.gd
godot --headless --path . -s res://tests/android_play_startup.gd
```

Check Alpha APK on both 16:9 and 20:9 landscape Android: visible backdrop, crisp centered transparent logo, real progress increments, cancel returns to title, world reveals after generation. Stable branch is intentionally unchanged.
