# Voxel boar art — gameplay-safe polish

This patch is stacked on draft PR #15 and is **visual only**. The original three Wild Boars still use the same health, chase radius, melee damage, respawn timer, hitbox and reward handlers.

In voxel mode `scripts/enemy.gd` asks `scripts/voxel/voxel_creatures.gd` for a single combined box-based boar mesh. The cached mesh and material are shared across every boar, using the same 16×16 nearest-filtered atlas as terrain and the player. Distinct ears, square snout, eyes, tusks, feet and tail replace the old spherical appearance. Toggle `voxel_art_enabled=false` to retain the old multi-part model.

Tests: `tests/voxel_boar.gd` asserts three original enemy spawns, one shared draw mesh per boar, original collision groups, damage behaviour, nearest filtering and the legacy fallback. Android screenshot/performance verification is still required.

This feature intentionally does **not** add hit flashes, pixel-fragment deaths or XP attraction particles. Those remain separate gameplay/FX development tasks.
