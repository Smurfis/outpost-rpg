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

## Run

```powershell
godot --path . 
godot --headless --path . --script res://tests/terrain_city_lab_plan.gd
```

Use your existing checkout if storage is tight. Do not create a second full clone simply for this experiment. The branch changes project.godot's main scene and display name; do not merge this configuration into Alpha.

CI checks five seeds, deterministic repeat generation, far-address identity, adjacency and socket constraints, cardinal terrain steps, greedy rectangle area, cross-section face culling and a successful scene launch marker. These checks are defined but are not proof they passed until a successful CI run is observed.

## Explicit limitations / next integration gates

- The current model is a single 88x88 site with a sparse voxel dictionary. No streaming, packed palette storage, native extension, threaded scheduling, region seam contract or camera-relative multi-region rendering yet.
- JSON defines parameters and entrance constraints for five built-in architecture grammars, not arbitrary imported block shapes. Next: versioned prefab voxel buffer with bounds, typed sockets, rotations, selection/export and round-trip tests.
- Street planning is terrain-aware at lot scale, not a full island road graph. Adjacent region continuity and coast/river/bridge placement are not implemented.
- Lab uses roofless architecture and grid-following movement, not the RPG's physics, cutaway, combat or site registry. The old stacked spiral remains separate; integrate it only after a shared 3D occupancy/vertical section contract is verified.
- No Vulkan benchmark, APK, server replication or Android validation yet. Keep renderer Compatibility until evidence supports changes.
- No changes to Alpha or stable are needed for this lab.

Do not promote the branch to the live game until the deterministic suite passes, graphical movement and visibility are tested, and an isolated Android package (separate application ID) is built and tested.
