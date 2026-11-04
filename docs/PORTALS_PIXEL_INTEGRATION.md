# Dungeon portal restoration over pixel-art visual integration
Review branch: `integration/pixel-art-dungeon-portals`; its base is PR #12's `integration/android-voxel-title-pixel-ui`. Draft and unmerged.

**Why:** PR #5 dungeon expansion was never applied to the voxel/title/UI prototype, leaving the field portals absent even though its source branch still exists.

**Restored in this narrow pass:** PR #5's dungeon scripts, rarity-tier demo portals, room/floor generation, guardian encounters, chest exits, separate clear/checkpoint save and required modular dungeon models. The main scene now includes the dungeon manager. Player supports temporary portal interaction locks without overriding the existing joystick. Demo portals register on the existing starter terrain; future chunk-streamer integration must explicitly call `register_chunk` and `unregister_chunk`.

**UI rule:** The original PR #5 HUD and menus were NOT imported. Existing pixel-art HUD and crafting remain intact. Only the dungeon prompt styles were adapted to the present nine-slice Outpost palette; final use of the user's approved generated screenshot/reference illustrations is a separate visual art task and requires usable cropped source assets rather than a whole screenshot.

**Not included:** PR #5's wider gear tiers, new crafting recipes, world ores, skill forge, salvage or achievement logic. Those are separate gameplay integrations needing save migration and UI work. Noray/LAN PR #6 is also separate. No new heightmapped chunks or boar voxel redesign in this branch.

**Known pending issue:** Dungeon doorway/corridor joins were reported to have gaps where characters can fall; these procedural geometry seams need a separate collision/floor safety review. Do not declare complete dungeon QA until tested. 

**Test:** `tests/portals_pixel_integration.gd` checks five overworld entrances, touch lock cancellation, entrance, connected generated floor and return; all original regression tests remain in CI. Test actual mobile navigation, entry/exit, collision around every doorway, and save persistence on Android before any mainline merge.
