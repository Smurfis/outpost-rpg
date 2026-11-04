# Character creation — deferred feature (approved concept)

**Status:** Backlog. Do not implement yet; complete co-op combat and core world tasks first.

The Outpost first-play/Play flow should eventually offer a compact, Android-friendly character creator with **four playable races**:

- **Human** — reuse the currently working human/adventurer voxel model and equipment rig.
- **Goblin** — smaller frame, larger ears, nimble silhouette, tailored equipment offsets.
- **Gnome** — shortest model, exaggerated head/hat proportions, readable silhouette on a phone.
- **Orc** — taller/broader build, strong jaw/tusks, scaled equipment and camera offsets.

All four are **player options**, not four factions or stat classes. Until balancing is approved, keep starter combat statistics and abilities equal across races; visual differences should not grant reach or hitbox advantages. Future cosmetic options may include skin tone/palette, hair/face presets, equipment previews and a randomize button.

Recommended integration:
1. Define stable race IDs `human`, `goblin`, `gnome`, `orc` and a small catalog with mesh/scale/equipment attachment offsets. Preserve existing save defaults: missing race -> `human`.
2. Preview selection in the character creator using the existing shared 16×16 nearest-filtered pixel atlas, with one compact rotating character and large touch-friendly arrow buttons; reuse current human mesh while the other assets are prepared.
3. Persist race/cosmetics in the player profile (not global world data); host validates allowed IDs and replicates the appearance to remote avatars once authoritative multiplayer identity is available.
4. Reuse gameplay hitbox proportions for fairness, handle differing rendered height by adjusting camera and the weapon visual anchors. Test armour, torch/shield offhand poses, clipping and Android performance.
5. Keep creator art modular and in the feature branch (do not rely on uncommitted or absent image assets).

**Do not silently build this now.** User explicitly postponed it while the main agent resumes the previous development priorities.
