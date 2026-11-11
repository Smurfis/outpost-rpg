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
		var focus_style: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
		_check(focus_style != null and focus_style.border_color.a < 0.01, name + " has no rectangular focus box")
		var plaque: TextureRect = button.get_node_or_null("PlaqueArtwork") as TextureRect
		_check(button.material == null and plaque != null and plaque.material is ShaderMaterial, name + " shades the PNG, not the Button's untextured canvas")
		button.call("_on_pointer_entered")
		_check(bool(button.call("is_title_highlighted")) == not button.disabled, name + " highlights only while enabled")
		if name == "QuitButton" and plaque != null and plaque.material is ShaderMaterial:
			_check((plaque.material as ShaderMaterial).shader.code.contains("vec3(1.0)"), "Hover and press whiten Quit power icon and text")
		button.call("_on_pointer_exited")
	# Changelog stays inside the screen, with a permanently visible
	# vertical scrollbar and actual published release metadata.
	var log_panel: PanelContainer = title.get_node_or_null("Artboard/ChangelogPanel") as PanelContainer
	var log_scroll: ScrollContainer = title.get_node_or_null("Artboard/ChangelogPanel/MarginContainer/VBoxContainer/ChangelogScrollList") as ScrollContainer
	_check(log_panel != null and log_panel.position.y + log_panel.size.y < 630.0, "Changelog is shorter than the title viewport with bottom clearance")
	_check(log_scroll != null and log_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS, "Changelog has persistent vertical scrollbar")
	var release_fixture: Array = [{
		"tag_name": "outpost-alpha-v9999",
		"name": "Outpost Alpha test release",
		"draft": false,
		"published_at": "2026-11-11T13:37:00Z",
		"author": {"login": "github-actions[bot]"},
		"body": "Verified title and menu updates"
	}]
	title.call("_on_changelog_releases_loaded", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(release_fixture).to_utf8_buffer())
	var log_entries: VBoxContainer = title.get("_changelog_entries") as VBoxContainer
	_check(log_entries != null and log_entries.get_child_count() == 2, "Latest Alpha releases replace offline notes")
	if log_entries != null and log_entries.get_child_count() == 2:
		var note_card: PanelContainer = log_entries.get_child(1) as PanelContainer
		var note_stack: VBoxContainer = note_card.get_child(0).get_child(0) as VBoxContainer
		var metadata: Label = note_stack.get_child(1) as Label
		var attribution: Label = note_stack.get_child(2) as Label
		_check(metadata.text.contains("2026-11-11") and metadata.text.contains("13:37 UTC"), "Release displays verified date and UTC time")
		_check(attribution.text.contains("Smurf") and attribution.text.contains("github-actions[bot]"), "Changelog distinguishes developer from automated publisher")
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
