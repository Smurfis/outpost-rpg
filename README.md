# Outpost — Mobile Sandbox RPG

**Five Star Interactive · Godot 4.7.2 · v0.4.0-dev**

Original isometric 3D fantasy sandbox RPG, developed for Android. **Source code and Godot project**, not an Android APK or multiplayer server.

## What's playable?
- An explorable forest outpost with mobile joystick and contextual action buttons
- **10 resources:** wood, stone, fiber, berries, iron, coal, clay, herbs, mushrooms, reeds
- **4 3D production stations:** workbench, forge, loom and campfire
- **13 recipes**, including tools, armour, food, refined materials and weapons
- **Interactive crafting:** pick a recipe, tap each material slot to load it, start crafting, perform hammer/forge/weave/stir actions while the station animates, then see the finished item revealed
- Equipment improves gathering yield, character speed, damage or defence
- Wild boars, hides, coins, health and experience; automatic local saves
- Original scalable vector icons and procedurally built low-poly meshes (not yet polished asset-pack quality)

## How to craft
1. Walk up to any station identified by its floating label: **WOODWORK**, **FORGE**, **LOOM**, or **CAMPFIRE**.
2. Tap **CRAFT** (you can browse anywhere; crafting itself requires proximity to the correct station).
3. Select the station tab and choose an item from the left recipe list.
4. Tap the required ingredient slots on the right to load each material.
5. Press **BEGIN CRAFTING**, then tap **HAMMER / STRIKE / WEAVE / STIR** the indicated number of times as the progress bar fills.
6. The item appears in the completion screen and your BAG when it is finished.

**Example production chain:** gather iron + coal → smelt iron ingot at Forge → craft an Iron Blade with two ingots and wood.

Materials are spent only on completion. If the app closes or you stop mid-craft, materials remain in your inventory.

## Android phone-only install
1. Install the standard Godot 4.7.2 Android editor (or use your existing installation).
2. Download repository source: https://github.com/Smurfis/outpost-rpg/archive/refs/heads/main.zip
3. Extract into a **fresh folder**; select `project.godot` via Godot Project Manager → Import.
4. After asset imports, press Play in landscape.
5. Left virtual joystick moves; GATHER, ATTACK, CRAFT, BAG and HEAL buttons perform actions.
6. You can also use WASD, E gather, F attack, C craft, B bag, H eat meal.

The save file remains at `user://outpost_progress_v02.json` and old v0.2/v0.3 inventory and progression can be loaded. Fresh extracted projects may use a separate save location.

## Source overview
```text
project.godot
scenes/main.tscn
scripts/game.gd           World, inventory, recipe processing, saves
scripts/menu.gd           Touch crafting screen, ingredient slots and work animation
scripts/station.gd        Four visible 3D stations with activity effects
scripts/resource_node.gd  Ten distinct gathering nodes
scripts/player.gd         Character, equipment and controls
scripts/enemy.gd          Wild boar enemy
scripts/hud.gd            Mobile HUD and joystick
data/recipes.json         Costs, station, production time, strokes, category
data/resources.json       Resource descriptions and tools
assets/icons/*.svg        Original item icons
tests/smoke.gd            Automated gameplay regression checks
```

## Validation
GitHub Actions runs the official Godot 4.7.2 Linux editor headlessly to import sprites, start the game, and run a scripted gameplay regression suite. This is **not** the same as playing on Android, so graphical usability and FPS still require your device test.

License: MIT (original source + icons).
