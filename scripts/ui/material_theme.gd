extends RefCounted
## Outpost UI toolkit: shared surfaces, touch-sized buttons and local Material Symbols.
const ICON_ROOT: String = "res://assets/material_symbols/"
const INK: Color = Color("f2f1e9")
const BACKDROP: Color = Color(0.055, 0.077, 0.100, 0.97)
const SURFACE: Color = Color(0.105, 0.140, 0.160, 0.97)
const ACCENT: Color = Color("e3bb79")
const MIN_TOUCH_HEIGHT: float = 54.0

static func style(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(2 if border.a > 0.01 else 0)
	box.content_margin_left = 15.0
	box.content_margin_right = 15.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box

static func button(label: String, symbol: String, tint: Color = ACCENT) -> Button:
	var result := Button.new()
	result.text = label
	result.custom_minimum_size = Vector2(130.0, MIN_TOUCH_HEIGHT)
	result.add_theme_font_size_override("font_size", 19)
	result.add_theme_color_override("font_color", INK)
	result.add_theme_color_override("font_hover_color", INK)
	result.add_theme_color_override("font_pressed_color", INK)
	result.add_theme_color_override("font_disabled_color", Color("89969b"))
	result.add_theme_stylebox_override("normal", style(SURFACE, tint))
	result.add_theme_stylebox_override("hover", style(SURFACE.lightened(0.07), tint))
	result.add_theme_stylebox_override("pressed", style(SURFACE.darkened(0.15), tint))
	result.add_theme_stylebox_override("disabled", style(SURFACE.darkened(0.17), Color.TRANSPARENT))
	var icon_path: String = ICON_ROOT + symbol + ".svg"
	if ResourceLoader.exists(icon_path):
		result.icon = load(icon_path) as Texture2D
		result.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		result.expand_icon = true
	return result

static func label(text_value: String, font_size: int = 20, tint: Color = INK) -> Label:
	var result := Label.new()
	result.text = text_value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", tint)
	return result
