extends SceneTree
## Regression for Android v1029: solid ground collisions existed but GPU ocean
## appeared over every terrain chunk. Shader ALPHA writes caused the blended
## transparent queue even when ALPHA was exactly 1.0.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS OPAQUE TERRAIN: " + message)
	else:
		failures += 1
		push_error("FAIL OPAQUE TERRAIN: " + message)

func _run() -> void:
	var terrain_shader: Shader = load("res://scripts/voxel/greedy_atlas.gdshader")
	var ocean_shader: Shader = load("res://scripts/voxel/coastal_water.gdshader")
	check(terrain_shader != null and ocean_shader != null, "Terrain and water shaders import")
	if terrain_shader == null or ocean_shader == null:
		quit(1)
		return
	check(not terrain_shader.code.contains("ALPHA ="), "Opaque ground shader never enters the transparent alpha pipeline")
	check(not ocean_shader.code.contains("ALPHA ="), "Opaque ocean shader never enters the transparent alpha pipeline")
	check(terrain_shader.code.contains("depth_draw_opaque"), "Ground explicitly uses opaque depth")
	check(ocean_shader.code.contains("depth_draw_opaque"), "Water explicitly uses opaque depth")
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Playable world scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var biome = game.get_node_or_null("VoxelAtmosphere")
	check(biome != null, "Streamed voxel island exists")
	if biome != null:
		check(biome.is_land_at(0.0, 0.0), "Starter camp remains LAND")
		check(biome._land_cell(0, 0), "Starter ground cell is solid land")
		check(biome._tile_height(0, 0) > biome.SEA_LEVEL + 1.0, "Starter top surface physically above ocean")
		check(biome.loaded_chunk_count() > 0, "Visible terrain chunks generated")
		var dry_ground: MeshInstance3D = biome.get_node_or_null("GroundChunk_0_0") as MeshInstance3D
		check(dry_ground != null and dry_ground.mesh != null, "Camp produces rendered ground mesh (not just collision)")
		if dry_ground != null:
			check(dry_ground.visible, "Ground remains a visible 3D node")
			check(dry_ground.material_override is ShaderMaterial, "Greedy terrain uses correct surface material")
			if dry_ground.material_override is ShaderMaterial:
				var shader: Shader = (dry_ground.material_override as ShaderMaterial).shader
				check(shader != null and not shader.code.contains("ALPHA ="), "Actual ground mesh uses opaque material")
		var water: MeshInstance3D = biome.get_node_or_null("DistantWaterHorizon") as MeshInstance3D
		check(water != null, "Coastal water effect remains available")
		if water != null:
			check(water.position.y < biome._tile_height(0, 0), "Water surface remains below the starter island")

		# Water-cell foam used to render as tinted rectangular patches. Confirm
		# coastal overlays contain feathered vertex colours and follow grid edges.
		biome.update_streaming_for(Vector3(79.0, 0.0, 68.0))
		var surf: MeshInstance3D = null
		for item in biome.get_children():
			if item is MeshInstance3D and str(item.name).begins_with("ShoreFoam_"):
				surf = item as MeshInstance3D
				break
		check(surf != null and surf.mesh != null, "Surf exists near the real island shoreline")
		if surf != null and surf.mesh != null:
			var surface_arrays: Array = surf.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = surface_arrays[Mesh.ARRAY_COLOR]
			check(colors.size() == vertices.size() and colors.size() > 0,
				"Shore foam provides actual per-vertex fade data")
			var transparent_edge: bool = false
			var soft_foam: bool = false
			var narrow_coast: bool = true
			var restrained_surf: bool = true
			var bluish_white: bool = true
			for i in range(colors.size()):
				transparent_edge = transparent_edge or colors[i].a <= 0.01
				soft_foam = soft_foam or colors[i].a > 0.2 and colors[i].a < 0.7
				bluish_white = bluish_white and colors[i].b >= colors[i].g and colors[i].g > colors[i].r
				restrained_surf = restrained_surf and colors[i].a <= 0.29
				var vertex: Vector3 = vertices[i]
				if minf(absf(vertex.x - roundf(vertex.x)), absf(vertex.z - roundf(vertex.z))) > 0.34:
					narrow_coast = false
			check(transparent_edge and soft_foam, "Surf blends away instead of showing hard-edged boxes")
			check(bluish_white, "Surf tint is cool white, not a murky green overlay")
			check(narrow_coast, "Surf strips hug coastline edges rather than filling water cells")
			check(restrained_surf, "Shore foam has restrained alpha instead of bright opaque border wedges")
			check(surf.material_override is StandardMaterial3D
				and (surf.material_override as StandardMaterial3D).vertex_color_use_as_albedo,
				"Android foam material respects vertex-colour transparency")
	game.queue_free()
	await process_frame
	print("OPAQUE TERRAIN RESULT: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
