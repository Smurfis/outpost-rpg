@tool
extends Button
## Outpost's re-usable textured, touch-friendly title menu button.
## Transparent PNG artwork takes priority over independent SVG fallback assets.
@export_enum("play", "continue", "settings", "quit") var button_kind: String = "play"
@export var button_caption: String = ""

const ASSET_BASE := "res://assets/ui/title/"
const CAPTIONS := {"play": "Play", "continue": "Continue", "settings": "Settings", "quit": "Quit"}
var _pointer_hovered: bool = false
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
		# The approved PNG already includes its own hand-lettered caption/icon.
		# Keep this a true accessible Button, but do not print a second label.
		text = ""
		icon = null
		tooltip_text = CAPTIONS[kind]
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for state in ["normal", "hover", "pressed", "disabled"]:
			var art_style := StyleBoxTexture.new()
			art_style.texture = baked_image
			art_style.modulate_color = Color.WHITE
			if state == "hover":
				art_style.modulate_color = Color("fff5db")
			elif state == "pressed":
				art_style.modulate_color = Color("d4c3aa")
			elif state == "disabled":
				art_style.modulate_color = Color(0.72, 0.72, 0.72, 0.92)
			add_theme_stylebox_override(state, art_style)
		var art_focus := StyleBoxFlat.new()
		art_focus.bg_color = Color.TRANSPARENT
		art_focus.border_color = Color(0.98, 0.77, 0.37, 0.88)
		art_focus.set_border_width_all(3)
		art_focus.set_corner_radius_all(18)
		add_theme_stylebox_override("focus", art_focus)
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
	add_theme_color_override("font_hover_color", Color("ffffff") if kind != "quit" else Color("482b24"))
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
	queue_redraw()

func _process(delta: float) -> void:
	if reduced_motion or not is_title_highlighted():
		return
	_spark_elapsed = fposmod(_spark_elapsed + delta, TAU)
	queue_redraw()

func _draw() -> void:
	if not is_title_highlighted():
		return
	var alpha: float = 0.92 if reduced_motion else 0.84 + 0.14 * sin(_spark_elapsed * 2.0)
	var gold := Color(1.0, 0.77, 0.26, alpha)
	var pale := Color(1.0, 0.94, 0.68, alpha)
	var mid: float = roundf(size.y * 0.5)
	for side in [-1, 1]:
		var x: float = -12.0 if side == -1 else size.x + 12.0
		draw_line(Vector2(x, mid - 16.0), Vector2(x, mid - 6.0), gold, 3.0)
		draw_line(Vector2(x, mid + 6.0), Vector2(x, mid + 16.0), gold, 3.0)
		draw_line(Vector2(x - 15.0, mid), Vector2(x - 5.0, mid), pale, 3.0)
		draw_line(Vector2(x + 5.0, mid), Vector2(x + 15.0, mid), pale, 3.0)
		draw_rect(Rect2(Vector2(x - 3, mid - 3), Vector2(6, 6)), pale)

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
