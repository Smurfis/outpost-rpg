extends SceneTree
## Live title/intro polish contract: playable buttons, non-overlapping
## single-line slogans, ambience and reduced-motion fallback.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, note: String) -> void:
	if ok:
		print("PASS TITLE AMBIENT: " + note)
	else:
		failures += 1
		push_error("FAIL TITLE AMBIENT: " + note)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_check(scene != null, "Approved title scene loads")
	if scene == null:
		quit(1)
		return
	var title: Control = scene.instantiate() as Control
	root.add_child(title)
	await process_frame
	var splash: Label = title.get_node_or_null("Artboard/UpdateSplash") as Label
	_check(splash != null, "Rotating slogan exists")
	if splash != null:
		_check(splash.text == "Bring a torch!", "Torch slogan opens the title")
		_check(splash.autowrap_mode == TextServer.AUTOWRAP_OFF and not splash.clip_text, "Rotating slogan uses manual line breaks without opaque clipping")
		splash.call("set_message", "Pixel by pixel!")
		_check(splash.text == "Pixel by pixel!", "Rotating text is precise and contains no extra glyph")
		var hero: TextureRect = splash.get_node_or_null("HandLetteredHero") as TextureRect
		_check(hero != null and not hero.visible, "Live text does not double-paint the hero PNG")
		splash.call("set_message", "Now with deeper\\ndungeons!")
		_check(hero != null and hero.visible and splash.text.is_empty(), "Hand-lettered hero PNG remains available without duplicate text")
		splash.call("set_message", "Bring a torch!")
	for name in ["PlayButton", "ContinueButton", "SettingsButton", "QuitButton"]:
		var button: Button = title.get_node_or_null("Artboard/" + name) as Button
		_check(button != null, name + " remains a real button")
		if button == null:
			continue
		_check(button.has_method("is_title_highlighted"), name + " implements gold selection")
		var focus_style: StyleBox = button.get_theme_stylebox("focus")
		_check(focus_style is StyleBoxEmpty, name + " has no opaque/rectangular focus image")
		_check(button.material == null, name + " has no custom canvas shader that could draw a white quad")
		var normal: StyleBoxTexture = button.get_theme_stylebox("normal") as StyleBoxTexture
		var hover: StyleBoxTexture = button.get_theme_stylebox("hover") as StyleBoxTexture
		_check(normal != null and hover != null and normal.texture != hover.texture, name + " uses independent alpha-masked highlight art")
		button.call("_on_pointer_entered")
		_check(bool(button.call("is_title_highlighted")) == not button.disabled, name + " highlights only while enabled")
		if name == "QuitButton" and normal != null and hover != null:
			var idle: Image = normal.texture.get_image()
			var lit: Image = hover.texture.get_image()
			var whited: int = 0
			for y in range(18, mini(61, idle.get_height())):
				for x in range(46, mini(235, idle.get_width())):
					var a: Color = idle.get_pixel(x, y)
					var b: Color = lit.get_pixel(x, y)
					if a.a > 0.8 and a.r < 0.38 and b.r > 0.98 and b.g > 0.98 and b.b > 0.98:
						whited += 1
			_check(whited > 50, "Quit power icon and lettering become white in selected PNG")
		button.call("_on_pointer_exited")
	var embers: Control = title.get_node_or_null("Artboard/CampfireEmbers") as Control
	_check(embers != null, "Two small campfire ember emitters are wired into title")
	if embers != null:
		_check(embers.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Embers cannot steal touch events")
		embers.set("reduced_motion", true)
		_check(bool(embers.get("reduced_motion")), "Reduced-motion option suppresses ember movement")
	var backdrop: TextureRect = title.get_node_or_null("Artboard/Backdrop") as TextureRect
	var wide: Control = title.get_node_or_null("Artboard/WideBackdrop") as Control
	title.call("_process", 0.4)
	_check(backdrop != null and backdrop.modulate == Color.WHITE, "Approved background no longer receives mismatched opacity tint")
	_check(wide != null and wide.modulate == Color.WHITE, "Ultrawide landscape also preserves original tones")
	title.queue_free()
	await process_frame

	var intro_scene: PackedScene = load("res://scenes/ui/company_splash.tscn")
	_check(intro_scene != null, "Five Star intro scene loads")
	if intro_scene != null:
		var intro: Control = intro_scene.instantiate() as Control
		intro.set("auto_advance", false)
		root.add_child(intro)
		await process_frame
		_check(not bool(ProjectSettings.get_setting("application/boot_splash/show_image", true)), "Godot boot logo is suppressed before Five Star ident")
		_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Five Star splash fills 20:9 Android instead of being pillarboxed")
		var emblem: TextureRect = intro.get_node_or_null("StarMark") as TextureRect
		_check(emblem != null and emblem.anchor_left <= 0.1 and emblem.anchor_right >= 0.9, "Five Star branding spans widescreen Android")
		var twinkles: Control = intro.get_node_or_null("StarTwinkles") as Control
		_check(twinkles != null, "Five Star pixel glints are added")
		_check(twinkles != null and twinkles.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Intro stars cannot block tap-to-skip")
		_check(intro.has_method("_go_next"), "Five Star retains the skip transition")
		intro.queue_free()
		await process_frame
	print("TITLE AMBIENT RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
