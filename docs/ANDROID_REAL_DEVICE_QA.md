# Android real-device QA — 4 November 2026

## Branch stack and release policy
- PR #27: real world-generation loading progress and initial chunk budgeting
- PR #28: Outpost tent icon in the actual installed APK, including adaptive icons
- PR #29: new layered title scenery is shipped, **but it is an original SVG approximation**, not the finalized approved transparent PNG cuts; acceptance remains open
- PR #30: first-pass downhill terrain, distant water horizon, proximity-only labels, forward attack and swipeable one-at-a-time crafting flow
- PR #31 (this branch): silver/white iron ore (not purple magic crystal), voxel hit numbers and fragment bursts, resources + boars in outer streamed chunks, more distant dungeon gates, larger/outlined HUD and crafting text, attack phase correction

## Known release gates
1. The headless Godot smoke test currently needs to complete green for this precise branch head. A previous PR #30 test failed its forward-swing first-frame assertion; this branch corrects the attack phase and retains the test.
2. The Android debug APK pipeline also must complete successfully **at the same commit** before shipping a new direct GitHub release. Never claim that queued builds are finished.
3. Ask for real Android screenshots/video only if the QA feedback genuinely cannot be assessed from the description. Check intro, Play loading, FPS, field elevation, side faces, portals, damage hits and defeat.
4. Preserve save backups before replacing a debug-signed APK; each GitHub runner creates a fresh test signing key.
5. Do not merge this stacked feature into main until its base PRs are reconciled and actual Android testing passes.

## Behavior and limitations
- Grass/soil terrace transition is still quantized and may not have the desired organic look. The finite 192x192 map now has a water horizon, but invisible hard bounds remain. A coastline biome or truly unbounded origin-rebased streaming is a **separate architecture project**.
- Spawned resources are **real** nodes with harvest/recovery behavior and are cleaned up when their 12x12 chunk unloads. Returning recreates deterministic positions; per-node remaining hits currently reset on reload. Durable exhaustion persistence is future work.
- Some boars are created in outer chunks when the playable world streams them after the character exists. Combat/loot still use original item and save IDs.
- Dungeon portal sites are deterministic outside the camp during the actual Play-loading path; they register through the existing DungeonManager and unregister with the chunk. They are not network-host-authoritative world generation yet.
- Pixel bursts are original MultiMesh-based particles with a floating damage number when actual damage is dealt. Solo enemies and hero use them; LAN guardian damage and downed state still need remote effect replication.
- Iron ore is still called **iron** internally, so gear, recipe ingredients and saved items retain compatibility. Purple magic-crystal atlas tile 13 is reserved for fantasy/magical resources, not iron.
- Title/menu art: PR #29 improves layout, but approved source artwork wasn't committed. The in-game HUD already has some nine-slice parchment/wood assets but **full visual signoff and detailed Albion-like menu navigation are pending**. Do not call the UI complete.

## Next sequence
1. Finish CI and Android QA on this branch; fix any parse errors, geometry performance spikes or visual regressions.
2. Complete authoritative menu/title asset merge with the originally approved individual PNG cuts and scalable font/UI tokens; improve gamepad and touch navigation with screenshots as acceptance references.
3. Prototype coastline/rivers/lakes and a truly streamed resource/portal grid beyond the finite 192x192 square, preserving 2–3 chunk/frame mobile budgets.
4. Improve animation blend and directional melee hit feedback; integrate LAN guardian and player damage particles and local death animations.
5. Continue item skills/salvage and four-race character creator backlog only after playable stability.

This file exists to prevent an agent from calling stacked preview features merged or finished before visible Android acceptance.
