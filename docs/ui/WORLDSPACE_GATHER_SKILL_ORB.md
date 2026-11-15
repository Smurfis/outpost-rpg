# Outpost: world-space receipts and skill XP icon (Alpha V2)

## Visual decisions from Android screenshot feedback

- No permanent Last Gathered HUD card. Successful harvesting creates a **single** translucent `+N Wood`-style `Label3D` above the avatar and fades it upward. It only displays the amount actually accepted by the inventory; a full bag cannot create a fake gain.
- Resource XP no longer creates an enormous top-centre toast. Real quest/dungeon/level-up notices remain available. The existing compact Loot & Combat panel with rarity-bordered, tappable item icons remains beneath the Quest tracker.
- Player damage shows actual health loss, updated HP bar and short red 3D damage number. It does not show the redundant `Ouch! -9 HP` banner. A fatal hit still gives the actual respawn notice.
- The character portrait has its name and HP; it does **not** repeat `Training Blade • M1`. Existing live effect icons remain in the reserved lower portrait slot.
- Character XP remains the full-width bottom-edge progress bar, now on a translucent fill/backing. Its short central numeric value is **character XP**, not an invented mastery skill.
- `TrainedSkillOrb` is a small low-profile circular progress icon on the left of the XP bar. The ring displays **the most recently trained skill's real 60-XP mastery segment**: Woodcutting (axe icon), Mining (pickaxe), Foraging (satchel), or the equipped/used weapon (attack, spear, or iron-blade icon).
- Gathering mastery XP is awarded from successful harvesting only and stored under `gathering_skill_xp`; weapon mastery uses pre-existing authoritative `weapon_mastery_xp`. The final active `last_trained_skill` is also saved. Older v2–v5 saves remain loadable by defaulting missing keys to zero; do not reset or assume skill ranks.
- Dungeon guardians have actual group `dungeon_guardians` and a `display_name`; overworld wild boars now also have a dedicated `wild_boars` group (node names are not globally unique in Godot). Other mobs use their own node name. Do not call any generic enemy "Boar".

## Lifecycle and tests

- `game.gather()` → `grant_item` → `hud.record_gather()` (internal history) → `_show_gather_pickup(hero.position,item,accepted_amount)` (one 3D label) → `gain_experience()` (character XP) → `gain_gathering_skill()` (actual skill mastery).
- `game.gain_weapon_mastery()` sets the active icon and progress; `game._load()` restores its last persisted state.
- `scripts/ui/skill_xp_orb.gd` is a reusable, touch-transparent Control; it never captures camera, thumbstick, or smart-attack input.
- `tests/hud_world_skill_progress_v2.gd` covers these interactions and actual save/restore. Existing XP-width tests still assert bottom-edge full-screen geometry at 16:9 and 20:9. The old gathered-card tests now assert its invisibility rather than resurrecting the panel.

This is an Alpha-only UI change. Play Store distribution, unrelated feature branches, main/Stable and the active APK signing/update policy are not changed.
