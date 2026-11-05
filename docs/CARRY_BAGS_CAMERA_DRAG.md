# Outpost — Carry weight, tiered bags and touch camera

## Shipped implementation
- Base 36 load units; materials and equipment have distinct weights; coins are weightless.
- Six bag recipes: T1/T2 general backpacks (+26/+52), wood and ore specialist satchels (+15/+27 and 38-50% matching weight reduction).
- Recrafting an already-owned bag raises its quality by one star (up to three) without adding duplicate stock. Each star grants +5 load, and specialists get 3% more targeted weight reduction.
- Dedicated bag equipment slot; unequipping or changing to smaller bag never destroys inventory. Overloaded movement slows to 48%, gathering and new crafting are restricted.
- Excess quest or enemy rewards move to persistent stored loot, claimable from the Bag UI after freeing space.
- Inventory screen: real capacity meter, star display, tier and specialty bonuses and recovery action. Existing staged crafting interaction remains.
- Drag the central open world on mobile for continuous orbit. Joystick and smart-action slider keep separate touch identities. Right-mouse drag and Q/R keyboard fallback on desktop.
- Smooth vertical camera follow for beach steps; teleport snaps prevent long camera lag.

## Migration and limitations
- Save version remains 5. Optional bag_quality and overflow_loot keys default safely for existing saves.
- Existing gathering tool called satchel is separate from new carry satchels.
- Star quality is maintained per bag recipe type, not per physical instance. No full inventory bank, world drops or other bag variants yet.
- Kipper Falcon third-party forest textures are NOT included; user plans to supply ZIP separately.
- Android touchscreen visual QA required before final sign-off.

## Verification
Run tests/carry_bags_camera.gd, tests/island_smart_action_camera_knockback.gd, tests/pixel_ui_integration.gd, tests/smoke.gd and the full GitHub Godot 4.7.2 smoke workflow.
