extends Control
## Short Five Star Interactive ident, independent of title and world loading.
@export var next_scene_path: String = "res://scenes/ui/title_screen.tscn"
@export var auto_advance: bool = true
@export var hold_seconds: float = 2.0

const STUDIO_LOGO := "res://assets/ui/title/five_star_logo.png"
const STUDIO_TWINKLES := preload("res://scripts/ui/studio_twinkles.gd")
const UI_PREFS := "user://outpost_ui.cfg"
var _transition_started: bool = false
var _reduced_motion: bool = false

func _ready() -> void:
	var prefs := ConfigFile.new()
	if prefs.load(UI_PREFS) == OK:
		_reduced_motion = bool(prefs.get_value("title", "reduced_motion", false))
	var emblem: TextureRect = get_node_or_null("StarMark") as TextureRect
	if emblem != null:
		emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Keep the SVG art as the no-download fallback. Use final art if added.
		if ResourceLoader.exists(STUDIO_LOGO):
			emblem.texture = load(STUDIO_LOGO) as Texture2D
			emblem.anchor_left = 0.24
			emblem.anchor_top = 0.11
			emblem.anchor_right = 0.76
			emblem.anchor_bottom = 0.86
			emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			get_node("StudioName").visible = false
			get_node("Subtitle").visible = false
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
