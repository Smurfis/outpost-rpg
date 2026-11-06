extends SceneTree
## Regression: shipped title assets must import and be wired into live title scene.
## A fallback to an invalid 160px JPG or just a blank logo is a build failure.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, name: String) -> void:
	if ok:
		print("PASS TITLE ART: " + name)
	else:
		failures += 1
		push_error("FAIL TITLE ART: " + name)

func _run() -> void:
	var background_path := "res://assets/ui/title/title_background.png"
	var logo_path := "res://assets/ui/title/outpost_logo.png"
	for path in [background_path, logo_path]:
		_check(ResourceLoader.exists(path), "Bundled approved PNG art exists: " + path)
		var texture: Texture2D = load(path) as Texture2D
		_check(texture != null, "Bundled approved PNG art imports: " + path)
		if texture != null:
			_check(texture.get_size().x > 400.0, "Art has suitable desktop/Android resolution: " + path)
	var scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_check(scene != null, "Real title screen scene imports")
	if scene == null:
		quit(1)
		return
	var title: Control = scene.instantiate() as Control
	root.add_child(title)
	await process_frame
	var backdrop: TextureRect = title.get_node_or_null("Artboard/Backdrop") as TextureRect
	_check(backdrop != null and backdrop.texture != null, "Full-screen illustrated backdrop is visible on real title")
	if backdrop != null and backdrop.texture != null:
		_check(backdrop.texture.resource_path == background_path, "Title loads source-approved PNG artwork rather than vector fallback")
		_check(backdrop.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Backdrop stays nearest/pixel safe")
	var logo: Control = title.get_node_or_null("Artboard/OutpostLogo") as Control
	_check(logo != null and logo.get("_logo_texture") != null, "Real title has shipped transparent tent logo")
	if logo != null:
		_check(logo.get_node_or_null("FallbackWordmark") == null, "Approved hand-painted logo is not duplicated by a fallback wordmark")
	for kind in ["Play", "Continue", "Settings", "Quit"]:
		var button: Button = title.get_node_or_null("Artboard/" + kind + "Button") as Button
		_check(button != null and button.get_theme_stylebox("normal") is StyleBoxTexture, kind + " has individual reusable textured button")
	var version: Label = title.get_node_or_null("Artboard/Version") as Label
	_check(version != null and version.text == "v0.5.0-dev", "Version label uses running app version")
	title.queue_free()
	await process_frame
	print("TITLE ART RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
