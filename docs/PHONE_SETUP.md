# Phone-only development — Outpost

## Required
- Android phone with OpenGL 3 or newer; enough free storage for the Godot Android editor.
- Godot 4.7.2 Standard Android editor from https://godotengine.org/download/android/
- An archive manager, or the Android built-in Files app for ZIP extraction.
- GitHub account (optional for downloading, useful for contributions).

## Initial import
1. Open https://github.com/Smurfis/outpost-rpg → Code → Download ZIP.
2. Open Files, extract to e.g. Documents/outpost-rpg-main.
3. Open Godot → Import → navigate to outpost-rpg-main/project.godot.
4. Ensure access to files is granted; reopen the project if file permissions were denied.
5. Wait until the bottom status indicates file imports have finished (SVG assets).
6. Press Play (triangle icon) in the editor. Set landscape orientation.
7. You should begin at the outpost; move with the left joystick. GATHER and ATTACK are disabled unless a valid target is close.
8. Tap CRAFT to browse recipes, stand near the workbench to make items, and use BAG to inspect inventory or eat a meal.
9. The source passed Godot 4.7.2 headless gameplay tests on GitHub, but touchscreen usability must be checked on your phone.

## Expected game loop
Gather 3 wood, 2 stone. Craft at the bench. Kill a boar. Close/reopen and check that XP and loot remain.

## Updating from GitHub
Download/extract the latest repository ZIP, or use Git in Termux. Back up project changes before overwriting. Godot local save is stored separately in user://outpost_progress_v02.json. The save is NOT cloud-synchronized.

## Debugging
If you see a red parse error, tap the bottom Debugger/Errors tab in the Godot editor; copy the first complete error including script path and line number back into ChatGPT. Runtime testing has not yet been performed.

Godot Android documentation: https://docs.godotengine.org/en/stable/tutorials/editor/using_the_android_editor.html
