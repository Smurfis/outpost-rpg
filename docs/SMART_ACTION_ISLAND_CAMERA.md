# Outpost — smart action, island coast, camera and knockback (v0.5 Android)

Implemented as interactive Godot 4.7.2 code, not screenshot mockups.

## Thumb controls
- Large bottom-right **main INTERACT** button, with smaller direct Attack, Gather and Heal neighbours (old tests/API preserved).
- **Tap:** chooses the nearby valid action: attack a hostile target, harvest a resource, open a nearby crafting station, or toggle a selected torch. If nothing relevant is near, tap does nothing (no spam).
- **Hold 0.34 seconds or drag upward:** reveals a vertical list of **owned gear and tools** (including default training blade). Sliding your finger across a row highlights it; lifting equips/selects it. Unowned equipment never appears. An owned tool uses existing equipment slots and does not toggle itself off if already worn.
- Tool selection persists as optional `active_quick_tool` in existing v5 save JSON; legacy saves default to the training blade. All prior data and package ID remain unchanged. On desktop E = smart interact, G = gather, F = attack.
- Camera left/right controls sit below the clock, with Q/R keyboard bindings, 45° per step; a cheap terrain ray can raise camera height transiently if the character would be obscured.

## Combat
- Striking live boars adds a capped, decaying horizontal impulse and small upward recoil without breaking collision/respawn or AI pursuit; boar attacks give the player similar lateral knockback. No teleporting enemies or damage-stat changes. LAN guardian hit ownership is untouched.

## Island and water
- Finite 192×192 coordinate bounds are still used for chunk budget; **the land silhouette is no longer a 192×192 square**. A deterministic 4th-power superellipse with several seeded undulations produces headlands, inset coves and differently shaped edges.
- Greedy voxel top faces and collision remain chunked. Underwater cells form hidden seabed collision; beaches use path/gravel tiles and a coastal chunk adds one batched translucent foam strip mesh along water-adjacent shore.
- The ocean plane is one animated shader mesh using inexpensive moving colour and small highlights, compatible with GL Compatibility; no GPU-heavy reflections and no extra textures.
- **Not sailing yet**: the player returns to Outpost if falling into deep water. That is a deliberate temporary safety behavior, not a boat system. A subsequent boat/swim feature should replace this return-to-camp condition; keep the sea-level constant and the land query as possible interfaces.

## Acceptance
- Full Godot smoke suite plus `tests/island_smart_action_camera_knockback.gd`: coastline, shader, foam, touch selector, owned gear selection, camera angles and impulse.
- Old regression tests for exact 72,72 corner decoration or resources now verify these features in reachable land chunks, because ocean cells should stay empty.
- A physical Android landscape test remains mandatory: hold the main button with one finger while using the joystick with another; check no accidental activation, release outside the tool slider; run along cliff faces, rotate camera, walk to shoreline, check water rendering and frame rate.
- Existing permanent signing workflow publishes Android APK updates under `outpost-android-v<code>` from `main`.

## Future work
- Actual buoyant boats, steering, swimming, co-op water traversal, water collision/buoyancy and true infinite terrain streamer.
- Better silhouette-based object visibility / occluder fading for cliffs and roofs; current orbit + limited automatic camera rise reduces but does not fully eliminate every occlusion.
- Shoreline surf sound / wave crest sprite animation and beach biome vegetation; water shader is an inexpensive first pass.
