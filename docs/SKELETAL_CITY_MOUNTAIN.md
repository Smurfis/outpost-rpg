# Skeletal City — mountain kingdom feature

Status: **isolated foundation only** on `feature/skeletal-city-mountain`. No in-game mountain, meshes, collision, city, or Android APK has been produced.

## Experience to build

A huge, recognisable mountain on a distant generated island. A monumental dwarven gate is a real hole in the rock, not a portal. The player walks inside and physically descends a broad, one-voxel-at-a-time, multi-turn spiral cut through the mountain. From an overlook, a vast ruined **Skeletal City** becomes visible: bridges, towers, waterfalls and vertical districts within an immense cavern, with a fortified royal/crypt district in its centre.

**Visual reference:** the user-provided image in the Nov 23, 2026 design conversation (dark block-stone walls, red banners, warm brazier lighting, waterfalls, chasms, bridges and central giant gate). The image itself is *not* committed to this repository.

## Procedural architecture

1. **Landmark placement + mountain shape:** pick an unprotected exploration site outside Outpost's starter island. Blend a prominent mountain form into the existing fractal biome rather than replacing world generation globally.
2. **Carved gateway + staged descent:** reserve mountain air volumes and solid steps before creating chunk meshes. Keep a continuous route from the surface through a grand entrance hall and down an open, wide spiral.
3. **City anchors:** reserve a cavern, overlook, central fortress/throne hall, bridges and at least one guaranteed route through the city.
4. **BSP centre:** divide the fortress and central rooms into navigable smaller chambers, then connect them with corridors.
5. **WFC outer districts:** place compatible, socket-defined modular streets, homes, towers, bridges and ruined architecture outward from fixed BSP gateways. Reject or repair disconnected layouts.
6. **Organic cavern transition:** integrate existing cave-carving/noise logic into the city outskirts while preserving essential structural spans.
7. **Site persistence:** deterministic seed and site ID govern structure; changes to loot, bosses and events persist separately from geometry.

Do not randomly place mission-critical destinations after navigation validation. Reserve them first.

## Foundation added now

`scripts/world/skeletal_city_mountain_plan.gd` builds a deterministic **3D floor/air/support proposal**. It currently generates:
- a five-voxel-wide straight approach into the mountain,
- three turns of a three-voxel-wide angular dwarven spiral,
- one-voxel descents separated by ten horizontal tiles,
- a continuous lower exit towards a reserved city-centre anchor,
- multiple **separate Y levels per X/Z column**, including where turns overlap.

The generator returns a dictionary with `entrance_route`, `spiral_route`, `exit_route`, `floors`, `air`, `supports`, `column_levels`, `gateway`, `city_center`, and mountain-radius metadata.

This geometry **has not yet been installed into the live world**. In particular, `mountain_radius` and `city_center` are reservation metadata, not rendered objects.

## Existing system constraints to resolve before integration

- `scripts/world/stepped_cave_tunnels.gd` stores `floors[Vector2i]` as a **single** elevation per X/Z column. A spiral has stacked traversable Y levels even within one turn, so it cannot be stored in that format.
- `scripts/world/fractal_archipelago_data.gd` presently calculates `solid_column` with a `(1 << height) - 1`-style bit mask and asserts `top - BEDROCK < 63`, with `BEDROCK = -7`. Do **not** simply request an 80-high mountain using the existing column encoding: first implement and test an extended vertical-span or vertical-section representation.
- The fractal terrain streamer, physics and visible-geometry picking must use the **same** layered occupancy contract. Rendering cutaway is not a substitute for correctly carved geometry and collider removal.
- The city cannot be merged into Alpha or the old cave route without passing safety, save and regeneration regressions.
- The mountain should leave the seed-64012 starter Outpost untouched; its placement must be coordinated with registered persistent sites, other caves and existing world modifications.

## Next code milestones

### M1 — Integrate a placeholder physical mountain

- Choose a distant, valid site using the world-site registry; reserve its geometry and rejection/exclusion area.
- Extend terrain occupancy to represent several 3D air spans per horizontal column, with enough vertical range for a landmark mountain and a deep city.
- Apply the spiral proposal to chunk mesh and collision output, without damaging other island routes.
- Make a simple rectangular opening and entrance hall with debug stone geometry.
- **Pass:** walk from outdoors to the bottom of the spiral, including unload/reload, with no teleports, missing steps or rock collisions.

### M2 — Camera and click-to-move

- Reuse the isometric chamber cutaway approach while respecting the 3D occupancy/visibility contract.
- Ensure the on-screen target picker ignores hidden occluders and can distinguish stacked, visible floors.
- Test rotating the camera, ascending, descending, and clicking a destination multiple revolutions below.
- **Pass:** no ghost clicks, skipped floors, top-wall silhouettes or pathfinding soft locks.

### M3 — Procedural city topology

- Start with a broad traversable cavern and guaranteed backbone path from the lower landing to the central fortified hall.
- Generate BSP chamber partitions inside the central district; preserve all exits and a mandatory central room.
- Generate surrounding WFC district sockets and buildings, *constrained* by reserved roads, stairs, bridges and entrance sockets.
- Join and validate all necessary 3D paths, then add optional organic cave branches.
- **Pass:** numerous seeds yield connected, vertically layered cities.

### M4 — Art and gameplay

- Prioritise the reference's layered bridges and towers, chasms, hanging banners, waterfalls, brazier lighting and huge fortified gate.
- Populate the Skeletal City with undead and environmental storytelling; preserve mobile readability.
- Test chunk budgets, Android frame time, return trips, persistent site data and repeated seed generation.
- **Pass:** a clear, playable surface-to-city experience, then a separately reviewed merge.

## Focused regression

```sh
godot --headless --path . --script res://tests/skeletal_city_mountain_plan.gd
```

This pure proposal test checks repeatability, route joins, one-voxel steps, stacked floors and the absence of collisions between required air and supports. A graphical Godot integration test and Android device test are still required.
