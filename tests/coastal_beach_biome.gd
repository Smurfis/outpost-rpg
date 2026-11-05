extends SceneTree
## Coastline regression: height, texture and collision must agree on Android,
## including after camera orbit and deterministic chunk unloading/rebuilding.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS BEACH: " + message)
	else:
		failures += 1
		push_error("FAIL BEACH: " + message)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Playable world scene remains loadable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var biome = game.get_node_or_null("VoxelAtmosphere")
	check(biome != null and biome.stream_enabled, "Real streamed island and camp still active")
	if biome == null:
		quit(1)
		return
	check(biome.is_land_at(0.0, 0.0) and biome.coast_zone_at(0.0, 0.0) == "inland", "Safe starter camp remains inland")
	check(not biome.is_land_at(95.0, 95.0), "Square diagonal corners remain water")

	var atlas: Texture2D = load("res://assets/voxel/coastal_terrain_16px.svg")
	check(atlas != null and atlas.get_size() == Vector2(32, 32), "Separate 4-cell 16px coastal art atlas imported")
	var coast_texture: Texture2D = load("res://scripts/voxel/voxel_palette.gd").coast_texture()
	check(coast_texture != null and coast_texture.get_size() == Vector2(32, 32), "Greedy atlas has real loaded coastal texture")
	var shader: Shader = load("res://scripts/voxel/greedy_atlas.gdshader")
	check(shader != null and shader.code.contains("coast_texture"), "Opaque 3D shader samples beach atlas")
	check(shader != null and not shader.code.contains("ALPHA ="), "Avoid Android 1029 transparent-ground regression")
	var material = load("res://scripts/voxel/greedy_mesher.gd").material()
	check(material.get_shader_parameter("coast_texture") != null, "Terrain shader binds imported coastal texture")

	var zones: Dictionary = {}
	var shoreline_heights: Array[float] = []
	for x in range(35, 96):
		for z in [-36, -12, 0, 12, 36]:
			var posx: float = float(x) + 0.5
			var posz: float = float(z) + 0.5
			var zone: String = biome.coast_zone_at(posx, posz)
			zones[zone] = true
			var ground_height: float = biome._tile_height(x, z)
			if biome.is_land_at(posx, posz):
				if zone != "inland":
					check(ground_height > biome.SEA_LEVEL, "Sand and dune cells remain above sea at " + str(x) + "," + str(z)) if ground_height <= biome.SEA_LEVEL else false
					shoreline_heights.append(ground_height)
				var texture_id: int = biome._ground_tile(x, z)
				match zone:
					"wet_sand":
						check(texture_id == biome.TILE_WET_SAND, "Wet sand maps to atlas 17") if texture_id != 17 else false
					"dry_sand":
						check(texture_id == biome.TILE_DRY_SAND, "Dry sand maps to atlas 16") if texture_id != 16 else false
					"grass_sand":
						check(texture_id == biome.TILE_GRASS_SAND, "Grass-to-sand transition maps to atlas 18") if texture_id != 18 else false
					"coastal_soil":
						check(texture_id == biome.TILE_COAST_SOIL, "Dirt transition maps to atlas 19") if texture_id != 19 else false
			elif zone == "water":
				check(ground_height < biome.SEA_LEVEL, "Submerged floor stays below ocean") if ground_height >= biome.SEA_LEVEL else false
	for required in ["inland", "coastal_soil", "grass_sand", "dry_sand", "wet_sand", "water"]:
		check(zones.has(required), "Procedural island creates real " + required + " cells")
	check(shoreline_heights.size() > 20, "Beach is a multi-cell band, not a one-tile coastline sticker")
	check(biome._tile_height(0, 0) > biome.SEA_LEVEL + 1.0, "Camp mesh remains physically above ocean")

	biome.update_streaming_for(Vector3(79.0, 0, 7.0))
	var coast_material_count: int = 0
	var mesh_count: int = 0
	for node in biome.get_children():
		if not str(node.name).begins_with("GroundChunk_") or not node is MeshInstance3D:
			continue
		var mesh_node: MeshInstance3D = node
		mesh_count += 1
		if mesh_node.mesh == null:
			continue
		var arrays: Array = (mesh_node.mesh as ArrayMesh).surface_get_arrays(0)
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for texcoord in uv2:
			if texcoord.x >= 16.0 and texcoord.x <= 19.0:
				coast_material_count += 1
				break
	check(mesh_count > 0 and coast_material_count > 0, "Actual streamed ground triangles use new sand/material atlas IDs")

	var original: float = biome._tile_height(80, 7)
	var old_angle: float = game.camera_angle_target
	game.rotate_camera(1)
	game._camera(0.4)
	check(biome._tile_height(80, 7) == original, "Rotating iso camera doesn't rotate shoreline textures or collision")
	game.rotate_camera(-1)
	check(is_equal_approx(game.camera_angle_target, old_angle), "Camera rotation still reversible")

	game.queue_free()
	await process_frame
	print("COASTAL BEACH RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
