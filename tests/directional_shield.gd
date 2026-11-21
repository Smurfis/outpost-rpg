extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, detail: String) -> void:
	if value:
		print("PASS SHIELD: " + detail)
	else:
		failures += 1
		push_error("FAIL SHIELD: " + detail)

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hero = game.hero
	game.equipment["offhand"] = "shield"
	hero.visual.rotation.y = 0.0
	hero.blocking = true
	var at: Vector3 = hero.global_position
	hero.health = 100.0
	hero.take_hit(10.0, at + Vector3.FORWARD * 2.0)
	check(is_equal_approx(hero.health, 94.0), "Frontal shield block reduces damage once")
	hero.health = 100.0
	hero.take_hit(10.0, at + Vector3.BACK * 2.0)
	check(is_equal_approx(hero.health, 90.0), "Rear attack bypasses the shield")
	hero.blocking = false
	hero.health = 100.0
	hero.take_hit(10.0, at + Vector3.FORWARD * 2.0)
	check(is_equal_approx(hero.health, 90.0), "Equipped but lowered shield does not block")
	game.controls.set_desktop(false)
	game.hud._process(0.1)
	check(game.hud.shield_block_button.visible, "Touch shield action appears when equipped")
	var touch := InputEventScreenTouch.new()
	touch.index = 9
	touch.position = game.hud.shield_block_button.get_global_rect().get_center()
	touch.pressed = true
	game.hud._input(touch)
	check(hero.blocking, "Touch hold raises shield")
	touch.pressed = false
	game.hud._input(touch)
	check(not hero.blocking, "Touch release lowers shield")
	game.queue_free()
	await process_frame
	print("DIRECTIONAL SHIELD RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
