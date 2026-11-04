extends Control
## Tiny readable map: topological room graph, treasures, boss/stairs, live player dot.
var instance: Node3D
var last_room: int = 0
var map_visible: bool = false

func setup(dungeon: Node3D) -> void:
	instance = dungeon
	map_visible = dungeon != null
	visible = map_visible
	queue_redraw()

func _process(_delta: float) -> void:
	if not map_visible or instance == null or not is_instance_valid(instance):
		return
	var current: int = nearest_room()
	if current != last_room:
		last_room = current
		queue_redraw()

func nearest_room() -> int:
	if instance == null or instance.hero == null or instance.layout.is_empty():
		return 0
	var rooms: Array = instance.layout.get("rooms", [])
	var center: Vector3 = instance.hero.global_position - instance.global_position
	var best: int = 0
	var dist: float = INF
	for room in rooms:
		var grid: Vector2i = room["grid"]
		var point: Vector2 = Vector2(float(grid.x) * 14.0, float(grid.y) * 14.0)
		var d: float = point.distance_squared_to(Vector2(center.x, center.z))
		if d < dist:
			dist = d
			best = int(room["id"])
	return best

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("122226e8"), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("b6a078"), false, 2.0)
	if instance == null or not is_instance_valid(instance) or instance.layout.is_empty():
		return
	var rooms: Array = instance.layout.get("rooms", [])
	if rooms.is_empty():
		return
	var least: Vector2 = Vector2(999, 999)
	var greatest: Vector2 = Vector2(-999, -999)
	for room in rooms:
		var g: Vector2i = room["grid"]
		var point: Vector2 = Vector2(float(g.x), float(g.y))
		least = least.min(point)
		greatest = greatest.max(point)
	var extents: Vector2 = greatest - least + Vector2.ONE
	var scale_by: float = minf((size.x - 28.0) / extents.x, (size.y - 28.0) / extents.y)
	scale_by = minf(scale_by, 26.0)
	var origin: Vector2 = (size - (extents - Vector2.ONE) * scale_by) * 0.5
	var positions: Dictionary = {}
	for room in rooms:
		var g: Vector2i = room["grid"]
		positions[int(room["id"])] = origin + (Vector2(float(g.x), float(g.y)) - least) * scale_by
	for link in instance.layout.get("edges", []):
		draw_line(positions[link.x], positions[link.y], Color("79939a"), 4.0, true)
	for room in rooms:
		var id: int = int(room["id"])
		var color: Color = Color("c4c6bd")
		if room["role"] == "boss":
			color = Color("e38e69")
		elif room["role"] == "stairs":
			color = Color("c9b36e")
		elif room["role"] == "treasure":
			color = Color("a0d8b4")
		elif room["role"] == "start":
			color = Color("83a9c1")
		draw_circle(positions[id], 5.5, color)
	var here: int = nearest_room()
	if positions.has(here):
		draw_circle(positions[here], 4.4, Color("f1df75"))
		draw_arc(positions[here], 9.0, 0, TAU, 20, Color("f6eeb0"), 1.6)
