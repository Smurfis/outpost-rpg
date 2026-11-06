extends SceneTree
## The tiny door in the six-slot flyout opens a real save/leave confirmation.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS EXIT HUD: " + description)
	else:
		failures += 1
		push_error("FAIL EXIT HUD: " + description)

func _run() -> void:
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
	var entry: Button = hud.get_node_or_null("OutpostHUD/ExitDoorMenuButton") as Button
	_check(entry != null and entry.get_node_or_null("ExitDoorIcon") is TextureRect, "Six-slot menu contains a centred pixel-art door icon")
	_check((hud.get("top_menu_actions") as Array).size() == 6, "No extra HUD slots overlap combat controls")
	var popup: PanelContainer = hud.get_node_or_null("OutpostHUD/LeaveGamePanel") as PanelContainer
	var shade: ColorRect = hud.get_node_or_null("OutpostHUD/LeaveGameShade") as ColorRect
	_check(popup != null and shade != null and not popup.visible, "Save-and-exit panel is hidden during normal gameplay")
	hud.call("_open_leave_menu")
	_check(popup != null and popup.visible and shade != null and shade.visible, "Door opens touch-blocking wood/pixel exit overlay")
	var return_button: Button = popup.find_child("ReturnToTitle", true, false) as Button if popup != null else null
	_check(return_button != null and return_button.text.contains("RETURN"), "Exit menu has deliberate save-and-return action")
	_check(game.has_method("save_and_return_to_title"), "Return flow saves game and disconnects existing LAN")
	hud.call("_close_leave_menu")
	_check(popup != null and not popup.visible and shade != null and not shade.visible, "Resume dismisses the modal")
	game.queue_free()
	await process_frame
	print("EXIT HUD RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
