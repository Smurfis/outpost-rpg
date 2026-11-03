# Outpost v0.7 — Controller and HUD recovery

## Why this change exists

The last user-confirmed movable Android release was **v0.2** (Git commit `d8a817197854`). Later GitHub headless checks proved scripts loaded, but **did not prove Android touchscreen movement**.

This branch retains v0.4+ equipment, crafting, world and dungeon systems while restoring the v0.2 **global touch/joystick contract**:
- Touch presses and screen drags in the joystick region directly update `hud.move_vector`.
- Mouse-event emulation also works for Android editor installations using emulated pointer input.
- Joystick ownership is released after menu, portal confirmation and app focus changes.
- The base player's movement calculation remains based on `Input.get_vector` or `hud.move_vector`, with dungeon interaction automatic walking **disabled by default**.

## Mobile HUD

Only a large ATTACK button, contextual GATHER/CRAFT button, optional SKILL button and MENU are persistent. Inventory, crafting, equipment, skills, salvage and healing live in the MENU drawer. This deliberately keeps the world visible.

The **MENU → INPUT DIAGNOSTICS** option reveals TOUCH/MOUSE event counts, stick length, lock and menu status for Android issue reports.

## Verification

`tests/movement.gd` checks motion from synthesized touch input, Android-style mouse fallback, menus, dungeon portal lock recovery and cancellation. Tests do **not** replace a real-device screen and input check.

## Android QA checklist

1. Import the feature branch into a fresh project directory using Godot 4.7.2.
2. Confirm the player moves with the left joystick **immediately** after spawning.
3. Open MENU → INPUT DIAGNOSTICS; try moving and check whether touch/mouse counts increase and STICK changes.
4. Press MENU, close it, verify movement resumes.
5. Approach a dungeon portal, open and cancel; verify joystick still moves.
6. Enter and leave a dungeon, verify movement in both scenes.

**Do not merge the feature branch into main until steps 2–6 pass on a real Android device.**
