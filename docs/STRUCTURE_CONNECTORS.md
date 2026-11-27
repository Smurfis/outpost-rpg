# Outpost Structure Connectors — dungeon experiment

A connector is authoring metadata describing an aperture, not a solid runtime block. Inspired by Minecraft jigsaws and Hytale's prefab-driven creator workflow. No claim that Hytale uses this exact solver.

## First contract
- Fixed 15 × 5 × 15 voxel modules (odd width keeps the central socket aligned on quarter-turns); storage sections remain 16³ and are not the same concept.
- Direction 0 north (-Z), 1 east (+X), 2 south (+Z), 3 west (-X).
- Each declared socket is a centered 3-wide × 3-high clear opening, with solid floor at Y=0, reachable from the module center.
- The type string must match at both ends; rotated directions must oppose. Undeclared edges cannot expose traversable apertures.
- The module uses City Lab's existing schema-v1 voxel prefab payload plus ID, weight and socket metadata. Example envelope:
```json
{
  "schema_version": 1,
  "id": "custom:stone_left",
  "weight": 5,
  "prefab": {
    "schema_version": 1,
    "size": [15,5,15],
    "voxels": ["replace with actual captured voxel rows [x,y,z,material]"]
  },
  "sockets": [
    {"direction": 0, "type": "stone_corridor"},
    {"direction": 3, "type": "stone_corridor"}
  ]
}
```
The placeholder voxel row above is illustrative, not a valid import.

## Assembly
Start at a central cross module; pick an unoccupied frontier slot; choose a weighted compatible rotated asset; connect reciprocal ports. Compatible adjacent ports may form a loop. Every unconnected port is physically sealed when materializing a module. Slots cannot overlap. Built-in sample modules are straight, left, right, tee, cross, chamber and dead end. Generation is seeded and currently bounded to at most 128 modules; a frontier exhaustion is reported as failure. Voxel geometry is materialized per module rather than accumulated as a world-wide buffer.

Tests verify default/custom asset validation, obstruction and incorrect orientation rejection, deterministic 32-module layouts, connectivity, reciprocal physical apertures, closed caps and maximum size. They are wired to CI, not yet observed passing.

## Sector preview and creator integration (next iteration)

City Lab now has N/E/S/W connector toggles, selection weight and Export module. Capture a 15 × 5 × 15 volume (including its floor), designate its centered 3 × 3 doorway directions, then export. The registry checks physical clearance and center access before saving `user://city_lab_connector.json`. The Dungeon Lab button saves pending city edits and opens a separate roofless preview. Import module loads that one custom asset into the built-in pool; it participates only when its rotated socket mask exactly fits a planned room. Default pack removes it from the current preview.

Each independently generated 5 × 5 module sector uses a seeded depth-first spanning tree plus optional loops. Four fixed centered gates align with the neighboring sector's opposite gate; every sector has a guaranteed path between them. Weighted prefab selection occurs after graph planning, matching the full required mask. Geometry uses 16³ greedy render sections and a local A* grid built only from reachable physical floors. Click/tap a floor or choose a gate button. Reaching the middle gate cell switches to the neighbor's local scene and places the player one cell inside the reciprocal doorway. Global signed 64-bit sector addresses are never converted to world-space floats.

This is a bounded one-sector-at-a-time preview (75 × 75 blocks, 25 modules); transitions are synchronous scene rebuilds, not seamless streaming. The original finite frontier solver remains available separately. No saved dungeon progression, collision bodies, combat, multi-floor modules, visible authoring marker blocks or graphical runtime verification yet.

CI now includes extreme-address sector repeatability, reciprocal gate alignment, actual A* routes from the center to all four gates, and a dungeon scene launch check.

## Remaining work
1. Replace the initial cardinal socket toggles with physical directional marker blocks, typed pools, configurable apertures and a dedicated module construction workspace. Add multi-asset library import and rotated pair preview.
2. Extend the existing roofless section-meshed preview and local 2D navigation to true 3D occupancy, collision, cutaways and the physical Skeletal City entrance.
3. Add variable-size and multi-floor modules, vertical stairs, alignment offsets, reserved clearance volumes, terrain carving, boss/key/quest placement, and a typed pool/transition policy.
4. For endless dungeons do not extend a mutable random frontier in player exploration order. Plan bounded sectors using exact signed integer addresses, deterministic seeds, shared border sockets and a guaranteed backbone. Stream only nearby sectors and keep persistent edits/rewards keyed by site and cycle. Cap terminal branches; never promise infinite in-memory assembly.
5. Use WFC for local architecture and optional compatible modules, not as the sole guarantee that mandatory paths connect. Reserve critical graph routes, then solve and validate the geometry.

No Alpha or stable changes, APK or confirmed runtime verification. The new scene and creator import/export are committed source code.

## Multi-prefab packs and city site linkage

The lab supports a versioned `outpost:dungeon_pack` envelope with a namespaced pack ID, 0–100 loop percentage and up to 64 named captured modules (4 MB JSON limit). Modules are validated before registration, sorted by ID, and duplicate IDs are refused. The current sector generator uses only the standard stone_corridor type and fixed module aperture. Creator controls add captured modules to a local pack without replacing existing IDs. Dungeon Lab imports that pack or the original single module. Zero loop density keeps the spanning tree; 100 percent adds all possible cardinal grid edges. Neither value guarantees an arbitrary specific authored room will be selected.

The keep in City Lab can now open its address-derived dungeon. Enter keep dungeon routes to the keep first; activate again at the destination. The scene tree retains the original city seed and exact integer region identity and returning restores the city at its keep. Dungeon seed is a derived 32-bit RNG seed, not the full persistent site ID. This is a lab scene transition, not a physical underground entrance. Dungeon progression is not saved. The full site identity is retained in memory only during the preview. Pack modifications change future layouts; persistent production sites will need to pin pack versions/fingerprints.

Added pack/loop/site tests are not yet runtime verified. The desktop-only WorldEdit console and flight controls are design-only, see [CREATOR_STUDIO_PC_PLAN.md](CREATOR_STUDIO_PC_PLAN.md).
