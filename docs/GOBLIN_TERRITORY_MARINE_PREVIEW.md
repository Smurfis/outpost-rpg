# Goblin Territory and marine World Preview

This iteration is isolated to the World Preview channel (or explicit test flag). The existing three exploration island coordinates, original cave indexes, mine IDs and Alpha release channel are retained.

## Goblin Territory

A fourth, northern exploration island is centered at (0,-207), nominal radius 58. Its initial template has a surface terrace, eleven roofed structures, reserved streets, four surface guards, a three-wide descending cave entry, a grand avenue, crossroads, throne hall, barracks, forge, treasury and bone shrine, with five underground guards. Room dimensions and roles vary by seed/cycle. The terrain cave mask and section renderer use the same authoritative floor and ceiling cells. The current template is a connected single-floor underground district network, not a general multi-floor spiral or WFC city. Buildings reuse the existing architecture and cutaway code; goblins use the existing creature art and combat. No permanent quest or dungeon loot is issued by the experimental guards. The guard population is streamed rather than a persistent encounter lifecycle.

The preview world map exposes Goblin City travel and regeneration controls. Regeneration increments the local layout cycle, validates connectivity and plot overlap before publishing, and requires the player to be outside the territory. It invalidates relevant streamed geometry and cave section caches without changing other cave cells. The cycle is currently session-local; full persistent regeneration transactions and dynamic territory events are not implemented.

## Island biomes and sea front

Named biome profiles: rocky highlands/rocky shoals, temperate woodland/kelp coast, warm meadow/sandbanks, goblin badlands/cold reef. Preview inland material differentiation uses the existing atlas; the submerged coastal shelf extends up to nine cells beyond the land mask. This is a starting biome layer, not complete biome-specific forests, creatures, snow or weather. Existing dry island radii intentionally stay unchanged for save compatibility. Future larger island footprints should be introduced with versioned world generation.

## Ocean and trinket

Nearby seeded shoals are streamed on a 32m radius; eight small original voxel fish per school share a MultiMesh. Local cohesion, alignment, separation and containment are bounded. Five rarity ring colors indicate reward size. With a fishing net equipped, interact to cast, then interact during the bite window. The current reward is 1–5 existing shrimp items with an eight-second cooldown; fish inventory species, persistent school depletion and full fishing UI are not yet implemented. No external fish asset is used.

The preview Workbench adds a Wooden Rowboat recipe (30 wood, 10 fibre). It uses the trinket equipment slot and displays an automatically deployed boat visual in swimming water, increasing speed by 1.8x. Existing swimmer collision and buoyancy remain in use; real boat physics, boarding, oars, seats and boat-specific water collision are future work.

## Character inventory

Wider landscape screens show character equipment beside bag items; preview display subtracts the worn item from the bag quantity, tap a bag item then its compatible slot to equip/swap, and the existing native drag target remains available. Preview crafting no longer silently overwrites a character slot. Quick tool selection switches only equipped tools. Returning gear to bag remains an explicit action. This is a presentation and interaction correction, not a separate equipment-instance ownership/save migration. Existing saves keep shared aggregate counts; the future transactional migration must account for crafting, bag capacity, gear quality, death/tombstone, multiplayer and tool selection before physically separating slots from bag inventory. Native Android drag/swipe, detail card sizing, tool icon and layout need graphical testing.

The dedicated preview regression at a31da79 passed generation, regeneration, streamed city checks, shoal creation and rowboat equipment/deployment. Later sea shelf and explicit equipment selection changes have added assertions and require fresh verification. The earlier general settlement checks passed. Existing updater/changelog smoke issue remains a release blocker. No normal Alpha promotion. Preview APK publication is asynchronous GitHub CI; verify completed release assets before giving a download link.
