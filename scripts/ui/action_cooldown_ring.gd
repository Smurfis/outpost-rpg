extends Control
## Lightweight true radial action cooldown; no texture-sheet fake timers.
## Never accepts touch: the parent Button keeps its full hit area.
var fraction: float = 0.0
var seconds_left: float = 0.0

func set_cooldown(remaining: float, total: float) -> void:
	var next_fraction: float = clampf(remaining / maxf(total, 0.001), 0.0, 1.0)
	if absf(next_fraction - fraction) < 0.005 and (remaining <= 0.0) == (seconds_left <= 0.0):
		return
	fraction = next_fraction
	seconds_left = remaining
	queue_redraw()

func _draw() -> void:
	if fraction <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.39
	var count: int = maxi(4, int(ceilf(fraction * 48.0)))
	var vertices := PackedVector2Array()
	vertices.append(center)
	for i in range(count + 1):
		var angle: float = -PI / 2.0 + TAU * fraction * float(i) / float(count)
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(vertices, Color(0.08, 0.07, 0.09, 0.64))
	draw_arc(center, radius + minf(size.x, size.y) * 0.04,
		-PI / 2.0, -PI / 2.0 + TAU * fraction,
		maxi(6, count), Color("#ffd16e"), maxf(2.0, minf(size.x, size.y) * 0.037), true)
