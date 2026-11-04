extends SceneTree
const MESHER = preload("res://scripts/voxel/voxel_greedy.gd")
var failed: int = 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS GREEDY: " + msg)
	else:
		failed += 1
		push_error("FAIL GREEDY: " + msg)
func _run() -> void:
	var scene = load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene imports")
	if scene == null:
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var terrain = game.get_node("VoxelAtmosphere")
	var atlas_material: ShaderMaterial = MESHER.get_material()
	check(atlas_material != null and atlas_material.shader != null, "Shared greedy pixel-atlas shader loads")
	check(atlas_material.get_shader_parameter("atlas") != null, "Greedy shader uses checked-in atlas texture")
	check(terrain.stream_enabled and terrain.greedy_enabled, "Streaming uses greedy planes by default")
	var chunk: MeshInstance3D = terrain.get_node("GroundChunk_0_0")
	check(chunk.material_override == atlas_material, "Terrain renders with shared repeat-safe shader")
	var merged: int = int(chunk.get_meta("greedy_top_quads", -1))
	check(merged > 0 and merged <= 144, "Top greedy quad count tracks source voxel area")
	var triangles: int = (chunk.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3
	check(triangles >= merged * 2, "Ground mesh has a valid triangle surface")
	var first_faces: PackedVector3Array = (chunk.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	terrain.update_streaming_for(Vector3(75, 0, 75))
	terrain.update_streaming_for(Vector3.ZERO)
	await physics_frame
	var rebuilt: MeshInstance3D = terrain.get_node("GroundChunk_0_0")
	check((rebuilt.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == first_faces, "Greedy ground reconstructs deterministically")
	var profile: Dictionary = {}
	for x in range(-36, 37, 12):
		for z in range(-36, 37, 12):
			var sample: MeshInstance3D = MESHER.build_chunk(x, z, 12, 96, Callable(terrain, "surface_y_at"), Callable(terrain, "_ground_tile"))
			var m: int = int(sample.get_meta("greedy_top_quads", 144))
			profile["%d,%d" % [x, z]] = m
	check(profile.values().any(func(v): return int(v) < 144), "Flat same-texture planes merge into fewer quads")
	check(game.get_node("Dungeons").entrances.size() == 5, "Portals stay functional")
	check(int(game.inventory.get("wood", 0)) == 0, "Inventory and saved progression unaffected")
	game.queue_free()
	await process_frame
	var legacy = scene.instantiate()
	legacy.greedy_meshing_enabled = false
	root.add_child(legacy)
	await process_frame
	check(not legacy.get_node("VoxelAtmosphere").greedy_enabled, "Legacy per-tile terrain remains selectable")
	check(legacy.get_node("VoxelAtmosphere").get_node("GroundChunk_0_0").material_override is StandardMaterial3D, "Per-tile fallback uses original material")
	legacy.queue_free()
	await process_frame
	print("GREEDY MESH RESULT: %d failures." % failed)
	quit(0 if failed == 0 else 1)
