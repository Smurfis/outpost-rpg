extends Control
## Overlay graduations, not a second XP bar: the parent ProgressBar owns
## the actual current/max value and these lines remain purely decorative.
const SEGMENTS: int = 20

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for i in range(1, SEGMENTS):
		var x: float = roundf(size.x * float(i) / float(SEGMENTS))
		var is_major: bool = i % 5 == 0
		draw_line(Vector2(x, 1.0), Vector2(x, size.y - 1.0),
				Color(0.16, 0.08, 0.22, 0.36 if is_major else 0.22), 1.0, false)
		if is_major:
			draw_line(Vector2(x + 1.0, 2.0), Vector2(x + 1.0, size.y - 2.0),
					Color(0.98, 0.83, 0.60, 0.30), 1.0, false)
