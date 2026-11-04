# Day & Night / off-hand torch — independent atmosphere feature

- **Narrative line:** *“No matter how dark the world becomes, you are its light.”* Shown once when the first evening starts.
- Configurable 9-minute in-game cycle (`day_night_enabled`, `day_length_seconds`). Starts at noon; dusk, night and dawn gradually shift directional sun, ambient light and pixel sky. Shadows stay OFF for the Android budget.
- A small HUD clock is added without redesigning the existing UI.
- **Wanderer's Torch** is a new workbench recipe (2 wood + 1 fibre, 3 work actions). Torches use the existing offhand slot, mutually exclusive with the shield, with an attached pixel-atlas mesh and one shadowless local light (`omni_range=7.4`). The old shield has the same defence mechanics.
- New inventory key `torch` defaults to 0; old save version 5 remains readable, with optional `world_time_seconds` so the in-game clock can resume on load.
- `assets/icons/torch.svg` is an original simple icon, not final illustrated interface art.
- **Future:** light sources in dungeons, weather, biome-specific darkness, light flicker/particles and multiplayer time synchronization are separate tasks.
- Android: confirm nighttime readability and low-end GPU performance. No additional dynamic shadows; no claim of real phone certification.
