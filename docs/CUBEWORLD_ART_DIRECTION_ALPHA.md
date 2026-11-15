# Outpost — Colourful voxel adventure direction (Alpha)

Reference: user-provided **Cube World** gameplay screenshot, 6 November 2026.
The goal is an original voxel fantasy RPG, not copied Cube World game assets.

## Implemented in this feature
- **World:** deterministic colour-clustered pink cherry, chartreuse, violet, teal and green tree canopies. The existing 64×64 nearest-filtered Outpost atlas remains in use. Seasonal variation is encoded as mesh vertex colours; no per-tree extra scene node, shadow-casting light or new material download is introduced. Tree crowns have staggered voxel layers. Streamed Fields chunks gain a second tree and additional flowers in their batched scenery, with existing chunk limits unchanged.
- **Characters:** enlarged pixel-face proportions; stepped hair, small cheeks and nose, shoulders and straps, extra boot details. Existing character pivot animation, collision capsule, weapon grip and equipment script APIs remain unchanged.
- **Weapons:** original hand-built voxel steel-sword fuller, blade tip, wider iron blade, spear flanges. No combat balance/stat/recipe changes.
- **Map:** keep the already-working round, camera-relative minimap (not a static image). Add actual sampled height shading at 2-pixel intervals on inland terrain and small markers for *existing* stationary trees. Rotation changes only the canvas transform; it still cannot capture camera dragging.
- **Compatibility:** no save-file schema, terrain collision, multiplayer, portal, dungeon, crafting, or item-ID changes. `voxel_art_enabled=false` still restores the legacy character/world visuals.

## Why this is a first art pass, not a complete World style migration
The current terrain is a finite 192×192 island with coastal streaming, not a sprawling Cube World forest. Basic biome tiles and chunk budgets are unchanged. The actual gameplay HUD is not redesigned here, and the map is a circular terrain overview rather than a 3D rendered terrain tile. Future changes need deliberate profiling on Android.

## Follow-up implementation milestones
1. **World:** larger continuous varied forest/meadow/river biome regions, cliffs and terraced hills with safe slope access; colour palettes by biome/season; water edges, natural rocks, wildflowers and dense but culled tree clusters. Keep coast and dungeon entrances accessible.
2. **Character creator:** selectable human, goblin, gnome and orc voxel proportions and hair/skin/eyes using shared compatible skeleton and collision, without introducing player-sized collision mismatches. Equipment should wrap the same rig and update in-game.
3. **Equipment:** iconic tier silhouettes for swords, daggers, staves, shields, armour, bags and gathering tools, all original voxel meshes with right-hand animations.
4. **Map:** optional user-toggleable raised/isometric miniature viewport clipped into the existing circle after GPU profiling. Keep camera orientation, player-centre, party markers and fog of exploration in sync. Dungeon floor map is a separate integration task.
5. **QA:** Godot CI, 1280×720 Android landscape and ultrawide screenshots, draw call count, RAM, stream radius FPS, collision/step-up, neutral/attack swing, and circular-map drag rotation.

## Merge policy
Target **alpha only** after smoke checks and Android visual review. No mainline merge until the owner verifies the updated in-game look.
