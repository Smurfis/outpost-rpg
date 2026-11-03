# Outpost — Pixel UI & Compact Crafting: Mainline Integration Handoff

**Owner:** UI feature workstream  
**Target:** `main` (review and merge only after QA)  
**Source:** `feature/pixel-ui-crafting-overhaul`  
**Project:** Godot 4.7.2 / Android landscape / Five Star Interactive / v0.5.0-dev  
**Status:** Initial implementation committed; requires CI and device review before merge.

## Purpose and approved direction

Replace the generic dark fullscreen UI with the Outpost title-screen's visual language: warm parchment, dark carved wood, brass/gold trim, pixel-fantasy action icons and less visual obstruction of the world. A familiar Albion-style context panel is the aim, but the implementation and artwork are original. Focus specifically on crafting and the gameplay HUD; this is not a request to rewrite crafting gameplay or to merge any other feature branch.

## Files currently changed on this branch

| Path | Integration responsibility |
| --- | --- |
| `scripts/ui/outpost_skin.gd` | New shared Godot StyleBoxFlat/UI button styling; central palette. |
| `scripts/menu.gd` | Smaller centred panel; wood-themed tabs/recipe entries; `craft_step` state; split browse → prepare → existing manual crafting/result flow. Bag and equipment remain available. |
| `scripts/hud.gd` | Compact player/quest status; HP and XP meters; themed toast panel; smaller action controls; uses new SVGs. |
| `assets/ui/icons/attack.svg` | New original transparent pixel-style action icon. |
| `assets/ui/icons/gather.svg` | New original transparent pixel-style action icon. |
| `assets/ui/icons/craft.svg` | New original transparent pixel-style action icon. |
| `assets/ui/icons/bag.svg` | New original transparent pixel-style action icon. |
| `assets/ui/icons/heal.svg` | New original transparent pixel-style action icon. |
| `docs/PIXEL_UI_INTEGRATION.md` | This handoff. |

**Unchanged:** `scripts/game.gd`, `scripts/player.gd`, `data/recipes.json`, world, stations, inventory schema, saves and `project.godot`. The menus call existing `game.begin_craft()`, `game.work_craft()`, `game.equip_item()`, `game.consume()`, etc.

## Transparent PNG art pack — now committed to this branch

The complete original asset pack is now stored **as individual files in GitHub**, not as a separate required ZIP:

- `assets/ui/frames/*.png` — 5 transparent 128×128 cards, parchment and wood panels;
- `assets/ui/buttons/*.png` — 4 transparent 192×64 textured button states;
- `assets/ui/icons/*.png` — 5 transparent 128×128 action icon PNGs;
- `assets/ui/icons/*.svg` — 5 original vector equivalents already used by the HUD;
- `assets/ui/ASSET_GUIDE.md` — sizes, palette, and stretch-margin recommendations.

**No user download or manual ZIP transfer is required.** GitHub agents can access the files from this PR. The files are **committed, not yet automatically wired to every menu control**: `outpost_skin.gd` currently uses procedural `StyleBoxFlat`. If adding the textured artwork, use `NinePatchRect` / `StyleBoxTexture` with 16 px margins on 128×128 frames and 18 px horizontal / 12 px vertical margins on 192×64 buttons; enable nearest-neighbour filtering and verify Android scaling.

## How to integrate safely

1. Fetch the latest `main` and `feature/pixel-ui-crafting-overhaul` branches. Review changed files and the draft PR; **do not merge blindly or overwrite other feature work**.
2. If the title-screen branch, voxel/chunk atmosphere branch, dungeon progression or co-op branches have landed since this UI branch split, update/rebase this branch against latest `main` before approving. Keep their world, terrain, save and gameplay code unchanged.
3. Resolve conflicts in `scripts/menu.gd` and `scripts/hud.gd` semantically. Retain their public methods (`setup`, `open`, `close_page`, `refresh`, `render_status`, `update_context`, `toast`, `_toggle_ingredient`, `_start_craft`, `on_craft_started`, `on_craft_completed`) and gameplay references. Avoid copying entire older scripts over newer features.
4. Import `res://scripts/ui/outpost_skin.gd` and five `res://assets/ui/icons/*.svg` paths. These references must remain valid after moving files.
5. Run Godot 4.7.2 resource import/parse, headless launch and existing `tests/smoke.gd` as specified in `.github/workflows/godot-smoke.yml`; review logs for parse/runtime errors.
6. Verify landscape Android touch ergonomics at 1280×720 and at a real phone's aspect ratio: joystick drag, gather/attack/craft/bag/heal tap targets, toasts, readability, safe-area boundaries, and no accidental movement while any menu is open.
7. Confirm gameplay: select recipe → Next/Prepare → load ALL ingredients → start; hold/process crafting time and perform required manual station actions; receive item once; equip/unequip; cancel without spending resources; unique gear cannot be duplicated; opening/closing menu during work does not cancel; bag food use works.
8. Merge through reviewed PR only after required checks pass; preserve `main` history and keep the source feature branch for future polish until review completes.

## Current implementation boundaries and known follow-up work

- The shared theme is procedural `StyleBoxFlat`. The committed PNG NinePatch frames are optional art, **not yet the fully wired textured theme**. Connect and review on an Android device before claiming full polish.
- The compact crafting flow **currently keeps a two-column recipe browser and a prepare step**; a one-card-at-a-time popup, quantity selectors, sortable recipe categories, persistent equipment tooltips, and other polish are follow-ups rather than completed guarantees.
- The XP meter currently displays `xp % 100` as a visual placeholder; integrate with a real level curve before claiming it depicts level progress.
- Existing `assets/icons/*.svg` item icons remain in inventory and recipes. New art replaces **five HUD action** icons only.
- The existing `scripts/menu.gd` still rebuilds controls on refresh and retains a 3D equipment preview. Test phone performance and menu opening carefully.
- No change to save-file path or crafting economics is intended. Keep the current save migration and `data/recipes.json` untouched.
- New code has not yet been confirmed on a physical Android build. A green headless check alone does not establish visual quality.

## Acceptance checklist

- [ ] GitHub Actions Godot 4.7.2 smoke check passes.
- [ ] Manual Android landscape UI review completed.
- [ ] Crafting + inventory + equipment regression passed.
- [ ] No conflict with title-screen, voxel atmosphere, dungeon or co-op work.
- [ ] Committed PNG sprite assets wired into the UI, or consciously deferred.
- [ ] `main` remains unchanged until the reviewed PR is explicitly merged.

## Review message

> Please integrate the independent `feature/pixel-ui-crafting-overhaul` workstream with current `main` only after running CI and Android touch QA. Preserve original crafting logic, recipe data and save format; resolve UI script conflicts semantically with other features. The branch contains the initial compact crafting flow, HUD and original SVG action icons. The optional transparent PNG frames are delivered as a separate ZIP, not yet fully wired into the project. Treat remaining cosmetic polish as follow-up rather than as a merge-blocking claim of completion.
