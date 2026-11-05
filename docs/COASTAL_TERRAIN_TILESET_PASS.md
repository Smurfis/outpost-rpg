# Outpost coastal terrain and tiled beach pass

## Shipped procedural geometry
- Continuous signed coastline sampler controls walkable island, graded sandy beach, underwater seabed and collision. No square hard cut or single-pixel sand stripe.
- Surface zones: water -> wet sand -> dry sand -> grassy sand -> coastal soil -> inland grass.
- Existing 12x12 stream chunk geometry, greedy meshing, dungeon locations, save logic and camera orbit remain intact.
- New separate 2x2 (32x32 pixels) coastal texture atlas has cell IDs 16-19. Original 4x4 (64x64) atlas for tiles 0-15 and world props stays compatible.
- The new atlas is assets/voxel/coastal_terrain_16px.svg. It is ORIGINAL project art, not the artist pack, and is nearest sampled on 3D terrain; no camera-locked 2D diamond outlines.
- Coastal tree/resource/boar placements are moved inland to avoid floaters.
- No ALPHA writes in the terrain shader: Android's opaque ocean/terrain depth handling remains mandatory following Build 1029.

## Art licensing and status
Requested forest pack: https://store.godotengine.org/asset/kipper-falcon/isometric-forest-pixel-art-2d/

The Kipper Falcon asset page lists CC0 game usage, while also requesting no repackaging/redistribution of the raw asset files. The external archive could not be fetched through the current runtime. This branch therefore uses its own interim 16x16 pixel atlas and DOES NOT claim the artist's actual texture pixels have been integrated.

To finish exact source artwork, download the author's ZIP from the asset store (or OpenGameArt) and provide it to the implementation environment. Extract flat material patterns into the existing atlas cells without reusing perspective-specific diamond silhouettes on rotating 3D faces. Keep the raw third-party source archive out of standalone repository redistribution. Replace artwork independently of collision, mask or save data.

## Validation
Run tests/coastal_beach_biome.gd, tests/android_opaque_terrain_water.gd, tests/chunk_streaming.gd and tests/island_smart_action_camera_knockback.gd under Godot 4.7.2; then verify the actual coastline on an Android device.

Deferred: boating, water swimming, wet sand footsteps, beach erosion and the exact third-party texture-art pass.