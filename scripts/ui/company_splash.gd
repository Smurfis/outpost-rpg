extends Control
## Five Star Interactive cinematic ident, independent of game/title rendering.
## Tap/click/key to skip. Reduced-motion uses the finished 3D crest.
@export var next_scene_path: String = "res://scenes/ui/title_screen.tscn"
@export var auto_advance: bool = true
@export var hold_seconds: float = 1.8

const UI_PREFS := "user://outpost_ui.cfg"
const STAR_FLIGHT := 6.0
var _elapsed: float = 0.0
var _transition_started: bool = false
var _reduced_motion: bool = false
var _previous_window_aspect: int = -1
@onready var _world: Node3D = $Stage/Viewport/World
@onready var _studio: Label = $StudioName
@onready var _subtitle: Label = $Subtitle

func _ready() -> void:
	_previous_window_aspect = get_window().content_scale_aspect
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var prefs := ConfigFile.new()
	if prefs.load(UI_PREFS) == OK:
		_reduced_motion = bool(prefs.get_value("title", "reduced_motion", false))
	modulate.a = 0.0
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.tween_property(self, "modulate:a", 1.0, 0.35)
	_draw_state()

func _process(delta: float) -> void:
	if _transition_started:
		return
	_elapsed += delta
	_draw_state()
	if auto_advance:
		var total: float = (1.4 if _reduced_motion else STAR_FLIGHT) + hold_seconds
		if _elapsed >= total:
			_go_next()

func _draw_state() -> void:
	var seconds: float = STAR_FLIGHT if _reduced_motion else minf(STAR_FLIGHT, _elapsed)
	_world.call("seek", seconds)
	var alpha: float = 1.0 if _reduced_motion else _smooth(5.0, 6.0, _elapsed)
	_studio.modulate.a = alpha
	_subtitle.modulate.a = alpha

func _smooth(start: float, finish: float, value: float) -> float:
	var t: float = clampf((value - start) / maxf(0.001, finish - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _exit_tree() -> void:
	if _previous_window_aspect >= 0:
		get_window().content_scale_aspect = _previous_window_aspect

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_go_next()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_go_next()
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
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
