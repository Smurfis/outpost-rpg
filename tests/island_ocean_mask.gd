extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ISLAND OCEAN: " + message)
	else:
		failures += 1
		push_error("FAIL ISLAND OCEAN: " + message)

func run() -> void:
	var biome = load("res://scripts/voxel/voxel_biome.gd").new()
	var islands = load("res://scripts/world/island_archipelago.gd").new()
	islands.setup(64012)
	biome.archipelago = islands
	biome.map_world_half = 384
	biome._configure_island_ocean_mask()
	var image: Image = biome._island_ocean_mask.get_image()
	check(biome._water_material().get_shader_parameter("island_land_mask_enabled") == true, "Water mask is enabled for islands")
	for island in islands.terrain.islands:
		var center: Vector2i = island.center
		check(image.get_pixel(center.x + 384, center.y + 384).r > 0.5, "Land beneath island %s is masked" % center)
		var matches := true
		for dx in range(-50, 51, 2):
			for dz in range(-50, 51, 2):
				var x: int = center.x + dx
				var z: int = center.y + dz
				if x < -384 or x >= 384 or z < -384 or z >= 384:
					continue
				var should_mask: bool = islands.terrain.height_at(x, z) > biome.SEA_LEVEL
				if (image.get_pixel(x + 384, z + 384).r > 0.5) != should_mask:
					matches = false
		check(matches, "Island %s shoreline mask follows terrain height" % center)
	check(image.get_pixel(384 + 100, 384 + 150).r < 0.5, "Open ocean remains unmasked")
	islands.free()
	biome.free()
	print("ISLAND OCEAN RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
