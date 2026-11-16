extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, detail: String) -> void:
	if value:
		print("PASS KEY BINDING: " + detail)
	else:
		failures += 1
		push_error("FAIL KEY BINDING: " + detail)

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.rebind_key("left", KEY_H), "Movement key can be changed")
	check(not game.rebind_key("cancel", KEY_H), "Escape is protected")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_H
	check(event.is_action_pressed("outpost_left") == false, "Unpressed key does not count as action")
	event.pressed = true
	check(event.is_action_pressed("outpost_left"), "New key activates movement")
	game._register_keys()
	check(event.is_action_pressed("outpost_left"), "Reinitializing restores the saved binding")
	check(not game.rebind_key("missing", KEY_H), "Unknown action is rejected")
	game.hud._start_rebind("right")
	var input := InputEventKey.new()
	input.keycode = KEY_L
	input.physical_keycode = KEY_L
	input.pressed = true
	game.hud._input(input)
	check(game.hud.key_rebind_waiting.is_empty() and input.is_action_pressed("outpost_right"), "Controls menu captures and applies a key")
	game.queue_free()
	await process_frame
	print("KEY BINDING RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
