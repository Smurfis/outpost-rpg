# Outpost — Android Sandbox RPG

**Five Star Interactive · Godot 4.7.2 · v0.5.0-dev**

An original isometric 3D RPG with gathering, hand-crafted equipment, four production stations and mobile controls. This repository contains the playable **Godot source project**, not an APK or MMO server.

## What's new in v0.5?
- **10 original low-poly 3D OBJ mesh assets**, with shared material palette: a modular adventurer, modelled weapons/shield/cloak, oak trees, faceted boulders and supply crates. This replaces the previous block-based character and basic tree/stone resource appearance.
- **Animated character rig:** separate arm/leg pivots create a walking gait, combat strikes and gathering swings.
- **Interactive equipment page:** BAG → GEAR. Own an item, then equip, swap or unequip it. A rotating 3D adventurer preview shows the current loadout.
- **Actual equipped bonuses:** main hand determines 8/16/24 damage, equipped axe/pickaxe/satchel doubles its matching gathering yields, shield reduces damage and cloak improves speed.
- **Better gathering feedback:** nearby resource markers show type and remaining hits; striking a node plays a tool-swing animation and floating resource pickup text. The empty-area spam fix remains.
- **More distinctive scenery:** original oak trees and supplies, organic triangular pathways and stone props around the same outpost.

## Existing systems retained
- **10 gatherable types:** wood, stone, fiber, berries, iron, coal, clay, herbs, mushrooms and reeds.
- **4 stations** (workbench, forge, loom, campfire), **13 recipes** and hands-on production.
- Select a recipe, load ingredients, then do hammer/forge/weave/stir actions while the progress bar advances; collect the result.
- Boars, XP, materials, health, healing food, local saves.

## Phone-only installation
1. Download the latest source ZIP: https://github.com/Smurfis/outpost-rpg/archive/refs/heads/main.zip
2. **Extract into a fresh folder** (the source is NOT a compiled app). Open your installed Godot **4.7.2 Android editor**.
3. Project Manager → Import → choose `project.godot` in the new folder.
4. Allow all OBJ models and SVG sprites to import; press Play with the phone in landscape mode.
5. Left joystick: move. GATHER: hit nearby highlighted resource. ATTACK: nearby boar. CRAFT: stations. BAG: inventory; GEAR: equipment selection from within the same menu.

**Crafting example:** collect iron and coal → use Forge to make iron ingots → forge an iron blade → open BAG → GEAR to swap between the spear and iron blade.

Existing local saves: `user://outpost_progress_v02.json`. v2-v4 inventories are migrated to v5 equipment records when opened in the same project save location. Extracting to a new folder may create a different Godot user:// location, depending on platform/app project identity. Back up saves before deleting old project folders.

## Code and art layout
```text
project.godot
scenes/main.tscn
scripts/game.gd                World, equipment, crafting, save migration
scripts/player.gd              Modular 3D avatar, walk/attack/gather animations
scripts/resource_node.gd       Harvestable nodes, target indicators
scripts/menu.gd                Inventory, equipment, 3D preview, crafting
scripts/station.gd             Workbench, forge, loom, campfire
scripts/enemy.gd               Boar AI
scripts/hud.gd                 Mobile HUD, health bar and controls
assets/models/*.obj            Original low-poly models (10)
assets/models/outpost.mtl      Original material palette
assets/icons/*.svg             Item and action UI sprites
data/recipes.json              Recipes, costs and station definitions
data/resources.json            Resource definitions
tests/smoke.gd                 Godot 4.7.2 automated regression checks
```

## Verification and limitations
GitHub Actions tests sprite and model import, headless launch and scripted gameplay. Tests cannot prove the actual Android rendering quality, touch ergonomics or FPS. The modular meshes are **original low-poly models**, not imported AAA game art or a bone-rigged character. Multiplayer, music and larger biomes are not yet implemented.

Original source and art licensed under MIT.
