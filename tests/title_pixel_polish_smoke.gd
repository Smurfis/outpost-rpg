extends SceneTree
## Checks title-only illustrated enhancements without starting the heavy world.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, note: String) -> void:
	if ok:
		print("PASS TITLE POLISH: " + note)
	else:
		failures += 1
		push_error("FAIL TITLE POLISH: " + note)

func _run() -> void:
	var light_path := "res://assets/ui/title/title_lights.svg"
	var logo_path := "res://assets/ui/title/outpost_logo_vector.svg"
	var plaque_path := "res://assets/ui/title/tip_panel.svg"
	for asset_path in [light_path, logo_path, plaque_path]:
		_check(ResourceLoader.exists(asset_path), "Source asset bundled: " + asset_path)
		var texture: Texture2D = load(asset_path) as Texture2D
		_check(texture != null, "Source asset imports in Godot: " + asset_path)
	var scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_check(scene != null, "Standalone title scene loads")
	if scene == null:
		quit(1)
		return
	var title: Control = scene.instantiate() as Control
	root.add_child(title)
	await process_frame
	var lights: TextureRect = title.get_node_or_null("Artboard/TitleLights") as TextureRect
	_check(lights != null and lights.texture != null, "Separate title atmosphere image renders")
	if lights != null:
		_check(lights.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Glow overlay keeps pixel-safe filtering")
		_check(lights.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Atmosphere overlay never blocks touch buttons")
	var plaque: TextureRect = title.get_node_or_null("Artboard/TipPlaque") as TextureRect
	_check(plaque != null and plaque.texture != null, "Independent rustic tip plaque renders")
	var tips: Array = Array(title.get_script().get_script_constant_map().get("TIPS", []))
	_check(tips.size() >= 25, "At least 25 short rotating adventure tips are available")
	_check(tips.has("Tip: Keep the campfire burning — Chloe and Iyla need a safe outpost after dark."),
		"Original approved personal campfire tip remains")
	var current_tip: Label = title.get_node_or_null("Artboard/WorldTip") as Label
	_check(current_tip != null, "Readably sized live tip text still exists")
	if current_tip != null:
		title.set("_reduced_motion", true)
		var previous: String = current_tip.text
		title.call("_advance_tip")
		_check(current_tip.text != previous, "Tips advance without animation when reduced motion is selected")
	var slogan: Label = title.get_node_or_null("Artboard/UpdateSplash") as Label
	_check(slogan != null, "Original angled yellow splash label remains")
	if slogan != null:
		var messages: PackedStringArray = slogan.get("messages")
		_check(messages.size() >= 10, "More playful editable slogans are bundled")
	for kind in ["Play", "Continue", "Settings", "Quit"]:
		var button: Button = title.get_node_or_null("Artboard/" + kind + "Button") as Button
		_check(button != null and button.pressed.get_connections().size() > 0,
			kind + " is still wired to its action")
	title.queue_free()
	await process_frame
	print("TITLE POLISH RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
