# Android voxel + title integration review

This review branch combines **PR #8** (voxel atmosphere and 16×16 nearest-filtered atlas), **PR #10** (weapon-grip and voxel-equipment fix) and **PR #7** (Five Star splash and Play/Continue title). It is not a main merge. PR #9 (crafting UI), PR #5 (dungeon expansion), and PR #6 (LAN co-op) remain separate and are NOT in this base.

## Conflict decisions

- `scripts/game.gd`: retained voxel lighting, procedural meshes, equipment and RPG systems; inserted title scene's one-shot Play/Continue save-load guard only.
- `project.godot`: startup points to `res://scenes/ui/company_splash.tscn`; the title transitions into `scenes/main.tscn`.
- `.github/workflows/godot-smoke.yml`: retained existing gameplay, voxel art, and weapon pose tests; added title/logo regressions.
- Original voxel art remains behind the exported `voxel_art_enabled` flag, requiring a scene reload to change styles.
- The title branch's newly-added scripts, scenes and SVGs are reused from their original Git blob SHA to avoid inadvertent changes.

## Android test protocol

Import this branch in **Godot 4.7.2**, run the project, and check splash → title Play / Continue → voxel game. Compare `voxel_art_enabled = true` versus false in `scenes/main.tscn`. Verify joystick, attacks, the relaxed diagonal sword, gathering, four crafting stations, equipment and saved progress.

The generated voxel ground is **visual only**; collision remains a flat 46×46 bounded map, so elevation, caves and infinite streaming are not in this PR. Check GPU frame time, FPS and graphics on a real Android device before sign-off. The world and title are not the approved painted PNG assets yet unless these are supplied separately.

Do not merge into `main` without user approval. After Android testing, review PR #9 separately for semantic HUD and crafting integration.
