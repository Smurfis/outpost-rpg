# Outpost Nightfall — daylight, offhand torch and message

Standalone review branch based on PR #19 (co-op + terrain streamer); does not depend on either competing greedy-meshing branch. This is a gameplay-lighting foundation, NOT the final illustrated HUD art pass.

- One `DayNightCycle` node drives the existing WorldEnvironment and single directional sunlight. Full day length is 480 seconds, default start at 09:07; ambient energy ranges 0.20–0.94, so the world remains readable on mobile rather than pitch black.
- A new **Wanderer's Torch** workbench recipe costs 2 wood + 1 fiber. It uses the real `offhand` equipment slot; no simultaneous shield+torch. Crafting, inventory, Continue save and unique-item protection reuse existing methods.
- The player has one shadowless OmniLight3D of radius 8, attached to the left-hand voxel torch. The torch is hidden and emits no light when unequipped. A quick HUD TORCH button toggles the offhand equipment. When torch isn't owned, it explains how to craft one.
- A small DAY / NIGHT clock is added near the co-op button. No other HUD layout overhaul.
- On the first dusk transition the HUD displays: **"I don't care how dark the world gets. You are its light."** Once shown, it is saved as `night_quote_seen`.
- Old save file `user://outpost_progress_v02.json` remains the default. The v5 JSON structure is extended additively with `day_phase`, `night_quote_seen` and torch inventory; v2–v5 saves still load. `save_path` export permits tests to use an isolated path.
- Automated test `tests/night_torch.gd`: sunrise/nighttime ambient, time display, unique torch crafting and material spending, mutually exclusive torch/shield, HUD quick toggle and save/reload.
- **Not network replicated:** Co-op previews do not yet synchronize clock authority or visible remote torches. That belongs in synchronized session state once combat/loot networking is live. Do not claim full multiplayer night cycle.
- Android checks: verify readable moonlight on OLED screens, one local light cost, animation of held torch, craft UI icon, 16:9 landscape HUD spacing and app-resume save consistency.

The greedy mesh optimisation lives in PR #20 or PR #21 independently; avoid merging both renderers.
