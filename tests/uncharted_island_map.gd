extends SceneTree
## Explorers must see all undiscovered islands before sailing, without any
## fog-of-war progress or private cave/chest positions being revealed.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS UNCHARTED MAP: " + message)
	else:
		failures += 1
		push_error("FAIL UNCHARTED MAP: " + message)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Outpost gameplay scene loads")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var biome = game.get_node_or_null("VoxelAtmosphere")
	check(biome != null and biome.archipelago != null,
		"Fractal archipelago initializes in the gameplay scene")
	if biome == null or biome.archipelago == null:
		game.queue_free()
		quit(1)
		return
	var map = game.world_map
	check(map != null and map.uncharted != null, "Map preview layer exists")
	if map != null and map.uncharted != null:
		var shadows = map.uncharted
		check(shadows.island_count == 3 and shadows.land_cells > 500,
			"Three seeded unexplored silhouettes are meshed before discovery")
		check(shadows.island_mesh != null and shadows.ocean_mesh != null,
			"Dark island mesh contrasts with ocean background")
		if shadows.island_mesh != null:
			check(shadows.island_mesh.layers == (1 << 1),
				"Undiscovered island shadows render on the map-only layer")
		check(map.mini_camera.cull_mask == 1,
			"Mini-map doesn't reveal undiscovered island shadows")
		check(map.service.discovered.size() == 0,
			"Preview never modifies discovered fog-of-war cells")
		map.overview()
		check(map.target_span > 450.0,
			"Islands overview is wider than original home-only framing")
		check(map.target_focus.z > 20.0,
			"Islands overview is centred between home and remote terrain")
		check(map.service.visibility_at(Vector3(172, 0, 62)) == 0,
			"Uncharted islands remain unknown in gameplay discovery")
	# Verify actual island geometry is generated when approached at sea.
	var streamer = biome.archipelago
	streamer._queue_near(Vector3(155, 8, 62))
	streamer._build_pending()
	check(streamer.loaded_chunk_count() > 0,
		"Approaching an exploration island streams actual mesh chunks")
	var rock: int = 0
	for node in streamer.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("IslandRock_"):
			rock += 1
	check(rock > 0, "Streamed island has visible terrain geometry")
	game.queue_free()
	await process_frame
	print("UNCHARTED MAP RESULT: %d failures." % failures)
	quit(0 if failures == 0 else 1)
