extends Control
## Short Five Star Interactive ident, independent of title and world loading.
@export var next_scene_path: String = "res://scenes/ui/title_screen.tscn"
@export var auto_advance: bool = true
@export var hold_seconds: float = 2.0

const STUDIO_LOGO := "res://assets/ui/title/five_star_logo.png"
const STUDIO_TWINKLES := preload("res://scripts/ui/studio_twinkles.gd")
const UI_PREFS := "user://outpost_ui.cfg"
# The ident has a fixed 16:9 design canvas even when Android expands to 20:9.
# A 512x320 mark must never inherit a percentage-based stretched viewport box.
const IDENT_DESIGN := Vector2(1280.0, 720.0)
var _full_logo_art: bool = false
var _transition_started: bool = false
var _reduced_motion: bool = false

func _ready() -> void:
	var prefs := ConfigFile.new()
	if prefs.load(UI_PREFS) == OK:
		_reduced_motion = bool(prefs.get_value("title", "reduced_motion", false))
	var emblem: TextureRect = get_node_or_null("StarMark") as TextureRect
	if emblem != null:
		emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Preserve the source ratio for both the 512x320 SVG and any future PNG.
		if ResourceLoader.exists(STUDIO_LOGO):
			var final_art: Texture2D = load(STUDIO_LOGO) as Texture2D
			if final_art != null:
				emblem.texture = final_art
				_full_logo_art = true
				get_node("StudioName").visible = false
				get_node("Subtitle").visible = false
	_layout_ident()
	resized.connect(_layout_ident)
	var twinkles: Control = STUDIO_TWINKLES.new()
	twinkles.name = "StarTwinkles"
	add_child(twinkles)
	twinkles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	twinkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	twinkles.set("reduced_motion", _reduced_motion)
	# Short fade and a tiny shimmer rather than a long unskippable logo.
	modulate.a = 0.0
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.tween_property(self, "modulate:a", 1.0, 0.45)
	if auto_advance:
		await get_tree().create_timer(maxf(0.5, hold_seconds)).timeout
		_go_next()

func _layout_ident() -> void:
	# Center a proportional 1280x720 design inside the actual phone viewport.
	# Ultrawide extra width becomes safe margin instead of inflating the star.
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor: float = minf(size.x / IDENT_DESIGN.x, size.y / IDENT_DESIGN.y)
	var origin: Vector2 = (size - IDENT_DESIGN * scale_factor) * 0.5
	var emblem: TextureRect = get_node_or_null("StarMark") as TextureRect
	if emblem != null:
		if _full_logo_art:
			# Full stacked studio graphic: contain it without changing its texture ratio.
			_place_ident(emblem, origin + Vector2(285, 100) * scale_factor, Vector2(710, 490) * scale_factor)
		else:
			# Original SVG has an exact 8:5 width-to-height ratio.
			_place_ident(emblem, origin + Vector2(384, 65) * scale_factor, Vector2(512, 320) * scale_factor)
	var studio: Label = get_node_or_null("StudioName") as Label
	if studio != null:
		_place_ident(studio, origin + Vector2(230, 391) * scale_factor, Vector2(820, 95) * scale_factor)
		studio.add_theme_font_size_override("font_size", maxi(16, roundi(65.0 * scale_factor)))
	var subtitle: Label = get_node_or_null("Subtitle") as Label
	if subtitle != null:
		_place_ident(subtitle, origin + Vector2(230, 496) * scale_factor, Vector2(820, 58) * scale_factor)
		subtitle.add_theme_font_size_override("font_size", maxi(12, roundi(31.0 * scale_factor)))
	var hint: Label = get_node_or_null("Hint") as Label
	if hint != null:
		_place_ident(hint, origin + Vector2(235, 647) * scale_factor, Vector2(810, 38) * scale_factor)
		hint.add_theme_font_size_override("font_size", maxi(12, roundi(20.0 * scale_factor)))

func _place_ident(node: Control, at: Vector2, extent: Vector2) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	node.custom_minimum_size = Vector2.ZERO
	node.position = at
	node.size = extent

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			_go_next()
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_go_next()
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo:
			_go_next()

func _go_next() -> void:
	if _transition_started or not is_inside_tree():
		return
	_transition_started = true
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.tween_property(self, "modulate:a", 0.0, 0.28)
	await fade.finished
	if is_inside_tree():
		get_tree().change_scene_to_file(next_scene_path)
