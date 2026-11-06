extends Control
## Fully standalone Outpost title menu (Godot 4.7.x / Android landscape).
## The PNG artwork is optional until final art sign-off; transparent SVG placeholders render without it.
const DESIGN := Vector2(1280.0, 720.0)
const MAIN_GAME := "res://scenes/main.tscn"
const WORLD_LOADING := "res://scenes/ui/world_loading.tscn"
const SAVE_PATH := "user://outpost_progress_v02.json"
const UI_PREFS := "user://outpost_ui.cfg"
const BUTTON_SCENE := preload("res://scenes/ui/title_menu_button.tscn")
const LOGO_SCENE := preload("res://scenes/ui/title_logo.tscn")
const SPLASH_SCENE := preload("res://scenes/ui/title_splash.tscn")
const ANDROID_UPDATER := preload("res://scripts/ui/android_updater.gd")
const TIPS := [
	"Tip: Gather wood and stone before visiting the workbench.",
	"Tip: Equipped tools increase your harvest from the right resources.",
	"Tip: Smelt iron at the forge before crafting stronger equipment.",
	"Tip: Switch weapons and armour through the BAG and GEAR screens.",
	"Tip: Workbenches turn simple resources into useful equipment.",
	"Tip: A shield reduces incoming damage but occupies your off-hand.",
	"Tip: A torch shares the off-hand slot with your shield.",
	"Tip: Keep a torch handy before the light begins to fade.",
	"Tip: The Fields stretch beyond the clearing. Bring supplies.",
	"Tip: Portals lead to dungeons. Prepare your gear before entering.",
	"Tip: A cloak can help you travel through the world a little faster.",
	"Tip: Harvestable trees and ore deposits recover after a while.",
	"Tip: Search near cliffs and paths for stone, ore and plants.",
	"Tip: Stock up on herbs, berries and mushrooms while exploring.",
	"Tip: Your bag has a carry limit. Upgrade it before a long expedition.",
	"Tip: Gather materials first, then load a recipe at its crafting station.",
	"Tip: Finish the station's work actions to complete crafting.",
	"Tip: Keep an eye on enemy movement before closing the distance.",
	"Tip: A forged blade is a useful upgrade over your starting weapon.",
	"Tip: Your gathering, crafting and combat all help your adventure grow.",
	"Tip: Try rotating the camera to see what's hidden behind the trees.",
	"Tip: On a keyboard, press E to interact and C to open crafting.",
	"Tip: A brighter campfire makes the night feel less lonely.",
	"Tip: Every outpost begins with one small shelter and a little hope.",
	"Tip: The purple glow on the horizon may hide a dungeon entrance.",
	"Tip: What you craft today may save you when night falls.",
	"Tip: Take time to explore. Not every reward is found in a fight.",
	"Tip: However dark the world gets, you are its light.",
	"Tip: Keep the campfire burning — Chloe and Iyla need a safe outpost after dark."
]
var _canvas: Control
var _splash: Label
var _tip_text: Label
var _tip_plaque: TextureRect
var _light_layer: TextureRect
var _continue_button: Button
var _settings_panel: PanelContainer
var _updater: Node
var _update_button: Button
var _update_status: Label
var _update_notice: Button
var _update_download_url: String = ""
var _show_tips := true
var _reduced_motion := false
var _tip_index := 0
var _tip_elapsed := 0.0
const TIP_CYCLE_SECONDS: float = 9.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_read_prefs()
	# Pick a different opening tip each session; every tip remains in the rotation.
	_tip_index = randi_range(0, TIPS.size() - 1)
	_make_screen()
	_layout()
	get_viewport().size_changed.connect(_layout)
	if OS.has_feature("Android") and _updater != null:
		# Passive, single startup check; only display a banner if there's
		# a newer signed APK. Never download or install automatically.
		_updater.check_for_updates.call_deferred()
	set_process(true)

func _layout() -> void:
	if _canvas == null:
		return
	var available: Vector2 = get_viewport_rect().size
	var fit: float = minf(available.x / DESIGN.x, available.y / DESIGN.y)
	_canvas.scale = Vector2.ONE * fit
	_canvas.position = (available - DESIGN * fit) * 0.5

func _make_screen() -> void:
	var curtain := ColorRect.new()
	curtain.color = Color("151c32")
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)

	_canvas = Control.new()
	_canvas.name = "Artboard"
	_canvas.size = DESIGN
	add_child(_canvas)
	_add_image("Backdrop", "title_background.png", "title_backdrop.svg", Vector2.ZERO, DESIGN)
	# Independent light pass: campsite lanterns, fire, distant portal and waterfall.
	_add_image("TitleLights", "title_lights.png", "title_lights.svg", Vector2.ZERO, DESIGN)
	_light_layer = _canvas.get_node_or_null("TitleLights") as TextureRect
	_add_image("TitleFrame", "title_frame.png", "title_frame.svg", Vector2.ZERO, DESIGN)
	_add_image("LeftBanner", "banner_star.png", "banner_star.svg", Vector2(51, 17), Vector2(90, 115))
	_add_image("RightBanner", "banner_star.png", "banner_star.svg", Vector2(1140, 17), Vector2(90, 115))
	
	var logo: Control = LOGO_SCENE.instantiate() as Control
	logo.name = "OutpostLogo"
	logo.position = Vector2(392, 8)
	logo.size = Vector2(496, 330)
	logo.custom_minimum_size = Vector2.ZERO
	_canvas.add_child(logo)

	_splash = SPLASH_SCENE.instantiate() as Label
	_splash.name = "UpdateSplash"
	_splash.position = Vector2(850, 92)
	_splash.size = Vector2(365, 135)
	_splash.pivot_offset = Vector2(182, 67)
	_splash.custom_minimum_size = Vector2.ZERO
	_canvas.add_child(_splash)
	if _reduced_motion:
		_splash.animate_bounce = false

	for i in range(4):
		var kind: String = ["play", "continue", "settings", "quit"][i]
		var b: Button = BUTTON_SCENE.instantiate() as Button
		b.name = kind.capitalize() + "Button"
		b.set("button_kind", kind)
		b.position = Vector2(425, 342 + 79 * i)
		b.size = Vector2(430, 72)
		_canvas.add_child(b)
		b.custom_minimum_size = Vector2(430, 72)
		match kind:
			"play":
				b.pressed.connect(_on_play)
				b.grab_focus.call_deferred()
			"continue":
				_continue_button = b
				b.pressed.connect(_begin_continue)
			"settings":
				b.pressed.connect(_toggle_settings)
			"quit":
				b.pressed.connect(func() -> void: get_tree().quit())
	_continue_button.disabled = not _has_valid_save()

	# Only use a textless PNG plaque. The reference art's v0.1.0-dev must not show behind the actual version.
	_add_image("VersionPlaque", "version_badge_textless.png", "version_badge.svg", Vector2(1069, 661), Vector2(190, 47))
	var version := Label.new()
	version.name = "Version"
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.5.0-dev")).trim_prefix("v")
	version.position = Vector2(1077, 670)
	version.size = Vector2(174, 30)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_style(version, 20, Color("fff1d5"), Color("2b1e25"))
	_canvas.add_child(version)

	_add_image("TipPlaque", "tip_panel.png", "tip_panel.svg", Vector2(247, 656), Vector2(785, 53))
	_tip_plaque = _canvas.get_node_or_null("TipPlaque") as TextureRect
	if _tip_plaque != null:
		_tip_plaque.visible = _show_tips
	_tip_text = Label.new()
	_tip_text.name = "WorldTip"
	_tip_text.position = Vector2(280, 662)
	_tip_text.size = Vector2(720, 41)
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.clip_text = true
	_tip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_text.text = TIPS[_tip_index]
	_tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_style(_tip_text, 17, Color("fff2cc"), Color("2b1a21"))
	_canvas.add_child(_tip_text)
	_tip_text.visible = _show_tips

	_build_settings()
	_update_notice = Button.new()
	_update_notice.name = "UpdateAvailable"
	_update_notice.text = "OUTPOST UPDATE AVAILABLE"
	_update_notice.position = Vector2(912, 591)
	_update_notice.size = Vector2(314, 53)
	_update_notice.visible = false
	_update_notice.add_theme_font_size_override("font_size", 18)
	_update_notice.add_theme_color_override("font_color", Color("ffefbd"))
	var update_frame := StyleBoxFlat.new()
	update_frame.bg_color = Color("392833")
	update_frame.border_color = Color("f1bd69")
	update_frame.set_border_width_all(4)
	update_frame.set_corner_radius_all(7)
	_update_notice.add_theme_stylebox_override("normal", update_frame)
	_update_notice.pressed.connect(_check_or_download_update)
	_canvas.add_child(_update_notice)

func _add_image(node_name: String, png: String, svg: String, where: Vector2, how_big: Vector2) -> void:
	# The screenshot/mock-up is not one flattened UI. Every asset stays a
	# separate clickable/replaceable Godot node, including the backdrop.
	var base := "res://assets/ui/title/"
	var texture: Texture2D
	for path in [base + png, base + svg]:
		if not ResourceLoader.exists(path):
			continue
		texture = load(path) as Texture2D
		if texture != null:
			break
	if texture == null:
		push_warning("Outpost title artwork missing: " + png + " / " + svg)
		return
	var image := TextureRect.new()
	image.name = node_name
	image.texture = texture
	image.position = where
	image.size = how_big
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node_name in ["Backdrop", "TitleLights"]:
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.add_child(image)

func _label_style(label: Label, font_size: int, ink: Color, outline: Color) -> void:
	var s := LabelSettings.new()
	s.font_size = font_size
	s.font_color = ink
	s.outline_color = outline
	s.outline_size = 3
	label.label_settings = s

func _has_valid_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (data is Dictionary):
		return false
	return int(data.get("version", 0)) in [2, 3, 4, 5]

func _on_play() -> void:
	if _has_valid_save():
		var warning := ConfirmationDialog.new()
		warning.title = "Start a new adventure?"
		warning.dialog_text = "Your existing save will be replaced when the new adventure saves.\nSelect Continue to keep your current progress."
		_canvas.add_child(warning)
		warning.confirmed.connect(func() -> void: _launch_game(true))
		warning.popup_centered(Vector2i(560, 210))
	else:
		_launch_game(true)

func _begin_continue() -> void:
	if _has_valid_save():
		_launch_game(false)

func _launch_game(new_adventure: bool) -> void:
	get_tree().root.set_meta("outpost_new_adventure", new_adventure)
	get_tree().change_scene_to_file(WORLD_LOADING)

func _process(delta: float) -> void:
	# A restrained breathing light pass; no particles, shaders or heavy post effects.
	if _light_layer != null:
		_light_layer.modulate.a = 0.79 if _reduced_motion else 0.78 + 0.14 * sin(float(Time.get_ticks_msec()) * 0.0017)
	if _show_tips and _tip_text != null:
		_tip_elapsed += delta
		if _tip_elapsed >= TIP_CYCLE_SECONDS:
			_tip_elapsed = 0.0
			_advance_tip()

func _advance_tip() -> void:
	_tip_index = (_tip_index + 1) % TIPS.size()
	if _reduced_motion:
		_tip_text.text = TIPS[_tip_index]
		_tip_text.modulate.a = 1.0
		return
	var fade := create_tween()
	fade.tween_property(_tip_text, "modulate:a", 0.12, 0.20)
	fade.tween_callback(func() -> void: _tip_text.text = TIPS[_tip_index])
	fade.tween_property(_tip_text, "modulate:a", 1.0, 0.26)

func _build_settings() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.position = Vector2(340, 169)
	_settings_panel.size = Vector2(600, 405)
	_settings_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("25243b")
	style.border_color = Color("dfb47b")
	style.set_border_width_all(5)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(22)
	_settings_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_settings_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	_settings_panel.add_child(stack)
	var heading := Label.new()
	heading.text = "Outpost Settings"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_style(heading, 32, Color("ffe1a0"), Color("40242c"))
	stack.add_child(heading)
	var motion := CheckButton.new()
	motion.text = "Reduce menu animation"
	motion.button_pressed = _reduced_motion
	motion.toggled.connect(func(enabled: bool) -> void:
		_reduced_motion = enabled
		_splash.animate_bounce = not enabled
		if enabled:
			_splash.scale = Vector2.ONE
		_write_prefs()
	)
	stack.add_child(motion)
	var tips := CheckButton.new()
	tips.text = "Show adventure tips"
	tips.button_pressed = _show_tips
	tips.toggled.connect(func(enabled: bool) -> void:
		_show_tips = enabled
		_tip_text.visible = enabled
		if _tip_plaque != null:
			_tip_plaque.visible = enabled
		_write_prefs()
	)
	stack.add_child(tips)

	# Update checking belongs in the existing title settings; no gameplay modal
	# and no background traffic until the player asks for an update.
	_updater = ANDROID_UPDATER.new()
	_updater.name = "AndroidUpdater"
	add_child(_updater)
	_updater.status_changed.connect(_on_update_status)
	_updater.update_found.connect(_on_update_found)
	_update_button = Button.new()
	_update_button.name = "CheckForUpdates"
	_update_button.text = "CHECK FOR ANDROID UPDATES"
	_update_button.custom_minimum_size = Vector2(0, 55)
	_update_button.pressed.connect(_check_or_download_update)
	stack.add_child(_update_button)
	_update_status = Label.new()
	_update_status.name = "UpdateStatus"
	_update_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_status.text = "Android build %d • Updates keep saves with the same signing key" % int(ProjectSettings.get_setting("application/config/android_build_code", 11))
	_label_style(_update_status, 16, Color("fff1d5"), Color("2b1e25"))
	stack.add_child(_update_status)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 54)
	back.pressed.connect(_toggle_settings)
	stack.add_child(back)

func _check_or_download_update() -> void:
	if not _update_download_url.is_empty():
		# The Android installer always needs the user's approval. A browser
		# download avoids unsafe file:// URI / FileProvider workarounds.
		var error: Error = OS.shell_open(_update_download_url)
		if error != OK:
			_on_update_status("Couldn't open your browser; use the GitHub Releases page.")
		return
	if _updater != null:
		_updater.check_for_updates()

func _on_update_status(message: String) -> void:
	if _update_status != null:
		_update_status.text = message

func _on_update_found(download_url: String, version_code: int, _release_url: String) -> void:
	_update_download_url = download_url
	_update_button.text = "DOWNLOAD ANDROID UPDATE"
	if _update_notice != null:
		_update_notice.text = "UPDATE AVAILABLE  •  BUILD %d" % version_code
		_update_notice.visible = true
	_on_update_status("New Outpost build %d available. Tap Download, then approve Android's install prompt." % version_code)

func _toggle_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible
	_settings_panel.move_to_front()

func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel != null and _settings_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_toggle_settings()
			get_viewport().set_input_as_handled()

func _read_prefs() -> void:
	var prefs := ConfigFile.new()
	if prefs.load(UI_PREFS) == OK:
		_reduced_motion = bool(prefs.get_value("title", "reduced_motion", false))
		_show_tips = bool(prefs.get_value("title", "show_tips", true))

func _write_prefs() -> void:
	var prefs := ConfigFile.new()
	prefs.set_value("title", "reduced_motion", _reduced_motion)
	prefs.set_value("title", "show_tips", _show_tips)
	prefs.save(UI_PREFS)
