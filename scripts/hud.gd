extends CanvasLayer
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
## Landscape touchscreen HUD with original scalable SVG item and ability art.
var game
var root: Control
var status: Label
var world_clock: Label
var quest: Label
var hint: Label
var toast_label: Label
var health_bar: ProgressBar
var xp_bar: ProgressBar
var toast_panel: Panel
var items: Dictionary = {}
var joystick: Panel
var knob: Panel
var move_vector := Vector2.ZERO
var finger := -1
var mouse_stick := false
var gather_button: Button
var attack_button: Button
var craft_button: Button
var toast_time := 0.0

func setup(ref: Node) -> void:
	game = ref

func _ready() -> void:
	root = Control.new()
	root.name = "OutpostHUD"
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel(0.015, 0.02, 0.302, 0.215, Color("#291d1b"))
	world_clock = _label("DAY 12:00", 13, Color("#e9d4ab"), 0.780, 0.046, 0.879, 0.110)
	status = _label("OUTPOST  ◆  HP 100/100", 16, Color("#f9e2b7"), 0.029, 0.028, 0.29, 0.077)
	health_bar = _meter(0.03, 0.079, 0.284, 0.105, Color("#d94f44"))
	xp_bar = _meter(0.03, 0.113, 0.284, 0.131, Color("#6db4dd"))
	var start_x := 0.027
	for key in ["wood", "stone", "hide", "coins"]:
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/" + key + ".svg") as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(icon)
		_anchors(icon, start_x, 0.147, start_x + 0.035, 0.19)
		var amount := _label("0", 15, Color("#f8e1b3"), start_x + 0.037, 0.146, start_x + 0.065, 0.193)
		items[key] = amount
		start_x += 0.067
	_panel(0.355, 0.019, 0.788, 0.116, Color("#291d1b"))
	quest = _label("Gather wood and stone, then craft at the workbench", 16, Color("#f5ddaa"), 0.371, 0.028, 0.776, 0.108)
	quest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel(0.325, 0.902, 0.669, 0.967, Color("#291d1b"))
	hint = _label("Explore the forest", 14, Color("#f6e7c6"), 0.339, 0.907, 0.653, 0.958)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_panel = _panel(0.354, 0.138, 0.729, 0.221, Color("#edd09b"))
	toast_panel.add_theme_stylebox_override("panel", SKIN.box("toast"))
	toast_panel.visible = false
	toast_label = _label("", 17, Color("#4d3020"), 0.367, 0.144, 0.716, 0.214)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Minimal co-op entry for Android: functional control, not an art overhaul.
	var multiplayer_entry := Button.new()
	multiplayer_entry.name = "CoopEntryButton"
	multiplayer_entry.text = "CO-OP"
	multiplayer_entry.add_theme_font_size_override("font_size", 16)
	SKIN.apply_button(multiplayer_entry, "wood")
	root.add_child(multiplayer_entry)
	_anchors(multiplayer_entry, 0.882, 0.035, 0.974, 0.116)
	multiplayer_entry.pressed.connect(_open_coop)
	_action("bag", "BAG", 0.761, 0.475, 0.839, 0.612, Color("#6e4a32"))
	_action("craft", "CRAFT", 0.852, 0.475, 0.937, 0.612, Color("#6e4a32"))
	_action("heal", "HEAL", 0.693, 0.746, 0.772, 0.893, Color("#476c43"))
	_action("gather", "GATHER", 0.784, 0.712, 0.868, 0.91, Color("#476c43"))
	_action("attack", "ATTACK", 0.883, 0.69, 0.986, 0.934, Color("#844237"))
	joystick = Panel.new()
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := SKIN.flat("hud")
	ring.set_corner_radius_all(90)
	joystick.add_theme_stylebox_override("panel", ring)
	root.add_child(joystick)
	joystick.size = Vector2(154, 154)
	knob = Panel.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thumb := SKIN.flat("parchment_light")
	thumb.set_corner_radius_all(60)
	knob.add_theme_stylebox_override("panel", thumb)
	joystick.add_child(knob)
	knob.size = Vector2(56, 56)
	_position_stick()

func _meter(left: float, top: float, right: float, bottom: float, front: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.max_value = 100.0
	meter.value = 100.0
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := SKIN.flat("inset")
	bg.set_corner_radius_all(4)
	var fill := SKIN.flat("wood_selected")
	fill.bg_color = front
	fill.set_border_width_all(0)
	fill.set_corner_radius_all(3)
	meter.add_theme_stylebox_override("background", bg)
	meter.add_theme_stylebox_override("fill", fill)
	root.add_child(meter)
	_anchors(meter, left, top, right, bottom)
	return meter

func _anchors(n: Control, left: float, top: float, right: float, bottom: float) -> void:
	n.anchor_left = left
	n.anchor_top = top
	n.anchor_right = right
	n.anchor_bottom = bottom
	n.offset_left = 0
	n.offset_right = 0
	n.offset_top = 0
	n.offset_bottom = 0

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	return s

func _panel(left: float, top: float, right: float, bottom: float, _color: Color) -> Panel:
	var n := Panel.new()
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_stylebox_override("panel", SKIN.box("hud"))
	root.add_child(n)
	_anchors(n, left, top, right, bottom)
	return n

func _label(value: String, size: int, color: Color, left: float, top: float, right: float, bottom: float) -> Label:
	var n := Label.new()
	n.text = value
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", color)
	root.add_child(n)
	_anchors(n, left, top, right, bottom)
	return n

func _action(key: String, label: String, left: float, top: float, right: float, bottom: float, _color: Color) -> void:
	var button := Button.new()
	button.text = ""
	button.name = "Action_" + key
	if key == "gather":
		gather_button = button
	elif key == "attack":
		attack_button = button
	elif key == "craft":
		craft_button = button
	SKIN.apply_button(button, "red" if key == "attack" else "green" if key in ["gather", "heal"] else "wood")
	root.add_child(button)
	_anchors(button, left, top, right, bottom)
	var art_icon := TextureRect.new()
	art_icon.texture = load("res://assets/ui/icons/" + key + ".png") as Texture2D
	art_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art_icon)
	art_icon.anchor_left = 0.17
	art_icon.anchor_right = 0.83
	art_icon.anchor_top = 0.07
	art_icon.anchor_bottom = 0.65
	var title := Label.new()
	title.text = label
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#f9e7c0"))
	title.add_theme_font_size_override("font_size", 13)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.66
	title.anchor_bottom = 0.96
	if key == "gather":
		button.pressed.connect(_gather)
	elif key == "attack":
		button.pressed.connect(_attack)
	elif key == "craft":
		button.pressed.connect(_craft)
	elif key == "bag":
		button.pressed.connect(_bag)
	else:
		button.pressed.connect(_heal)

func _process(delta: float) -> void:
	_position_stick()
	knob.position = (joystick.size - knob.size) * 0.5 + move_vector * 45.0
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0:
			toast_label.text = ""
			toast_panel.visible = false

func _position_stick() -> void:
	var screen := get_viewport().get_visible_rect().size
	joystick.position = Vector2(28, screen.y - 182)

func _center() -> Vector2:
	return joystick.get_global_rect().get_center()

func _input(event: InputEvent) -> void:
	if game != null and ((game.menu != null and game.menu.visible) or (game.coop != null and game.coop.ui != null and game.coop.ui.visible)):
		_reset_touch()
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and event.position.distance_to(_center()) < 104:
			finger = event.index
			mouse_stick = false
			_stick(event.position)
		elif not event.pressed and event.index == finger:
			_reset_touch()
	elif event is InputEventScreenDrag and event.index == finger:
		_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and finger == -1 and event.position.distance_to(_center()) < 104:
			mouse_stick = true
			_stick(event.position)
		elif not event.pressed and mouse_stick and finger == -1:
			_reset_touch()
	elif event is InputEventMouseMotion and mouse_stick and finger == -1:
		_stick(event.position)

func _reset_touch() -> void:
	finger = -1
	mouse_stick = false
	move_vector = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_reset_touch()

func _stick(pos: Vector2) -> void:
	move_vector = ((pos - _center()) / 55.0).limit_length(1.0)

func set_world_clock(display_time: String, night: bool) -> void:
	if world_clock == null:
		return
	world_clock.text = ("NIGHT " if night else "DAY ") + display_time
	world_clock.add_theme_color_override("font_color", Color("#eab970") if night else Color("#e9d4ab"))

func render_status(hp: float, inventory: Dictionary, xp: int, kills: int, weapon: String, objective: String, helper: String) -> void:
	status.text = "OUTPOST  ◆  HP %d/100\nXP %d  •  KILLS %d  •  %s" % [int(ceilf(hp)), xp, kills, weapon.replace("_", " ").to_upper()]
	if health_bar != null:
		health_bar.value = clampf(hp, 0.0, 100.0)
	if xp_bar != null:
		xp_bar.value = float(xp % 100)
	for key in items:
		items[key].text = str(inventory.get(key, 0))
	quest.text = objective
	hint.text = helper

func update_context(has_resource: bool, has_enemy: bool, at_bench: bool) -> void:
	if gather_button != null:
		gather_button.disabled = not has_resource
	if attack_button != null:
		attack_button.disabled = not has_enemy
	if craft_button != null:
		craft_button.modulate = Color.WHITE if at_bench else Color(0.65, 0.70, 0.74)

func toast(message: String) -> void:
	toast_label.text = message
	toast_panel.visible = true
	toast_time = 3.4

func _open_coop() -> void:
	if game.coop != null and game.coop.ui != null:
		game.coop.ui.open()

func _gather() -> void:
	game.gather()
func _attack() -> void:
	game.attack()
func _craft() -> void:
	game.craft()
func _bag() -> void:
	game.show_inventory()
func _heal() -> void:
	game.use_meal()
