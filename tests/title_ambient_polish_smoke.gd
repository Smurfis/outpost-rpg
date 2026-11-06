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
		_check(splash.autowrap_mode == TextServer.AUTOWRAP_OFF and splash.clip_text, "Slogan is one line with clipped overflow, not double-wrapped")
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
		var focus_style: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
		_check(focus_style != null and focus_style.border_color.a > 0.4, name + " has visible gold focus border")
		button.call("_on_pointer_entered")
		_check(bool(button.call("is_title_highlighted")) == not button.disabled, name + " highlights only while enabled")
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
	_check(backdrop != null and backdrop.modulate.r < 1.0, "Dusk tint affects original painted landscape")
	_check(wide != null and wide.modulate.r < 1.0, "Dusk tint also affects ultrawide landscape")
	title.queue_free()
	await process_frame

	var intro_scene: PackedScene = load("res://scenes/ui/company_splash.tscn")
	_check(intro_scene != null, "Five Star intro scene loads")
	if intro_scene != null:
		var intro: Control = intro_scene.instantiate() as Control
		intro.set("auto_advance", false)
		root.add_child(intro)
		await process_frame
		var twinkles: Control = intro.get_node_or_null("StarTwinkles") as Control
		_check(twinkles != null, "Five Star pixel glints are added")
		_check(twinkles != null and twinkles.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Intro stars cannot block tap-to-skip")
		_check(intro.has_method("_go_next"), "Five Star retains the skip transition")
		intro.queue_free()
		await process_frame
	print("TITLE AMBIENT RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
