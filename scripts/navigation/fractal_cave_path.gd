extends RefCounted
## Direct cave-centreline path on seeded, fully carved walkable tunnel cells.
## Generic overworld AStar scans terrain top-down and would select the roof
## above the adventurer instead of the lower cavern floor.
const INVALID_FLOOR: int = -99999
const MAX_NEAR_ROUTE: float = 3.0

static func try_plan(game: Node3D, start: Vector3, target: Vector3, reach: float = 0.0) -> Dictionary:
	var biome: Variant = game.get("terrain_surface")
	var remote: Variant = biome.get("archipelago") if biome != null else null
	if remote == null or remote.terrain == null:
		return {"applicable": false}
	var cave = remote.terrain.caves
	if remote.mine != null and remote.mine.access.closed:
		var access = remote.mine.access
		if access.blocks_destination(target):
			return {"applicable": true, "path": PackedVector3Array()}
		# Surface journeys around a shut mine must use physical terrain rays.
		if access.footprint.has(Vector2i(floori(start.x), floori(start.z))) or access.footprint.has(Vector2i(floori(target.x), floori(target.z))):
			return {"applicable": false}
	if not cave.has_cave(floori(start.x), floori(start.z)) or not cave.has_cave(floori(target.x), floori(target.z)):
		return {"applicable": false}
	var from := Vector2i(floori(start.x), floori(start.z))
	var to := Vector2i(floori(target.x), floori(target.z))
	if not cave.branches.is_empty() and from.distance_squared_to(Vector2i(cave.entrances[0].x,cave.entrances[0].z)) < 64*64:
		return {"applicable":true,"path":_branch_path(cave,from,to,target)}
	var side = remote.side_chamber
	if side != null and from.distance_squared_to(side.center) < 64*64 and to.distance_squared_to(side.center) < 64*64:
		return {"applicable":true,"path":_branch_path(cave,from,to,target)}
	var best_score: float = INF
	var best_route: Array = []
	var first_index: int = -1
	var last_index: int = -1
	for route in cave.routes:
		var a_index: int = -1
		var b_index: int = -1
		var a_distance: float = INF
		var b_distance: float = INF
		for i in range(route.size()):
			var cell: Vector3i = route[i]
			var point := Vector2(float(cell.x) + 0.5, float(cell.z) + 0.5)
			var first_distance: float = point.distance_to(Vector2(start.x, start.z))
			var last_distance: float = point.distance_to(Vector2(target.x, target.z))
			if first_distance < a_distance:
				a_index = i
				a_distance = first_distance
			if last_distance < b_distance:
				b_index = i
				b_distance = last_distance
		if a_distance > MAX_NEAR_ROUTE or b_distance > MAX_NEAR_ROUTE:
			continue
		if a_distance + b_distance < best_score:
			best_score = a_distance + b_distance
			best_route = route
			first_index = a_index
			last_index = b_index
	if first_index < 0 or last_index < 0:
		return {"applicable": false}
	var result := PackedVector3Array()
	var increment: int = 1 if last_index >= first_index else -1
	var i: int = first_index
	var previous: Vector3i = best_route[i]
	while i != last_index:
		i += increment
		var point: Vector3i = best_route[i]
		if absi(point.y - previous.y) > 1 or not cave.has_cave(point.x, point.z):
			return {"applicable": true, "path": PackedVector3Array()}
		result.append(Vector3(float(point.x) + 0.5, float(point.y) + 0.10, float(point.z) + 0.5))
		previous = point
	# The final exact clicked floor is accepted only if the carve guarantees
	# air above solid backing. A wall or roof cannot become a destination.
	if reach <= 0.0:
		var floor_y: int = cave.floor_at(floori(target.x), floori(target.z))
		if floor_y == INVALID_FLOOR or absf(target.y - float(floor_y)) > 1.25:
			return {"applicable": true, "path": PackedVector3Array()}
		if not remote.terrain.is_solid(floori(target.x), floor_y - 1, floori(target.z)):
			return {"applicable": true, "path": PackedVector3Array()}
		result.append(Vector3(target.x, float(floor_y) + 0.10, target.z))
	elif result.is_empty():
		result.append(Vector3(float(previous.x) + 0.5, float(previous.y) + 0.10, float(previous.z) + 0.5))
	return {"applicable": true, "path": result}

# The optional branch leaves the generated route's centreline. Follow actual
# neighbouring carved floors so an approach cannot cut through the corner.
static func _branch_path(cave, start: Vector2i, goal: Vector2i, target: Vector3) -> PackedVector3Array:
	var path := PackedVector3Array()
	if absf(target.y-cave.floor_at(goal.x,goal.y)) > 1.25:
		return path
	var queue: Array[Vector2i] = [start]
	var parents := {start:start}
	var i := 0
	while i < queue.size() and not parents.has(goal):
		var cell := queue[i]
		i += 1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var n: Vector2i = cell+offset
			if not parents.has(n) and cave.has_cave(n.x,n.y) and absi(cave.floor_at(n.x,n.y)-cave.floor_at(cell.x,cell.y)) <= 1:
				parents[n] = cell
				queue.append(n)
	if parents.has(goal):
		var cell := goal
		while cell != start:
			path.append(Vector3(cell.x+0.5,cave.floor_at(cell.x,cell.y)+0.1,cell.y+0.5))
			cell = parents[cell]
		path.reverse()
		path.append(Vector3(target.x,cave.floor_at(goal.x,goal.y)+0.1,target.z))
	return path
