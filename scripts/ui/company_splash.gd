extends Control
## First-party studio ident. Scene is independent from gameplay and mobile safe.
@export var next_scene_path: String = "res://scenes/ui/title_screen.tscn"
@export var auto_advance: bool = true
@export var hold_seconds: float = 2.1

var _transition_started := false

func _ready() -> void:
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
