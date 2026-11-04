extends SceneTree
## Real chunk loading/unloading and exact terrain reproduction after travel.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS STREAM: " + description)
	else:
		failures += 1
		push_error("FAIL STREAM: " + description)

func _run() -> void:
	var source: PackedScene = load("res://scenes/main.tscn")
	if source == null:
		check(false, "Gameplay scene loads")
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = source.instantiate()
	root.add_child(game)
	await process_frame
	var field = game.get_node("VoxelAtmosphere")
	check(field.stream_enabled, "Finite Fields chunk streaming is on by default")
	check(field.map_half == 96, "Fields spans 192x192 world studs")
	check(field.loaded_chunk_count() == 49, "Only nearest 7x7 chunks load at spawn")
	check(field.chunk_meshes.size() == field.loaded_chunk_count(), "Chunk tracking contains one mesh per loaded cell")
	check(field.has_chunk_at(0.5, 0.5), "Spawn terrain has collision and visual mesh")
	check(not field.has_chunk_at(83, 83), "Distant terrain is not generated at startup")
	var original = field.get_node_or_null("GroundChunk_0_0")
	check(original != null, "Origin mesh exists")
	var original_vertices: PackedVector3Array = (original.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	game.hero.global_position = Vector3(78, 4.0, 78)
	field.update_streaming_for(game.hero.global_position)
	await physics_frame
	check(field.has_chunk_at(78, 78), "Moving into distant Fields loads nearby terrain")
	check(not field.has_chunk_at(0, 0), "Travelling unloads distant starting cells")
	check(field.get_node_or_null("GroundCollision_72_72") != null, "New destination collision loads with mesh")
	check(field.loaded_chunk_count() <= 49, "Loaded mesh/collider budget stays bounded")
	check(field.get_node_or_null("ChunkDecor_72_72") != null, "Chunk decoration streams in as a unit")
	# Private dungeons teleport the hero to coordinates far beyond Fields.
	# The streaming subsystem must ignore that without tearing down the map.
	var count_before: int = field.loaded_chunk_count()
	field.update_streaming_for(Vector3(2500, 0, 2500)) # direct calls must be safe
	check(field.loaded_chunk_count() == count_before, "Out-of-world dungeon positions never unload overworld cells")
	game.hero.global_position = Vector3(0, 0.35, 0)
	field.update_streaming_for(game.hero.global_position)
	await physics_frame
	check(field.has_chunk_at(0, 0), "Return trip reconstructs starting terrain")
	check(not field.has_chunk_at(78, 78), "Return trip unloads far-off terrain")
	var rebuilt = field.get_node_or_null("GroundChunk_0_0")
	check(rebuilt != null, "Origin mesh is recreated")
	if rebuilt != null:
		var rebuilt_vertices: PackedVector3Array = (rebuilt.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(rebuilt_vertices == original_vertices, "Unloaded chunks rebuild identical deterministic voxel terrain")
	check(int(game.inventory.get("wood", -1)) == 0, "Chunk travel does not modify inventory")
	check(game.get_node("Dungeons").entrances.size() == 5, "Existing dungeon portals remain registered")
	game.queue_free()
	await process_frame
	# The older complete-map mode stays configurable for technical A/B tests.
	var fallback = source.instantiate()
	fallback.chunk_streaming_enabled = false
	root.add_child(fallback)
	await process_frame
	var old_field = fallback.get_node("VoxelAtmosphere")
	check(old_field.map_half == 48 and old_field.chunk_meshes.size() == 64, "Disabling streaming restores the original 96x96 all-loaded Fields")
	fallback.queue_free()
	await process_frame
	print("CHUNK STREAM RESULT: %d failures." % failures)
	quit(0 if failures == 0 else 1)
