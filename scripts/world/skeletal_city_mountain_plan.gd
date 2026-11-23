extends RefCounted
## Deterministic, isolated geometry proposal for Skeletal City's entrance and
## three-turn dwarven descent. This does NOT modify live terrain or save data.
##
## The current cave system stores one floor per Vector2i. This landmark must
## instead support several walkable Y levels at a single X/Z column, so all
## proposed cells are keyed by Vector3i until a 3D terrain adapter exists.

const TURNS: int = 3
const TILES_PER_DROP: int = 10
const WALKWAY_WIDTH: int = 3
const WALKWAY_CLEARANCE: int = 4
const GATE_LENGTH: int = 32
const EXIT_LENGTH: int = 18
const CITY_HALF_WIDTH: int = 48

func generate(world_seed: int, origin: Vector3i = Vector3i(0, 43, 0)) -> Dictionary:
	# An angular spiral suits the dwarven masonry and keeps every movement
	# orthogonal; later rendered corners may be bevelled without changing it.
	var radius: int = 15 + posmod(world_seed, 3)
	var ring: Array[Vector2i] = _square_ring(radius)
	var floors: Dictionary = {} # Vector3i -> true, at standing-foot elevation
	var air: Dictionary = {} # Vector3i -> true, carved/open
	var supports: Dictionary = {} # Vector3i -> true, solid underneath foot
	var levels: Dictionary = {} # Vector2i -> Array of walkable Y levels
	var entrance: Array[Vector3i] = []
	var spiral: Array[Vector3i] = []
	var exit_path: Array[Vector3i] = []

	# The gateway is a horizontal, roofed tunnel approaching the first turn.
	for z in range(-radius - GATE_LENGTH, -radius + 1):
		var center := Vector3i(origin.x + radius, origin.y, origin.z + z)
		entrance.append(center)
		for dx in range(-2, 3):
			_register_floor(Vector3i(center.x + dx, center.y, center.z), floors, air, supports, levels)

	# Build each turn independently. Within a turn, shared width cells take
	# the lower of adjacent step heights, avoiding conflicting floor surfaces.
	# Separate turns intentionally share horizontal columns at DIFFERENT Y.
	for turn in range(TURNS):
		var turn_floors: Dictionary = {} # Vector2i -> Y
		for i in range(ring.size()):
			var local: Vector2i = ring[i]
			var foot_y: int = origin.y - int((turn * ring.size() + i) / TILES_PER_DROP)
			for band_cell: Vector2i in _inner_band(local, radius):
				var cell := Vector2i(origin.x + band_cell.x, origin.z + band_cell.y)
				turn_floors[cell] = mini(int(turn_floors.get(cell, foot_y)), foot_y)
		for cell: Vector2i in turn_floors:
			_register_floor(Vector3i(cell.x, int(turn_floors[cell]), cell.y),
				floors, air, supports, levels)
		for local: Vector2i in ring:
			var at := Vector2i(origin.x + local.x, origin.z + local.y)
			spiral.append(Vector3i(at.x, int(turn_floors[at]), at.y))

	# The lowest landing leads away from the shaft towards the future city
	# overlook. This is a real walkable route, not a teleport destination.
	var end: Vector3i = spiral.back()
	exit_path.append(end)
	for i in range(1, EXIT_LENGTH + 1):
		var at := Vector3i(end.x, end.y, end.z - i)
		exit_path.append(at)
		for dx in range(-1, 2):
			_register_floor(Vector3i(at.x + dx, at.y, at.z),
				floors, air, supports, levels)

	for column: Vector2i in levels:
		(levels[column] as Array).sort()

	var exit_at: Vector3i = exit_path.back()
	return {
		"seed": world_seed,
		"mountain_center": origin,
		"mountain_radius": 130,
		"gateway": entrance.front(),
		"entrance_route": entrance,
		"spiral_route": spiral,
		"exit_route": exit_path,
		"city_center": Vector3i(exit_at.x, exit_at.y, exit_at.z - 24),
		"city_half_width": CITY_HALF_WIDTH,
		"floors": floors,
		"air": air,
		"supports": supports,
		"column_levels": levels,
		"radius": radius
	}

func _register_floor(foot: Vector3i, floors: Dictionary, air: Dictionary,
		supports: Dictionary, levels: Dictionary) -> void:
	floors[foot] = true
	supports[foot + Vector3i.DOWN] = true
	for dy in range(WALKWAY_CLEARANCE):
		air[foot + Vector3i(0, dy, 0)] = true
	var column := Vector2i(foot.x, foot.z)
	var elevations: Array = levels.get(column, [])
	if not elevations.has(foot.y):
		elevations.append(foot.y)
	levels[column] = elevations

func _inner_band(cell: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in range(WALKWAY_WIDTH):
		if absi(cell.x) == radius:
			cells.append(cell + Vector2i(-signi(cell.x) * i, 0))
		else:
			cells.append(cell + Vector2i(0, -signi(cell.y) * i))
	return cells

func _square_ring(radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for z in range(-radius, radius + 1):
		result.append(Vector2i(radius, z))
	for x in range(radius - 1, -radius - 1, -1):
		result.append(Vector2i(x, radius))
	for z in range(radius - 1, -radius - 1, -1):
		result.append(Vector2i(-radius, z))
	for x in range(-radius + 1, radius):
		result.append(Vector2i(x, -radius))
	return result
