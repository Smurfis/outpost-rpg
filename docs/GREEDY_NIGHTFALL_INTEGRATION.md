# Combined Android review: greedy terrain and nightfall

This branch integrates two independently tested features:
- Greedy 12×12 terrain top/side face merging from PR #21, with atlas-safe nearest-filtered repeat shader and physics collision.
- Nightfall from PR #23, with sunrise/dusk, 8-minute full day, craftable offhand torch, HUD clock, quick torch toggle and first-night message.

This is **not** a merge to main and not a replacement for original source PRs. We deliberately do not import competing greedy PR #20 or competing day-night PR #22 to avoid dual renderers/clock controllers.

Conflict resolution: both PRs share base PR #19; PR #23's gameplay, torch icon and saves are copied unchanged, while the greedy PR #21 voxel_biome.gd, shader and greedy tests remain in place. GitHub workflow combines both test suites.

Android: import project.godot with Godot 4.7.2 and test terrain chunk boundaries, 1-block auto-step, screen brightness from daytime to night, torch crafting at workbench and torch/shield switch, title startup and offhand HUD tap. Compare GPU/frame time with torches equipped; ensure no duplicated world clock per remote player in co-op. Only one player-local torch light is modeled, and LAN co-op combat remains preview-only.

Neither physical Android visuals nor network clock synchronization are certified by headless CI. Do not merge to main without user approval.
