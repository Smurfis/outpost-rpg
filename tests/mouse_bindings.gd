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
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.controls.context_button() == MOUSE_BUTTON_RIGHT and game.controls.orbit_button() == MOUSE_BUTTON_MIDDLE, "Default interaction and orbit buttons")
	game.hud._swap_mouse_bindings()
	check(game.controls.context_button() == MOUSE_BUTTON_MIDDLE and game.controls.orbit_button() == MOUSE_BUTTON_RIGHT, "Settings swap interaction and orbit")
	var prefs := ConfigFile.new()
	check(prefs.load(game.hud.CONTROL_PREFS) == OK and prefs.get_value("controls", "swap_context_and_orbit", false) == true, "Mouse setting persists")
	game.swap_context_and_orbit = false
	game.hud._load_control_prefs()
	check(game.swap_context_and_orbit, "Reload restores swapped buttons")
	game.equipment["offhand"] = "shield"
	var world_point: Vector2 = game.camera.unproject_position(Vector3(0, -0.05, -8))
	var click := InputEventMouseButton.new()
	click.position = world_point
	click.button_index = MOUSE_BUTTON_MIDDLE
	click.pressed = true
	game.controls._unhandled_input(click)
	game.controls._process(0.30)
	check(game.hero.blocking, "Holding swapped context button blocks on empty ground")
	click.pressed = false
	game.controls._input(click)
	check(not game.hero.blocking, "Releasing swapped context button ends block")
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	game.controls._input(click)
	check(game.controls.rotating, "Swapped orbit button starts camera rotation")
	click.pressed = false
	game.controls._input(click)
	check(not game.controls.rotating, "Releasing orbit ends rotation")
	game.queue_free()
	await process_frame
	print("MOUSE BINDING RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
