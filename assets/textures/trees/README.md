# Outpost tree textures and foliage renderer

This Alpha feature integrates the original pixel-art tree atlas created for Outpost. The shipped file is `tree_atlas_padded_16.png`: **80 × 60 RGBA pixels**, with 12 source tiles (16 × 16 each) in a 4-column by 3-row grid. Every tile has 2px of extruded edge padding to avoid bleeding. This is the native runtime asset; the earlier illustration board is not used in-game.

## Tiles

| Index | Tile |
| --- | --- |
| 0 | Oak bark |
| 1 | Birch bark |
| 2 | Pine bark |
| 3 | Mossy bark |
| 4 | Oak leaves |
| 5 | Sunlit oak leaves |
| 6 | Birch leaves |
| 7 | Pine needles |
| 8 | Autumn leaves |
| 9 | Blossom leaves |
| 10 | Twilight leaves |
| 11 | Log cut end |

**Runtime:** `scripts/voxel/foliage_renderer.gd`. Trees and shrubs now use a dedicated nearest-filtered atlas material. Multiple tree silhouettes share one material and one mesh surface per tree. Decorative foliage in each streamed terrain chunk is batched into a single mesh so there is no separate draw call per tree. Chunk vegetation streams in and out with the terrain mesh and collisions; the placement is deterministic across reloads.

**Consumers:** camp decorations (`scripts/game.gd`), harvestable wood (`scripts/resource_node.gd`), common voxel tree/bush functions (`scripts/voxel/voxel_props.gd`), streamed and non-streamed biome scenery (`scripts/voxel/voxel_biome.gd`).

**Invariants:** The 64 × 64 shared terrain atlas, coastal water shader, item drops, resource harvest/recovery behavior and existing collision setup are unchanged. The foliage module does not need a per-frame update.

**Validation:**

```sh
godot --headless --editor --path . --quit
godot --headless --path . -s res://tests/foliage_renderer.gd
godot --headless --path . -s res://tests/chunk_streaming.gd
godot --headless --path . -s res://tests/voxel_art_smoke.gd
```

CI runs the new smoke test on pull requests. Android visual inspection is still required before calling the foliage final.
