# Pixel HUD + crafting art integration — Android review

Source is PR #9 at `feature/pixel-ui-crafting-overhaul` including every PNG/SVG and `assets/ui/ASSET_GUIDE.md`. Combined with PR #11 (voxel atlas, revised sword pose and Five Star title screen) on `integration/android-voxel-title-pixel-ui`.

## What is connected
- `scripts/ui/outpost_skin.gd` now renders graphic nine-sliced `StyleBoxTexture` panels and buttons. 128×128 panel borders use 16px margins; 192×64 button edges use 18px horizontal / 12px vertical margins.
- Title and UI render use nearest filtering. The gameplay HUD displays the original 128×128 PNG action icons.
- The HUD keeps large tappable action areas; round joystick and health meters intentionally use solid fills instead of stretching rectangular textures.
- The crafting screen uses the wood-framed centre panel, parchment recipe buttons, item cards, gold and green/red action buttons, toast and inventory equipment views.
- Recipe browsing, preparing ingredients, timed station actions, completion receipts and unique-item prevention still call the unchanged `scripts/game.gd` API. Receipt acknowledgement is cosmetic; items have already been awarded exactly once when crafting completed.
- No modifications to save layout, recipes, gear calculations, combat, terrain, voxel atlas, or title startup.

## Test gates
- New `tests/pixel_ui_integration.gd` validates real 128×128 / 192×64 imported PNGs, button pressed-state art, nearest filtering, UI construction, all crafting stages, ingredient spending only once, unique equipment and inventory access.
- Also run voxel, sword, title and old gameplay regressions in the combined workflow.
- Real Android landscape (1280×720 and wider devices), touch, input focus, font readability, texture edges and frame rate still require a phone test. A headless workflow can't assert how a PNG panel looks on a screen.

## Merge plan
This is an isolated integration candidate. Do not overwrite the PR #9 agent's feature branch or merge to `main` until combined-branch QA and developer sign-off. Do not mistake the current visual-only voxel chunk tiles for the future heightmapped streaming world.
