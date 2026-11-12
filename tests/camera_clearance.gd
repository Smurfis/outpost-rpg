extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("CAMERA FAIL: " + label)
	else:
		print("CAMERA PASS: " + label)

func solid(at: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.global_position = at
	return body

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.hero.set_physics_process(false)
	# Isolate the camera test from world terrain and moving enemies.
	game.hero.global_position = Vector3(2000, 0, 2000)
	game.camera_angle = 0.0
	game.camera_angle_target = 0.0
	game.camera_focus_smooth = Vector3.ZERO
	game.camera_occlusion_rise = 0.0
	game._camera(1.0)
	var original: Vector3 = game.camera.global_position
	var focus: Vector3 = game.camera_focus_smooth
	# Solid lintel at the same height and thickness as a dungeon doorway.
	var lintel := solid(Vector3(focus.x, 2.96, focus.z + 2.638), Vector3(4, 0.5, 0.55))
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(original, focus, 1, [game.hero.get_rid()])
	check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Doorway fixture blocks the old camera sightline")
	game._camera(1.0)
	check(game.camera.global_position.is_equal_approx(original), "Doorway lintel does not lift the camera")
	var tree := solid(focus + Vector3(0, 4, 5.25), Vector3(2, 6, 2))
	await physics_frame
	await physics_frame
	game._camera(1.0)
	check(is_zero_approx(game.camera_occlusion_rise), "Tree on the sightline does not change camera framing")
	var obstruction := solid(original, Vector3(2, 1, 2))
	await physics_frame
	await physics_frame
	game._camera(1.0)
	check(game.camera_occlusion_rise > 0.9 and game.camera_occlusion_rise <= 1.0, "Geometry at the actual camera position still activates clearance")
	var orbit: Vector3 = game.camera.global_position - (focus + Vector3.UP * game.camera_occlusion_rise)
	check(orbit.is_equal_approx(Vector3(0, 20, 26.25)), "Clearance preserves fixed isometric pitch and orbit")
	obstruction.queue_free()
	await physics_frame
	await physics_frame
	game._camera(2.0)
	check(game.camera_occlusion_rise < 0.001, "Camera returns to normal framing after obstruction clears")
	lintel.queue_free()
	tree.queue_free()
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
