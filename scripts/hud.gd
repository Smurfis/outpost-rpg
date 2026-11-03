extends CanvasLayer
## Outpost Compact HUD v0.7 — designed for landscape phone screens.
## Controls reference the v0.2 touch movement contract (global touch + mouse fallback).
## Only two large action buttons remain; non-combat systems live in one drawer.
var game
var root: Control
var status: Label
var quest: Label
var hint: Label
var toast_label: Label
var health_bar: ProgressBar
var items: Dictionary = {}
var joystick: Panel
var knob: Panel
var move_vector: Vector2 = Vector2.ZERO
var finger: int = -1
var mouse_stick: bool = false
var touches_seen: int = 0
var mice_seen: int = 0
var last_input_source: String = "NONE"
var input_diagnostic: Label
var quick_menu: PanelContainer
var quick_menu_open: bool = false
var menu_button: Button
var gather_button: Button
var attack_button: Button
var craft_button: Button
var ability_button: Button
var toast_time: float = 0.0
var context_available: bool = false
const INK: Color = Color("10272b")
const INK_LIGHT: Color = Color("233d41")
const GOLD: Color = Color("d9bc83")
const CREAM: Color = Color("eee2c5")

func setup(ref: Node) -> void:
	game = ref

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.name = "CompactOutpostHUD"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel(0.020, 0.022, 0.350, 0.145, Color("14282c"))
	status = _label("OUTPOST  •  HP 100/100", 18, CREAM, 0.034, 0.030, 0.333, 0.077)
	health_bar = ProgressBar.new()
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("background", _style(Color("3a4241"), 8))
	health_bar.add_theme_stylebox_override("fill", _style(Color("b75d50"), 8))
	root.add_child(health_bar)
	_anchors(health_bar, 0.036, 0.094, 0.330, 0.116)
	_panel(0.365, 0.025, 0.778, 0.110, Color("14282c"))
	quest = _label("Explore the Outpost", 17, GOLD, 0.378, 0.043, 0.762, 0.105)
	quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint = _label("", 15, Color("d4d7ba"), 0.326, 0.894, 0.678, 0.952)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = _label("", 19, CREAM, 0.304, 0.145, 0.725, 0.210)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.visible = false

	joystick = Panel.new()
	joystick.name = "Move"
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.add_theme_stylebox_override("panel", _style(Color(0.18, 0.29, 0.31, 0.66), 100, GOLD, 2))
	root.add_child(joystick)
	joystick.size = Vector2(182, 182)
	knob = Panel.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.add_theme_stylebox_override("panel", _style(Color(0.83, 0.85, 0.76, 0.90), 100))
	joystick.add_child(knob)
	knob.size = Vector2(66, 66)

	attack_button = _action("attack", "ATTACK", 0.838, 0.738, 0.982, 0.968, Color("a7564b"))
	gather_button = _action("gather", "GATHER", 0.690, 0.766, 0.819, 0.958, Color("487c61"))
	craft_button = _action("craft", "CRAFT", 0.690, 0.766, 0.819, 0.958, Color("94714e"))
	gather_button.visible = false
	craft_button.visible = false
	ability_button = _action("ability", "SKILL", 0.862, 0.545, 0.977, 0.710, Color("456a80"))
	ability_button.visible = false
	menu_button = _action("menu", "MENU", 0.850, 0.022, 0.981, 0.128, INK_LIGHT)

	quick_menu = PanelContainer.new()
	quick_menu.name = "QuickMenu"
	quick_menu.add_theme_stylebox_override("panel", _style(Color("1a3236"), 12, GOLD, 2))
	root.add_child(quick_menu)
	_anchors(quick_menu, 0.410, 0.198, 0.720, 0.790)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	quick_menu.add_child(layout)
	var heading := Label.new()
	heading.text = "OUTPOST  /  JOURNAL"
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", GOLD)
	layout.add_child(heading)
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 7)
	actions.add_theme_constant_override("v_separation", 7)
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(actions)
	for action_name in ["BAG", "CRAFTING", "GEAR", "SKILLS", "SALVAGE", "HEAL"]:
		var button := Button.new()
		button.text = action_name
		button.custom_minimum_size = Vector2(116, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("normal", _style(INK_LIGHT, 8, Color("52645a"), 1))
		button.add_theme_stylebox_override("hover", _style(Color("345359"), 8, GOLD, 1))
		button.add_theme_stylebox_override("pressed", _style(Color("30524f"), 8, GOLD, 1))
		button.pressed.connect(_quick_action.bind(action_name))
		actions.add_child(button)
	var debug := Button.new()
	debug.text = "INPUT DIAGNOSTICS"
	debug.custom_minimum_size = Vector2(0, 35)
	debug.pressed.connect(_toggle_diagnostics)
	layout.add_child(debug)
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(close_quick_menu)
	layout.add_child(close)
	quick_menu.visible = false
	input_diagnostic = _label("", 14, CREAM, 0.015, 0.58, 0.65, 0.626)
	input_diagnostic.visible = false
	_position_stick()

func _anchors(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_right = 0.0
	control.offset_top = 0.0
	control.offset_bottom = 0.0

func _style(color: Color, radius: int, outline: Color = Color.TRANSPARENT, thickness: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = outline
	style.set_border_width_all(thickness)
	style.set_corner_radius_all(radius)
	return style

func _panel(left: float, top: float, right: float, bottom: float, color: Color) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(color, 12))
	root.add_child(panel)
	_anchors(panel, left, top, right, bottom)

func _label(value: String, size: int, color: Color, left: float, top: float, right: float, bottom: float) -> Label:
	var out := Label.new()
	out.text = value
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.add_theme_font_size_override("font_size", size)
	out.add_theme_color_override("font_color", color)
	root.add_child(out)
	_anchors(out, left, top, right, bottom)
	return out

func _action(key: String, caption: String, left: float, top: float, right: float, bottom: float, color: Color) -> Button:
	var button := Button.new()
	button.name = key.capitalize() + "Button"
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style(color, 18, Color("b6aa8a"), 1))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.14), 18, GOLD, 2))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.22), 18, GOLD, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("3c4b4d"), 18))
	root.add_child(button)
	_anchors(button, left, top, right, bottom)
	var artwork := TextureRect.new()
	var icon_id: String = "flag" if key == "menu" else "spear" if key == "ability" else key
	artwork.texture = load("res://assets/icons/" + icon_id + ".svg") as Texture2D
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(artwork)
	_anchors(artwork, 0.22, 0.09, 0.78, 0.66)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", CREAM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	_anchors(label, 0, 0.69, 1.0, 0.99)
	match key:
		"attack": button.pressed.connect(_attack)
		"gather": button.pressed.connect(_gather)
		"craft": button.pressed.connect(_craft)
		"ability": button.pressed.connect(_ability)
		"menu": button.pressed.connect(_toggle_menu)
	return button

func _process(delta: float) -> void:
	_position_stick()
	if knob != null:
		knob.position = (joystick.size - knob.size) * 0.5 + move_vector * 56.0
	if input_diagnostic != null and input_diagnostic.visible:
		var locked: bool = game != null and game.hero != null and game.hero.interaction_locked
		var other_menu: bool = game != null and ((game.menu != null and game.menu.visible) or (game.progression_ui != null and game.progression_ui.visible))
		input_diagnostic.text = "INPUT %s | T:%d M:%d | STICK %.2f | LOCK:%s UI:%s" % [last_input_source, touches_seen, mice_seen, move_vector.length(), str(locked), str(other_menu or quick_menu_open)]
	if toast_time > 0.0:
		toast_time = maxf(0.0, toast_time - delta)
		if toast_time == 0.0:
			toast_label.visible = false

func _position_stick() -> void:
	if joystick == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	joystick.position = Vector2(32, maxf(32.0, screen.y - joystick.size.y - 26.0))

func _center() -> Vector2:
	return joystick.get_global_rect().get_center()

func _reset_joystick() -> void:
	finger = -1
	mouse_stick = false
	move_vector = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if game == null:
		return
	var modal_open: bool = quick_menu_open or (game.menu != null and game.menu.visible) or (game.progression_ui != null and game.progression_ui.visible) or (game.hero != null and game.hero.interaction_locked)
	if modal_open:
		_reset_joystick()
		return
	# Keep v0.2 global-input movement; both Android touches and mouse
	# emulation are accepted, without allowing the mouse twin to steal a finger.
	if event is InputEventScreenTouch:
		touches_seen += 1
		last_input_source = "TOUCH"
		if event.pressed and finger == -1 and event.position.distance_to(_center()) <= 140.0:
			mouse_stick = false
			finger = event.index
			_stick(event.position)
		elif not event.pressed and event.index == finger:
			_reset_joystick()
	elif event is InputEventScreenDrag:
		if event.index == finger:
			last_input_source = "DRAG"
			_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mice_seen += 1
		if event.pressed and finger == -1 and event.position.distance_to(_center()) <= 140.0:
			mouse_stick = true
			last_input_source = "MOUSE"
			_stick(event.position)
		elif not event.pressed and mouse_stick and finger == -1:
			_reset_joystick()
	elif event is InputEventMouseMotion:
		if mouse_stick and finger == -1:
			last_input_source = "MOUSE-DRAG"
			_stick(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_reset_joystick()

func _stick(at: Vector2) -> void:
	move_vector = ((at - _center()) / 64.0).limit_length(1.0)

func _toggle_menu() -> void:
	if quick_menu_open:
		close_quick_menu()
	else:
		quick_menu_open = true
		quick_menu.visible = true
		_reset_joystick()

func close_quick_menu() -> void:
	quick_menu_open = false
	if quick_menu != null:
		quick_menu.visible = false
	_reset_joystick()

func _quick_action(id: String) -> void:
	close_quick_menu()
	match id:
		"BAG": game.show_inventory()
		"CRAFTING": game.show_crafting()
		"GEAR": game.show_progression("equipment")
		"SKILLS": game.show_progression("skills")
		"SALVAGE": game.show_progression("salvage")
		"HEAL": game.use_meal()

func _toggle_diagnostics() -> void:
	if input_diagnostic != null:
		input_diagnostic.visible = not input_diagnostic.visible

func render_status(hp: float, inventory: Dictionary, xp: int, kills: int, _weapon: String, objective: String, helper: String) -> void:
	if status == null:
		return
	status.text = "OUTPOST  /  HP %d   •   XP %d   •   KILLS %d" % [int(ceilf(hp)), xp, kills]
	health_bar.value = clampf(hp, 0.0, 100.0)
	for key in items:
		items[key].text = str(inventory.get(key, 0))
	quest.text = objective
	hint.text = helper

func update_context(has_resource: bool, has_enemy: bool, at_station: bool) -> void:
	context_available = has_resource or at_station
	gather_button.visible = has_resource and not quick_menu_open
	gather_button.disabled = not has_resource
	craft_button.visible = not has_resource and at_station and not quick_menu_open
	craft_button.disabled = not at_station
	attack_button.disabled = not has_enemy
	var available_skill: bool = false
	if game != null and game.progression_ui != null:
		var active: Array = game.SKILLS.active_skills(game.crafted_gear, game.gear_loadout, game.learned_skills)
		available_skill = not active.is_empty()
	ability_button.visible = available_skill and not quick_menu_open

func toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_time = 3.4

func _gather() -> void:
	game.gather()

func _attack() -> void:
	game.attack()

func _craft() -> void:
	game.craft()

func _ability() -> void:
	game.cast_skill()

func _bag() -> void:
	close_quick_menu()
	game.show_inventory()

func _heal() -> void:
	game.use_meal()

func _skills() -> void:
	close_quick_menu()
	game.show_progression("skills")
