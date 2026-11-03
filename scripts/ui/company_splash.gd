extends Control
## First-party studio ident. Scene is independent from gameplay and mobile safe.
@export var next_scene_path: String = "res://scenes/ui/title_screen.tscn"
@export var auto_advance: bool = true
@export var hold_seconds: float = 2.1

var _transition_started := false

const STUDIO_LOGO := "res://assets/ui/title/five_star_logo.png"

func _ready() -> void:
	# Prefer finalized transparent artwork; otherwise the editor-safe mark/labels display.
	if ResourceLoader.exists(STUDIO_LOGO):
		var emblem: TextureRect = get_node("StarMark") as TextureRect
		emblem.texture = load(STUDIO_LOGO) as Texture2D
		emblem.anchor_left = 0.24
		emblem.anchor_top = 0.11
		emblem.anchor_right = 0.76
		emblem.anchor_bottom = 0.86
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		get_node("StudioName").visible = false
		get_node("Subtitle").visible = false
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.5)
	if auto_advance:
		await get_tree().create_timer(maxf(0.5, hold_seconds)).timeout
		_go_next()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_go_next()
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.pressed:
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
	fade.tween_property(self, "modulate:a", 0.0, 0.30)
	await fade.finished
	if is_inside_tree():
		get_tree().change_scene_to_file(next_scene_path)
