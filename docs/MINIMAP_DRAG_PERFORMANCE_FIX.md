# Outpost mobile camera drag + minimap recovery

This pass fixes issues reported after APK v1040. It does not change the terrain mesher, saved game schema, inventory, dungeon logic or Android signing.

## Root causes addressed

- World orbit was gated behind a 0.82 second hold, and deliberate swipes moving more than 26 screen pixels before that timeout were **cancelled**, producing the impression that camera rotation was broken. Free-world drags now activate orbit once the drag passes 16 screen pixels; the existing tiny-drift guard, optional hold, joystick and action-zone exclusions remain.
- The original minimap recreated a 48×48 terrain texture whenever the smoothed camera heading changed by more than 0.035 rad. During a continuous orbit this could rerun expensive terrain/coastline noise calls near every frame, competing with input and world rendering on Android.
- The map texture is a 64×64 original-art, **north-aligned terrain cache**. Dragging the camera uses the inexpensive CanvasItem rotation transform. Terrain sampling occurs when the player moves far enough (and after the minimum 0.24 second refresh interval) or teleports. The current terrain is static; stationary idle does not trigger a periodic rebuild.
- The player indicator remains centred, markers rotate with the camera, and map position is compensated between samples with a small display offset. Wood-and-brass framing, scale-aware compass ticks, clearer coast/path colours and more legible station dots are included.

## Acceptance

CI tests in `tests/visual_world_minimap.gd` confirm 64×64 sample resolution, that camera-only rotation does not increment the pixel cache update counter, that player movement does, and that north/station transform remains camera-relative.

Android gesture tests in `tests/island_smart_action_camera_knockback.gd` exercise both long-hold drag and immediate deliberate drag, ensuring a small accidental 10-pixel wobble does not orbit.

## Device QA

On a landscape phone with the installed APK:
1. Drag horizontally on the **unoccupied middle of the world** without holding. The orbit should start after about 16px of movement and remain smooth.
2. Long-hold then drag still rotates; screen movement joystick, quick tool selector, and three skill buttons still function independently.
3. Rotate while stationary: the circular terrain and station dots rotate, with the player icon staying centred. The terrain detail should not stutter from resampling.
4. Walk towards the coast while rotating, and verify that beaches, paths and water update as you cross them.
5. Enter a dungeon: overworld map hides and the existing dungeon room map is still shown.
6. Test on physical Android for frame pacing, brightness, touch comfort, and narrow landscape screens.

No claim of actual device FPS until recorded on hardware.
