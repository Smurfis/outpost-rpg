# Physical Goblin Mineshaft stability

## Cancelled route

On the original desktop controller, seed 64013, the return to the tunnel junction stopped at physics tick 1249. The click-to-move controller had accepted (175.5, 0.1, 61.5). At (175.50, 0.90, 59.55) the player was moving at 5.1 units/s with three waypoints left. The target chunk was resident and its cave floor was still at Y=0. The contact list was empty. Stick, keyboard and recoil were zero, health was full and the UI had no modal open. The stop stack was `_notification → cancel → stop_interaction_move`. The old lifecycle handler cleared the route for either application focus loss or pause. The old trace did not retain the notification number. The three original 5A reports had no stop stacks, so they cannot each be attributed retrospectively.

The desktop controller now releases held mouse movement, rotation and shield input on focus loss and preserves an accepted ground route. Pause, target interactions and touch retain their cancellation semantics. The new regression delivers focus loss to a real projected-floor click, compares the pending waypoint array, waits for physical arrival, and separately checks that pause cancels. Route diagnostics can be enabled with `OUTPOST_TRACE_MOVEMENT=1`. They record the initial ray hit and plan, waypoint and view changes, occupancy and loaded state at the destination, the current screen pick, physical contacts, manual inputs, route age and stop call stack. A moved camera can project a different surface at the old click without changing the original world destination.

A controlled headless replay delivered the identical desktop focus-out notification to both controllers at the mine entrance. The 5A controller cleared all 33 waypoints. The 5B controller retained all 33 in order. The graphical regression also walked the full route out to the surface and back into the mine three times. Those surface crossings covered 55 presented frames and measured 59.8 / 61.4 / 79.0 ms (p50 / p95 / maximum).

## Live frame measurements

Godot 4.7.2 GL Compatibility, AMD Radeon integrated graphics, Windows desktop at 50 Hz, 1280×720, offscreen non-focusable game window. Seed 64013, isolated saves and one game instance. The live fixture enables the normal game, terrain, cutaway, day/night, physics and HUD loops. It issues movement and combat commands from a script. Whole-frame intervals use consecutive post-draw timestamps. PNG readbacks, route tracing and GPU queries are disabled during the normal measurements. These are local desktop observations.

Both comparison runs use the focus fix so that the routes finish. The before run uses the 5A mesh builder. Both follow the same route and use the same renderer, VSync and instrumentation. Combat includes approach to the miner and fighting. Return and re-entry pool three or more traversals. The outdoor walk only spans the three metres to the entrance, so its eight frames give a weak tail estimate.

| Scenario | Frames before / after | Before p50 / p95 / max (ms) | After p50 / p95 / max (ms) |
|---|---:|---:|---:|
| outdoor idle | 36 / 36 | 60.9 / 81.4 / 140.8 | 61.0 / 81.2 / 139.6 |
| outdoor movement | 8 / 8 | 60.1 / 61.0 / 61.0 | 60.3 / 79.6 / 79.6 |
| underground idle | 36 / 36 | 60.0 / 79.8 / 80.4 | 60.2 / 80.5 / 81.4 |
| underground movement | 42 / 41 | 60.1 / 140.1 / 160.2 | 60.5 / 159.1 / 183.1 |
| combat | 59 / 56 | 60.6 / 100.4 / 200.0 | 61.0 / 119.4 / 179.4 |
| return to entrance | 471 / 469 | 60.1 / 80.0 / 359.9 | 60.1 / 80.3 / 119.5 |
| repeat mine entry | 370 / 368 | 60.1 / 61.3 / 80.6 | 60.1 / 79.3 / 81.0 |

## Where the time goes

- Presentation dominates the steady 60 ms cadence. In the fixed outdoor pose with VSync enabled, disabling the entire 3D viewport still measured a 60.0 ms median. With the scene restored, switching VSync off gave 7.8 ms in that diagnostic. In the matched candidate, VSync-off medians were 8.9 ms outdoors and 11.7 ms underground. The engine frame cap was zero and low-processor mode was off. The precise driver/compositor scheduling behaviour on this 50 Hz desktop remains unresolved.
- With VSync off, hiding only the distant ocean produced 8.1 ms outdoors and 10.9 ms underground. Hiding streamed island terrain and retaining the ocean gave 7.3 and 11.3 ms. Disabling the 3D viewport gave 4.9 and 5.2 ms. These are short, separate trials with overlapping work. GPU timers in a separate full-scene sample reported 8.0 and 7.5 ms p95. Rendering contributes to uncapped cost. None of these probes changes gameplay graphics settings.
- During the first underground approach, p95 wall times were 143.7 ms between pre-draw and post-draw, 19.5 ms in the idle processing phase and 16.2 ms in the physics phase. A physics phase can encompass multiple fixed steps per presented frame. Individually instrumented stages peaked at 14.7 ms for terrain streaming, 4.0 ms for cave masks, 2.8 ms for building faces, 6.9 ms for publication, 0.3 ms for player path planning and 2.2 ms for mine goblin processing. During combat the goblin processes peaked at 8.3 ms and face preparation at 18.6 ms. Idle, physics, submission and subsystem counters overlap. Submission wall time includes presentation waits and does not measure GPU execution alone.
- On repeated returns the highest observed interval fell from 359.9 to 119.5 ms. Median pacing barely changed, and some p95 intervals rose. One matched run per implementation cannot establish a repeatable improvement in tail latency.
- The separate graphical acceptance run measured 60.0 / 79.6 / 100.4 ms during live backtracking, close to 5A’s 60.1 / 78.4 / 100.4 ms. In its stationary VSync-on GPU-query phase the driver reported 50.6 ms GPU at p95 and 4.2 ms viewport CPU. That GPU number varies markedly from the uncapped probes and from 5A’s 5.7 ms VSync-on GPU sample. These runs cannot assign every stall to the GPU or isolate the compositor.

The graphical mine walkthrough also timed individual systems directly. Its main game manager took 1.87 ms p95 and 3.54 ms maximum. Terrain and water updates took 0.05 / 13.94 ms, and navigation planning peaked at 0.62 ms per command. These measurements put a bound on the script work that the broader idle-phase interval includes.

## Mesh reconstruction

The builder now reads the existing terrain occupancy bit column directly and translates packed unit-face arrays in the engine. It retains the same one-block sill, caps, material mapping, picking surfaces, fixed terrain collision and publication policy. A separate headless comparison alternated execution order across eight headings in the final chamber. It built all 156 patch variants with each implementation and compared every vertex, normal, UV, atlas tile and cut-face count. All matched. Cumulative cold reconstruction fell from 491.9 ms to 210.6 ms (57%). These timings exclude GPU upload and do not represent a single-frame saving.

## Verification

The seed 64013 graphical mine walkthrough passed both goblin fights, underground enemy and chest picks, guarded and duplicate treasure checks, four camera headings, surface restoration, partial and full chunk reload, and save reload. Peak estimated cutaway cache was 15,715,248 bytes. The seed 64012 four-room regression passed with 112 evictions. Additional headless passes covered section mesh generation, world-site registry and streaming, mouse and keyboard bindings, isometric picking, cave camera, chunk streaming, island ocean mask and gameplay smoke.

## Reproducing the measurements

Run `tests/mine_stability.gd` as a Godot SceneTree script with GL Compatibility and isolated user data. It prints per-scenario sample counts followed by p50, p95 and maximum microseconds in this order: whole frame, render submission, idle processing, physics, terrain streaming, cave mask, faces, publication, player planner, mine goblins and GPU. The fixture enables `OUTPOST_PROFILE_MINE=1` before creating the world. GPU timing is collected only in the explicitly named GPU scenarios. Run `tests/physical_mineshaft.gd` separately for treasure, chunk unloading and save/reload verification.

Android CPU, GPU, presentation pacing and touch lifecycle behaviour remain unmeasured on hardware.
