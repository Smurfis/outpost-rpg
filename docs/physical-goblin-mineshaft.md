# First physical Goblin Mineshaft

The default first Fractal Island has a timber-marked entrance on its eastern shoulder. Follow the descending stone passage into the branches. The miner and foreman guard the strongbox in the 7×7 end chamber. Ore deposits and supply crates use existing world-object interactions. The branch generator and both earlier development flags continue to work independently.

The mine uses a distinct per-world site identity, leaving existing portal records readable. Its layout uses the registry's initial-cycle seed. Defeats are written immediately to stable encounter slots. The strongbox uses the normal player inventory and remaining-contents save, followed by a site receipt. Loading a fully emptied chest repairs a missing receipt. Unloading a chunk removes the local actors and props. Defeated guards stay defeated. Living guards may respawn at their placement after unloading. Regeneration is outside this slice.

## Verification

Godot 4.7.2 GL Compatibility on Windows, AMD Radeon integrated graphics, 1280×720. Tests ran sequentially with isolated saves. The physical mine used world seed 64013 and layout seed 837339951. Its three side chambers are centred at (165,55), (175,54) and (166,71). The final room is centred at (158,64). The earlier four-room trial also passed on seed 64012.

The first graphical walkthrough completed both fights, screen picking, treasure collection, backtracking and reload. A second run beginning farther out on the hillside reached all rooms and returned to the surface, but reported three cancelled automatic walks. At the first cancellation the player was at (179.63,0,64.25), with only a floor contact recorded after stopping. A focused graphical replay passed and the complete final headless walkthrough passed from the hillside. The cancellation trigger remains unresolved.

The final headless test also selected and collected ore and crate supplies, checked the locked chest before the last kill, confirmed the exact payout, unloaded and rebuilt a partially cleared encounter, and reloaded both save files in a new main scene. The layout, mesh, cave camera, picking, controls, chunk streaming, ocean mask, site registry, legacy portal, dungeon and gameplay smoke regressions passed.

[Walkthrough](../artifacts/cave_render/physical-mine/walkthrough.png) · [Four rooms at four headings](../artifacts/cave_render/physical-mine/rotations.png)

## Performance and visual diagnosis

With the same camera and room, the final graphical session measured these intervals in milliseconds. The live samples used normal game, terrain and camera processing. The window was offscreen, so foreground pacing on the laptop is unverified.

| Draw-to-draw interval | Median | p95 | Worst |
|---|---:|---:|---:|
| Fixture, stationary | 59.98 | 61.46 | 61.94 |
| Live game, stationary | 59.92 | 61.50 | 61.59 |
| Live game, directional backtracking | 60.07 | 78.40 | 100.43 |

The roughly 60 ms median persisted with manual fixture updates removed. The earlier 301 ms spike did not recur during live backtracking in these two mine runs. The earlier mine run peaked at 198 ms on backtracking. Rendering submission includes driver and presentation waits. The final stationary GPU-instrumented sample measured 5.71 ms GPU and 3.57 ms viewport CPU at p95. Those samples do not identify the cause of every long frame.

During the initial successful graphical walk, terrain streaming peaked at 21.35 ms, the physics phase at 4.50 ms, route planning at 1.09 ms and the main game manager at 2.56 ms. The coldest heading in that run took 103.41 ms including 43.03 ms preparing the mask, 37.27 ms building faces and 19.12 ms publishing. Cold turns remain synchronous to preserve correct immediate picking and visuals. The final graphical run peaked at 76.07 ms for a cold turn and 14.98 MiB of estimated cached payload. Dedicated uncut shadow meshes now cast island shadows once per surface.

In the old eastern-room pose the bright pixel projected onto the remote portal's emissive gate and pulse. Hiding the gate reduced its RGB values from approximately (0.95,0.95,0.94) to (0.56,0.59,0.53). The physical entrance has no portal glow. The shutdown leak reproduced as orphaned steel sword meshes after equipping the player. Freeing the temporary node after transferring its mesh and material removed those orphans and the corresponding shutdown leak messages. Android remains untested.
