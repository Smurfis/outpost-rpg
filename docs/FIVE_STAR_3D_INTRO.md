# Five Star Interactive — native 3D studio ident

**Integration target:** the existing startup scene on the Outpost \`alpha\` branch.
**Scope:** splash replacement only. Title, menus, world saves, gameplay portals, and dungeon transitions are unchanged.

## Why this replaces the GIF

The generated 8/12-frame reference clips have perspective inconsistencies and skipped motion. This version uses actual interpolated 3D transforms in Godot: five independently extruded stars, continuous Bézier flight paths, generated ribbon trails, three concentric golden torus rings, a voxel miniature of the watchtower/forest/cliff, sunset backdrop shader, and real UI type.

## Files

- \`scenes/ui/company_splash.tscn\`: full-window intro; UI wordmark, 3D SubViewport and background.
- \`scripts/ui/company_splash.gd\`: timings, reduced-motion preference, skip, fade and unchanged title navigation.
- \`scripts/ui/studio_ident_world.gd\`: deterministic procedural geometry, camera, five stars, rings, voxel art, animation.
- \`assets/branding/studio_sunset.gdshader\`: warm sky; separate from all 3D moving elements.
- \`tests/company_splash_3d_smoke.gd\`: import, component count, seek, startup wiring regression.

## Playback

On boot, five stars accelerate in from the far sky, sweep close to the camera and settle evenly around a golden ring showing a miniature voxel fantasy outpost. The ring forms during the swoop, then FIVE STAR / INTERACTIVE fades in. All motion is evaluated from the current timeline position, not frame-indexed. The sequence is approximately 8 seconds including the final hold and is skippable with tap/click/key.

The \`title/reduced_motion\` option in \`user://outpost_ui.cfg\` presents the completed emblem immediately, then advances after a short hold. The existing portrait/landscape resize behaviour returns to the prior aspect on exit. The main project start scene stays \`res://scenes/ui/company_splash.tscn\`.

## Tests and visual acceptance

Run in Godot 4.7.2:

\`\`\`sh
godot --headless --path . --script res://tests/company_splash_3d_smoke.gd
godot --headless --path . --script res://tests/title_screen_smoke.gd
godot --path . res://scenes/ui/company_splash.tscn
\`\`\`

Visually inspect desktop 16:9 and Android 20:9 landscape; confirm a stable camera and readable typography, all five stars settle at once, no frame skipping, skip/auto-advance works, and the reduced-motion preference is respected. Benchmark low-end Android using the Compatibility renderer. Generated meshes are optimized with MultiMesh batches for voxel cubes and no dynamic shadows. **These tests and device checks must be performed before merging.**

## Future reusable portal

The 3D ring and star mesh construction live in \`studio_ident_world.gd\`. For gameplay, extract those into a dedicated \`GoldenRingPortal3D\` scene with rarity-specific materials and a lightweight destination-preview texture. Do not directly attach the studio scene to dungeon portals: it contains a camera, lighting, backdrop and intro-only movement. Preserve existing dungeon IDs, save/load lifecycle, collisions and tap interaction.
