# Procedural cave trial

Set `OUTPOST_TEST_PROCEDURAL_CAVE=1` to grow a seeded set of branches from the first Fractal Island tunnel. The older `OUTPOST_TEST_SIDE_CHAMBER=1` fixture takes precedence if both flags are set. With both flags off the original layout is used.

The generator accepts two-lane branches only where terrain can supply a roof and stone boundaries. It retains the existing entrance, trunk and end chamber. Each branch supplies floor cells, a passage and a room to the existing navigation and visibility systems. The same geometry and picking cache serves all rooms. If the generator cannot fit two branches it discards the trial additions for that seed.

## Graphical walkthrough

Godot 4.7.2 GL Compatibility, Windows, integrated AMD Radeon graphics, 1280×720, seed 64012. The isolated fixture starts the adventurer at the entrance. All travel after placement uses the movement controller. It follows each branch, rotates through four cardinal headings and checks torso visibility every ten degrees. It selects visible floors, a chest and a live enemy, then backtracks with directional movement and exits at the surface.

| Room in visit order | Junction X,Z | Centre X,Z | Walkable size | Floor Y | First activation |
|---|---|---|---|---:|---:|
| Eastern branch | 183,64 | 183,54 | 5×3 | 1 | 0.40 ms |
| Northern branch | 170,60 | 170,53 | 7×3 | 0 | 0.56 ms |
| Southern branch | 170,61 | 170,68 | 7×3 | 1 | 0.61 ms |
| Original end chamber | — | 158,64 | 5×5 | 0 | 0.60 ms |

Each room used prepared patches on first entry. One intervening passage required 19 synchronous patches and took 46.03 ms. The cutaway followed the occupied passage, retained the floor and enclosure, and restored the surface. A small bright square is visible on the hillside outside the eastern chamber in the 0° view. Its source was not isolated. The captures show no ocean inside the chambers.

The walkthrough exited with status 0. Godot reported render-resource and ObjectDB leaks at shutdown, also seen in the previous milestone. The test did not establish their origin.

[Connected walkthrough](../artifacts/cave_render/procedural-trial/walkthrough.png) · [Four headings in each room](../artifacts/cave_render/procedural-trial/rotations.png)

## Timings

The trial counts draw-to-draw wall time while walking, excluding screenshot capture calls. Navigation samples time a separate invocation of the real route planner. The fixture explicitly drives streaming, the game manager and the camera on a fixed simulation timestep. Rendering wall time includes driver work and waiting. The counters overlap and their maxima can occur on different frames.

| Walking measurement in ms | p50 | p95 | Worst |
|---|---:|---:|---:|
| Whole-frame draw interval | 59.65 | 60.97 | 301.34 |
| Terrain streaming and water | 0.05 | 0.07 | 16.15 |
| Cutaway update | 0.24 | 3.96 | 45.70 |
| Mask preparation | 0.00 | 3.68 | 4.14 |
| Face preparation | 0.00 | 2.65 | 29.50 |
| Mesh and picking publication | 0.00 | 1.50 | 13.88 |
| Physics phase outside the timed fixture updates | 1.95 | 3.05 | 5.22 |
| Navigation per command | 0.28 | 0.60 | 0.62 |
| Main game manager | 1.39 | 1.94 | 2.36 |
| Render submission wall time | 50.58 | 55.09 | 295.75 |
| Godot viewport GPU | 6.54 | 45.13 | 54.59 |

Godot's viewport render CPU timer returned 2.69 ms at p50 and 4.27 ms at p95. Its delayed maximum exceeded two seconds and cannot be attributed to a particular walking frame. Render submission accounted for most of the observed walking interval. The GPU counters alone do not account for the longest stall.

Cold camera turns still finish visible geometry synchronously. The worst observed turn took 68.23 ms, including 22.76 ms projecting the mask, 29.24 ms preparing faces and 12.90 ms publishing. The previous two-room trial reached 62.67 ms. The terrain change samples occupancy once per column and computes exposed faces from neighbouring bit masks. The same representation replaces individual solid-voxel queries when intersecting the cutaway mask. In the initial headless profile, the terrain update had peaked at 24.73 ms. That and the graphical peak above were measured under different render workloads.

The four-room walk peaked at 15.01 MiB of estimated cache payload, with 113 variant evictions, 1,317 published patches and 741 exact patch reuses. Driver memory, object overhead and transient jobs are outside the estimate. The configured maximum remains 18 live views. Layout repeatability and occupancy were checked across five seeds. The walkthrough and hardware timings cover one seed and one Windows machine. Android remains unverified.
