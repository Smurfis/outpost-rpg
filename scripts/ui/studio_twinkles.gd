extends Control
## Tiny pixel-star glints for the Five Star studio ident.
@export var reduced_motion: bool = false

var _clock: float = 0.0
var _accum: float = 0.0
const STAR_POINTS := [
	Vector2(0.29, 0.23), Vector2(0.69, 0.27), Vector2(0.39, 0.12),
	Vector2(0.62, 0.62), Vector2(0.28, 0.69), Vector2(0.75, 0.51)
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)

func _process(delta: float) -> void:
	if reduced_motion:
		return
	_clock += delta
	_accum += delta
	if _accum > 0.065:
		_accum = 0.0
		queue_redraw()

func _draw() -> void:
	for index in range(STAR_POINTS.size()):
		var point: Vector2 = STAR_POINTS[index] * size
		var flicker: float = 0.5 if reduced_motion else 0.5 + 0.5 * sin(_clock * 3.1 + float(index) * 1.53)
		var ink := Color(1.0, 0.83, 0.47, 0.18 + 0.50 * flicker)
		var reach: float = 6.0 + 4.0 * flicker
		draw_line(point + Vector2(-reach, 0), point + Vector2(reach, 0), ink, 2.0)
		draw_line(point + Vector2(0, -reach), point + Vector2(0, reach), ink, 2.0)
		draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.96, 0.72, 0.25 + 0.70 * flicker))
