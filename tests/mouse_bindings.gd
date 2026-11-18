extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS MOUSE: " + message)
	else:
		failures += 1
		push_error("FAIL MOUSE: " + message)

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	root.set_meta("outpost_input_mode", "desktop")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.controls.context_button() == MOUSE_BUTTON_RIGHT and game.controls.orbit_button() == MOUSE_BUTTON_MIDDLE, "Context and alternative orbit buttons")
	game.equipment["offhand"] = "shield"
	var world_point: Vector2 = game.camera.unproject_position(Vector3(0, -0.05, -8))
	var click := InputEventMouseButton.new()
	click.position = world_point
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	game.controls._input(click)
	var move := InputEventMouseMotion.new()
	move.position = world_point + Vector2(30, 0)
	move.relative = Vector2(30, 0)
	var angle: float = game.camera_angle_target
	game.controls._input(move)
	check(game.controls.rotating and game.camera_angle_target != angle, "RMB drag rotates camera")
	click.pressed = false
	game.controls._input(click)
	check(not game.controls.rotating and not game.hero.blocking, "RMB release ends orbit without blocking")
	click.button_index = MOUSE_BUTTON_MIDDLE
	click.pressed = true
	game.controls._input(click)
	angle = game.camera_angle_target
	game.controls._input(move)
	check(game.controls.rotating and game.camera_angle_target != angle, "MMB drag also rotates camera")
	click.pressed = false
	game.controls._input(click)
	check(not game.controls.rotating, "Releasing orbit ends rotation")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.pressed = true
	game.controls._input(key)
	check(game.hero.blocking, "Shift holds shield block")
	key.pressed = false
	game.controls._input(key)
	check(not game.hero.blocking, "Releasing block key ends blocking")
	game.queue_free()
	await process_frame
	print("MOUSE BINDING RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
