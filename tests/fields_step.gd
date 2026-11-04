extends SceneTree
## 96x96 generated Fields, taller voxel portals, 1-block controller step.
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS FIELDS: " + message)
	else:
		failed += 1
		push_error("FAIL FIELDS: " + message)

func _box(caption: String, position: Vector3, dimensions: Vector3) -> StaticBody3D:
	var node := StaticBody3D.new()
	node.name = caption
	node.collision_layer = 1
	node.collision_mask = 1
	node.position = position
	var child := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	child.shape = shape
	node.add_child(child)
	return node

func _run() -> void:
	var source: PackedScene = load("res://scenes/main.tscn")
	check(source != null, "Original game scene loads")
	if source == null:
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = source.instantiate()
	root.add_child(game)
	await process_frame
	var terrain = game.get_node("VoxelAtmosphere")
	check(game.fields_biome_enabled, "Expanded Fields enabled by default in voxel mode")
	check(terrain.map_half == 48, "New Fields bounds are 96x96")
	check(terrain.chunk_meshes.size() == 64, "Fields split into 64 render chunks, 12x12 studs each")
	check(terrain.get_node_or_null("GroundCollision_-48_-48") != null, "Terrain chunks use real trimesh collision")
	check(is_equal_approx(terrain.surface_y_at(0, 0), -0.055), "Outpost camp remains level")
	check(is_equal_approx(terrain.surface_y_at(23, 12), -0.055), "Original starter boundary stays level")
	var elevations: Dictionary = {}
	var quantized: bool = true
	for x in range(-44, 45, 4):
		for z in range(-44, 45, 4):
			if maxf(absf(float(x)), absf(float(z))) < 32.0:
				continue
			var h: float = terrain.surface_y_at(float(x), float(z)) + 0.055
			elevations[roundi(h)] = true
			if absf(h - float(roundi(h))) > 0.0001:
				quantized = false
	check(quantized, "Perlin elevations land on whole-voxel heights")
	check(elevations.size() >= 2, "Fields contains multiple walkable elevations")
	check(terrain.get_node_or_null("FieldsBatchedScenery") != null, "Far-field trees, rocks and shrubs share one mesh")
	check(game.get_node_or_null("Terrain") != null, "Starter collision floor remains intact")
	var manager = game.get_node("Dungeons")
	check(manager.entrances.size() == 5, "Existing rarity dungeons remain available")
	var portal = manager.entrances["preview_rare:0"]
	check(portal.get_node_or_null("VoxelStoneMonument") != null, "Dungeon entrance uses single pixel-atlas stone monument")
	check(portal.orb != null and portal.orb.mesh is BoxMesh, "Oversized rarity gate uses chunky glow")
	check(portal.label.position.y > 5.8, "Portal exceeds five voxel blocks in height")
	check((portal.get_child(0) as CollisionShape3D).shape.size.x > 5.0, "Monument remains touchable on phone")
	check(game.hero.auto_step_enabled and game.hero.max_auto_step_height > 1.0, "Player can automatically climb 1 voxel")
	check(game.hero.floor_snap_length > 1.0, "Character snaps down short drops")
	
	# An isolated high-altitude obstacle probes the real CharacterBody3D
	# collision path, without depending on the random terrain seed.
	var slab := _box("StepTestFloor", Vector3(0, 19.5, 0), Vector3(11, 1, 11))
	game.add_child(slab)
	var low := _box("OneVoxelStep", Vector3(0, 20.5, -1), Vector3(3, 1, 1))
	game.add_child(low)
	var tall := _box("TallWall", Vector3(3, 21.0, -1), Vector3(1, 2.0, 1))
	game.add_child(tall)
	game.hero.global_position = Vector3(0, 20.03, 0.1)
	game.hero.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	var stepped: bool = game.hero._try_auto_step(Vector3(0, 0, -0.88))
	check(stepped, "Controller steps across one-voxel obstacle")
	check(game.hero.global_position.y > 20.90, "Controller actually rises onto step")
	game.hero.global_position = Vector3(3, 20.03, 0.1)
	game.hero.velocity = Vector3.ZERO
	await physics_frame
	var blocked: bool = game.hero._try_auto_step(Vector3(0, 0, -0.88))
	check(not blocked, "Two-voxel obstacle cannot be climbed automatically")
	# Prove that the ordinary joystick -> move_and_slide path can trigger the
	# auto-step after the capsule hits the obstacle's face.
	game.hero.global_position = Vector3(-1, 20.03, 0.24)
	game.hero.velocity = Vector3.ZERO
	game.hud.move_vector = Vector2.ZERO
	await physics_frame
	var climbed_by_joystick: bool = false
	for frame_number in range(95):
		var camera_forward: Vector3 = -game.camera.global_transform.basis.z
		camera_forward.y = 0.0
		camera_forward = camera_forward.normalized()
		var camera_right: Vector3 = game.camera.global_transform.basis.x
		camera_right.y = 0.0
		camera_right = camera_right.normalized()
		var desired := Vector3(0, 0, -1)
		game.hud.move_vector = Vector2(desired.dot(camera_right), -desired.dot(camera_forward)).limit_length()
		await physics_frame
		if game.hero.global_position.y > 20.90 and game.hero.global_position.z < -0.5:
			climbed_by_joystick = true
			break
	game.hud.move_vector = Vector2.ZERO
	check(climbed_by_joystick, "Ordinary joystick walking climbs the one-voxel ledge automatically")
	game.queue_free()
	await process_frame
	print("FIELDS RESULT: %d failed assertion(s)." % failed)
	quit(0 if failed == 0 else 1)
