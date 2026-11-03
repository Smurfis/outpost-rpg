extends RefCounted
## Shared, resolution-independent Outpost UI skin.
## Uses built-in StyleBoxFlat so the UI imports on Android without font plugins.
const INK := Color("#342416")
const CREAM := Color("#f9e9c2")
const GOLD := Color("#e3b75d")

static func box(kind: String = "parchment") -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var bg := Color("#e8ce97")
	var rim := Color("#80502b")
	var shadow := Color("#21130e")
	var border_width := 3
	var corners := 4
	match kind:
		"frame":
			bg = Color("#503122")
			rim = Color("#d7a45b")
			border_width = 4
			corners = 8
		"parchment":
			bg = Color("#e8d0a2")
			rim = Color("#aa7642")
		"parchment_light":
			bg = Color("#fae8bd")
			rim = Color("#bd8a4c")
		"inset":
			bg = Color("#63402d")
			rim = Color("#a87945")
		"wood":
			bg = Color("#79502d")
			rim = Color("#cc9449")
		"wood_selected":
			bg = Color("#af783a")
			rim = Color("#f7d47d")
		"green":
			bg = Color("#42663a")
			rim = Color("#d9b75d")
		"red":
			bg = Color("#773a31")
			rim = Color("#dfab65")
		"hud":
			bg = Color("#291d1b", 0.90)
			rim = Color("#c39a59")
			border_width = 2
			corners = 7
		"toast":
			bg = Color("#f0d9a5", 0.97)
			rim = Color("#b37b3c")
			border_width = 3
		"transparent":
			bg = Color("#000000", 0.0)
			rim = Color("#000000", 0.0)
			border_width = 0
	s.bg_color = bg
	s.border_color = rim
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(corners)
	s.set_content_margin_all(8)
	s.shadow_color = shadow.darkened(0.15)
	s.shadow_size = 3 if kind != "hud" else 1
	s.anti_aliasing = false
	return s

static func apply_button(button: Button, kind: String = "wood") -> void:
	var normal := box(kind)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.13)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = normal.bg_color.darkened(0.34)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", box("transparent"))
	var text_color := INK if kind.begins_with("parchment") else CREAM
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color.darkened(0.21))
	button.add_theme_font_size_override("font_size", 16)
	button.focus_mode = Control.FOCUS_NONE
