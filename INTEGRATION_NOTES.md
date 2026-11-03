# OUTPOST — Official main-agent integration notes

**Scope:** Godot 4.7.2 Android voxel/pixel-art appearance experiment.
**Source:** [Draft PR #8](https://github.com/Smurfis/outpost-rpg/pull/8) — `feature/voxel-art-direction` → `main`.
**Parallel feature:** [Draft PR #7](https://github.com/Smurfis/outpost-rpg/pull/7) — Five Star intro/Outpost title.
**Owner's goal:** Cube World-style colourful, atmospheric 3D with **visible pixel-art texture detail**, without discarding working Outpost gameplay.

These are integration instructions, not a merge command or an assertion that proposed combat/loot/XP mechanics are already implemented. **Do not merge PR #8 or PR #7 without the owner's approval.**

## 1. Exactly what is already in PR #8

| File | Implementation | Conflict sensitivity |
| --- | --- | --- |
| `assets/voxel/outpost_atlas_16px.png` (new, **real PNG**) | Checked-in source pixel texture atlas; used directly at runtime by `voxel_palette.gd` | **Required**: retain binary file when cherry-picking; do not only copy scripts |
| `scripts/voxel/voxel_palette.gd` (new) | Generates one **64×64** atlas: sixteen **16×16** pattern tiles; shares a nearest-filtered `StandardMaterial3D` | Preserve cell UVs, palette indices, nearest sampling |
| `scripts/voxel/voxel_biome.gd` (new) | 8×8-cell batch-mesh ground chunks with path tiles, small flowers and decorative stepped cliffs outside gameplay walls | Visual-only, not editable heightmap |
| `scripts/voxel/voxel_props.gd` (new) | Blocky trees, ores/rocks, bushes, crates and stepped tent | Harvest/drop logic unchanged |
| `scripts/voxel/voxel_character.gd` (new) | Pixel-textured torso/head/arms/legs, preserving original rig pivots | Equipment meshes remain mixed prototype assets |
| `scripts/game.gd` | Adds `@export var voxel_art_enabled: bool = true`, warm sky/light, chooses terrain/decor art | HIGH — title-screen agent also modifies this file |
| `scripts/player.gd` | Conditionally creates voxel body parts with existing animation/controller untouched | HIGH — watch other avatar changes |
| `scripts/resource_node.gd` | Conditionally uses voxel harvestables, retaining `kind`, `hits_left`, respawn and `harvest()` | MEDIUM |
| `scripts/station.gd` | Pixel-textured craft structures, keeps `setup()`, `stroke()` and `set_activity()` | MEDIUM |
| `tests/voxel_art_smoke.gd` (new) | Verifies atlas, textured props/character/stations, resource count and legacy-mode switch | Keep after merge |
| `.github/workflows/godot-smoke.yml` | Adds voxel regression check after existing gameplay checks | Preserve all agents' CI additions |
| `docs/voxel-art-direction.md` and `docs/agent-handoff-android-voxel-and-loot.md` | Art scope and future feature design | Documentation |

**Asset manifest:** [`assets/voxel/README.md`](assets/voxel/README.md) lists the binary atlas and all procedurally built geometry. **No separate asset ZIP is needed for Feature B.** The PNG is part of this Git branch; title-screen art in PR #7 and future UI art are separate.

The new art is chosen when objects are created. Changing `voxel_art_enabled` while playing does **not** automatically regenerate the scene; reload to compare visual modes.

**Not implemented:** editable Minecraft terrain, height-changing collision, infinite streaming, multiplayer, item bags, Need/Greed, gold XP scrolls, hit flashes or XP orb animations.

## 2. Recommended integration and conflict workflow

Use a temporary review branch, test on Android, then merge into the appropriate target only after approval.

    git fetch origin
    git switch -c integration/android-voxel-review origin/main
    git merge --no-ff origin/feature/voxel-art-direction
    # Resolve any conflicts individually. Run Godot checks and Android review.

If another agent has updated `main`, rebase/merge current main into the temporary review branch deliberately; previous mergeability/checks do not guarantee new compatibility.

**PR #7 overlap:**
- `project.godot`: PR #8 starts directly at `res://scenes/main.tscn`, while PR #7 switches to `res://scenes/ui/company_splash.tscn`. In a combined build, preserve the Five Star → Outpost menu → gameplay flow as intended; don't accidentally delete it.
- `scripts/game.gd`: the title branch includes a one-shot New Adventure/Continue save-load flag. The voxel branch alters lighting, world geometry, asset instantiation and adds the exported visual toggle. **Manually retain both sets**. Verify Continue loads existing progress and Play starts a fresh game.
- `.github/workflows/godot-smoke.yml`: keep title/menu tests **and** voxel/gameplay smoke tests.
- The separate UI-overhaul agent may modify `scripts/hud.gd`, `scripts/menu.gd`, `scripts/game.gd`, and `scripts/player.gd`; avoid bulk file replacement and settle shared signal contracts first.

**Important:** If testing only PR #8, the Five Star title sequence is *not* expected; it is in PR #7.

## 3. Keeping the 3D graphics visibly pixelated

**The voxel look here comes from deliberately low-resolution art and point filtering, not just blocky shapes.**

- Current `voxel_palette.gd` **loads the checked-in 64×64 PNG atlas first**, falls back to generating the same 16px tiles only if the asset is missing, and sets `BaseMaterial3D.TEXTURE_FILTER_NEAREST`. Keep the tiles/UV half-pixel inset coherent; check edges at glancing angles for seams.
- For any later hand-authored atlas or texture file: import losslessly, select nearest filtering on the relevant canvas/material, choose a consistent texel density, and avoid bilinear/trilinear blur. Review mipmaps separately on mobile instead of assuming they are always wrong.
- Old OBJ equipment/weapon meshes **do not automatically acquire pixel textures**; several have no UVs. UV-unwrap/rebuild them in a later asset pass. Don't pretend a project render flag makes all legacy assets pixel-art.
- Keep the existing 2D UI crisp and readable at Android resolution. If experimenting with a low-resolution/pixelated 3D viewport, render UI separately at native resolution rather than pixelating text and touch targets.
- Keep shared atlas materials immutable during flashes/auras. Changing the common material would recolour terrain, trees, enemy and hero together. Use per-instance overlay, duplicated material or instance shader uniforms as appropriate.
- Voxel floor mesh is visual only; original flat `Terrain` collision and boundary walls stay in place. Background cliffs sit outside +/-23 world bounds and cannot be mined or climbed in this pass.
- Batch mesh faces/props and share materials; favour `ArrayMesh`/`MultiMesh` over thousands of MeshInstance3D cubes. Measure draw calls, memory and FPS on the actual Android phone.

## 4. Test matrix / Android merge gate

In a Godot 4.7.2 environment (binary may be called `godot` or `Godot_v4.7.2-stable_linux.x86_64`):

    godot --headless --editor --path . --quit
    godot --headless --path . --quit-after 120
    godot --headless --path . -s res://tests/smoke.gd
    godot --headless --path . -s res://tests/voxel_art_smoke.gd
    # Once PR #7 is integrated, also run its title/logo smoke tests.

- [ ] Check `assets/voxel/outpost_atlas_16px.png` exists in the merged tree; Godot import, launch and both regression suites pass after conflict resolution.
- [ ] 1280×720 landscape mobile layout remains readable; touch controls work.
- [ ] Atlas stays sharp without stretched patterns, cracks, z-fighting or blurry UV edges.
- [ ] Hero movement, world collision, combat, harvest highlights, cooldown/respawn, crafting stations and equipment still work.
- [ ] Save path `user://outpost_progress_v02.json` and earlier save compatibility unchanged.
- [ ] Compare old and voxel looks by toggling `voxel_art_enabled` and **reloading** the scene.
- [ ] Record Android GPU frame time, FPS, memory and thermal behaviour at the same camera/location and representative crafting/combat action.
- [ ] For combined title build: Five Star splash, Play/New Adventure, Continue and settings all function.
- [ ] Owner signs off visual direction/performance **before any main merge**.

**Automated Godot checks do not prove Android performance or pixel-perfect art.**

## 5. Interfaces for the next systems (proposals, NOT already implemented)

### Combat hit flash, death and XP-orb visuals

The user wants a cartoony hit response: a short **white flash** on impact, increasing reddish damaged tint toward low HP, a brief explosive burst of **moving pixel fragments** on death, and a few XP particles flying to the hero.

- Keep damage and the exactly-once death reward in the gameplay model (`scripts/enemy.gd::receive_damage` and `scripts/game.gd::on_enemy_killed`). Notify an effects-only controller with hit position and normalized remaining HP.
- Flash white ~0.08–0.12s and return to a damage tint scaled by HP. Do **not** tint the globally shared voxel atlas material.
- Death: disable enemy collision/rewards promptly and play a pooled ~16–40-fragment visual burst with tween/eased velocities for ~0.5–1s; reduce count on low-end devices.
- XP flying orbs are **cosmetic**. Add XP to the saved game immediately, never when the last orb reaches the player, so disabling effects or closing the app cannot lose or duplicate XP.

### Ground loot bags and later party Need/Greed

- Start **single player** with visible ground loot bags, with resources and items grouped as stacks and one logical bag per enemy kill. Decide whether bag contents are persisted and when they expire. Prevent awarding resources both immediately and on pickup.
- Add UI-managed bag inspection/pickup, but keep ownership, reward granting and duplicate prevention in gameplay state.
- Need / Greed / Pass only when party/multiplayer exists. Suggested 20-second timer; Need > Greed; server-generated 1–100 roll, tie reroll and one server-confirmed award. No fabricated multiplayer authority in this single-player prototype.
- Let the UI agent own roll panels, loot-bag views and on-screen status, not the underlying reward decisions.

### Temporary golden XP scroll pickups

User wants a **gold-highlighted character**, timed pickup scrolls and rarer, stronger XP bonuses. **Suggested, not approved final balance:**

| Rarity | XP multiplier | Duration |
| --- | --- | --- |
| Common | ×2.0 | 10 min |
| Uncommon | ×2.25 | 20 min |
| Rare | ×2.5 | 30 min |
| Epic | ×3.0 | 45 min |
| Legendary | ×4.0 | 60 min |

- Centralize the existing direct XP updates in `scripts/game.gd` first: gathering `experience += 2 * amount`, crafting `experience += 8`, boar kill `experience += 12`. Introduce an authoritative `award_xp(base_amount, source)` method. XP buff multiplier applied **once**, returning the actual awarded integer for HUD/FX.
- Keep buff data (`rarity`, `multiplier`, `expires_at`, stacking/replace policy) independent from rendering. For offline play define pause/resume and save/restart clock rules; future multiplayer must use server time.
- Only one blessing active initially; show remaining duration and multiplier on the HUD, and use a subtle golden rim/halo overlay that does not wipe out pixel armour detail. Do **not** recolour the shared texture atlas to implement it.
- UI agent: icon, countdown, pickup tooltip. Gameplay agent: XP ledger, buff expiry, scroll inventory, one-shot award rules. Effects agent: gold outline/pixel aura.

## 6. Agent responsibilities and order

| Agent | Owns | Must avoid |
| --- | --- | --- |
| Integration/main agent | Merge conflicts, Godot/Android validation, save compatibility, review/merge decisions | Blindly overwriting changes from other agents |
| World/voxel | 16px atlas, procedural meshes, materials, 3D environment and visual optimisation | Unreviewed rewrites of gameplay/save/UI |
| UI overhaul | HUD, crafting/inventory layouts, bag/roll panels and scroll timer widget | XP award and loot authority |
| Future combat/loot | Hit feedback, death effects, authoritative bag lifecycle, XP scroll state and multiplayer rolls | Shared atlas mutation and title/gameplay replacement |

**Order:** Android voxel test first → title-screen PR reconciliation → in-game UI → cosmetic hit/death/XP FX → ground loot grouping → scroll buffs → party Need/Greed when multiplayer authority exists.

**Related:** [voxel art direction](docs/voxel-art-direction.md) and [long-form handoff](docs/agent-handoff-android-voxel-and-loot.md).
