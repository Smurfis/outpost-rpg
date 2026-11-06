extends SceneTree
## Approved menu layers must be committed, imported and rendered by real buttons.
## Run: godot --headless --path . -s res://tests/title_approved_raster_smoke.gd
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, note: String) -> void:
	if condition:
		print("PASS APPROVED TITLE: " + note)
	else:
		failures += 1
		push_error("FAIL APPROVED TITLE: " + note)

func _run() -> void:
	var expected: Dictionary = {
		"title_background.png": Vector2i(1280, 720),
		"outpost_logo.png": Vector2i(438, 350),
		"splash_deeper_dungeons.png": Vector2i(305, 171),
		"btn_play.png": Vector2i(422, 92),
		"btn_continue.png": Vector2i(360, 79),
		"btn_settings.png": Vector2i(336, 76),
		"btn_quit.png": Vector2i(296, 76),
		"version_badge_textless.png": Vector2i(177, 57),
		"version_badge_original.png": Vector2i(177, 57)
	}
	for asset_name in expected.keys():
		var path: String = "res://assets/ui/title/" + asset_name
		_check(ResourceLoader.exists(path), "PNG tracked and imported: " + asset_name)
		var image: Texture2D = load(path) as Texture2D
		_check(image != null, "PNG is a valid Godot texture: " + asset_name)
		if image != null:
			var dimensions: Vector2i = Vector2i(image.get_size())
			_check(dimensions == expected[asset_name], "Approved source dimensions: " + asset_name)

	var scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_check(scene != null, "Standalone title scene loads")
	if scene == null:
		quit(1)
		return
	var title: Control = scene.instantiate() as Control
	root.add_child(title)
	await process_frame
	_check(bool(title.get("_approved_art")), "Approved pixel-art mode selected")
	var backdrop: TextureRect = title.get_node_or_null("Artboard/Backdrop") as TextureRect
	_check(backdrop != null and backdrop.texture != null, "Approved backdrop exists")
	if backdrop != null and backdrop.texture != null:
		_check(backdrop.texture.resource_path.ends_with("/title_background.png"), "Scene uses the approved painted backdrop")
		_check(backdrop.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Backdrop uses nearest pixel sampling")
	var logo: Control = title.get_node_or_null("Artboard/OutpostLogo") as Control
	_check(logo != null, "Separate original crest Control survives")
	if logo != null:
		var source_texture: Texture2D = logo.get("_logo_texture") as Texture2D
		_check(source_texture != null and source_texture.resource_path.ends_with("/outpost_logo.png"), "Crest uses approved image instead of vector approximation")
		_check(logo.position == Vector2(416, 0) and logo.size == Vector2(438, 350), "Crest positioned at approved coordinates")
	var layout: Dictionary = {
		"Play": Rect2(427, 344, 422, 92),
		"Continue": Rect2(459, 430, 360, 79),
		"Settings": Rect2(474, 504, 336, 76),
		"Quit": Rect2(497, 575, 296, 76)
	}
	for button_name in layout.keys():
		var button: Button = title.get_node_or_null("Artboard/" + button_name + "Button") as Button
		_check(button != null, button_name + " remains a real pressable Godot Button")
		if button == null:
			continue
		var rect: Rect2 = layout[button_name]
		_check(button.position.is_equal_approx(rect.position) and button.size.is_equal_approx(rect.size), button_name + " aligns to exact cutout coordinates")
		_check(button.text.is_empty() and button.icon == null, button_name + " does not double-render baked artwork caption or icon")
		var style: StyleBoxTexture = button.get_theme_stylebox("normal") as StyleBoxTexture
		_check(style != null and style.texture != null, button_name + " has independent approved PNG art")
		if style != null and style.texture != null:
			_check(style.texture.resource_path.ends_with("/btn_" + button_name.to_lower() + ".png"), button_name + " uses matching approved cutout")
		_check(button.pressed.get_connections().size() > 0, button_name + " retains its interactive action")
	var lights: TextureRect = title.get_node_or_null("Artboard/TitleLights") as TextureRect
	_check(lights != null and not lights.visible, "Legacy SVG light layer is hidden to prevent double artwork")
	var version: Label = title.get_node_or_null("Artboard/Version") as Label
	_check(version != null and version.text.begins_with("v0.5.0-dev"), "Live version data is still available")
	if version != null:
		_check(version.modulate.a > 0.99, "Matching hand-painted version text is not duplicated")
	var version_plaque: TextureRect = title.get_node_or_null("Artboard/VersionPlaque") as TextureRect
	_check(version_plaque != null and version_plaque.texture != null, "Version plaque is independent from world backdrop")
	if version_plaque != null and version_plaque.texture != null:
		_check(version_plaque.texture.resource_path.ends_with("/version_badge_textless.png"), "Original matching version plaque rendered")
	var splash: Label = title.get_node_or_null("Artboard/UpdateSplash") as Label
	_check(splash != null and splash.get_node_or_null("HandLetteredHero") != null, "Hand-lettered approved slogan loads independently")
	if splash != null:
		_check(splash.position == Vector2(903, 80) and splash.size == Vector2(312, 129), "Rotating slogan's first hand-drawn frame aligns exactly")
	_check(ResourceLoader.exists("res://scenes/ui/world_loading.tscn"), "Title still launches through streaming-world loading gateway")
	# Widescreen Android screens must not pillarbox, skew the logo or move
	# actual button hitboxes away from their approved pixel coordinates.
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Title expands viewport instead of using 16:9 black sidebars")
	var artboard: Control = title.get_node_or_null("Artboard") as Control
	var wide: Control = title.get_node_or_null("Artboard/WideBackdrop") as Control
	_check(wide != null, "Approved background has three aspect-safe widescreen slices")
	if wide != null and artboard != null and backdrop != null:
		title.call("_layout_for_size", Vector2(2400.0, 1080.0)) # 20:9 Android
		var left: TextureRect = wide.get_node_or_null("WideLeft") as TextureRect
		var center: TextureRect = wide.get_node_or_null("WideCenter") as TextureRect
		var right: TextureRect = wide.get_node_or_null("WideRight") as TextureRect
		_check(wide.visible and not backdrop.visible, "20:9 uses extended scenery instead of 16:9 backdrop")
		_check(artboard.scale.is_equal_approx(Vector2(1.5, 1.5)), "Foreground uniformly scales without stretching the logo or buttons")
		_check(left != null and center != null and right != null, "All three background slices present")
		if left != null and center != null and right != null:
			_check(is_equal_approx(artboard.position.x + left.position.x * artboard.scale.x, 0.0), "Background reaches left screen edge")
			_check(is_equal_approx(artboard.position.x + (right.position.x + right.size.x) * artboard.scale.x, 2400.0), "Background reaches right screen edge")
			_check(center.position.is_equal_approx(Vector2(320, 0)) and center.size.is_equal_approx(Vector2(800, 720)), "Original centre preserves cutout alignment")
			var atlas: AtlasTexture = center.texture as AtlasTexture
			_check(atlas != null and atlas.region == Rect2(320, 0, 800, 720), "Centre samples original approved PNG without distortion")
		var play: Button = title.get_node_or_null("Artboard/PlayButton") as Button
		_check(play != null and play.position == Vector2(427, 344) and play.size == Vector2(422, 92), "Widescreen preserves Play hitbox and art geometry")
		title.call("_layout_for_size", Vector2(1280.0, 720.0))
		_check(not wide.visible and backdrop.visible and artboard.position.is_equal_approx(Vector2.ZERO), "16:9 remains pixel-identical to approved composition")
	title.queue_free()
	await process_frame
	print("APPROVED TITLE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
