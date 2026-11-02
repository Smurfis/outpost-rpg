extends CanvasLayer
## Landscape touchscreen HUD with original scalable SVG item and ability art.
var game
var root: Control
var status: Label
var quest: Label
var hint: Label
var toast_label: Label
var items: Dictionary = {}
var joystick: Panel
var knob: Panel
var move_vector := Vector2.ZERO
var finger := -1
var mouse_stick := false
var toast_time := 0.0

func setup(ref: Node) -> void:
	game = ref

func _ready() -> void:
	root = Control.new()
	root.name = "OutpostHUD"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel(0.01, 0.016, 0.45, 0.205, Color(0.045, 0.09, 0.11, 0.86))
	status = _label("OUTPOST  /  HP 100
XP 0   KILLS 0", 19, Color("efdfba"), 0.026, 0.023, 0.42, 0.095)
	var start_x := 0.026
	for key in ["wood", "stone", "hide", "coins"]:
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/" + key + ".svg") as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(icon)
		_anchors(icon, start_x, 0.120, start_x + 0.033, 0.173)
		var amount := _label("0", 19, Color.WHITE, start_x + 0.034, 0.122, start_x + 0.079, 0.174)
		items[key] = amount
		start_x += 0.103
	_panel(0.56, 0.015, 0.989, 0.116, Color(0.10, 0.14, 0.105, 0.84))
	quest = _label("Gather 3 wood and 2 stone", 19, Color("e7d7a2"), 0.574, 0.033, 0.970, 0.102)
	_panel(0.285, 0.865, 0.685, 0.974, Color(0.05, 0.09, 0.12, 0.83))
	hint = _label("Explore the forest", 18, Color("f9efd1"), 0.297, 0.885, 0.671, 0.958)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label = _label("", 22, Color("ffe5a4"), 0.26, 0.21, 0.75, 0.33)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action("gather", "GATHER", 0.688, 0.70, 0.816, 0.965, Color("346e57"))
	_action("attack", "ATTACK", 0.85, 0.69, 0.986, 0.964, Color("893e34"))
	_action("craft", "CRAFT", 0.817, 0.48, 0.986, 0.63, Color("655279"))
	joystick = Panel.new()
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.add_theme_stylebox_override("panel", _style(Color(0.12, 0.19, 0.23, 0.54), 90))
	root.add_child(joystick)
	joystick.size = Vector2(170, 170)
	knob = Panel.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.add_theme_stylebox_override("panel", _style(Color(0.84, 0.85, 0.76, 0.90), 90))
	joystick.add_child(knob)
	knob.size = Vector2(67, 67)
	_position_stick()

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

func _panel(left: float, top: float, right: float, bottom: float, color: Color) -> void:
	var n := Panel.new()
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_stylebox_override("panel", _style(color, 15))
	root.add_child(n)
	_anchors(n, left, top, right, bottom)

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

func _action(key: String, label: String, left: float, top: float, right: float, bottom: float, color: Color) -> void:
	var button := Button.new()
	button.text = ""
	button.add_theme_stylebox_override("normal", _style(color, 22))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.12), 22))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.2), 22))
	root.add_child(button)
	_anchors(button, left, top, right, bottom)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/" + key + ".svg") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.anchor_left = 0.24
	icon.anchor_right = 0.76
	icon.anchor_top = 0.09
	icon.anchor_bottom = 0.64
	var title := Label.new()
	title.text = label
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title)
	title.anchor_left = 0
	title.anchor_right = 1
	title.anchor_top = 0.68
	title.anchor_bottom = 1.0
	if key == "gather":
		button.pressed.connect(_gather)
	elif key == "attack":
		button.pressed.connect(_attack)
	else:
		button.pressed.connect(_craft)

func _process(delta: float) -> void:
	_position_stick()
	knob.position = (joystick.size - knob.size) * 0.5 + move_vector * 53.0
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0:
			toast_label.text = ""

func _position_stick() -> void:
	var screen := get_viewport().get_visible_rect().size
	joystick.position = Vector2(35, screen.y - 204)

func _center() -> Vector2:
	return joystick.position + joystick.size * 0.5

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and event.position.distance_to(_center()) < 115:
			finger = event.index
			_stick(event.position)
		elif not event.pressed and event.index == finger:
			finger = -1
			move_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == finger:
		_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.distance_to(_center()) < 115:
			mouse_stick = true
			_stick(event.position)
		elif not event.pressed and mouse_stick:
			mouse_stick = false
			move_vector = Vector2.ZERO
	elif event is InputEventMouseMotion and mouse_stick:
		_stick(event.position)

func _stick(pos: Vector2) -> void:
	move_vector = ((pos - _center()) / 62.0).limit_length(1.0)

func render_status(hp: float, inventory: Dictionary, xp: int, kills: int, spear: bool, objective: String, helper: String) -> void:
	status.text = "OUTPOST   /   HP %d/100\nXP %d   KILLS %d   •   %s" % [int(ceilf(hp)), xp, kills, "SPEAR" if spear else "BLADE"]
	for key in items:
		items[key].text = str(inventory.get(key, 0))
	quest.text = objective
	hint.text = helper

func toast(message: String) -> void:
	toast_label.text = message
	toast_time = 3.4

func _gather() -> void:
	game.gather()
func _attack() -> void:
	game.attack()
func _craft() -> void:
	game.craft()
