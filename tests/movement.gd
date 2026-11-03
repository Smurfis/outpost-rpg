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
	check(game.hud.menu_button != null and game.hud.attack_button != null, "Compact HUD exposes menu and attack")
	check(not game.hud.quick_menu_open, "Compact menu closed at spawn")
	game.hud._toggle_menu()
	check(game.hud.quick_menu_open and game.hud.quick_menu.visible, "Compact menu opens")
	game.hud._reset_joystick()
	game.hud.close_quick_menu()
	check(not game.hud.quick_menu_open, "Compact menu closes")

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
	# Mouse emulation is a valid Android editor input source, not a desktop-only path.
	var mouse_start := InputEventMouseButton.new()
	mouse_start.button_index = MOUSE_BUTTON_LEFT
	mouse_start.pressed = true
	mouse_start.position = game.hud._center() + Vector2(68, 0)
	game.hud._input(mouse_start)
	check(game.hud.move_vector.x > 0.7, "Emulated mouse starts virtual joystick")
	where = game.hero.global_position
	await frames(20)
	check(game.hero.global_position.distance_to(where) > 0.2, "Character moves using emulated-mouse joystick fallback")
	var mouse_end := InputEventMouseButton.new()
	mouse_end.button_index = MOUSE_BUTTON_LEFT
	mouse_end.pressed = false
	mouse_end.position = mouse_start.position
	game.hud._input(mouse_end)
	check(game.hud.move_vector == Vector2.ZERO, "Emulated-mouse release resets joystick")

	release.index = 12
	game.hud._input(release)
	# A dungeon portal may lock movement only while confirmation is visible.
	var manager = game.get_node("Dungeons")
	manager.register_chunk("movement_test", Rect2(Vector2(3,-5), Vector2(12,10)), 0, [Vector3(8,0,0)], true)
	var portal = manager.entrances["movement_test:0"]
	game.hero.global_position = Vector3(0,0.35,0)
	manager._on_portal_selected(portal)
	check(not game.hero.interaction_moving and not game.hero.interaction_locked, "Distant portal tap does not steal joystick")
	game.hero.global_position = Vector3(7,0.35,0)
	manager._on_portal_selected(portal)
	check(manager.dimmer.visible and game.hero.interaction_locked, "Nearby portal locks only while confirmation visible")
	manager._cancel_dialog()
	check(not game.hero.interaction_locked and not manager.dimmer.visible, "Cancel portal restores movement")
	game.hud._reset_joystick()
	touch.index = 17
	game.hud._input(touch)
	where = game.hero.global_position
	await frames(20)
	check(game.hero.global_position.distance_to(where) > 0.2, "Hero moves after portal cancellation")
	release.index = 17
	game.hud._input(release)
	game.queue_free()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("MOVEMENT RESULT: %d failed assertion(s)" % failed)
	quit(0 if failed == 0 else 1)
