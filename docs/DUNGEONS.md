# Outpost — Instanced dungeon integration (v4 handoff)

This feature is designed to merge into an actively changing procedural-world branch without forcing a rewrite of the world generator. It is **single-player**: each entered dungeon gets a fresh enclosed gameplay cell, chest, and guardians, and the player returns to the same overworld position after clearing or abandoning.

## Player experience

- World portals use the **World of Warcraft quality colour conventions**: Common #FFFFFF, Uncommon #1EFF00, Rare #0070DD, Epic #A335EE, Legendary #FF8000. Quality affects guardians and guaranteed end-chest rewards.
- Approach a portal to see a touch-friendly **ENTER** button; clicking/tapping the 3D portal from further away auto-runs the player toward it (manual movement cancels this). On arrival a rarity-coloured **YES • ENTER / CANCEL** confirmation appears.
- Inside a new enclosed dungeon, defeat 1–5 guardians, walk to the chest, and tap/click or use **OPEN FINAL CHEST**. Loot gives coins, experience and crafting materials, scaled by tier.
- Opening the final chest **removes the overworld entrance and saves its stable entrance ID**. Leaving or dying early unloads the current cell but preserves the entrance for retrying.
- Five starter-map preview portals demonstrate every tier. Remove/disable the previews when v4 chunks are connected.

## v4 procedural chunk hook

The `scenes/main.tscn` includes a child `Dungeons` node running `scripts/dungeons/dungeon_manager.gd`. Disable its exported `demo_chunk_fallback` once the v4 streamer supplies real loaded chunks.

```gdscript
var dungeons = get_node("Dungeons")
dungeons.demo_chunk_fallback = false

# On chunk loading: chunk id must be stable per world seed, coordinate and generation epoch.
# Bounds are world-space X/Z; placements are terrain-validated Vector3 locations.
dungeons.register_chunk(
    "world_123:chunk_4_-2",
    Rect2(Vector2(128, -64), Vector2(32, 32)),
    2, # Chunk rarity: 0 Common, 1 Uncommon, 2 Rare, 3 Epic, 4 Legendary
    [Vector3(138, 0, -54), Vector3(150, 0, -42)]
)

# On chunk unloading:
dungeons.unregister_chunk("world_123:chunk_4_-2")
```

**Spawn budgets:** chunk quality grants 1 / 1 / 2 / 3 / 3 distinct entrance slots. Entrance qualities are rolled with chunk-dependent weights and never exceed chunk quality. An explicit placement array caps the number of spawned slots. Use stable chunk keys and deterministic terrain-approved candidate positions. Reloading a chunk never regenerates previously claimed entrance IDs.

The current fallback samples are intentionally forced to the quality of each demonstration chunk. Call `register_chunk()` without the optional fifth `force_quality` argument to enable weighted drops.

**Persistence:** `user://outpost_dungeon_clear_v1.json` saves cleared entrance IDs independently of the main Outpost save. Abandonment and cancelling the prompt do not alter this record. To reset testing, delete that file (do not delete players' production saves). If chunk generation changes significantly, include a new world epoch in chunk IDs.

## Files and ownership

- `scripts/dungeons/dungeon_rarity.gd` — tier names, colour hexes, chunk caps, drop tables and guardian counts.
- `scripts/dungeons/dungeon_portal.gd` — animated, tappable 3D entrance + in-world quality/name.
- `scripts/dungeons/dungeon_guardian.gd` — reusable, tier-scaled melee enemy.
- `scripts/dungeons/dungeon_instance.gd` — each session's corridor, guardians and final chest.
- `scripts/dungeons/dungeon_manager.gd` — loaded chunk registry, confirmation, auto-approach, instances, persistent completions.
- `scripts/ui/material_theme.gd` — reusable dark UI surface, touch-sized icon buttons and text.
- `assets/material_symbols/*.svg` — 20 Google Material Symbols outlined icon SVGs, locally bundled for Android, with `LICENSE` (Apache 2.0) and source notice.
- `scripts/player.gd` — small, cancellable interaction auto-walk hook.
- `scripts/game.gd` — tiny change so the combat toast names dungeon guardians instead of boars.
- `scenes/main.tscn` — mounts the dungeon system, without changing the core game script's startup pipeline.
- `tests/dungeons.gd` — regression coverage invoked in `.github/workflows/godot-smoke.yml`.

## Known prototype limitations

- Dungeon cells currently live in an isolated, distant coordinate region of the same SceneTree, not in a networked server instance or a separate physics World3D. The streaming branch should suppress terrain/chunk creation around that dungeon coordinate region, or replace this with a proper separate-world scene/viewport when world scale demands it.
- Auto-running uses the player's existing kinematic walking/collision, not navmesh pathfinding; **v4 must pass portal locations that have clear walkable approaches**. Hook a NavigationAgent3D once navigation meshes become available.
- The quality colour palette references conventional quality codes, not World of Warcraft textures, audio, UI art, names or other game assets.
- The reward pool consists of existing inventory item IDs and is intentionally conservative until v4 expands items and equipment.
- UI is designed for landscape Android. Verify safe area, rendering and tap targets on-device after the automated Godot checks pass.

## Manual acceptance

1. Launch a fresh project; verify five coloured portal arches on the starter map.
2. Click a distant portal and verify the player runs toward it, with manual movement cancel.
3. On arrival, verify the rarity-coloured confirmation has **YES • ENTER** and **CANCEL**.
4. Enter; verify guardians, exit option and the locked final chest.
5. Defeat guardians, claim the chest; verify XP/coins/materials and original portal disappearing.
6. Reload the game/chunk; cleared portal should remain absent; abandoned dungeons should remain available.
