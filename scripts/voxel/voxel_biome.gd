extends Node3D
## Walkable, chunked voxel Fields biome. The existing Outpost clearing stays
## level and traversable; seeded Perlin noise forms one-voxel terraces outside.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")
const CHUNK_SIZE: int = 12
const MAP_HALF: int = 23
const FIELDS_MAP_HALF: int = 48
const STREAM_MAP_HALF: int = 96
const STREAM_RADIUS: int = 3 # Keep 7x7 neighbour chunks around the active player
const CHUNK_CREATION_BUDGET: int = 2 # Android: do not construct 49 meshes/colliders during one _ready().
const SAFE_CLEARING_RADIUS: float = 23.0
const HEIGHT_BLEND_BAND: float = 12.0
const MAX_ELEVATION: float = 3.0

var map_half: int = MAP_HALF
var fields_enabled: bool = false
var world_seed: int = 64012
var _noise: FastNoiseLite
var chunk_meshes: Array[MeshInstance3D] = []
var stream_enabled: bool = false
var _stream_center: Vector2i = Vector2i(99999, 99999)
var _loaded: Dictionary = {} # Vector2i cell -> [mesh, collider, decoration]
var defer_streaming: bool = false
var _pending_chunks: Array[Vector2i] = []
var _initial_total: int = 0
var _initial_built: int = 0
var _initial_completed: bool = true

func build(enable_fields: bool = false, seed: int = 64012, enable_streaming: bool = false, defer_initial_chunks: bool = false) -> void:
	name = "VoxelAtmosphere"
	fields_enabled = enable_fields
	stream_enabled = enable_fields and enable_streaming
	defer_streaming = stream_enabled and defer_initial_chunks
	_pending_chunks.clear()
	_initial_total = 0
	_initial_built = 0
	_initial_completed = not defer_streaming
	map_half = STREAM_MAP_HALF if stream_enabled else FIELDS_MAP_HALF if fields_enabled else MAP_HALF
	world_seed = seed
	_noise = FastNoiseLite.new()
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.037
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_noise.fractal_gain = 0.45
	if stream_enabled:
		if defer_streaming:
			_queue_streaming_for(Vector3.ZERO)
		else:
			update_streaming_for(Vector3.ZERO)
	else:
		_make_ground()
	_make_cliff_rim()
	if not stream_enabled:
		_make_grass_detail()
		if fields_enabled:
			_make_fields_scenery()

func surface_y_at(x: float, z: float) -> float:
	# All landmarks, stations and starter portals remain on the original flat
	# ground. Quantized Perlin elevation beyond the clearing gives the visual
	# silhouette and traversable one-block steps of Minecraft Dungeons.
	if not fields_enabled:
		return -0.055
	var radial: float = maxf(absf(x), absf(z))
	var blend: float = clampf((radial - SAFE_CLEARING_RADIUS) / HEIGHT_BLEND_BAND, 0.0, 1.0)
	blend = blend * blend * (3.0 - 2.0 * blend)
	if blend <= 0.0:
		return -0.055
	var sample: float = _noise.get_noise_2d(floorf(x) + 0.5, floorf(z) + 0.5)
	var field_height: float = (1.1 + (sample + 1.0) * 1.05) * blend
	return -0.055 + clampf(roundf(field_height), 0.0, MAX_ELEVATION)

func _process(_delta: float) -> void:
	if not stream_enabled:
		return
	var owner: Node = get_parent()
	if owner == null:
		return
	var player = owner.get("hero")
	if player == null:
		return
	var point: Vector3 = player.global_position
	# Entering a private dungeon teleports far beyond the overworld. Do not
	# unload the entire Fields map merely because the player entered an instance.
	if absf(point.x) > float(map_half) or absf(point.z) > float(map_half):
		return
	if defer_streaming:
		_queue_streaming_for(point)
		_build_pending_chunks()
	else:
		update_streaming_for(point)

func initial_generation_progress() -> float:
	if not defer_streaming or _initial_completed:
		return 1.0
	return float(_initial_built) / float(maxi(1, _initial_total))

func initial_generation_complete() -> bool:
	return _initial_completed

func _queue_streaming_for(point: Vector3) -> void:
	if absf(point.x) >= float(map_half) or absf(point.z) >= float(map_half):
		return
	var center: Vector2i = _cell_at(point)
	if center == _stream_center:
		return
	_stream_center = center
	var wanted: Dictionary = {}
	var candidates: Array[Vector2i] = []
	for dx in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
		for dz in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
			var cell: Vector2i = center + Vector2i(dx, dz) * CHUNK_SIZE
			if cell.x < -map_half or cell.x >= map_half or cell.y < -map_half or cell.y >= map_half:
				continue
			wanted[cell] = true
			if not _loaded.has(cell):
				candidates.append(cell)
	# Spawn collision first; never build outer rings before the hero's tile.
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center)
	)
	_pending_chunks = candidates
	if _initial_total == 0:
		_initial_total = candidates.size()
	for cell in _loaded.keys():
		if wanted.has(cell):
			continue
		var members: Array = _loaded[cell]
		for object in members:
			if object != null and is_instance_valid(object):
				if object is MeshInstance3D:
					chunk_meshes.erase(object)
				remove_child(object)
				object.queue_free()
		_loaded.erase(cell)

func _build_pending_chunks() -> void:
	for i in range(mini(CHUNK_CREATION_BUDGET, _pending_chunks.size())):
		var cell: Vector2i = _pending_chunks.pop_front()
		if _loaded.has(cell):
			continue
		_build_ground_chunk(cell.x, cell.y)
		if not _initial_completed:
			_initial_built += 1
	if _pending_chunks.is_empty() and not _initial_completed:
		_initial_completed = true

func _cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / float(CHUNK_SIZE)) * CHUNK_SIZE,
		floori(point.z / float(CHUNK_SIZE)) * CHUNK_SIZE)

func update_streaming_for(point: Vector3) -> void:
	if not stream_enabled or absf(point.x) >= float(map_half) or absf(point.z) >= float(map_half):
		return
	var center: Vector2i = _cell_at(point)
	if center == _stream_center:
		return
	_stream_center = center
	var required: Dictionary = {}
	for dx in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
		for dz in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
			var cell: Vector2i = center + Vector2i(dx, dz) * CHUNK_SIZE
			if cell.x < -map_half or cell.x >= map_half or cell.y < -map_half or cell.y >= map_half:
				continue
			required[cell] = true
			if not _loaded.has(cell):
				_build_ground_chunk(cell.x, cell.y)
	for cell in _loaded.keys():
		if required.has(cell):
			continue
		var previous: Array = _loaded[cell]
		for object in previous:
			if object != null and is_instance_valid(object):
				if object is MeshInstance3D:
					chunk_meshes.erase(object)
				remove_child(object)
				object.queue_free()
		_loaded.erase(cell)

func loaded_chunk_count() -> int:
	return _loaded.size()

func has_chunk_at(x: float, z: float) -> bool:
	return _loaded.has(_cell_at(Vector3(x, 0, z)))

func _make_ground() -> void:
	for chunk_x in range(-map_half, map_half, CHUNK_SIZE):
		for chunk_z in range(-map_half, map_half, CHUNK_SIZE):
			_build_ground_chunk(chunk_x, chunk_z)

func _tile_height(x: int, z: int) -> float:
	return surface_y_at(float(x) + 0.5, float(z) + 0.5)

func _build_ground_chunk(chunk_x: int, chunk_z: int) -> void:
	var key: Vector2i = Vector2i(chunk_x, chunk_z)
	if _loaded.has(key):
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x_end: int = mini(chunk_x + CHUNK_SIZE, map_half)
	var z_end: int = mini(chunk_z + CHUNK_SIZE, map_half)
	# Merge adjacent coplanar upper faces when BOTH height and atlas tile match.
	# This is intentionally per-chunk; no mesh/collision dependency crosses
	# an asynchronously loaded cell boundary.
	var used: Dictionary = {}
	for x in range(chunk_x, x_end):
		for z in range(chunk_z, z_end):
			if used.has(Vector2i(x, z)):
				continue
			var tile: int = _ground_tile(x, z)
			var height: float = _tile_height(x, z)
			var width: int = 1
			while x + width < x_end:
				if used.has(Vector2i(x + width, z)) or _ground_tile(x + width, z) != tile or not is_equal_approx(_tile_height(x + width, z), height):
					break
				width += 1
			var depth: int = 1
			while z + depth < z_end:
				var same: bool = true
				for ox in range(width):
					if used.has(Vector2i(x + ox, z + depth)) or _ground_tile(x + ox, z + depth) != tile or not is_equal_approx(_tile_height(x + ox, z + depth), height):
						same = false
						break
				if not same:
					break
				depth += 1
			for ox in range(width):
				for oz in range(depth):
					used[Vector2i(x + ox, z + oz)] = true
			GREEDY.tiled_quad(st,
				Vector3(float(x), height, float(z)),
				Vector3(float(x), height, float(z + depth)),
				Vector3(float(x + width), height, float(z + depth)),
				Vector3(float(x + width), height, float(z)), tile, "top")
	# Merge exposed vertical walls along a continuous row when they share
	# exactly the same upper/lower heights; all directions handle unloaded
	# neighbour chunks using the world-wide deterministic height sampler.
	for side in ["east", "west", "south", "north"]:
		if side in ["east", "west"]:
			for x in range(chunk_x, x_end):
				var z: int = chunk_z
				while z < z_end:
					var high: float = _tile_height(x, z)
					var adjacent: float = _tile_height(x + (1 if side == "east" else -1), z) if (x < map_half - 1 if side == "east" else x > -map_half) else -2.2
					if high <= adjacent + 0.01:
						z += 1
						continue
					var stop: int = z + 1
					while stop < z_end:
						var next_high: float = _tile_height(x, stop)
						var next_low: float = _tile_height(x + (1 if side == "east" else -1), stop) if (x < map_half - 1 if side == "east" else x > -map_half) else -2.2
						if not is_equal_approx(high, next_high) or not is_equal_approx(adjacent, next_low):
							break
						stop += 1
					var plane_x: float = float(x + 1 if side == "east" else x)
					if side == "east":
						GREEDY.tiled_quad(st, Vector3(plane_x, adjacent, stop), Vector3(plane_x, adjacent, z), Vector3(plane_x, high, z), Vector3(plane_x, high, stop), 3, "x")
					else:
						GREEDY.tiled_quad(st, Vector3(plane_x, adjacent, z), Vector3(plane_x, adjacent, stop), Vector3(plane_x, high, stop), Vector3(plane_x, high, z), 3, "x")
					z = stop
		else:
			for z in range(chunk_z, z_end):
				var x: int = chunk_x
				while x < x_end:
					var high: float = _tile_height(x, z)
					var adjacent: float = _tile_height(x, z + (1 if side == "south" else -1)) if (z < map_half - 1 if side == "south" else z > -map_half) else -2.2
					if high <= adjacent + 0.01:
						x += 1
						continue
					var stop: int = x + 1
					while stop < x_end:
						var next_high: float = _tile_height(stop, z)
						var next_low: float = _tile_height(stop, z + (1 if side == "south" else -1)) if (z < map_half - 1 if side == "south" else z > -map_half) else -2.2
						if not is_equal_approx(high, next_high) or not is_equal_approx(adjacent, next_low):
							break
						stop += 1
					var plane_z: float = float(z + 1 if side == "south" else z)
					if side == "south":
						GREEDY.tiled_quad(st, Vector3(x, adjacent, plane_z), Vector3(stop, adjacent, plane_z), Vector3(stop, high, plane_z), Vector3(x, high, plane_z), 3, "z")
					else:
						GREEDY.tiled_quad(st, Vector3(stop, adjacent, plane_z), Vector3(x, adjacent, plane_z), Vector3(x, high, plane_z), Vector3(stop, high, plane_z), 3, "z")
					x = stop
	var mesh: MeshInstance3D = PIXELS.as_instance(st, "GroundChunk_%d_%d" % [chunk_x, chunk_z])
	mesh.material_override = GREEDY.material()
	add_child(mesh)
	chunk_meshes.append(mesh)
	var members: Array = [mesh]
	if fields_enabled:
		var body := StaticBody3D.new()
		body.name = "GroundCollision_%d_%d" % [chunk_x, chunk_z]
		body.collision_layer = 1
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		var collision_mesh: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
		collision_mesh.backface_collision = true
		shape.shape = collision_mesh
		body.add_child(shape)
		add_child(body)
		members.append(body)
	if stream_enabled:
		var decor: MeshInstance3D = _chunk_decoration(chunk_x, chunk_z)
		if decor != null:
			add_child(decor)
			members.append(decor)
	_loaded[key] = members

func _chunk_decoration(chunk_x: int, chunk_z: int) -> MeshInstance3D:
	# All grass, low shrubs and occasional trees generated deterministically
	# per chunk, sharing the atlas, so unloading a cell also removes its props.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, posmod(int(world_seed) + (chunk_x + 500) * 1789 + (chunk_z + 500) * 4931, 2147483647))
	var placed: int = 0
	for i in range(13):
		var x: float = rng.randf_range(float(chunk_x) + 0.5, float(chunk_x + CHUNK_SIZE) - 0.5)
		var z: float = rng.randf_range(float(chunk_z) + 0.5, float(chunk_z + CHUNK_SIZE) - 0.5)
		if absf(x) < 24.0 and absf(z) < 24.0:
			continue
		placed += 1
		var y: float = surface_y_at(x, z)
		if i == 0 and maxf(absf(x), absf(z)) > 28.0:
			PIXELS.box(st, Vector3(x, y + 0.73, z), Vector3(0.42, 1.42, 0.46), 8, 8)
			PIXELS.box(st, Vector3(x, y + 1.68, z), Vector3(1.4, 0.96, 1.44), 9, 10)
			PIXELS.box(st, Vector3(x, y + 2.3, z), Vector3(0.92, 0.66, 0.95), 1, 9)
		elif i % 3 == 0:
			PIXELS.box(st, Vector3(x, y + 0.17, z), Vector3(0.5, 0.31, 0.48), 9, 10)
		else:
			PIXELS.box(st, Vector3(x, y + 0.08, z), Vector3(0.1, 0.16, 0.12), 1, 9)
	if placed == 0:
		return null
	return PIXELS.as_instance(st, "ChunkDecor_%d_%d" % [chunk_x, chunk_z])

func _ground_tile(x: int, z: int) -> int:
	var pos := Vector2(float(x) + 0.5, float(z) + 0.5)
	var path_distance: float = minf(_distance_segment(pos, Vector2(-18, -1), Vector2(20, 2)),
		minf(_distance_segment(pos, Vector2(0, -21), Vector2(-1, 21)),
		_distance_segment(pos, Vector2(-1, -4), Vector2(6, 4))))
	var index: int = posmod(x * 137 + z * 113 + x * z * 7, 17)
	if maxf(absf(float(x)), absf(float(z))) < 23.0:
		if path_distance < 1.55:
			return 5 if index < 13 else 6
		if path_distance < 2.0 and index % 2 == 0:
			return 6
	if fields_enabled and maxf(absf(float(x)), absf(float(z))) >= 23.0:
		if index == 0:
			return 7
		if index >= 14:
			return 2
		if index <= 3:
			return 1
		return 0
	if index <= 2:
		return 1
	if index >= 14:
		return 2
	return 0

func _distance_segment(pos: Vector2, a: Vector2, b: Vector2) -> float:
	var segment: Vector2 = b - a
	var factor: float = clampf((pos - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return pos.distance_to(a + segment * factor)

func _make_cliff_rim() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-map_half - 9, map_half + 10, 3):
		for z in range(-map_half - 9, map_half + 10, 3):
			if absi(x) <= map_half and absi(z) <= map_half:
				continue
			var noise_height: float = _noise.get_noise_2d(float(x), float(z))
			var height: float = 2.4 + (noise_height + 1.0) * 1.6
			var raised: bool = noise_height > 0.12
			PIXELS.box(st, Vector3(float(x), (height - 2.0) * 0.5, float(z)),
				Vector3(3.0, height + 2.0, 3.0), 1 if raised else 0, 4 if raised else 3)
	add_child(PIXELS.as_instance(st, "SteppedDistanceCliffs"))

func _make_grass_detail() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 711
	for i in range(300 if fields_enabled else 90):
		var x: float = rng.randf_range(-float(map_half) + 2.0, float(map_half) - 2.0)
		var z: float = rng.randf_range(-float(map_half) + 2.0, float(map_half) - 2.0)
		if _ground_tile(int(floorf(x)), int(floorf(z))) in [5, 6]:
			continue
		if absf(x) < 4.0 and absf(z) < 4.0:
			continue
		var h: float = 0.11 + float(i % 4) * 0.035
		var y: float = surface_y_at(x, z)
		PIXELS.box(st, Vector3(x, y + h * 0.5 + 0.02, z), Vector3(0.10, h, 0.10), 1, 9)
		if i % 7 == 0:
			PIXELS.box(st, Vector3(x, y + h + 0.08, z), Vector3(0.17, 0.12, 0.17), 14, 14)
	add_child(PIXELS.as_instance(st, "VoxelWildflowers"))

func _make_fields_scenery() -> void:
	# Far-field vegetation is decorative and batched into ONE mesh draw call.
	# Individual harvestables/collisions belong to the future chunk streamer.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 1903
	for i in range(85):
		var x: float = rng.randf_range(-44.0, 44.0)
		var z: float = rng.randf_range(-44.0, 44.0)
		if maxf(absf(x), absf(z)) < 29.0:
			continue
		var y: float = surface_y_at(x, z)
		if i % 4 == 0:
			PIXELS.box(st, Vector3(x, y + 0.75, z), Vector3(0.45, 1.45, 0.48), 8, 8)
			PIXELS.box(st, Vector3(x, y + 1.7, z), Vector3(1.75, 1.0, 1.68), 9, 10)
			PIXELS.box(st, Vector3(x, y + 2.3, z), Vector3(1.2, 0.72, 1.35), 1, 9)
		elif i % 4 == 1:
			PIXELS.box(st, Vector3(x, y + 0.34, z), Vector3(1.0, 0.7, 0.92), 4, 3)
			PIXELS.box(st, Vector3(x + 0.27, y + 0.42, z - 0.16), Vector3(0.60, 0.80, 0.64), 7, 4)
		else:
			PIXELS.box(st, Vector3(x, y + 0.28, z), Vector3(0.88, 0.58, 0.82), 9, 10)
			PIXELS.box(st, Vector3(x + 0.28, y + 0.43, z), Vector3(0.75, 0.69, 0.85), 1, 9)
	add_child(PIXELS.as_instance(st, "FieldsBatchedScenery"))
