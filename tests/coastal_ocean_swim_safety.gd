extends SceneTree
## Regressions for player-reported ocean appearing inland and endless swimming falls.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS OCEAN SAFETY: " + label)
	else:
		failures += 1
		push_error("FAIL OCEAN SAFETY: " + label)

func _ocean_instances(biome: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in biome.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("OceanSurface_"):
			result.append(child as MeshInstance3D)
	return result

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var source: PackedScene = load("res://scenes/main.tscn")
	check(source != null, "Godot world imports")
	if source == null:
		quit(1)
		return
	var game = source.instantiate()
	root.add_child(game)
	await process_frame
	var biome: Node = game.get_node_or_null("VoxelAtmosphere")
	check(biome != null and biome.stream_enabled, "Overworld uses streamed coastline")
	if biome == null:
		quit(1)
		return
	var horizon: MeshInstance3D = biome.get_node_or_null("DistantWaterHorizon") as MeshInstance3D
	check(horizon != null and horizon.mesh != null and not horizon.visible,
		"Endless-looking deep ocean exists but is HIDDEN near camp inland")
	if horizon != null and horizon.mesh != null:
		var far_vertices: PackedVector3Array = horizon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var no_land_overlay: bool = true
		for i in range(0, far_vertices.size(), 3):
			var mid: Vector3 = (far_vertices[i] + far_vertices[i + 1] + far_vertices[i + 2]) / 3.0
			no_land_overlay = no_land_overlay and maxf(absf(mid.x), absf(mid.z)) >= float(biome.map_half)
		check(no_land_overlay and far_vertices.size() == 24,
			"Four horizon strips stay strictly OUTSIDE island map, never across unloaded land")
	check(_ocean_instances(biome).is_empty(), "No distant ocean surfaces appear when starting inland at camp")

	# Approach true offshore cells. Both the top water polygons and the
	# COLLIDABLE stone seabed must arrive in exactly the same streamed chunk.
	var sample := Vector3(95.2, biome.SEA_LEVEL - 0.74, 0.5)
	check(not biome.is_land_at(sample.x, sample.z), "Offshore sample is water, not inland ground")
	game.hero.global_position = sample
	game.hero.velocity = Vector3.ZERO
	biome.update_streaming_for(sample)
	biome._update_water_horizon(sample)
	await physics_frame
	check(horizon.visible and horizon.material_override is ShaderMaterial,
		"Approaching shore reveals animated endless ocean beyond streamed water")
	var ocean: Array[MeshInstance3D] = _ocean_instances(biome)
	check(not ocean.is_empty(), "Ocean becomes visible once its coastal chunks are streamed")
	var ocean_material_ok: bool = true
	var surfaces_only_over_water: bool = true
	var ocean_at_sea_level: bool = true
	var shore_colors_present: bool = true
	var shallow_pixel_present: bool = false
	for water in ocean:
		ocean_material_ok = ocean_material_ok and water.material_override is ShaderMaterial
		ocean_at_sea_level = ocean_at_sea_level and absf(water.global_position.y - biome.SEA_LEVEL) < 0.01
		var arrays: Array = water.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var shoreline_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		shore_colors_present = shore_colors_present and shoreline_colors.size() == vertices.size()
		for shore in shoreline_colors:
			shallow_pixel_present = shallow_pixel_present or shore.r > 0.15
		for i in range(0, vertices.size(), 3):
			var center: Vector3 = (vertices[i] + vertices[i + 1] + vertices[i + 2]) / 3.0
			surfaces_only_over_water = surfaces_only_over_water and not biome.is_land_at(center.x, center.z)
	check(ocean_material_ok and ocean_at_sea_level, "Streamed water retains the original animated opaque ocean shader at sea level")
	check(shore_colors_present and shallow_pixel_present,
		"Water mesh carries real shoreline proximity for turquoise pixels without extra geometry")
	var shallow_shader: Shader = load("res://scripts/voxel/coastal_water.gdshader")
	check(shallow_shader != null and shallow_shader.code.contains("ocean_shallow") and not shallow_shader.code.contains("ALPHA ="),
		"Turquoise shallows remain in the opaque Android water pipeline")
	check(surfaces_only_over_water, "Every rendered ocean triangle sits over real water cells, never dry or unloaded mainland")
	check(biome._tile_height(95, 0) < biome.SEA_LEVEL - 0.1, "Ocean tile has a real sloping underwater stone floor")
	check(biome.get_node_or_null("GroundCollision_84_0") != null, "Offshore stone floor has streamed trimesh collision")
	var from: Vector3 = Vector3(95.25, biome.SEA_LEVEL - 0.08, 0.5)
	var to: Vector3 = Vector3(95.25, -10.0, 0.5)
	var seabed_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	check(not seabed_hit.is_empty(), "Physics ray downward through ocean hits solid underwater terrain")

	# The original border stopped at Y=-1, ABOVE the water. Check both
	# physical collision and the swimming controller at the real sea depth.
	var rim_from := Vector3(382.0, biome.SEA_LEVEL - 0.78, 0.5)
	var rim_to := Vector3(386.0, biome.SEA_LEVEL - 0.78, 0.5)
	var rim_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(rim_from, rim_to, 1))
	check(not rim_hit.is_empty() and (rim_hit.get("position", Vector3.ZERO) as Vector3).x > 383.0,
		"Outer swimmable ocean boundary is far beyond the visible coastline")
	check(game.hero._detect_surface_swimming(), "Player enters actual swimming state in offshore water")
	for i in range(80):
		await physics_frame
	check(game.hero.global_position.y > biome.SEA_LEVEL - 5.0, "Swimming buoyancy keeps player above seabed over 80 physics frames")
	check(game.hero.global_position.x < 384.0 and game.hero.global_position.x > -384.0,
		"Swimmer stays in enlarged ocean play area instead of falling through old 96m border")

	# Force a position below the former five-metre cut-off to check that the
	# swimmer recovers at sea rather than accelerating into an infinite void.
	game.hero.global_position = Vector3(95.2, biome.SEA_LEVEL - 9.5, 0.5)
	game.hero.velocity = Vector3.DOWN * 20.0
	check(game.hero._detect_surface_swimming(), "Deep water still activates swimming; depth does not disable buoyancy")
	await physics_frame
	check(game.hero.global_position.y > biome.SEA_LEVEL - 2.1, "Underwater failsafe recovers at the same offshore location")
	check(game.hero.global_position.x > 90.0, "Underwater failsafe does not teleport swimmer back to camp")

	# Test genuinely playable open ocean well past the old terrain-map end.
	game.hero.global_position = Vector3(160.0, biome.SEA_LEVEL - 0.78, 0.0)
	game.hero.velocity = Vector3.ZERO
	check(game.hero._detect_surface_swimming(), "Player can keep swimming 64m beyond original sea border")
	var deep_floor_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(160.0, -3.2, 0.0), Vector3(160.0, -12.0, 0.0), 1))
	check(not deep_floor_hit.is_empty(), "Extended open-ocean seabed has real solid collision")
	await physics_frame
	check(game.hero.global_position.y > biome.SEA_LEVEL - 4.0, "Buoyancy remains stable beyond terrain-streaming boundary")
	game.hero.global_position = Vector3(0, 0.35, 0)
	biome._update_water_horizon(game.hero.global_position)
	biome.update_streaming_for(game.hero.global_position)
	await physics_frame
	check(_ocean_instances(biome).is_empty(), "Leaving shoreline unloads faraway ocean surfaces again")
	check(not horizon.visible, "Returning inland hides far horizon again to prevent false water on spawn")
	game.queue_free()
	await process_frame
	print("OCEAN SAFETY RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
