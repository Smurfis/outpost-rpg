extends SceneTree
## Test movement in physics, virtual joystick and touch state across both menus.
const SAVE_PATH: String = "user://outpost_movement_test_v1.json"
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS MOVE: " + label)
	else:
		failed += 1
		push_error("FAIL MOVE: " + label)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func _run() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	game.save_path = SAVE_PATH
	game.get_node("Dungeons").demo_chunk_fallback = false
	root.add_child(game)
	await frames(4)
	check(not game.menu.visible and not game.progression_ui.visible, "Menus closed at spawn")
	check(not game.hero.interaction_locked, "Player unlocked at spawn")
	var where: Vector3 = game.hero.global_position
	var center: Vector2 = game.hud._center()
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = center + Vector2(65,0)
	game.hud._input(touch)
	check(game.hud.move_vector.x > 0.7, "Joystick accepts touch")
	await frames(24)
	check(game.hero.global_position.distance_to(where) > 0.30, "Joystick causes physical world movement")
	var release := InputEventScreenTouch.new()
	release.index = 3
	release.pressed = false
	release.position = center + Vector2(65,0)
	game.hud._input(release)
	check(game.hud.finger == -1 and game.hud.move_vector == Vector2.ZERO, "Release clears finger ID")
	await frames(2)
	game.show_inventory()
	await frames(1)
	check(game.menu.visible, "Inventory opens")
	game.hud._input(touch)
	check(game.hud.finger == -1, "Modal never latches touch")
	game.menu.close_page()
	touch.index = 7
	game.hud._input(touch)
	check(game.hud.finger == 7, "Joystick works after inventory closes")
	where = game.hero.global_position
	await frames(22)
	check(game.hero.global_position.distance_to(where) > 0.25, "Player moves after inventory closes")
	release.index = 7
	game.hud._input(release)
	game.show_progression("equipment")
	await frames(1)
	check(game.progression_ui.visible, "Gear screen opens")
	game.progression_ui.close_page()
	touch.index = 12
	game.hud._input(touch)
	where = game.hero.global_position
	await frames(22)
	check(game.hero.global_position.distance_to(where) > 0.25, "Player moves after gear screen closes")
	release.index = 12
	game.hud._input(release)
	game.queue_free()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("MOVEMENT RESULT: %d failed assertion(s)" % failed)
	quit(0 if failed == 0 else 1)
