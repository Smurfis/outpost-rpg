extends RefCounted
## Shortest walkable 2-D grid route to a crafting station's usable perimeter.
## Designed for the streamed voxel outpost: graph built only when the player
## taps a station, not every frame. Dynamic controls always override walking.
const GRID_STEP: float = 1.0
const APPROACH_RADIUS: float = 2.65
const STATION_SOLID_RADIUS: float = 1.70
const WORLD_PADDING: int = 7

static func _ground(surface: Node, x: float, z: float) -> float:
	if surface != null and surface.has_method("surface_y_at"):
		return float(surface.call("surface_y_at", x, z))
	return -0.055

static func plan(start: Vector3, station_id: String, stations: Dictionary, surface: Node = null) -> PackedVector3Array:
	var output := PackedVector3Array()
	if not stations.has(station_id):
		return output
	var target: Vector3 = stations[station_id]
	var start_cell := Vector2i(roundi(start.x), roundi(start.z))
	var target_cell := Vector2i(roundi(target.x), roundi(target.z))
	var minimum := Vector2i(mini(start_cell.x, target_cell.x) - WORLD_PADDING, mini(start_cell.y, target_cell.y) - WORLD_PADDING)
	var maximum := Vector2i(maxi(start_cell.x, target_cell.x) + WORLD_PADDING + 1, maxi(start_cell.y, target_cell.y) + WORLD_PADDING + 1)
	# No multi-thousand-cell world graph: an interaction only needs this route.
	if maximum.x - minimum.x > 90 or maximum.y - minimum.y > 90:
		return output
	var graph := AStarGrid2D.new()
	graph.region = Rect2i(minimum, maximum - minimum)
	graph.cell_size = Vector2.ONE * GRID_STEP
	graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	graph.update()
	for x in range(minimum.x, maximum.x):
		for z in range(minimum.y, maximum.y):
			var cell := Vector2i(x, z)
			var horizontal := Vector2(float(x), float(z))
			# Crafting stations are obstacles, not the place the avatar should
			# walk through. Approach the accessible perimeter instead.
			for key in stations:
				var position: Vector3 = stations[key]
				if horizontal.distance_to(Vector2(position.x, position.z)) < STATION_SOLID_RADIUS:
					graph.set_point_solid(cell)
					break
			# Avoid steep terraces which the character's auto-step cannot climb.
			if not graph.is_point_solid(cell) and surface != null:
				var height: float = _ground(surface, float(x), float(z))
				if absf(height - _ground(surface, float(x + 1), float(z))) > 1.1 and absf(height - _ground(surface, float(x - 1), float(z))) > 1.1:
					graph.set_point_solid(cell)
				elif absf(height - _ground(surface, float(x), float(z + 1))) > 1.1 and absf(height - _ground(surface, float(x), float(z - 1))) > 1.1:
					graph.set_point_solid(cell)
	graph.set_point_solid(start_cell, false)
	var shortest: float = INF
	# Sample eight approach angles rather than walking into the station. A*
	# chooses the least-cost reachable route around the surrounding props.
	for index in range(8):
		var angle: float = TAU * float(index) / 8.0
		var destination := Vector2i(roundi(target.x + cos(angle) * APPROACH_RADIUS), roundi(target.z + sin(angle) * APPROACH_RADIUS))
		if not graph.is_in_boundsv(destination) or graph.is_point_solid(destination):
			continue
		var id_path: Array[Vector2i] = graph.get_id_path(start_cell, destination)
		if id_path.is_empty():
			continue
		var distance: float = 0.0
		for j in range(1, id_path.size()):
			distance += Vector2(id_path[j]).distance_to(Vector2(id_path[j - 1]))
		if distance >= shortest:
			continue
		shortest = distance
		output.clear()
		for j in range(1, id_path.size()):
			var point: Vector2i = id_path[j]
			output.append(Vector3(float(point.x), _ground(surface, float(point.x), float(point.y)) + 0.35, float(point.y)))
	return output
