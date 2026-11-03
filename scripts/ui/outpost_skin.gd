extends RefCounted
## Outpost's original pixel-fantasy UI textures; one visual language shared
## with the title screen. Nine-slice protects panel corners at phone sizes.
## Safe fallbacks keep the game usable if an asset import temporarily fails.

const INK := Color("#342416")
const CREAM := Color("#f9e9c2")
const GOLD := Color("#e3b75d")

const FRAME_ROOT: String = "res://assets/ui/frames/"
const BUTTON_ROOT: String = "res://assets/ui/buttons/"

static func _texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func _nine(path: String, horizontal_margin: float, vertical_margin: float, content_padding: float = 9.0) -> StyleBoxTexture:
	var art: Texture2D = _texture(path)
	if art == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = art
	style.texture_margin_left = horizontal_margin
	style.texture_margin_right = horizontal_margin
	style.texture_margin_top = vertical_margin
	style.texture_margin_bottom = vertical_margin
	style.set_content_margin_all(content_padding)
	return style

static func flat(kind: String = "parchment") -> StyleBoxFlat:
	# Explicitly keep a flat alternative for round joysticks and health bars,
	# which cannot use nine-sliced rectangular panel artwork.
	var style := StyleBoxFlat.new()
	var bg := Color("#e8ce97")
	var border := Color("#80502b")
	var border_width: int = 3
	match kind:
		"frame":
			bg = Color("#503122")
			border = Color("#d7a45b")
			border_width = 4
		"parchment":
			bg = Color("#e8d0a2")
			border = Color("#aa7642")
		"parchment_light":
			bg = Color("#fae8bd")
			border = Color("#bd8a4c")
		"inset", "item":
			bg = Color("#63402d")
			border = Color("#a87945")
		"wood", "hud":
			bg = Color("#38271d")
			border = Color("#cc9449")
		"wood_selected":
			bg = Color("#af783a")
			border = Color("#f7d47d")
		"green":
			bg = Color("#42663a")
			border = Color("#d9b75d")
		"red":
			bg = Color("#773a31")
			border = Color("#dfab65")
		"toast":
			bg = Color("#f0d9a5")
			border = Color("#b37b3c")
		"transparent":
			bg = Color(0.0, 0.0, 0.0, 0.0)
			border = Color(0.0, 0.0, 0.0, 0.0)
			border_width = 0
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(7.0)
	style.anti_aliasing = false
	return style

static func box(kind: String = "parchment") -> StyleBox:
	if kind == "transparent":
		return flat(kind)
	var file: String = "parchment_panel.png"
	match kind:
		"frame", "wood", "hud":
			file = "dark_wood_panel.png"
		"parchment", "parchment_light":
			file = "parchment_panel.png"
		"wood_selected":
			file = "transparent_wood_frame.png"
		"inset", "item":
			file = "item_card.png"
		"toast":
			file = "toast_card.png"
		"green":
			return _button_texture("green", "normal")
		"red":
			return _button_texture("red", "normal")
	var style: StyleBoxTexture = _nine(FRAME_ROOT + file, 16.0, 16.0, 9.0)
	if style == null:
		return flat(kind)
	return style

static func _button_texture(kind: String, state: String) -> StyleBox:
	var name: String = "wood_normal.png"
	if kind == "red":
		name = "red_normal.png"
	elif kind == "green":
		name = "green_normal.png"
	elif state == "pressed":
		name = "wood_pressed.png"
	var style: StyleBoxTexture = _nine(BUTTON_ROOT + name, 18.0, 12.0, 4.0)
	if style == null:
		return flat(kind)
	if state == "hover":
		style.modulate_color = Color(1.0, 0.98, 0.83, 1.0)
	elif state == "pressed" and kind != "wood":
		style.modulate_color = Color(0.83, 0.81, 0.74, 1.0)
	elif state == "disabled":
		style.modulate_color = Color(0.54, 0.52, 0.49, 0.78)
	return style

static func apply_button(button: Button, kind: String = "wood") -> void:
	var textured_kind: String = "wood"
	if kind == "green":
		textured_kind = "green"
	elif kind == "red":
		textured_kind = "red"
	if kind.begins_with("parchment"):
		button.add_theme_stylebox_override("normal", box("parchment"))
		button.add_theme_stylebox_override("hover", box("parchment_light"))
		var pressed: StyleBox = box("parchment")
		if pressed is StyleBoxTexture:
			pressed.modulate_color = Color(0.86, 0.82, 0.73)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("disabled", _button_texture("wood", "disabled"))
	else:
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, _button_texture(textured_kind, state))
	button.add_theme_stylebox_override("focus", flat("transparent"))
	var text_color: Color = INK if kind.begins_with("parchment") else CREAM
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color.darkened(0.21))
	button.add_theme_font_size_override("font_size", 16)
	button.focus_mode = Control.FOCUS_NONE
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
