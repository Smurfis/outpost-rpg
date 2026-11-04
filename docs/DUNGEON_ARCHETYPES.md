# Dungeon Room Archetypes — Feature 2

Based on the passing voxel-boar build; draft, stacked branch, no direct `main` merge.

## New room themes
Start/gatehouse, boss arena, stairs, cache/vault, pillar hall, collapsed ruin, armory, fungal grotto, crystal shrine, scorched hall, gallery. This changes the generated room appearance rather than duplicating the same room in every grid coordinate. Each theme has identifiable corner silhouettes, distinct floor ornaments and nearest-filtered voxel-atlas props. One shared-material decoration mesh per room keeps mobile draw calls low.

`dungeon_layout.gd` assigns a deterministic shuffled set of archetypes after completing the existing graph, so room connections, seeds, guard placement, rewards, floor count, and player saves remain unchanged. Decorations do not block the central 4×4 combat area or doorway entrances.

## Scope / further work
The dungeon connection safety fix remains from PR #15. This pass improves the static 3D look, not AI affixes, traps, dynamic lighting or bespoke hand-authored room scenes. Formal Android screenshot and pathing verification is still needed. Pixel HUD and title screen are deliberately untouched.

CI: `tests/dungeon_archetypes.gd` verifies determinism, role assignment, at least seven themes, atlas reuse, one mesh per room and existing encounter gates.
