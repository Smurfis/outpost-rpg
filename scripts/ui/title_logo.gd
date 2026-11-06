@tool
extends Control
## Standalone, reusable Outpost title logo.
## Drop the approved PNG at res://assets/ui/title/outpost_logo.png to replace
## the lightweight painted fallback automatically. No game-scene dependency.

const LOGO_PATH := "res://assets/ui/title/outpost_logo.png"
const VECTOR_PATH := "res://assets/ui/title/outpost_logo_vector.svg"
const DESIGN_SIZE := Vector2(800.0, 440.0)

var _logo_texture: Texture2D
var _wordmark: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(LOGO_PATH):
		_logo_texture = load(LOGO_PATH) as Texture2D
	# A committed transparent vector logo always ships in the APK. It intentionally
	# contains NO baked-in text, so the editable Label remains on top.
	if _logo_texture == null and ResourceLoader.exists(VECTOR_PATH):
		_logo_texture = load(VECTOR_PATH) as Texture2D
	if not ResourceLoader.exists(LOGO_PATH):
		_wordmark = Label.new()
		_wordmark.name = "FallbackWordmark"
		_wordmark.text = "Outpost"
		_wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wordmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_wordmark)
	_update_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		queue_redraw()

func _update_layout() -> void:
	if _wordmark == null:
		return
	var stretch := Vector2(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_wordmark.position = Vector2(70.0, 284.0) * stretch
	_wordmark.size = Vector2(660.0, 132.0) * stretch
	var settings := LabelSettings.new()
	settings.font_size = maxi(12, roundi(117.0 * minf(stretch.x, stretch.y)))
	settings.font_color = Color("f6d6a4")
	settings.outline_size = maxi(2, roundi(11.0 * minf(stretch.x, stretch.y)))
	settings.outline_color = Color("33201e")
	settings.shadow_color = Color("1f1415")
	settings.shadow_offset = Vector2i(roundi(3.0 * stretch.x), roundi(5.0 * stretch.y))
	_wordmark.label_settings = settings

func _draw() -> void:
	if _logo_texture != null:
		var image_size := _logo_texture.get_size()
		var fit := minf(size.x / image_size.x, size.y / image_size.y)
		var rect_size := image_size * fit
		draw_texture_rect(_logo_texture, Rect2((size - rect_size) * 0.5, rect_size), false)
		return

	# Editor-friendly placeholder artwork; the approved PNG is the final art.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y))
	# Floating stone and woodland sign behind the wordmark.
	_polygon([Vector2(80, 310), Vector2(720, 310), Vector2(665, 437), Vector2(165, 437)], Color("57515a"))
	_polygon([Vector2(102, 316), Vector2(688, 316), Vector2(640, 417), Vector2(177, 417)], Color("79747b"))
	draw_rect(Rect2(40, 300, 720, 122), Color("392623"), true)
	draw_rect(Rect2(52, 307, 696, 105), Color("795039"), true)
	draw_rect(Rect2(52, 307, 696, 105), Color("bf8052"), false, 8.0)
	draw_line(Vector2(60, 326), Vector2(740, 326), Color("ab7951"), 5.0)
	draw_line(Vector2(60, 393), Vector2(740, 393), Color("493128"), 4.0)
	# Grass-and-stone crest above the sign.
	_polygon([Vector2(80, 290), Vector2(160, 267), Vector2(658, 267), Vector2(730, 293), Vector2(730, 308), Vector2(80, 308)], Color("447642"))
	_polygon([Vector2(80, 281), Vector2(183, 257), Vector2(625, 257), Vector2(730, 280), Vector2(730, 291), Vector2(80, 291)], Color("7ead47"))
	# Tent silhouette, cream canvas, entrance and patched flap.
	_polygon([Vector2(205, 272), Vector2(407, 50), Vector2(603, 272)], Color("53372c"))
	_polygon([Vector2(221, 268), Vector2(407, 70), Vector2(585, 268)], Color("efcf96"))
	_polygon([Vector2(409, 72), Vector2(585, 268), Vector2(472, 266)], Color("c7925a"))
	_polygon([Vector2(343, 265), Vector2(407, 111), Vector2(474, 265)], Color("513321"))
	_polygon([Vector2(395, 144), Vector2(343, 265), Vector2(406, 265)], Color("7b4b2a"))
	draw_line(Vector2(408, 58), Vector2(408, 272), Color("b07642"), 7.0)
	_polygon([Vector2(279, 179), Vector2(341, 160), Vector2(354, 205), Vector2(293, 221)], Color("ae6655"))
	# Crossed poles and bindings.
	draw_line(Vector2(380, 54), Vector2(433, 17), Color("6d442f"), 12.0)
	draw_line(Vector2(381, 17), Vector2(431, 53), Color("99613b"), 12.0)
	draw_line(Vector2(393, 42), Vector2(422, 42), Color("e4b872"), 6.0)
	# Hanging lantern.
	draw_line(Vector2(409, 50), Vector2(409, 90), Color("3e2b28"), 5.0)
	draw_rect(Rect2(394, 87, 30, 42), Color("342b25"), true)
	draw_rect(Rect2(399, 93, 20, 28), Color("ffe18a"), true)
	draw_line(Vector2(399, 121), Vector2(419, 121), Color("b46f33"), 4.0)
	# Left-hand flag and campfire on the right.
	draw_line(Vector2(184, 58), Vector2(184, 272), Color("77492f"), 15.0)
	_polygon([Vector2(191, 67), Vector2(315, 76), Vector2(290, 133), Vector2(191, 120)], Color("923c3d"))
	_polyline([Vector2(224, 103), Vector2(244, 84), Vector2(262, 107), Vector2(272, 96), Vector2(288, 111)], Color("f4d7aa"), 6.0)
	_polygon([Vector2(594, 277), Vector2(630, 193), Vector2(651, 279)], Color("f4a33f"))
	_polygon([Vector2(608, 276), Vector2(631, 219), Vector2(644, 276)], Color("ffdb70"))
	draw_circle(Vector2(603, 281), 17.0, Color("6a6368"))
	draw_circle(Vector2(655, 281), 18.0, Color("6a6368"))
	# Small compass pennant, distinct from the main wordmark.
	_polygon([Vector2(359, 420), Vector2(441, 420), Vector2(431, 439), Vector2(400, 430), Vector2(369, 439)], Color("8d3b38"))

func _polygon(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _polyline(points: Array, color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)
