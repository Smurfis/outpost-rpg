extends SceneTree
## The camera cuts foreground fractal pixels, never terrain collision or
## whole cave-roof meshes. The shared starter-island material stays untouched.
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")
const ATLAS = preload("res://scripts/voxel/greedy_atlas.gdshader")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS CAVE CAMERA: " + message)
	else:
		failures += 1
		push_error("FAIL CAVE CAMERA: " + message)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var main: PackedScene = load("res://scenes/main.tscn")
	check(main != null, "Game scene imports")
	if main == null:
		quit(1)
		return
	var game = main.instantiate()
	root.add_child(game)
	await process_frame
	var island = game.terrain_surface.archipelago
	check(island != null, "Fractal archipelago is enabled")
	if island == null:
		quit(1)
		return
	check(island._cutaway_material != null and island._cutaway_material != GREEDY.material(),
		"Fractal material is independent from the starter Fields")
	check(not bool(GREEDY.material().get_shader_parameter("island_cutaway_enabled")),
		"Fields atlas cutaway is disabled by default")
	check(ATLAS.code.contains("discard;") and ATLAS.code.contains("island_world_position"),
		"Shader discards foreground pixels without changing mesh collision")
	var world = island.terrain
	var tunnel: Vector3i = Vector3i.ZERO
	var covered: bool = false
	for route in world.caves.routes:
		for point in route:
			var at: Vector3i = point
			if world.height_at(at.x, at.z) >= at.y + 4:
				tunnel = at
				covered = true
				break
		if covered:
			break
	check(covered, "Test island contains a real covered descending tunnel")
	if not covered:
		game.queue_free()
		await process_frame
		quit(1)
		return
	var cave_player := Vector3(float(tunnel.x) + 0.5, float(tunnel.y) + 0.35, float(tunnel.z) + 0.5)
	game.hero.global_position = cave_player
	game._camera(1.0)
	var cave_chunk: Vector2i = island._cell_at(cave_player)
	island._build_chunk(cave_chunk)
	check(not island._roof_nodes.is_empty(), "Covered cave has independent drawable roof geometry")
	var nodes: Array = island._loaded.get(cave_chunk, [])
	var body_count: int = 0
	var cutaway_mesh_count: int = 0
	for node in nodes:
		if node is StaticBody3D:
			body_count += 1
		elif node is MeshInstance3D:
			check(node.material_override == island._cutaway_material,
				"Both rock and ceiling use one independent cutaway material")
			cutaway_mesh_count += 1
	check(body_count == 1 and cutaway_mesh_count > 0, "Terrain keeps physical collider even with camera cutaway")
	island._update_cutaway(game, cave_player)
	check(island._cave_mode and bool(island._cutaway_material.get_shader_parameter("island_cave_mode")),
		"Descending cave widens the camera cutaway")
	check(is_equal_approx(float(island._cutaway_material.get_shader_parameter("island_cutaway_radius")), 5.2),
		"Interior ceiling uses the wider cutaway radius")
	check(bool(island._cutaway_material.get_shader_parameter("island_cutaway_enabled")),
		"Camera-to-player cutaway becomes active on a fractal island")
	check((island._cutaway_material.get_shader_parameter("island_cutaway_eye") as Vector3).distance_to(game.camera.global_position) < 0.01,
		"Cutaway follows actual smooth camera orbit")
	check((island._cutaway_material.get_shader_parameter("island_cutaway_focus") as Vector3).distance_to(cave_player + Vector3.UP * 0.95) < 0.01,
		"Cutaway tracks the player's head, not a remote chunk")
	for roof in island._roof_nodes:
		check(roof.visible, "Cave roofs are still rendered, never hidden wholesale")
	check(not bool(GREEDY.material().get_shader_parameter("island_cutaway_enabled")),
		"Shared Fields material remains unaffected by cave mode")
	# A hillside lookout is not an underground cave: the view corridor
	# shrinks but still reveals the player behind foreground rock.
	var shore: Vector3 = world.caves.entrances[0]
	var outside := Vector3(shore.x, float(world.height_at(floori(shore.x), floori(shore.z))) + 0.35, shore.z)
	island._update_cutaway(game, outside)
	check(bool(island._cutaway_material.get_shader_parameter("island_cutaway_enabled")),
		"Outdoor mountain sightline remains occlusion-aware")
	# Leaving remote-island streaming must restore the normal atlas path.
	game.hero.global_position = Vector3.ZERO
	island._process(0.016)
	check(not bool(island._cutaway_material.get_shader_parameter("island_cutaway_enabled")),
		"Cutaway is disabled when the hero leaves fractal islands")
	game.queue_free()
	await process_frame
	print("CAVE CAMERA RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
