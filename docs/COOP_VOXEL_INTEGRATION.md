# Co-op integration on streamed voxel world — Phase 5 foundation

Branch: `feature/coop-voxel-integration`; stacked on PR #18; **main untouched**.

This integrates the earlier verified LAN feature (PR #6) into the latest voxel Fields, dungeon archetypes and pixel HUD without replacing the HUD or copying obsolete game/progression scripts. Android users open **CO-OP** in the top right, enter a name and either Host LAN (UDP 30115) or Join IP on the same Wi-Fi. Four peers maximum per party. Solo offline remains the startup default.

Each party has a distinct host-owned ID/run descriptor, independent seed/floor state and walkable dungeon preview built deterministically on every member's client. Remote avatars now use the shared voxel material, with nameplates, instead of the earlier low-poly torso. Client-created dungeon guardians are frozen and do not award items. All co-op preview attacks are blocked in `game.attack()` to prevent client-side unvalidated rewards; solo combat and dungeon progression are unchanged.

Known limits: This is **not the final Phase 5 combat feature**. Enemy health, movement, abilities, revive, group rewards, PvP and online/Noray are not synchronized. Next step is host-authoritative encounter simulation and loot grants with anti-duplicate validation. Do not label the preview as full multiplayer dungeon gameplay.

Regression tests: `tests/coop_parties.gd` validates 4-member party isolation, leader floor control and the local preview; `tests/coop_lan_pair.gd` launches a real UDP host/client across two Godot processes and tests connection, remote character display and run entry/exit. Existing chunk, dungeon, crafting, title and boar tests remain in CI.

Android gates: grant INTERNET permission, use same Wi-Fi without client isolation, allow host UDP 30115 through firewalls. Test physical Android landscape touch controls and multiple devices before any main merge.
