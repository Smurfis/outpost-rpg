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

## Remaining work
1. Creator UI: place directional markers on faces of captured pieces; attach named socket types, pool, weight and aperture. Preview rotated pairs and report errors before export. The pure registry accepts captured voxel payloads now, but marker editing and import into the running dungeon are not yet wired.
2. Render/physics: adapt materialized module occupancy to the City Lab section mesher and shared 3D navigation; later attach to the physical Skeletal City entrance.
3. Add variable-size and multi-floor modules, vertical stairs, alignment offsets, reserved clearance volumes, terrain carving, boss/key/quest placement, and a typed pool/transition policy.
4. For endless dungeons do not extend a mutable random frontier in player exploration order. Plan bounded sectors using exact signed integer addresses, deterministic seeds, shared border sockets and a guaranteed backbone. Stream only nearby sectors and keep persistent edits/rewards keyed by site and cycle. Cap terminal branches; never promise infinite in-memory assembly.
5. Use WFC for local architecture and optional compatible modules, not as the sole guarantee that mandatory paths connect. Reserve critical graph routes, then solve and validate the geometry.

No Alpha or stable changes, APK, scene integration, or runtime verification in this stage.
