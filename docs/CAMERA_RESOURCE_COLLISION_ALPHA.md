# Camera clearance and resource jumping — Alpha v1061 base

Working branch: `feature/diorama-map-foundation`. These edits accompany the
experimental map cache and shoreline correction; they are not merged or built
into an APK. Reconcile `game.gd`, `player.gd` and `resource_node.gd` with the other
v1061 work before integration.

The camera now checks a small volume at its destination rather than treating
every object along the player-to-camera sightline as a collision. Trees and
door lintels therefore do not trigger the previous seven-metre framing lift.
Actual camera overlap still requests clearance with at most eight probes;
the query and shape are reused. This does not make foreground art transparent.

Wood, stone, iron, coal and clay harvestables now have one box collider each.
`collision_height` and `collision_width` are configurable before `setup()`;
zero derives dimensions from the visible model and bundle transforms. Width
overrides both X and Z. Defaults enclose the complete model, including tree
canopies; they are intentionally simple bounds, not detailed branch collision.
All dimensions are in local world units and inherit the resource transform.

Space is now Interact on PC; manual jumping is removed. Existing automatic
terrain stepping remains at 1.05 metres. Only collided ore/rock/clay nodes
allow the configurable `max_resource_hop_height` of 1.9 metres, and the landing
must be on that same resource. Trees and walls cannot borrow this allowance.
Players can land on resources from higher ground. Harvest feedback
animates meshes only, keeping the collision stable; depletion disables the
solid and respawn restores it. Small plants and fishing pools remain walkable.

Validation: `camera_clearance`, `resource_jump_collision`,
`pc_cross_platform_controls`, and `hud_topbar_camera_zone_v2` pass headlessly.
`fields_step` passes the ledge movement checks but fails its scenery-batch and
portal-count assertions. `dungeon_seams` passes 336 floor and 32 barrier samples
but fails its exact-five-portals assertion. These assertions have not been
changed in this work. Headless runs also report log/certificate access and
renderer teardown warnings.

Manual QA remains: orbit past trees and doorway lintels, jump onto/across
bundles, walk around the simplified canopy bounds, harvest while standing on
a node, and verify touch movement and frame pacing on Android. No device
performance or visual validation is claimed.
