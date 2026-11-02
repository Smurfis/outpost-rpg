# Outpost ⚔️

**Original Android-first isometric 3D RPG | Godot 4.7.x | v0.3.0-dev**

A small original fantasy sandbox RPG inspired by the *genre* of games like Albion Online. This repository contains playable Godot source, not a compiled APK. Five Star Interactive project.

## Current vertical slice — v0.3.0-dev
- Isometric 3D forest outpost with low-poly pines, rocks, a tent and crafting bench.
- Adventurer character with visible training blade / crafted spear.
- Mobile touchscreen joystick and large icon-based gathering, attack and crafting buttons; keyboard alternative.
- 10 original SVG HUD/action/item sprites in `assets/icons/`.
- Mine stone, chop trees, forage fiber and berries (2–3 hits per node, 18-second respawn); harvesting tools double specific yields.
- Actual workshop recipe browser: craft six item types, including axe, pickaxe, shield, satchel, spear and consumable healing meals.
- Fight boars with weapon swings, automatically loot hides/coins, earn XP; crafted shield reduces damage.
- Automatic local JSON persistence with v0.2 save migration (single device; no cloud storage).
- Context-sensitive interaction gating prevents repeated warnings and disables gather/attack when no target is close.

## v0.3 controls
- **GATHER** works only in range of a resource and is dimmed otherwise.
- **ATTACK** works only in range of a boar and is dimmed otherwise.
- **CRAFT** opens the recipe menu anywhere, but you must stand near the workbench to actually make an item.
- **BAG** opens inventory; **HEAL** consumes a crafted meal when injured.
- Keyboard: WASD/arrows, E gather, F attack, C craft, B/I bag, H heal.
- Craft unique equipment once, or repeat consumable recipes. Crafting consumes real inventory quantities.

## Android first-run
1. Install the official **Godot 4.7 Android editor**: https://godotengine.org/download/android/
2. Download the repository ZIP: https://github.com/Smurfis/outpost-rpg/archive/refs/heads/main.zip
3. Extract the ZIP into Documents or Downloads. **Do not import the ZIP itself.**
4. Godot Project Manager → Import → open the extracted `project.godot`.
5. Allow initial asset imports to finish, then press ▶ Run. Rotate your phone to landscape.
6. Use joystick on the left; action buttons on the right. Optional keyboard: WASD/arrows, E gather, C craft, F/Space attack.

**Quest:** gather 3 wood and 2 stone → return to workshop, open CRAFT and select Forest Spear → kill a wild boar. Restart and verify save. Tap outside a resource or enemy to see an instructional toast.

## Source map
```text
project.godot
scenes/main.tscn
scripts/game.gd              main world + progression + persistence
scripts/player.gd            movement + original stylized character
scripts/resource_node.gd     harvestable trees / ore rocks
scripts/enemy.gd             boar combat AI
scripts/hud.gd               Android controls + SVG inventory icons
assets/icons/*.svg           original scalable 2D art (10 sprites)
docs/PHONE_SETUP.md
docs/CHANGELOG.md
docs/ROADMAP.md
```

## Status / limitations
**Source added to repository, but NOT yet run in a Godot 4.7 runtime or verified on an Android device.** Please report any Godot Parser/Debugger errors. No touch interaction with world objects yet, no animation rig, audio, multiplayer, trading or server economy. Generated meshes are deliberate temporary low-poly art, not finished models. Godot is not an MMO host.

License: MIT for code and original artwork (see LICENSE).
