extends SceneTree
## Run: godot --headless --path . -s res://tests/illustrated_terrain_mushrooms.gd
var failures: int = 0

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var greedy = load("res://scripts/voxel/greedy_mesher.gd")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	greedy.tiled_quad(st, Vector3(0, 0, 0), Vector3(1, 0, 0),
		Vector3(1, 1, 0), Vector3(0, 1, 0), 3, "z")
	var mesh: ArrayMesh = st.commit()
	var uv2: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	_check(uv2.size() == 6 and is_equal_approx(uv2[0].y, 1.0),
		"Greedy dirt walls convey actual upper height for fringe shader")
	var tops := SurfaceTool.new()
	tops.begin(Mesh.PRIMITIVE_TRIANGLES)
	greedy.tiled_quad(tops, Vector3(0, 1, 0), Vector3(0, 1, 1),
		Vector3(1, 1, 1), Vector3(1, 1, 0), 0, "top")
	var top_mesh: ArrayMesh = tops.commit()
	var top_uv2: PackedVector2Array = top_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	_check(top_uv2.size() == 6 and top_uv2[0].y < -1000.0,
		"Ground tops do not accidentally receive cliff-fringe shading")
	var shader: Shader = load("res://scripts/voxel/greedy_atlas.gdshader")
	_check(shader != null, "Illustrated greedy terrain shader loads")
	var biome_script = load("res://scripts/voxel/voxel_biome.gd")
	_check(biome_script != null, "Chunked mushroom biome script parses")
	var voxel_props = load("res://scripts/voxel/voxel_props.gd")
	var mushroom_mesh: MeshInstance3D = voxel_props.mushrooms()
	_check(mushroom_mesh != null and mushroom_mesh.mesh != null, "New mushroom group is a renderable voxel mesh")
	if mushroom_mesh != null and mushroom_mesh.mesh != null:
		var arrays: Array = mushroom_mesh.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		_check(uv.size() >= 60, "Mushrooms include pixel-atlas stems, caps and contrasting spots")
	root.set_meta("outpost_new_adventure", true)
	var game_scene: PackedScene = load("res://scenes/main.tscn")
	_check(game_scene != null, "Game scene loads for collectible mushroom verification")
	if game_scene != null:
		var game = game_scene.instantiate()
		root.add_child(game)
		await process_frame
		var gatherable_count: int = 0
		for item in get_nodes_in_group("resources"):
			if item.kind == "mushrooms":
				gatherable_count += 1
				var pixel_mesh: MeshInstance3D = item.get_node_or_null("VoxelMushrooms") as MeshInstance3D
				_check(pixel_mesh != null and pixel_mesh.mesh != null,
					"Gatherable forest mushrooms use voxel artwork rather than smooth cones")
		_check(gatherable_count >= 3, "Existing camp mushroom resource locations remain available")
		game.queue_free()
		await process_frame
	print("Illustrated terrain tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
