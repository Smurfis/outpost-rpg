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
		_check(backdrop.texture.resource_path.ends_with("/title_background_clean.png"), "Scene uses the repaired painted backdrop")
		_check(backdrop.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Backdrop uses nearest pixel sampling")
	var logo: Control = title.get_node_or_null("Artboard/OutpostLogo") as Control
	_check(logo != null, "Separate original crest Control survives")
	if logo != null:
		var source_texture: Texture2D = logo.get("_logo_texture") as Texture2D
		_check(source_texture != null and source_texture.resource_path.ends_with("/outpost_loading_logo.png"), "Crest uses the transparent logo shared with loading")
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
			_check(style.texture is ImageTexture, button_name + " uses a genuine RGBA masked runtime texture")
			var pixels: Image = style.texture.get_image()
			_check(pixels != null and pixels.get_pixel(0, 0).a < 0.01 and pixels.get_pixel(pixels.get_width() / 2, pixels.get_height() / 2).a > 0.95, button_name + " has clear corners but keeps opaque centre art")
		_check(button.pressed.get_connections().size() > 0, button_name + " retains its interactive action")
	var lights: TextureRect = title.get_node_or_null("Artboard/TitleLights") as TextureRect
	_check(lights != null and not lights.visible, "Legacy SVG light layer is hidden to prevent double artwork")
	var version: Label = title.get_node_or_null("Artboard/Version") as Label
	_check(version != null and (version.text.begins_with("V.A.") or version.text.begins_with("V.S.")) and version.text.contains("BUILD"), "Channel-labelled incremental version and Android build are legible")
	if version != null:
		_check(version.modulate.a > 0.99, "Matching hand-painted version text is not duplicated")
	var version_plaque: TextureRect = title.get_node_or_null("Artboard/VersionPlaque") as TextureRect
	_check(version_plaque != null and version_plaque.texture != null, "Version plaque is independent from world backdrop")
	if version_plaque != null and version_plaque.texture != null:
		_check(version_plaque.texture.resource_path.ends_with("/version_plaque_clear.svg"), "Independent transparent version plaque replaces opaque screenshot patch")
	_check(title.get_node_or_null("Artboard/VersionCornerWood") == null, "No oversized opaque wood/grey patch is drawn around version badge")
	var splash: Label = title.get_node_or_null("Artboard/UpdateSplash") as Label
	_check(splash != null and splash.get_node_or_null("HandLetteredHero") != null, "Hand-lettered approved slogan loads independently")
	if splash != null:
		_check(splash.position == Vector2(903, 80) and splash.size == Vector2(312, 129), "Rotating slogan's first hand-drawn frame aligns exactly")
	_check(ResourceLoader.exists("res://scenes/ui/world_loading.tscn"), "Title still launches through streaming-world loading gateway")
	# Widescreen Android screens must not pillarbox, skew the logo or move
	# actual button hitboxes away from their approved pixel coordinates.
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Title expands viewport instead of using 16:9 black sidebars")
	var artboard: Control = title.get_node_or_null("Artboard") as Control
	var wide: Control = title.get_node_or_null("WideBackdrop") as Control
	_check(wide != null and wide.get_parent() == title, "Approved panorama is a viewport-level sibling, not a clipped artboard child")
	if wide != null and artboard != null and backdrop != null:
		title.call("_layout_for_size", Vector2(2400.0, 1080.0)) # 20:9 Android
		if version_plaque != null and version != null:
			_check(version_plaque.position == Vector2(1248, 645), "On 20:9, actual version plaque occupies expanded right-hand area")
			_check(version.position == Vector2(1255, 650), "Version label travels with plaque onto phone's far right")
			var right_gap: float = 2400.0 - (artboard.position.x + (version_plaque.position.x + version_plaque.size.x) * artboard.scale.x)
			_check(right_gap > 15.0 and right_gap < 50.0, "Version sits neatly near physical right screen edge")
		# Regression for Android screenshot with duplicated banner/tree/portal
		# panels and vertical border seams at BOTH x-edges of the 16:9 art.
		var panorama: TextureRect = wide.get_node_or_null("WidePanorama") as TextureRect
		_check(wide.visible and not backdrop.visible, "20:9 uses the continuous widescreen backdrop")
		_check(artboard.scale.is_equal_approx(Vector2(1.5, 1.5)), "Foreground logo and button art stay pixel-proportional")
		_check(panorama != null and wide.get_child_count() == 1, "One panorama only: never duplicate left/right flags, waterfall or decorative frame")
		if panorama != null:
			_check(panorama.material is ShaderMaterial and is_equal_approx(float((panorama.material as ShaderMaterial).get_shader_parameter("side_extension_px")), 160.0), "Widescreen stretches only the outer scenery, preserving the central campsite geometry")
			_check(panorama.texture == backdrop.texture, "Widescreen uses the single approved landscape rather than repeating atlas regions")
			_check(panorama.position.is_equal_approx(Vector2.ZERO), "Widescreen panorama begins at viewport x=0, independent of the artboard inset")
			_check(panorama.size.is_equal_approx(Vector2(2400, 1080)), "Widescreen panorama spans the complete 20:9 viewport")
			_check(wide.position.is_equal_approx(Vector2.ZERO) and wide.size.is_equal_approx(Vector2(2400, 1080)), "Background canvas reaches both physical edges")
			_check(wide.get_index() < artboard.get_index(), "Panorama is behind the artboard and its interactive buttons")
		var play: Button = title.get_node_or_null("Artboard/PlayButton") as Button
		_check(play != null and play.position == Vector2(427, 344) and play.size == Vector2(422, 92), "Widescreen preserves Play hitbox and art geometry")
		# Regression: the reported 1919x1010 desktop screenshot showed exactly
		# 62 pixels of navy curtain at the left, matching the centred artboard
		# inset. The new panorama must cover that full 19:10-ish viewport.
		title.call("_layout_for_size", Vector2(1919.0, 1010.0))
		_check(artboard.position.x > 60.0 and artboard.position.x < 63.0, "Desktop artboard still uses proportional centre alignment")
		_check(wide.position.is_equal_approx(Vector2.ZERO) and wide.size.is_equal_approx(Vector2(1919, 1010)), "Desktop background covers the formerly blank left strip")
		if panorama != null:
			_check(panorama.position.is_equal_approx(Vector2.ZERO) and panorama.size.is_equal_approx(Vector2(1919, 1010)), "Desktop panorama fills viewport outside centred artboard")
		title.call("_layout_for_size", Vector2(1280.0, 720.0))
		if version_plaque != null and version != null:
			_check(version_plaque.position == Vector2(1088, 645) and version.position == Vector2(1095, 650), "16:9 version uses original badge coordinates")
		_check(not wide.visible and backdrop.visible and artboard.position.is_equal_approx(Vector2.ZERO), "16:9 remains pixel-identical to approved composition")
	title.queue_free()
	await process_frame
	print("APPROVED TITLE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
