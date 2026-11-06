extends Control
## Decorative radial level jewel. Unlike the XP meter, this is not a
## loading indicator: it is tied to actual character-level progression.
const ART: Texture2D = preload("res://assets/ui/icons/level_radial_frame.svg")
var fill_amount: float = 0.0
var level_number: int = 1
var label: Label

func _ready() -> void:
	name = "RadialLevelFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label = Label.new()
	label.name = "LevelNumber"
	label.text = "1"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color("#fff0cf"))
	label.add_theme_color_override("font_outline_color", Color("#29202a"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func update_level(next_level: int, fraction: float) -> void:
	level_number = maxi(1, next_level)
	fill_amount = clampf(fraction, 0.0, 1.0)
	if label != null:
		label.text = str(level_number)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.352
	var start: float = -PI * 0.5
	draw_arc(center, radius, start, start + TAU, 88, Color("#32203d"), 8.0, true)
	if fill_amount > 0.0:
		draw_arc(center, radius, start, start + TAU * fill_amount, 88, Color("#bb83f1"), 7.0, true)
	draw_texture_rect(ART, Rect2(Vector2.ZERO, size), false)
