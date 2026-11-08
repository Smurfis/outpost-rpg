extends SceneTree
## Touch-real regression for the two independent Outpost popups.
## Previous smoke only inspected signal wiring, so Android taps could fail.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS EXIT HUD: " + description)
	else:
		failures += 1
		push_error("FAIL EXIT HUD: " + description)

func _tap(hud: Node, button: Button) -> void:
	if button == null:
		_check(false, "Tap target exists")
		return
	var location: Vector2 = button.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = 37
	down.position = location
	down.pressed = true
	hud._input(down)
	var up := InputEventScreenTouch.new()
	up.index = 37
	up.position = location
	up.pressed = false
	hud._input(up)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "Outpost game scene loads")
	if scene == null:
		quit(1)
		return
	var game: Node3D = scene.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	var hud: Node = game.get("hud")
	_check(hud != null, "In-game HUD is ready")
	if hud == null:
		game.queue_free()
		quit(1)
		return
	var hud_root: Control = hud.get("root") as Control
	var menu_entry: Button = hud_root.get_node_or_null("TopRightMenuButton") as Button
	var exit_entry: Button = hud_root.get_node_or_null("ExitDoorMenuButton") as Button
	var modal: Panel = hud_root.get_node_or_null("FunctionalHotbar") as Panel
	var modal_shade: ColorRect = hud_root.get_node_or_null("GameMenuShade") as ColorRect
	_check(menu_entry != null and exit_entry != null, "Mobile MENU and Save/Exit buttons are real touch controls")
	_check(exit_entry != null and exit_entry.get_node_or_null("ExitDoorIcon") is TextureRect, "Exit still uses its independent icon")
	_check(modal != null and modal_shade != null and not modal.visible, "Game MENU is a separate hidden popup")
	_check((hud.get("top_menu_actions") as Array).size() == 6, "Six existing destinations preserved")
	var popup: PanelContainer = hud_root.get_node_or_null("LeaveGamePanel") as PanelContainer
	var shade: ColorRect = hud_root.get_node_or_null("LeaveGameShade") as ColorRect
	var close_button: Button = hud_root.get_node_or_null("CloseLeaveOutpost") as Button
	_check(popup != null and shade != null and close_button != null and not popup.visible, "Leave popup starts closed")
	_check(popup != null and popup.get_theme_stylebox("panel") is StyleBoxFlat, "Leave popup uses reusable opaque modal frame, not old nine-slice")
	_check(popup != null and popup.find_child("LeaveGameNoticeFrame", true, false) != null, "Parchment notice style is a reusable component")

	_tap(hud, menu_entry)
	_check(bool(hud.get("top_menu_open")) and modal.visible and modal_shade.visible, "Actual Android tap opens the centered Game MENU")
	_tap(hud, exit_entry)
	_check(popup.visible and shade.visible and not modal.visible and not modal_shade.visible, "Touching Save/Exit opens Leave popup and closes Game MENU")
	var resume: Button = popup.find_child("ResumeAdventureButton", true, false) as Button
	var controls: Button = popup.find_child("LeaveControlsButton", true, false) as Button
	var versions: Button = popup.find_child("OpenVersionChannels", true, false) as Button
	var return_button: Button = popup.find_child("ReturnToTitle", true, false) as Button
	_check(resume != null and controls != null and versions != null and return_button != null, "All four Leave actions are present")
	_check(versions != null and versions.pressed.is_connected(hud._return_to_version_channels), "Version shortcut retains actual save/return binding")
	_check(return_button != null and return_button.pressed.is_connected(hud._return_to_title), "Save/Return shortcut retains actual saving binding")
	_tap(hud, resume)
	_check(not popup.visible and not shade.visible and not close_button.visible, "Actual RESUME touch dismisses modal and shade")
	hud.call("_open_leave_menu")
	_tap(hud, close_button)
	_check(not popup.visible and not shade.visible, "Actual circular X touch closes Leave popup")
	hud.call("_open_leave_menu")
	_tap(hud, controls)
	_check(not popup.visible and (hud.get("control_settings_panel") as Control).visible, "Actual CONTROLS touch opens settings instead of trapping player")
	(hud.get("control_settings_panel") as Control).visible = false
	hud.call("_open_leave_menu")
	var before: Vector2 = hud.get("move_vector")
	var outside := InputEventScreenTouch.new()
	outside.pressed = true
	outside.index = 8
	outside.position = Vector2(220.0, 360.0)
	hud._input(outside)
	_check(hud.get("move_vector") == before and popup.visible, "Opaque Leave shade blocks movement/camera input")
	hud.call("_close_leave_menu")
	game.queue_free()
	await process_frame
	print("EXIT HUD RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
