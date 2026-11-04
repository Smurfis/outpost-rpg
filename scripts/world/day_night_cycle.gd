extends Node
## Lightweight deterministic outdoor day/night atmosphere for Android.
## One directional light + environment colour; optional shadowless torch.
signal night_started
@export_range(60.0, 1800.0, 10.0) var day_length_seconds: float = 480.0
var phase: float = 0.38 # Morning by default; 0 midnight, 0.5 noon.
var environment: Environment
var sunlight: DirectionalLight3D
var sky_material: ProceduralSkyMaterial
var _tick: float = 0.0

func configure(env: Environment, light: DirectionalLight3D, sky: ProceduralSkyMaterial) -> void:
	environment = env
	sunlight = light
	sky_material = sky
	_apply_light()

func is_night() -> bool:
	return phase >= 0.76 or phase < 0.24

func clock_text() -> String:
	var mins: int = floori(phase * 1440.0) % 1440
	return "%02d:%02d" % [mins / 60, mins % 60]

func set_phase(value: float) -> void:
	var was_night: bool = is_night()
	phase = fposmod(value, 1.0)
	_apply_light()
	if not was_night and is_night():
		night_started.emit()

func _process(delta: float) -> void:
	if environment == null or sunlight == null or day_length_seconds <= 0.0:
		return
	var was_night: bool = is_night()
	phase = fposmod(phase + delta / day_length_seconds, 1.0)
	if not was_night and is_night():
		night_started.emit()
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		_apply_light()

func _apply_light() -> void:
	if environment == null or sunlight == null:
		return
	# Sun high at 0.50, below horizon at 0.0. Retain readable starlight
	# rather than making Android screens completely black.
	var altitude: float = -cos(phase * TAU)
	var daylight: float = smoothstep(-0.18, 0.74, altitude)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8496bd").lerp(Color("fff1d8"), daylight)
	environment.ambient_light_energy = lerpf(0.20, 0.94, daylight)
	sunlight.light_energy = lerpf(0.04, 1.45, daylight)
	sunlight.light_color = Color("aab9e7").lerp(Color("ffdfa9"), daylight)
	sunlight.rotation_degrees = Vector3(-18.0 - phase * 320.0, -30.0, 0.0)
	if sky_material != null:
		sky_material.sky_top_color = Color("101a31").lerp(Color("5d81b7"), daylight)
		sky_material.sky_horizon_color = Color("293451").lerp(Color("efb49b"), daylight)
		sky_material.ground_horizon_color = Color("34384d").lerp(Color("d9b8a6"), daylight)
		sky_material.ground_bottom_color = Color("1d2637").lerp(Color("66677f"), daylight)
