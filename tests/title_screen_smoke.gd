extends SceneTree
## godot --headless --path . --script res://tests/title_screen_smoke.gd
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in ["res://scenes/ui/company_splash.tscn", "res://scenes/ui/title_screen.tscn",
		"res://scenes/ui/title_menu_button.tscn", "res://scenes/ui/title_splash.tscn"]:
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("FAILED: " + path)
			quit(1)
			return
	var scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	var instance: Control = scene.instantiate() as Control
	root.add_child(instance)
	await process_frame
	for name in ["Artboard", "Artboard/PlayButton", "Artboard/ContinueButton", "Artboard/SettingsButton",
		"Artboard/QuitButton", "Artboard/WorldTip", "Artboard/UpdateSplash", "Artboard/SettingsPanel"]:
		if instance.get_node_or_null(name) == null:
			push_error("Missing title node: " + name)
			quit(1)
			return
	if not instance._has_valid_save():
		var continue_button: Button = instance.get_node("Artboard/ContinueButton") as Button
		if not continue_button.disabled:
			push_error("Continue must be disabled with no save")
			quit(1)
			return
	if not instance.TIPS.has("Tip: Keep the campfire burning — Chloe and Iyla need a safe outpost after dark."):
		push_error("Missing approved personal adventure tip")
		quit(1)
		return
	print("PASS: modular title scene, startup splash, controls and tip system")
	quit(0)
