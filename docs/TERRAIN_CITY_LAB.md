# Terrain City Lab — consolidation prototype

This is an isolated experiment based on feature/skeletal-city-mountain. It does not open or modify live RPG saves. The project launches the lab scene on this branch only.

## Implemented pipeline

1. Exact signed integer region address and world seed are hashed into bounded local terrain/district seeds. This is site-local addressing, not yet a continuous global terrain field.
2. FastNoiseLite fractal terrain, central terrace blend, and a cardinal one-block slope limiter.
3. Four gate approaches use weighted A* on the lot grid, with a reserved central ring; steeper lots cost more.
4. Versioned JSON prefab definitions specify weights, height, material, allowed entrance directions and road requirements. Constrained WFC applies thematic adjacency and road requirements.
5. BSP subdivides the keep. Mandatory routes are repaired through the central cross and room entrances.
6. Terrain, walls and furnishings produce one occupancy dictionary. Walkability checks the actual ground and two-block clearance. Flood-fill validates public streets, keep and selected road sockets.
7. A greedy mesher groups exposed faces by section, direction, plane and material, merges compatible rectangles, and culls internal faces across section edges. Mesh vertices are section-local.
8. The Godot lab presents an isometric camera, seed switching, movement, gate-to-keep navigation, and a far-region switch (+10^12,-10^12).

## Creator layer

The scene now includes a bounded two-corner voxel selection workflow. Select solid or adjacent air, optionally change Y offset, then choose two corners. Fill replaces the selected cells with a chosen material; Erase removes them. Undo retains up to 32 accepted patches. Edits are rejected and rolled back if they disconnect mandatory city destinations or the player's current cell. The prototype allows construction in the local city volume only, not full terrain traversal on new levels.

Capture exports selected occupied voxels as a versioned JSON prefab (up to 24 blocks along each axis). Rotate and Stamp use quarter-turns, with transparent air (only occupied cells are placed). Export/Import use a fixed local file, `user://city_lab_prefab.json`. Import validates dimensions, integer coordinates, material range, duplicates and placement bounds. There is no arbitrary script execution or asset file browser.

World changes are stored separately from the generated baseline using a seed, signed decimal region address and generator version. Save World writes a temporary file and renames it into place. Seed/region switches, reload, desktop close and mobile pause attempt to save unsaved edits; invalid existing overlays are refused rather than overwritten. This is local JSON persistence, not a crash-tested journal or multiplayer transaction service. Successful edits rebuild only touched 16³ mesh sections and face-neighbour sections, then rebuild the small local navigation grid.

Creator regression checks cover reversed inclusive selection, capture/JSON/rotation, stamp bounds, overlay replay, wrong-region rejection, invalid prefab rejection, undo, blocked-spawn rollback, dirty boundaries and disk write/replacement.

## Run

```powershell
godot --path . 
godot --headless --path . --script res://tests/terrain_city_lab_plan.gd
```

Use your existing checkout if storage is tight. Do not create a second full clone simply for this experiment. The branch changes project.godot's main scene and display name; do not merge this configuration into Alpha.

CI includes creator/persistence checks and checks five seeds, deterministic repeat generation, far-address identity, adjacency and socket constraints, cardinal terrain steps, greedy rectangle area, cross-section face culling and a successful scene launch marker. These checks are defined but are not proof they passed until a successful CI run is observed.

## Explicit limitations / next integration gates

- The current model is a single 88x88 site with a sparse voxel dictionary. No streaming, packed palette storage, native extension, threaded scheduling, region seam contract or camera-relative multi-region rendering yet.
- The regional JSON registry still defines five built-in grammars. The creator can capture and import arbitrary bounded voxel shapes for manual stamping, but imported shapes do not yet automatically become WFC candidates. Next: typed socket metadata, asset library and deterministic generator integration with content-pack versioning.
- Street planning is terrain-aware at lot scale, not a full island road graph. Adjacent region continuity and coast/river/bridge placement are not implemented.
- Lab uses roofless architecture and grid-following movement, not the RPG's physics, cutaway, combat or site registry. The old stacked spiral remains separate; integrate it only after a shared 3D occupancy/vertical section contract is verified.
- No Vulkan benchmark, APK, server replication or Android validation yet. Keep renderer Compatibility until evidence supports changes.
- No changes to Alpha or stable are needed for this lab.

Do not promote the branch to the live game until the deterministic suite passes, graphical movement and visibility are tested, and an isolated Android package (separate application ID) is built and tested.
