# Outpost Creator Studio — PC-only developer tooling plan

Status: design only. Do not implement this console or fly mode in Alpha, stable, or the Android RPG. The City/Dungeon Lab remains an isolated generation prototype. A later desktop developer build should be a separate executable/export preset, with a separate save namespace and content-pack output directory. An APK is Android packaging; a separate optional Android developer APK could expose touch-friendly previews, without desktop commands. No APK is created by this plan.

## Command contract (proposed)

| Command | Meaning |
|---|---|
| /pos1 [x y z] | First inclusive voxel corner, default targeted block |
| /pos2 [x y z] | Second inclusive voxel corner |
| /wand | Toggle selection tool; first/second click select corners |
| /set <material> | Replace selected volume |
| /fill <material> [bounds] | Fill selected or explicitly bounded region |
| /copy | Capture selection into a clipboard with local anchor |
| /paste [anchor] | Stamp clipboard at target (transparent or replace-air mode explicit) |
| /clone <source bounds> <destination> | Copy to another position; snapshot first for overlap safety |
| /rotate <90/180/270> | Rotate clipboard geometry and directional markers |
| /undo, /redo | Reversible validated edit transactions |
| /prefab save <id> | Export versioned asset, bounds and authoring markers |
| /prefab load <id> | Import validated prefab for placement/editing |
| /prefab validate | Check geometry, sockets, clearance and supported marker types |
| .fly | Toggle creative movement, Space ascends/jumps, Shift descends |

Provide optional Minecraft/WorldEdit-style double-slash aliases, but keep the grammar explicit. Coordinates are local within an addressed developer region; a global address is an integer tuple, never a float vector. Selections display exact dimensions and estimated block count before large edits. Large selections use bounded batches, with undo as a single logical transaction. Never write millions of blocks synchronously from an unvalidated command.

## Flight

Implement a dedicated creative controller, not real persistent invisible air blocks. If the desired feel is jumping off an invisible support surface, simulate a temporary player-local support plane or no-gravity vertical movement; Space ascends and Shift descends. No changes to the voxel store, mesh, save, pathfinding or multiplayer world. Turning flight off must find a safe standing cell or refuse the transition.

## Separation and permissions

The console and authoring tools are compiled/exported only in the standalone developer build. No arbitrary shell commands or executable scripts from content packs. The normal game consumes validated data-only packs through the shared world/asset APIs; it does not need the creator UI. Developer commands are never accepted by public gameplay servers unless a future authorized server-side admin policy explicitly exposes a narrow equivalent.

## Physical authoring markers

Creator mode should display Structure, Connector, Generator, Spawner, Loot, Trigger, Door, Checkpoint and Exit markers as selectable blocks. They are metadata stored separately from solid voxels. Rotate positions and directions with the prefab; validate typed sockets and aperture against occupancy. On runtime materialization, convert markers to supported data-defined behaviours or remove them from visible geometry. Do not allow arbitrary scripting by default.

## Implementation order when authorized

1. Shared selection/clipboard transaction API (reuse City Lab capture, overlays, validation and dirty-section remesh).
2. Separate desktop developer entry scene and export preset, no changes to shipped RPG.
3. Command parser with grammar/permission tests and selection wand.
4. Creative movement and camera with safe exit.
5. Multi-module library, visible connectors and generator configuration, validation previews.
6. Save/load/export, versioning, larger section-spanning assets and bounded asynchronous edits.
7. PC runtime verification, then optional touch developer APK only if desired.

The present implementation task remains city and dungeon generation, not the console.
