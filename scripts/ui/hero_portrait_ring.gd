extends Control
## Independent circular hero portrait ornament. Red health arc uses actual HP,
## never a decorative fake value; gold/steel accents mimic modern RPG portraits.

var health_fraction: float = 1.0

func _ready() -> void:
	name = "HeroPortraitRing"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	queue_redraw()

func update_health(value: float) -> void:
	var fraction: float = clampf(value, 0.0, 1.0)
	if not is_equal_approx(fraction, health_fraction):
		health_fraction = fraction
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5
	if radius < 5.0:
		return
	var center: Vector2 = size * 0.5
	var start: float = -PI * 0.5
	var rim: float = radius - 2.0
	# A true circle is the ONLY backing, not a tinted box around HP/name.
	draw_circle(center, radius - 3.0, Color(0.055, 0.044, 0.061, 0.18))
	draw_arc(center, rim, 0.0, TAU, 96, Color("#301c26"), 6.0, true)
	draw_arc(center, rim - 1.0, 0.0, TAU, 96, Color("#dfc28a"), 2.6, true)
	draw_arc(center, rim - 4.5, 0.0, TAU, 96, Color(0.30, 0.08, 0.11, 0.82), 4.0, true)
	if health_fraction > 0.001:
		draw_arc(center, rim - 4.5, start, start + TAU * health_fraction, 96, Color("#f05c56"), 4.0, true)
	# Tiny silver highlights at compass points help the ring read at phone size.
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(center + direction * (rim - 2.5), center + direction * (rim + 1.1), Color("#fff3d6"), 2.0, true)
