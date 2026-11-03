extends SceneTree
## Independent editor/headless check. Run: godot --headless --path . --script res://tests/title_logo_smoke.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var logo_scene: PackedScene = load("res://scenes/ui/title_logo.tscn")
	if logo_scene == null:
		push_error("TitleLogo scene failed to load")
		quit(1)
		return
	var logo: Control = logo_scene.instantiate() as Control
	if logo == null:
		push_error("TitleLogo root must be a Control")
		quit(1)
		return
	root.add_child(logo)
	await process_frame
	if logo.get_script() == null:
		push_error("TitleLogo script was not assigned")
		quit(1)
		return
	print("PASS: standalone title logo scene loads without altering game")
	quit(0)
