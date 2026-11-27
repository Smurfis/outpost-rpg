# Default settlement integration — Alpha first

This branch starts directly from Alpha, not City Lab. The existing game scene, Android controls, save format, starter camp and Goblin Mineshaft remain the intended baseline.

## Default content

The third exploration island (center 18,232) receives a bounded deterministic settlement. Candidate building sites avoid cave columns and their immediate neighbors; the layout preserves the original terrain height field. A weighted cardinal A* graph permits only one-block steps. It connects a hub to a reachable western shore and to up to four built-in building entrances. Buildings are selected on shallow foundations with a three-block-wide entrance. The default architectural kit is watchtower, smithy, storehouse and house; generation must place at least two or omit the settlement rather than publish an inaccessible site. These are architectural buildings only, not functioning NPC shops or crafting stations yet.

Road material is returned by the same island top-tile sampler used by terrain geometry and the map. No separate road overlay mesh or editor is needed. Settlement planning is lazy, only near the third island; current implementation is synchronous and should be profiled on Android. Each structure is attached to its anchor chunk and unloaded with it. This initial experiment does not yet guarantee a seamless appearance at the streaming radius.

## Camera and navigation

Buildings use a bounded voxel grammar with atlas-safe greedy rectangle merges. Floor/foundation, four wall groups and roof are independently rendered. Shared faces between visibility groups are retained so a hidden wall does not remove exposed caps from an adjacent visible group. The same physical collision bodies stay on gameplay layer 1. For an occupant at interior height, roof and camera-facing wall groups are hidden based on the actual existing camera position; the established WorldPicker building_cutaway_hidden convention skips only those bodies for selection. Leaving restores the complete exterior. No global camera angle, pitch, rotation controls, cave cutaway shader or cave picking policy is replaced.

The existing click-to-move graph uses cell-center samples near the settlement and samples inside the building below the roof. Wall cells are excluded; above-floor roof destinations are rejected. Physical capsule-width checks and step limits remain authoritative.

## Verification gate

The new default_settlement regression checks repeatability, placement, roads, entrance slopes, greedy mesh reduction, eight directions of cutaway state, picker flags and restoration. These are source-level checks until CI passes. Still required: full game walkthrough using touch tap and orbit, player path into/out of each building, actual pick-ray results in all orientations, stream out/re-entry, mine/save regression, Android frame time and screenshot comparison, then signed Alpha APK. The starter camp is untouched. No merge, Alpha release or APK has been made by this branch.

## Scope

The standalone PC developer tools and mod authoring are deferred. The experimental City Lab and dungeon connector solver are reference prototypes, not dependencies of this branch. Larger cities, WFC district planning, multi-island POI road networks, Skeletal City, native optimizations and physical underground connectors should follow the first validated settlement rather than replace it.
