extends Control
## Lightweight, deterministic pixel embers over the two painted campfires.
## No GPUParticles or texture imports; roughly 20 tiny rectangles at 20fps.
@export var reduced_motion: bool = false

var _clock: float = 0.0
var _draw_lag: float = 0.0
var _particles: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seed()
	set_process(true)

func _seed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# Design-space pixel origins: distant campfire on the left + logo's fire.
	var origins: Array[Vector2] = [Vector2(407, 521), Vector2(714, 151)]
	for origin_index in range(origins.size()):
		var amount: int = 12 if origin_index == 0 else 8
		for index in range(amount):
			_particles.append({
				"origin": origins[origin_index],
				"phase": rng.randf(),
				"speed": rng.randf_range(0.26, 0.57),
				"height": rng.randf_range(19.0, 39.0),
				"offset": rng.randf_range(-9.0, 9.0),
				"drift": rng.randf_range(2.5, 6.5),
				"size": rng.randi_range(2, 3),
				"index": index
			})

func _process(delta: float) -> void:
	if reduced_motion:
		return
	_clock += delta
	_draw_lag += delta
	if _draw_lag >= 0.05:
		_draw_lag = 0.0
		queue_redraw()

func _draw() -> void:
	if reduced_motion:
		return
	for particle in _particles:
		var origin: Vector2 = particle["origin"]
		var progress: float = fposmod(float(particle["phase"]) + _clock * float(particle["speed"]), 1.0)
		var x: float = origin.x + float(particle["offset"]) + sin(_clock * 1.15 + float(particle["index"])) * float(particle["drift"]) * progress
		var y: float = origin.y - progress * float(particle["height"])
		var fade: float = 0.72 * (1.0 - progress) * minf(1.0, progress * 8.0)
		var color := Color(1.0, 0.77, 0.32, fade)
		if int(particle["index"]) % 3 == 0:
			color = Color(1.0, 0.52, 0.14, fade)
		var side: float = float(particle["size"])
		draw_rect(Rect2(roundf(x), roundf(y), side, side), color)
