@tool
extends Button
## Outpost's re-usable textured, touch-friendly title menu button.
## Transparent PNG artwork takes priority over independent SVG fallback assets.
@export_enum("play", "continue", "settings", "quit") var button_kind: String = "play"
@export var button_caption: String = ""

const ASSET_BASE := "res://assets/ui/title/"
const CAPTIONS := {"play": "Play", "continue": "Continue", "settings": "Settings", "quit": "Quit"}
# Title controls must use pre-masked RGBA textures, not an item shader.
# Button StyleBoxTexture draw calls can otherwise expose a WHITE untextured quad.
var _base_style: StyleBoxTexture
var _highlight_style: StyleBoxTexture

var _pointer_hovered: bool = false
var _last_disabled: bool = false
var _spark_elapsed: float = 0.0
@export var reduced_motion: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(430, 76)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_appearance()
	focus_entered.connect(_refresh_highlight)
	focus_exited.connect(_refresh_highlight)
	mouse_entered.connect(_on_pointer_entered)
	mouse_exited.connect(_on_pointer_exited)
	button_down.connect(_refresh_highlight)
	button_up.connect(_refresh_highlight)
	set_process(true)

func _apply_appearance() -> void:
	var kind: String = button_kind if CAPTIONS.has(button_kind) else "play"
	var baked_image: Texture2D
	var approved_path: String = ASSET_BASE + "btn_" + kind + ".png"
	if ResourceLoader.exists(approved_path):
		baked_image = load(approved_path) as Texture2D
	if baked_image != null:
		baked_image = _remove_screenshot_matte(baked_image, kind)
		# The original PNG contains screenshot scenery and Play starbursts
		# outside the plaque. Pixel-alpha clip the plaque as REAL transparent
		# runtime art, so nothing remains baked when selection moves.
		# The approved PNG already includes its own hand-lettered caption/icon.
		# Keep this a true accessible Button, but do not print a second label.
		text = ""
		icon = null
		tooltip_text = CAPTIONS[kind]
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Never draw a white fallback quad over PNG button art. Alpha is
		# permanently baked into each state before it reaches the GPU.
		material = null
		var selected_image: Texture2D = _make_highlight_texture(baked_image, kind)
		_base_style = StyleBoxTexture.new()
		_base_style.texture = baked_image
		_highlight_style = StyleBoxTexture.new()
		_highlight_style.texture = selected_image
		add_theme_stylebox_override("normal", _base_style)
		add_theme_stylebox_override("hover", _highlight_style)
		add_theme_stylebox_override("pressed", _highlight_style)
		var disabled_style := StyleBoxTexture.new()
		disabled_style.texture = baked_image
		disabled_style.modulate_color = Color(0.72, 0.72, 0.72, 0.92)
		add_theme_stylebox_override("disabled", disabled_style)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_update_active_art()
		return
	text = button_caption if not button_caption.is_empty() else CAPTIONS[kind]
	var picture: Texture2D = _find_art("icon_", kind, "icons")
	if picture != null:
		icon = picture
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 32)
	add_theme_constant_override("h_separation", 22)
	add_theme_color_override("font_color", Color("fff1cd") if kind != "quit" else Color("482b24"))
	add_theme_color_override("font_hover_color", Color("ffffff"))
	add_theme_color_override("font_pressed_color", Color("ffefb9"))
	add_theme_color_override("font_disabled_color", Color("b3a79d"))
	add_theme_color_override("font_outline_color", Color("3b2021"))
	add_theme_constant_override("outline_size", 3)
	var image: Texture2D = _find_art("btn_", kind, "buttons")
	if image == null:
		return
	_set_plaque("normal", image, Color.WHITE)
	_set_plaque("hover", image, Color("fff5cd"))
	_set_plaque("pressed", image, Color("ceb59b"))
	_set_plaque("disabled", image, Color(0.6, 0.6, 0.6, 0.85))
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("ffdf7a")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(16)
	add_theme_stylebox_override("focus", focus_style)

## Gold glints are drawn OUTSIDE the art plaque, so baked text/icons remain sharp.
## Focus follows gamepad/keyboard and a finger tap; hover follows the mouse.
func is_title_highlighted() -> bool:
	return not disabled and (has_focus() or _pointer_hovered)

func _on_pointer_entered() -> void:
	_pointer_hovered = true
	if not disabled:
		grab_focus()
	_refresh_highlight()

func _on_pointer_exited() -> void:
	_pointer_hovered = false
	_refresh_highlight()

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			grab_focus()
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			grab_focus()

func _refresh_highlight() -> void:
	_update_active_art()
	queue_redraw()

func _update_active_art() -> void:
	# Focus (keyboard/gamepad), hover and touch all select a pre-rendered
	# transparent texture; absolutely no translucent white focus rectangle.
	if _base_style != null and _highlight_style != null:
		add_theme_stylebox_override("normal", _highlight_style if (is_title_highlighted() or is_pressed()) else _base_style)

func _process(delta: float) -> void:
	if disabled != _last_disabled:
		_last_disabled = disabled
		_update_active_art()
	if reduced_motion or not is_title_highlighted():
		return
	_spark_elapsed = fposmod(_spark_elapsed + delta, TAU)
	queue_redraw()

func _draw() -> void:
	# Rays and soft illumination are now entirely separate title-screen
	# layers that follow focus. Never draw a second fixed border over a PNG.
	pass

static func _remove_screenshot_matte(source: Texture2D, kind: String) -> Texture2D:
	var bitmap: Image = source.get_image()
	if bitmap == null:
		return source
	bitmap.convert(Image.FORMAT_RGBA8)
	# Vertices are in the original PNG pixel-space (never resize at import).
	# They hug the real cutouts rather than the opaque rectangular screenshot.
	var contour := PackedVector2Array()
	match kind:
		"play":
			contour = PackedVector2Array([Vector2(44, 27), Vector2(55, 13), Vector2(76, 6), Vector2(99, 4), Vector2(117, 10), Vector2(304, 10), Vector2(327, 2), Vector2(357, 8), Vector2(377, 22), Vector2(381, 67), Vector2(365, 82), Vector2(341, 90), Vector2(76, 91), Vector2(53, 80), Vector2(43, 60)])
		"continue":
			contour = PackedVector2Array([Vector2(12, 28), Vector2(32, 12), Vector2(54, 7), Vector2(308, 7), Vector2(334, 15), Vector2(351, 30), Vector2(350, 51), Vector2(327, 69), Vector2(41, 73), Vector2(11, 51)])
		"settings":
			contour = PackedVector2Array([Vector2(8, 33), Vector2(31, 11), Vector2(54, 5), Vector2(285, 5), Vector2(311, 17), Vector2(329, 39), Vector2(319, 58), Vector2(291, 71), Vector2(41, 71), Vector2(7, 55)])
		"quit":
			contour = PackedVector2Array([Vector2(4, 21), Vector2(21, 8), Vector2(265, 8), Vector2(287, 20), Vector2(288, 52), Vector2(268, 70), Vector2(21, 72), Vector2(4, 60)])
	if contour.is_empty():
		return source
	# The original PNG includes a few pixels of its old dark screenshot
	# matte INSIDE the outline. A hard polygon cut leaves a visible grey halo.
	# Feather only the final 3.5 px inward; never shrink or recolour the real
	# button text, icons or centre art. This is intentionally a tiny title pass.
	for y in range(bitmap.get_height()):
		for x in range(bitmap.get_width()):
			var pixel := Vector2(float(x) + 0.5, float(y) + 0.5)
			var px: Color = bitmap.get_pixel(x, y)
			if not Geometry2D.is_point_in_polygon(pixel, contour):
				px.a = 0.0
			else:
				var nearest: float = 100.0
				for i in range(contour.size()):
					var endpoint: Vector2 = contour[(i + 1) % contour.size()]
					var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pixel, contour[i], endpoint)
					nearest = minf(nearest, pixel.distance_to(closest))
				if nearest < 3.5:
					px.a *= smoothstep(0.0, 3.5, nearest)
			bitmap.set_pixel(x, y, px)
	return ImageTexture.create_from_image(bitmap)

static func _make_highlight_texture(source: Texture2D, kind: String) -> Texture2D:
	var image: Image = source.get_image()
	if image == null:
		return source
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < 0.01:
				continue
			var luminance: float = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
			if kind == "quit":
				# The ink of the power symbol and label turns WHITE on hover and
				# press, but never bleach the gold/wood outside the glyph region.
				var u: float = float(x) / float(image.get_width())
				var v: float = float(y) / float(image.get_height())
				if u > 0.16 and u < 0.81 and v > 0.24 and v < 0.79 and luminance < 0.78:
					pixel.r = 1.0
					pixel.g = 1.0
					pixel.b = 1.0
			else:
				# Warm selection accent, not a second rectangular light layer.
				if luminance > 0.13 and luminance < 0.72:
					pixel.r = minf(1.0, pixel.r * 1.18 + 0.045)
					pixel.g = minf(1.0, pixel.g * 1.10 + 0.025)
					pixel.b = minf(1.0, pixel.b * 0.94)
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)

func _set_plaque(state: String, picture: Texture2D, tint: Color) -> void:
	var style := StyleBoxTexture.new()
	style.texture = picture
	style.texture_margin_left = 25.0
	style.texture_margin_right = 25.0
	style.texture_margin_top = 20.0
	style.texture_margin_bottom = 20.0
	style.content_margin_left = 85.0
	style.content_margin_right = 45.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.modulate_color = tint
	add_theme_stylebox_override(state, style)

func _find_art(prefix: String, kind: String, category: String) -> Texture2D:
	# Import e.g. res://assets/ui/title/btn_play.png, icon_play.png.
	# Keep the SVG placeholders functional until every PNG passes visual review.
	var candidates: Array[String] = [
		ASSET_BASE + prefix + kind + ".png",
		ASSET_BASE + category + "/" + kind + ".png",
		ASSET_BASE + category + "/" + kind + ".svg"
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var asset: Texture2D = load(path) as Texture2D
			if asset != null:
				return asset
	return null
