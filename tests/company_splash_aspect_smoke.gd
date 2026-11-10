extends SceneTree
## Regression for FIVE STAR ident on 16:9 and 20:9 Android screens.
## Run: godot --headless --path . -s res://tests/company_splash_aspect_smoke.gd
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS FIVE STAR ASPECT: " + message)
	else:
		failures += 1
		push_error("FAIL FIVE STAR ASPECT: " + message)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/ui/company_splash.tscn")
	_check(scene != null, "Startup ident scene imports")
	if scene == null:
		quit(1)
		return
	var ident: Control = scene.instantiate() as Control
	ident.set("auto_advance", false)
	root.add_child(ident)
	await process_frame
	var mark: TextureRect = ident.get_node("StarMark") as TextureRect
	var studio: Label = ident.get_node("StudioName") as Label
	var subtitle: Label = ident.get_node("Subtitle") as Label
	var hint: Label = ident.get_node("Hint") as Label
	_check(mark.texture != null, "Five Star artwork is bundled")
	_check(mark.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"Logo texture is never distorted")
	for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2400, 1080)]:
		ident.size = viewport_size
		ident.call("_layout_ident")
		var center_x: float = mark.position.x + mark.size.x * 0.5
		_check(absf(center_x - viewport_size.x * 0.5) < 1.5,
			"Mark centered for %s" % str(viewport_size))
		_check(is_equal_approx(mark.size.x / mark.size.y,
			512.0 / 320.0) or bool(ident.get("_full_logo_art")),
			"Fallback 512x320 mark keeps 8:5 aspect")
		_check(mark.position.x >= 0.0 and mark.position.y >= 0.0
			and mark.position.x + mark.size.x <= viewport_size.x
			and mark.position.y + mark.size.y <= viewport_size.y,
			"Artwork remains inside %s" % str(viewport_size))
		_check(hint.position.y + hint.size.y <= viewport_size.y,
			"Skip hint stays inside phone bounds")
		_check(studio.position.y >= mark.position.y + mark.size.y or not studio.visible,
			"Studio name clears the emblem")
		_check(subtitle.position.y >= studio.position.y + studio.size.y - 1.5 or not subtitle.visible,
			"Subtitle clears studio name")
	ident.queue_free()
	await process_frame
	print("FIVE STAR ASPECT RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
