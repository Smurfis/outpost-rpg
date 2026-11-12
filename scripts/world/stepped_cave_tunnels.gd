extends RefCounted
## Minecraft-like hillside entrances and irregular 3D voxel tunnels.
## A guaranteed 5-block-wide walkable throat replaces the narrow open trench.
## Descent stays within one voxel; carving is in XYZ rather than entire columns.
const INVALID_FLOOR: int = -99999
const CORRIDOR_WIDTH: int = 5
const CORRIDOR_HEIGHT: int = 5
const DESCENT_SPACING: int = 5
const MOUTH_RADIUS: int = 3
const INNER_RADIUS: int = 2
const CHAMBER_RADIUS: int = 5
var floors: Dictionary = {} # Vector2i -> absolute walkable floor y
var _air: Dictionary = {} # Vector3i -> carved voxel. Never remove a whole XZ column.
var _cover: Dictionary = {} # Vector2i -> minimum solid hillside roof height
var routes: Array = []
var entrances: Array[Vector3] = []
var chests: Array[Vector3] = []
var _rock_noise: FastNoiseLite

func configure(terrain) -> void:
	floors.clear()
	_air.clear()
	_cover.clear()
	routes.clear()
	entrances.clear()
	chests.clear()
	_rock_noise = FastNoiseLite.new()
	_rock_noise.seed = terrain.seed + 1553
	_rock_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_rock_noise.frequency = 0.29
	for island in terrain.islands:
		var center: Vector2i = island["center"]
		var radius: float = float(island["radius"])
		var start := Vector2i(center.x + roundi(radius * 0.55), center.y + 8)
		# The approach is on the existing walkable hillside, immediately
		# outside the cliff. The carved entrance is IN the raised rock face.
		var first_height: int = maxi(1, terrain.height_at(start.x + 1, start.y))
		var route: Array = []
		var steps: int = mini(38, roundi(radius * 0.96))
		for step in range(steps):
			var bend: int = roundi(sin(float(step) * 0.17) * 1.5)
			var cell := Vector2i(start.x - step, start.y + bend)
			var floor_y: int = maxi(0, first_height - int(step / DESCENT_SPACING))
			route.append(Vector3i(cell.x, floor_y, cell.y))
			var mouth: bool = step <= 3
			var passage_radius: int = MOUTH_RADIUS if mouth else INNER_RADIUS
			# Short wider bays every ten steps break up identical corridor walls.
			if step > 5 and step % 10 in [0, 1]:
				passage_radius = MOUTH_RADIUS
			var height: int = CORRIDOR_HEIGHT + (1 if mouth else 0)
			_carve_passage(cell.x, cell.y, floor_y, passage_radius, height, step, start.x)
		routes.append(route)
		if route.is_empty():
			continue
		var entry: Vector3i = route[0]
		entrances.append(Vector3(float(entry.x) + 0.5, float(entry.y), float(entry.z) + 0.5))
		var end: Vector3i = route[route.size() - 1]
		_carve_chamber(end)
		chests.append(Vector3(float(end.x) + 0.5, float(end.y), float(end.z) + 0.5))

func _carve_passage(x: int, z: int, floor_y: int, radius: int,
		height: int, step: int, mouth_x: int) -> void:
	for side in range(-radius, radius + 1):
		var column_z: int = z + side
		var relative: float = float(abs(side)) / float(radius)
		# An arched, blocky Minecraft tunnel: broad standing room in the
		# middle, stepping down to three blocks high at the rocky shoulders.
		var arch: int = maxi(3, height - roundi(relative * relative * 2.3))
		if abs(side) == radius:
			var rough: float = _rock_noise.get_noise_3d(float(x), float(floor_y + arch), float(column_z))
			arch = maxi(3, arch - (1 if rough > 0.12 else 0))
		_register_floor(x, column_z, floor_y)
		for y in range(floor_y, floor_y + arch):
			_air[Vector3i(x, y, column_z)] = true
		# Keep a genuine stone ceiling and hill above the first chambers.
		# The start face stays open towards the EAST; no carved roof trench
		# or giant missing rectangular patch on the top of the island.
		var min_roof: int = floor_y + arch + 2
		var key := Vector2i(x, column_z)
		_cover[key] = maxi(int(_cover.get(key, min_roof)), min_roof)

func _carve_chamber(end: Vector3i) -> void:
	# Wider irregular terminal chamber, with chest on level ground.
	# An ellipsoid footprint blends into the final descending tunnel.
	for dx in range(-CHAMBER_RADIUS, CHAMBER_RADIUS + 1):
		for dz in range(-CHAMBER_RADIUS, CHAMBER_RADIUS + 1):
			var x: int = end.x + dx
			var z: int = end.z + dz
			var ragged: float = _rock_noise.get_noise_3d(float(x), 7.0, float(z)) * 0.45
			var oval: float = pow(float(dx) / float(CHAMBER_RADIUS), 2.0) + pow(float(dz) / 4.0, 2.0)
			if oval + ragged > 1.0:
				continue
			var arch: int = maxi(4, 7 - roundi(maxf(0.0, oval) * 2.0))
			_register_floor(x, z, end.y)
			for y in range(end.y, end.y + arch):
				_air[Vector3i(x, y, z)] = true
			var key := Vector2i(x, z)
			_cover[key] = maxi(int(_cover.get(key, 0)), end.y + arch + 2)

func _register_floor(x: int, z: int, floor_y: int) -> void:
	var key := Vector2i(x, z)
	floors[key] = mini(int(floors.get(key, floor_y)), floor_y)

func floor_at(x: int, z: int) -> int:
	return int(floors.get(Vector2i(x, z), INVALID_FLOOR))

func has_cave(x: int, z: int) -> bool:
	return floors.has(Vector2i(x, z))

func is_air(x: int, y: int, z: int) -> bool:
	return _air.has(Vector3i(x, y, z))

func cover_height_at(x: int, z: int) -> int:
	return int(_cover.get(Vector2i(x, z), INVALID_FLOOR))

func route_has_safe_steps(route: Array) -> bool:
	for i in range(1, route.size()):
		var a: Vector3i = route[i - 1]
		var b: Vector3i = route[i]
		if absi(a.y - b.y) > 1 or absi(a.x - b.x) + absi(a.z - b.z) > 2:
			return false
	return true
