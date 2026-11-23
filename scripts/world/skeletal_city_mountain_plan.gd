extends RefCounted
## Deterministic, isolated geometry proposal for Skeletal City's gateway and
## three-turn dwarven descent. Does NOT modify live terrain or save data.
##
## Unlike existing 2D cave floor columns, this reserves multiple walkable Y
## levels per X/Z column. The eventual terrain adapter must preserve them.

const TURNS: int = 3
const TILES_PER_DROP: int = 10
const WALKWAY_WIDTH: int = 3
const WALKWAY_CLEARANCE: int = 4
const GATE_LENGTH: int = 32
const EXIT_LENGTH: int = 18
const CITY_HALF_WIDTH: int = 48

func generate(world_seed: int, origin: Vector3i = Vector3i(0, 43, 0)) -> Dictionary:
	var radius: int = 15 + posmod(world_seed, 3)
	var ring: Array[Vector2i] = _square_ring(radius)
	var candidates: Dictionary = {} # Vector2i -> Array of proposed foot Ys
	var floors: Dictionary = {} # Vector3i -> true, standing elevation
	var air: Dictionary = {} # Vector3i -> true, must be carved
	var supports: Dictionary = {} # Vector3i -> true, must stay solid
	var levels: Dictionary = {} # Vector2i -> Array of valid foot Ys
	var entrance: Array[Vector3i] = []
	var spiral: Array[Vector3i] = []
	var exit_path: Array[Vector3i] = []

	# Carved entrance corridor from the mountain face into the spiral.
	for z in range(-radius - GATE_LENGTH, -radius + 1):
		var center := Vector3i(origin.x + radius, origin.y, origin.z + z)
		entrance.append(center)
		for dx in range(-2, 3):
			_add_candidate(Vector3i(center.x + dx, center.y, center.z), candidates)

	# Each revolution descends around the same X/Z perimeter, but at a
	# different height. Even ONE turn overlaps near its seam: never collapse
	# all heights into one floor as the existing cave column format does.
	for turn in range(TURNS):
		for i in range(ring.size()):
			var local: Vector2i = ring[i]
			var foot_y: int = origin.y - int((turn * ring.size() + i) / TILES_PER_DROP)
			var foot := Vector3i(origin.x + local.x, foot_y, origin.z + local.y)
			spiral.append(foot)
			for band_cell: Vector2i in _inner_band(local, radius):
				_add_candidate(Vector3i(origin.x + band_cell.x, foot_y,
					origin.z + band_cell.y), candidates)

	# Final landing bridges to a reserved cavern/city-overlook anchor.
	var end: Vector3i = spiral.back()
	exit_path.append(end)
	for i in range(1, EXIT_LENGTH + 1):
		var at := Vector3i(end.x, end.y, end.z - i)
		exit_path.append(at)
		for dx in range(-1, 2):
			_add_candidate(Vector3i(at.x + dx, at.y, at.z), candidates)

	# Close floor candidates from adjacent stair slices are one continuous
	# step surface; distant Y layers remain independently traversable.
	for column: Vector2i in candidates:
		var proposed: Array = candidates[column]
		proposed.sort()
		var merged: Array[int] = []
		for value in proposed:
			var y: int = int(value)
			if merged.is_empty() or y - merged.back() > 2:
				merged.append(y)
		for y: int in merged:
			_register_floor(Vector3i(column.x, y, column.y),
				floors, air, supports, levels)
		levels[column] = merged

	# Snap the route to the actual band floor without erasing separate turns.
	_snap_route(entrance, levels)
	_snap_route(spiral, levels)
	_snap_route(exit_path, levels)

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

func _add_candidate(foot: Vector3i, candidates: Dictionary) -> void:
	var column := Vector2i(foot.x, foot.z)
	var elevations: Array = candidates.get(column, [])
	elevations.append(foot.y)
	candidates[column] = elevations

func _register_floor(foot: Vector3i, floors: Dictionary, air: Dictionary,
		supports: Dictionary, levels: Dictionary) -> void:
	floors[foot] = true
	supports[foot + Vector3i.DOWN] = true
	for dy in range(WALKWAY_CLEARANCE):
		air[foot + Vector3i(0, dy, 0)] = true

func _snap_route(route: Array[Vector3i], levels: Dictionary) -> void:
	for i in range(route.size()):
		var pos: Vector3i = route[i]
		var elevations: Array = levels[Vector2i(pos.x, pos.z)]
		var best: int = int(elevations[0])
		for value in elevations:
			var y: int = int(value)
			if absi(y - pos.y) < absi(best - pos.y):
				best = y
		route[i] = Vector3i(pos.x, best, pos.z)

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
