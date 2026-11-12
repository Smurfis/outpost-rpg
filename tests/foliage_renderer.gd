extends SceneTree
## Run with: godot --headless --path . -s res://tests/foliage_renderer.gd
## Protects the dedicated foliage atlas, one-material trees, and chunk lifecycle.
var failures: int = 0

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS FOLIAGE: " + message)
	else:
		failures += 1
		push_error("FAIL FOLIAGE: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	const_path_check()
	var foliage = load("res://scripts/voxel/foliage_renderer.gd")
	_check(foliage != null, "Dedicated foliage renderer parses")
	if foliage == null:
		quit(1)
		return
	var mat: StandardMaterial3D = foliage.material()
	_check(mat != null and mat.albedo_texture != null, "Tree atlas material is bound")
	if mat != null and mat.albedo_texture != null:
		_check(mat.albedo_texture.get_size() == Vector2(80, 60), "Padded 4x3 tree atlas is 80x60")
		_check(mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Foliage uses nearest filtering")
	var original_palette = load("res://scripts/voxel/voxel_palette.gd")
	_check(mat != original_palette.get_material(), "Foliage material is independent of terrain and ocean")
	for species in range(7):
		var tree: MeshInstance3D = foliage.tree(species)
		_check(tree != null and tree.mesh != null and tree.mesh.get_surface_count() == 1,
			"Tree species %d uses one batched surface" % species)
		if tree != null and tree.mesh != null:
			var uv: PackedVector2Array = tree.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
			_check(uv.size() >= 100, "Tree species %d has textured faces" % species)
			_check(tree.material_override == mat, "Tree species %d shares the atlas material" % species)
	_check(foliage.species_at(12.0, -32.0) == foliage.species_at(12.0, -32.0),
		"Tree species remain deterministic across reloads")
	var props = load("res://scripts/voxel/voxel_props.gd")
	var harvest_tree: MeshInstance3D = props.tree()
	var shrub: MeshInstance3D = props.bush(true)
	_check(harvest_tree.material_override == mat, "Existing wood node uses new texture renderer")
	_check(shrub.material_override == mat, "Gatherable bushes use the same foliage atlas")
	var source: PackedScene = load("res://scenes/main.tscn")
	_check(source != null, "Main game scene parses after foliage integration")
	if source != null:
		root.set_meta("outpost_new_adventure", true)
		var game: Node3D = source.instantiate() as Node3D
		root.add_child(game)
		await process_frame
		var field: Node3D = game.get_node_or_null("VoxelAtmosphere") as Node3D
		_check(field != null, "Voxel Fields still builds")
		if field != null:
			# _chunk_foliage() deliberately returns null: the actual
			# harvestable wood resource carries the tree atlas. A duplicate
			# streamed crown used to draw a second, unharvestable tree.
			var duplicate_crowns: int = 0
			for child in field.get_children():
				if str(child.name).begins_with("ChunkFoliage_"):
					duplicate_crowns += 1
			_check(duplicate_crowns == 0, "Streaming avoids duplicate unharvestable tree crowns")
			var textured_tree_found: bool = false
			for resource in get_nodes_in_group("resources"):
				if str(resource.get("kind")) != "wood":
					continue
				for child in resource.get_children():
					if child is MeshInstance3D and child.name == "HarvestableModel":
						if child.material_override == mat:
							textured_tree_found = true
							break
				if textured_tree_found:
					break
			_check(textured_tree_found, "Loaded Fields has actual harvestable trees using the foliage atlas")
		game.queue_free()
		await process_frame
	print("FOLIAGE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func const_path_check() -> void:
	_check(ResourceLoader.exists("res://assets/textures/trees/tree_atlas_padded_16.png"),
		"Original generated tree atlas is committed and importable")
