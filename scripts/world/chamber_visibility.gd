extends RefCounted
## Experimental, read-only analysis of enclosed walkable columns. No terrain
## is changed. Narrow necks separate room cores; a bounded fallback handles
## passages which have no well-defined room core.
const NEIGHBORS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const INVALID := -99999

static func _connected(floors: Dictionary, enclosed: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	return floors.has(a) and floors.has(b) and enclosed.has(a) and enclosed.has(b) and absi(int(floors[a]) - int(floors[b])) <= 1

static func _core(floors: Dictionary, enclosed: Dictionary, cell: Vector2i) -> bool:
	if not floors.has(cell) or not enclosed.has(cell):
		return false
	# A full 2x2 walkable patch distinguishes a broad chamber interior from
	# a one-cell bottleneck without assuming axis-aligned rectangular rooms.
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var a := cell + Vector2i(sx, 0)
			var b := cell + Vector2i(0, sz)
			var diagonal := cell + Vector2i(sx, sz)
			if _connected(floors, enclosed, cell, a) and _connected(floors, enclosed, cell, b) and _connected(floors, enclosed, a, diagonal) and _connected(floors, enclosed, b, diagonal):
				return true
	return false

static func identify(floors: Dictionary, enclosed: Dictionary, origin: Vector2i, radius: int = 12) -> Dictionary:
	if not floors.has(origin) or not enclosed.has(origin):
		return {"cells": {}, "boundaries": [], "fallback": true}
	var result: Dictionary = {}
	var queue: Array[Vector2i] = [origin]
	var core_mode: bool = _core(floors, enclosed, origin)
	var max_radius: int = maxi(1, radius) if core_mode else mini(maxi(1, radius), 3)
	result[origin] = true
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for direction in NEIGHBORS:
			var neighbor: Vector2i = current + direction
			if result.has(neighbor) or neighbor.distance_squared_to(origin) > max_radius * max_radius:
				continue
			if not _connected(floors, enclosed, current, neighbor):
				continue
			if core_mode and not _core(floors, enclosed, neighbor):
				continue
			result[neighbor] = true
			queue.append(neighbor)
	# Add bordering walkable cells, but do not traverse the narrow neck.
	if core_mode:
		for current in queue:
			for direction in NEIGHBORS:
				var neighbor: Vector2i = current + direction
				if neighbor.distance_squared_to(origin) <= max_radius * max_radius and _connected(floors, enclosed, current, neighbor):
					result[neighbor] = true
	var boundaries: Array = []
	for cell in result:
		for direction in NEIGHBORS:
			if not _connected(floors, enclosed, cell, cell + direction):
				boundaries.append({"cell": cell, "outward": direction, "floor": int(floors[cell])})
	return {"cells": result, "boundaries": boundaries, "fallback": not core_mode}
