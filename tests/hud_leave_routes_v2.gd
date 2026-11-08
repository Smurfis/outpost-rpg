extends SceneTree
## Real press+release of both scene-changing Leave Outpost destinations.
## Prevents a modal that draws correctly but has inert buttons on Android.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, name: String) -> void:
	if ok:
		print("PASS EXIT ROUTES: " + name)
	else:
		failures += 1
		push_error("FAIL EXIT ROUTES: " + name)

func _tap(hud: Node, button: Button, finger_id: int) -> void:
	if button == null:
		_check(false, "Touch action exists")
		return
	var pos: Vector2 = button.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.index = finger_id
	press.position = pos
	press.pressed = true
	hud._input(press)
	var release := InputEventScreenTouch.new()
	release.index = finger_id
	release.position = pos
	release.pressed = false
	hud._input(release)

func _run() -> void:
	var game_scene: PackedScene = load("res://scenes/main.tscn")
	_check(game_scene != null, "Main world scene is loadable")
	if game_scene == null:
		quit(1)
		return

	var version_save: String = "user://hud_v2_versions_touch_test.json"
	root.set_meta("outpost_new_adventure", true)
	var game: Node3D = game_scene.instantiate()
	game.set("save_path", version_save)
	root.add_child(game)
	current_scene = game
	await process_frame
	var hud: Node = game.get("hud") as Node
	hud.call("_open_leave_menu")
	var version_action: Button = hud.get_node_or_null("OutpostHUD/LeaveGamePanel").find_child("OpenVersionChannels", true, false) as Button
	_tap(hud, version_action, 71)
	_check(bool(root.get_meta("outpost_open_settings", false)), "VERSIONS touch requests Title Settings")
	_check(FileAccess.file_exists(version_save), "VERSIONS touch actually saves progress")
	await process_frame
	await process_frame
	var title: Node = current_scene
	_check(title != null and title.scene_file_path.ends_with("title_screen.tscn"), "VERSIONS leaves gameplay for the real title scene")
	if title != null:
		var settings: Control = title.get("_settings_panel") as Control
		_check(settings != null and settings.visible, "VERSIONS opens real title Settings panel")
		# Clear out the first scene before starting a second simulated session.
		title.queue_free()
		current_scene = null
	await process_frame

	var return_save: String = "user://hud_v2_save_touch_test.json"
	root.set_meta("outpost_new_adventure", true)
	var game2: Node3D = game_scene.instantiate()
	game2.set("save_path", return_save)
	root.add_child(game2)
	current_scene = game2
	await process_frame
	var hud2: Node = game2.get("hud") as Node
	hud2.call("_open_leave_menu")
	var save_action: Button = hud2.get_node_or_null("OutpostHUD/LeaveGamePanel").find_child("ReturnToTitle", true, false) as Button
	_tap(hud2, save_action, 72)
	_check(FileAccess.file_exists(return_save), "SAVE & RETURN touch writes progress")
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path.ends_with("title_screen.tscn"), "SAVE & RETURN loads the title screen")
	print("EXIT ROUTES RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
