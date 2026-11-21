# Fractal Island chamber streaming

The streamer prepares the occupied region at the current camera heading first. Within eight cells of a threshold it prepares the facing views of up to two connected regions, ordered by distance. It then prepares the adjacent headings for the player and the closest threshold. The entrance approach uses the nearest region anchor. The plan changes when the player crosses a voxel boundary or turns into another camera sector.

Visibility uses the existing stepped sightlines and one-block collision sill. Preparation can pause between mask columns or mesh columns. A requested view that is still cold finishes synchronously before the next draw. Both the render mesh and its matching selection body change together. Physical terrain bodies continue to handle movement.

## Cache lifetime

Each 12×12 streamed chunk has four 6×6 replacement patches. Two views share a patch and its picking body when their hidden occupancy matches over the whole patch and its one-column border. Different patches can also reuse previously calculated vertices for the same world column. The cache retains up to two exposed-face patterns per column.

The limits are 18 live region/heading variants, 32 additional completed visibility masks and 64 pages of reusable column data. Published mesh and pick data have a 12 MiB soft target. Eviction protects the active and planned views, then favours retaining the current region, its neighbours and recently used variants. Shared resources are released after the last reference. Invalidating the island's geometry drops all three caches, including paused jobs.

## Measurement

The graphical walkthrough uses Godot 4.7.2 GL Compatibility on Windows with AMD Radeon integrated graphics, at 1280×720, with isolated saves and the side-chamber test flag. It follows the entrance and junction into both chambers, rotates in each, picks visible floors and the chest, probes a solid wall, exits, then drives the reverse traversal with directional movement. The fixture also forces abrupt heading changes to exercise the cold fallback. It drives cutaway and streaming explicitly, so these measurements describe the fixture workload.

The cache estimate counts 52 bytes per published triangle vertex for mesh attributes and pick positions, plus 40 bytes per retained column vertex. Driver allocations, physics acceleration structures, dictionaries and transient jobs are outside that estimate. Draw-to-draw intervals include other scene work and scheduling on the host. The cutaway timer measures only the update on the main thread.

| Final graphical walkthrough | Observed |
|---|---:|
| Entrance prewarm | 3.80 s, 54 updates, 47 patches |
| Peak update during entrance prewarm | 5.21 ms |
| First side / end chamber activation on foot | 0.69 / 0.54 ms |
| Side chamber activation on re-entry | 0.79 ms |
| Walking cutaway update, 95th percentile / maximum | 3.96 / 10.00 ms |
| Worst cutaway update including forced heading jumps | 62.67 ms |
| Walking draw-to-draw interval, 95th percentile / maximum | 77.28 / 252.89 ms |
| Peak estimated cache payload | 14.73 MiB |
| Walk and orbit totals | 1,237 published patches, 700 exact patch reuses, 20,528 column reuses, 83 variant evictions |

The previous graphical measurement on `e272c38` spent 22 s warming all 48 views, peaked at 17.3 ms per prewarm update and retained 35.3 MiB. The shorter entrance time above prepares the local plan. Both rooms continue warming as the player walks. The earlier 0.60 ms post-warm peak measured a fully resident cave. Incremental preparation adds work during movement.

An instrumented headless baseline spent 0.57 s projecting masks, 2.45 s building faces and 0.53 s publishing meshes and picks. Face construction accounted for 69% of those measured stages. On the final graphical traversal, including repeated visits and forced rotations, the corresponding cumulative times were 0.68 s, 2.23 s and 1.13 s. The two runs have different workloads and rendering drivers. In the isolated headless end-chamber check, a prepared entry and return each published zero patches. Three cold quarter-turns published 17, 17 and 9 patches.

## Verification and limits

The final walkthrough completed in both directions. The actual floor and chest passed picking checks, the solid sill blocked movement and targeting, and invalidation released the counted payload. At 270° a ray aimed at the edge of the end chamber hits the top of the sill at Y=1. The fixture checks rejection there and selects the exposed floor one metre farther into the room. The same occlusion was reproduced with the original milestone renderer.

One earlier graphical run stopped near the junction on the return to the entrance. Its only recorded collision was the floor. A traced repeat and the final run both completed. The fixture now ignores desktop unhandled input and uses an unfocusable window. The original cancellation could not be attributed conclusively.

The bounded approach is ready for a larger topology trial. Abrupt cold turns still synchronously finish visible geometry. Frame times on the integrated GPU exceeded an interactive frame budget during this benchmark, and larger rooms may exceed the soft memory target while pinned. Android performance and procedurally generated room graphs remain unverified.

[Before and after, four headings in each room](../artifacts/cave_render/streamed-section/comparison.png) · [Walkthrough captures](../artifacts/cave_render/streamed-section/walkthrough.png)
