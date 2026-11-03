extends Control
## Fully standalone Outpost title menu (Godot 4.7.x / Android landscape).
## The PNG artwork is optional until final art sign-off; transparent SVG placeholders render without it.
const DESIGN := Vector2(1280.0, 720.0)
const MAIN_GAME := "res://scenes/main.tscn"
const SAVE_PATH := "user://outpost_progress_v02.json"
const UI_PREFS := "user://outpost_ui.cfg"
const BUTTON_SCENE := preload("res://scenes/ui/title_menu_button.tscn")
const LOGO_SCENE := preload("res://scenes/ui/title_logo.tscn")
const SPLASH_SCENE := preload("res://scenes/ui/title_splash.tscn")
const TIPS := [
	"Tip: Gather wood and stone before visiting the workbench.",
	"Tip: Equipped tools can increase your resource yields.",
	"Tip: Visit the forge to turn iron ore into iron ingots.",
	"Tip: Equip your newly crafted weapons through BAG and GEAR.",
	"Tip: Keep supplies ready before exploring the wilderness.",
	"Tip: Campfires and crafting stations are your friends.",
	"Tip: Use a shield to reduce damage from wild creatures.",
	"Tip: A cloak can help you move a little faster.",
	"Tip: Check nearby resources before swinging your tools.",
	"Tip: Collect herbs, berries and mushrooms when travelling.",
	"Tip: Your workbench can turn simple resources into useful tools.",
	"Tip: Finish each crafting action to complete the recipe.",
	"Tip: Keep the campfire burning — Chloe and Iyla need a safe outpost after dark."
]
var _canvas: Control
var _splash: Label
var _tip_text: Label
var _continue_button: Button
var _settings_panel: PanelContainer
var _show_tips := true
var _reduced_motion := false
var _tip_index := 0
var _tip_elapsed := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_read_prefs()
	_make_screen()
	_layout()
	get_viewport().size_changed.connect(_layout)
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

func _add_image(node_name: String, png: String, svg: String, where: Vector2, how_big: Vector2) -> void:
	var path := "res://assets/ui/title/" + png
	if not ResourceLoader.exists(path):
		path = "res://assets/ui/title/" + svg
	if not ResourceLoader.exists(path):
		return
	var image := TextureRect.new()
	image.name = node_name
	image.texture = load(path) as Texture2D
	image.position = where
	image.size = how_big
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	get_tree().change_scene_to_file(MAIN_GAME)

func _process(delta: float) -> void:
	if _show_tips:
		_tip_elapsed += delta
		if _tip_elapsed >= 10.0:
			_tip_elapsed = 0.0
			_tip_index = (_tip_index + 1) % TIPS.size()
			_tip_text.text = TIPS[_tip_index]

func _build_settings() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.position = Vector2(340, 213)
	_settings_panel.size = Vector2(600, 345)
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
		_write_prefs()
	)
	stack.add_child(tips)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 54)
	back.pressed.connect(_toggle_settings)
	stack.add_child(back)

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
