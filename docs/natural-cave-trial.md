# Natural cave trial

Set `OUTPOST_TEST_NATURAL_CAVES=1` before starting the game. The seed 64012 trial uses the second Fractal Island. The approach is at X/Z (-201, -27), immediately inland of the northern shore. The original first-island mine retains its own layout and site record.

The hillside passage divides into three irregular chambers. The west chamber contains one cave goblin, and the east chamber contains an iron deposit and a shaft with a stepped way back to the surface. At the sinkhole, the floor rises around the open throat to the rim at (-186, -35). Distinct floor and ceiling elevations determine each column’s solid voxel mask. Both the streamed collision mesh and the camera cutaway use this occupancy. The trial supports one connected walkable floor per column. Stacked walkable tunnels and additional networks per island remain future work.

The seed and island determine encounter and ore IDs. Goblin health and defeat state travel with the player save, separately from the mine lifecycle. Ore uses the existing persistent world-object inventory. The spawn rule checks stone cover, distance from the hero and torch, line of sight and the occupied cave view. It does not create a new encounter on chunk reload.

## Verification

Run `tests/natural_cave_generation.gd` and `tests/natural_cave_walk.gd` separately with isolated user data. The first checks deterministic generation, occupied-column agreement, protected-build avoidance and reachability. The second starts the player once on the shore approach, then drives the ordinary movement, combat and interaction code. The fixture equips a torch. Its graphical run uses Godot 4.7.2 GL Compatibility.

On the Windows test laptop, generation took 16.3 ms for 155 connected columns at seven elevations. During the captured walkthrough, route planning was 0.38 ms median and 0.74 ms maximum over eleven waypoint requests. Terrain/stream updates took 0.081 ms median, 0.120 ms p95 and 26.06 ms maximum. The coldest measured camera turn took 64.25 ms. Peak estimated cutaway payload was 15.56 MiB. These are instrumented fixed-step walkthrough measurements, not device FPS. Cold turns can still hitch. Android is unverified.

[Hillside entrance](../artifacts/cave_render/natural-network/01-hillside.png) · [Goblin chamber](../artifacts/cave_render/natural-network/03-dark-chamber.png) · [Shaft descent](../artifacts/cave_render/natural-network/06-descending.png)
