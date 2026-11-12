# World map overhaul — Alpha v1061 recovery

## Recovery continuation
Recovered from `rescue/diorama-map-wip` at `5cae365`.
A separate review branch fixes POI revision propagation, rejects impossible
saved discovery cells that would stall the relief queue, and adds tests for
minimap tap-to-open and malformed saves. Generated `.import` files, logs,
and screenshot artifacts are omitted from the review diff; they remain
available in the immutable WIP recovery commit.

**Validation gate:** Run targeted Godot 4.7.2 CI plus Android landscape and
desktop GPU visual checks before Alpha merge. Tests logged earlier by Codex
predate the final shader, minimap and save changes; do not cite those as proof
the recovered final tree is tested. Stable/main must not be touched.


Branch: `feature/diorama-map-foundation`.

The title border fix (`d554b73`, PR #132) and newer shoreline/foam fix
(`264b1dd`, PR #133) were merged into this branch in `4347646`. The newer
shoreline implementation replaces the earlier local water correction. Both
requested detached reference worktrees point at `264b1dd`.

## Implemented in the working tree

- A separate map World3D containing only simplified terrain and scenery meshes.
  Fullscreen and circular minimap cameras share this geometry and MapService.
- Responsive viewport aspect and nearest filtering, 50-degree orthographic
  view, island-centred overview, free pan beyond today's finite island,
  wheel/pinch zoom, optional right-drag rotation, player/overview controls.
- M and minimap tap open; M, Escape, close button and Android Back close.
  Modal input routing blocks movement, skills, consumption and interaction.
- Exploration follows player coordinates, not map cameras. Unexplored cells
  have no rendered geometry; previously explored geometry is dimmed. Cells,
  discovered POIs, scenery snapshots and layer preferences save under
  `map_state` alongside the existing v5 player data, keyed by world seed.
- Discovered-place search, zone labels, station/rarity portal markers,
  filtered resources, live disposition markers and square-framed player arrow.
  Creature records originate from actual loaded entities. Current boars stay
  hostile; passive/neutral glyph support does not add nonexistent wildlife.
- Player combat transitions are driven by attacks and incoming damage, with
  a six-second activity timeout. Map closes immediately on transition and
  cannot reopen during combat. Merely seeing a hostile does not trigger it.
- Cached 12m terrain samples, incremental 48-cell sampling, at most one mesh
  build per tick, per-chunk invalidation, 256 map mesh cap, 64 sample-cache
  chunks. Camera orbit does not resample or rebuild terrain. Both viewport
  updates are throttled except while interacting with the full map.

## Validation so far

Passed headlessly: `world_map_overhaul` (initial integration coverage),
`pc_cross_platform_controls`, `visual_world_minimap` (legacy fallback),
`diorama_map_foundation`, `coastal_ocean_swim_safety`,
`android_opaque_terrain_water`, `title_approved_raster_smoke`,
`title_ambient_polish_smoke`, and the earlier camera/resource collision tests.

Desktop OpenGL Compatibility captures exist under `artifacts/map/`: overview,
close and minimap. The first two were visually inspected. These use a scripted
fully explored QA world, not a fresh player's discovery state. The second
capture corrected the first fixture, which allowed combat to close the map.

`hud_topbar_camera_zone_v2` exposed initial filtering being set too late; the
initial nearest-filter setup is now corrected but awaits rerun. Additional
radar lifecycle and old-save assertions were added to `world_map_overhaul`
after its last passing run. Those additions and the latest minimap centring
and discovery-reset edits also await rerun.

Godot runs report existing log/certificate-access and renderer teardown
warnings. An actual stale-boar transform error was identified in a control
test and fixed by checking tree membership before reading its live record;
the changed path still needs the next test run.

## Remaining review

On the user's request, **all Godot launches are paused while they play League**.
Do not launch a graphical or headless Godot process until they resume testing.

- Rerun the checks identified above and repeat visual QA after subsequent edits.
- Inspect landscape/mobile filter layout, touch release/echo handling, and
  viewport changes on a physical Android device. No device performance claim.
- The supplied screenshot references were not attached; exact angle and
  maximum close zoom comparison remain unverified. The 9m zoom-in limit uses
  the earlier local map's 12m limit as reference.
- Terrain currently uses coarse 2m relief geometry and simplified tree/rock/
  station miniatures. Original textures, high-detail close LOD, dedicated
  quest-location providers, party markers, editable waypoints and detailed
  marker portraits are not implemented in this increment. Unavailable quest
  positions or wildlife are not invented.
- Existing dungeon graph UI remains intact; the overworld viewer is unavailable
  inside dungeon instances rather than leaking overworld entities there.
- Full explored-island geometry fits the current 256-chunk cap. Future larger
  worlds need additional far-distance LOD; panning already works outside the
  current bounds without inventing terrain or loading gameplay chunks.
- No APK, PR or Alpha merge for this overhaul yet. Stable/main untouched.

The earlier Space-to-interact, resource auto-hop and camera-clearance changes
remain on this branch. See `CAMERA_RESOURCE_COLLISION_ALPHA.md`.
