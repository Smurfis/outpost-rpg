extends SceneTree
## Android regressions: genuine orbit touch routing and bag dismissal.
## Run: godot --headless --path . -s res://tests/minimap_bag_camera_regression.gd
var failures: int = 0

func _check(ok: bool, explanation: String) -> void:
	if ok:
		print("MAP BAG CAMERA PASS: " + explanation)
	else:
		failures += 1
		push_error("MAP BAG CAMERA FAIL: " + explanation)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "Main Outpost scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var menu = game.menu
	var hud = game.hud
	_check(menu != null and hud != null, "Bag and HUD use the live game")
	if menu == null or hud == null:
		quit(1)
		return

	game.show_inventory()
	_check(menu.visible and menu.current_page == "bag", "Bag opens")
	var close: Button = menu.get("close_button") as Button
	_check(close != null and close.text.contains("CLOSE"), "Large labelled close control exists")
	if close != null:
		_check(menu.popup_frame.get_global_rect().has_point(close.get_global_rect().get_center()), "Close button is within the visible menu frame")
		_check(close.pressed.is_connected(menu.close_page), "Close button invokes the real close action")
		close.pressed.emit()
		_check(not menu.visible, "Close button dismisses the bag")
	game.show_inventory()
	_check(menu.visible, "Bag can reopen after close")
	var tap_outside := InputEventScreenTouch.new()
	tap_outside.index = 28
	tap_outside.pressed = true
	tap_outside.position = Vector2(6.0, 6.0)
	menu._on_shade_input(tap_outside)
	_check(not menu.visible, "Tapping the backdrop dismisses the bag")
	game.show_inventory()
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	menu._input(back)
	_check(not menu.visible, "Android back or keyboard escape dismisses the bag")
	game.show_inventory()
	game.show_inventory()
	_check(not menu.visible, "Reopening the same bag toggles it closed")

	var screen: Vector2 = hud.get_viewport().get_visible_rect().size
	var outer_world: Vector2 = screen * Vector2(0.82, 0.47)
	_check(hud._can_start_camera_drag(outer_world), "Orbit responds on the open right-hand world, beyond former narrow zone")
	_check(not hud._can_start_camera_drag(hud.smart_button.get_global_rect().get_center()), "World orbit never steals smart-action button input")
	_check(not hud._can_start_camera_drag(hud.menu_button.get_global_rect().get_center()), "World orbit never steals the in-game menu button")
	var down := InputEventScreenTouch.new()
	down.index = 27
	down.pressed = true
	down.position = outer_world
	hud._input(down)
	_check(hud.camera_drag_finger == 27, "Free-world touch captures camera drag")
	var before: float = game.camera_angle_target
	var move := InputEventScreenDrag.new()
	move.index = 27
	move.position = outer_world + Vector2(62.0, 0.0)
	move.relative = Vector2(62.0, 0.0)
	move.screen_relative = Vector2.ZERO # Some Android devices send this
	hud._input(move)
	_check(absf(game.camera_angle_target - before) > 0.1, "Orbit uses Android relative movement if screen-relative is zero")
	var up := InputEventScreenTouch.new()
	up.index = 27
	up.pressed = false
	up.position = move.position
	hud._input(up)
	_check(hud.camera_drag_finger == -1, "Release ends camera orbit cleanly")
	_check(hud.root.get_node_or_null("LiveWorldMinimap") != null, "Camera fix leaves the minimap installed")
	game.queue_free()
	await process_frame
	print("MAP BAG CAMERA RESULT: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
