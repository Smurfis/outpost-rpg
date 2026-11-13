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

static func plan_world(game: Node3D, start: Vector3, target: Vector3, reach: float = 0.0) -> PackedVector3Array:
	# Reuse the station grid/perimeter model, but validate each edge against
	# actual loaded voxel/dungeon colliders (including cliffs and walls).
	var result := PackedVector3Array()
	var first := Vector2i(roundi(start.x), roundi(start.z))
	var last := Vector2i(roundi(target.x), roundi(target.z))
	var minimum := Vector2i(mini(first.x, last.x) - WORLD_PADDING, mini(first.y, last.y) - WORLD_PADDING)
	var maximum := Vector2i(maxi(first.x, last.x) + WORLD_PADDING, maxi(first.y, last.y) + WORLD_PADDING)
	if maximum.x - minimum.x > 70 or maximum.y - minimum.y > 70:
		return result
	var graph := AStar3D.new()
	var cells: Dictionary = {}
	var excluded: Array[RID] = [game.hero.get_rid()]
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if enemy is CollisionObject3D:
			excluded.append(enemy.get_rid())
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var top: float = maxf(start.y, target.y) + 5.0
	var archipelago: Variant = game.terrain_surface.get("archipelago") if game.terrain_surface != null else null
	for x in range(minimum.x, maximum.x + 1):
		for z in range(minimum.y, maximum.y + 1):
			var cell := Vector2i(x, z)
			var ray_top: float = top
			var ray_bottom: float = minf(start.y, target.y) - 6.0
			# Inside a roofed fractal cave the highest solid surface is the
			# mountain roof. A ray from above will select that roof as a
			# walking node, making clicks in the tunnel impossible to route.
			# Sample from inside the carved air column down to its true floor.
			if archipelago != null and archipelago.terrain != null:
				var floor_y: int = archipelago.terrain.caves.floor_at(x, z)
				if floor_y != -99999:
					ray_top = float(floor_y) + 1.60
					ray_bottom = float(floor_y) - 2.0
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, ray_top, z), Vector3(x, ray_bottom, z), 1, excluded)
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
				continue
			var point: Vector3 = hit.position
			# Click routes stay on dry loaded ground. Manual swimming is retained.
			if absf(point.x) < 100.0 and absf(point.z) < 100.0 and point.y < -2.7:
				continue
			if cell != first and not game.prop_placement.available(point, 0.35):
				continue
			var id: int = graph.get_available_point_id()
			graph.add_point(id, point + Vector3.UP * 0.08)
			cells[cell] = id
	if not cells.has(first):
		return result
	for cell in cells:
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var next: Vector2i = cell + offset
			if not cells.has(next):
				continue
			var a: Vector3 = graph.get_point_position(cells[cell])
			var b: Vector3 = graph.get_point_position(cells[next])
			if absf(a.y - b.y) > game.hero.max_auto_step_height:
				continue
			if offset.x != 0 and offset.y != 0:
				var side_a: Vector2i = cell + Vector2i(offset.x, 0)
				var side_b: Vector2i = cell + Vector2i(0, offset.y)
				if not cells.has(side_a) or not cells.has(side_b):
					continue
				if absf(graph.get_point_position(cells[side_a]).y - a.y) > game.hero.max_auto_step_height or absf(graph.get_point_position(cells[side_b]).y - a.y) > game.hero.max_auto_step_height:
					continue
			# Capsule-width corridor checks keep routes away from dungeon walls.
			var blocked: bool = false
			var side: Vector3 = Vector3(b.z - a.z, 0, a.x - b.x).normalized() * 0.4
			for shift in [Vector3.ZERO, side, -side]:
				var height := Vector3.UP * (maxf(a.y, b.y) + 0.65)
				var ray := PhysicsRayQueryParameters3D.create(Vector3(a.x, 0, a.z) + height + shift, Vector3(b.x, 0, b.z) + height + shift, 1, excluded)
				if not space.intersect_ray(ray).is_empty():
					blocked = true
					break
			if not blocked:
				graph.connect_points(cells[cell], cells[next])
	var candidates: Array[Vector2i] = []
	if reach <= 0.0:
		if cells.has(last):
			candidates.append(last)
	else:
		for cell in cells:
			var point: Vector3 = graph.get_point_position(cells[cell])
			if point.distance_to(target) < reach - 0.25:
				candidates.append(cell)
	var best: float = INF
	for cell in candidates:
		var path: PackedVector3Array = graph.get_point_path(cells[first], cells[cell])
		if path.is_empty():
			continue
		var length: float = 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		if length < best:
			best = length
			result = path
	if result.size() > 1:
		result.remove_at(0)
	if reach <= 0.0 and not result.is_empty():
		# Preserve the real raycast point instead of rounding the final click.
		result.append(target + Vector3.UP * 0.08)
	return result
