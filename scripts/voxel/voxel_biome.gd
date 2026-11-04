extends Node3D
## Walkable, chunked voxel Fields biome. The existing Outpost clearing stays
## level and traversable; seeded Perlin noise forms one-voxel terraces outside.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const CHUNK_SIZE: int = 12
const MAP_HALF: int = 23
const FIELDS_MAP_HALF: int = 48
const STREAM_MAP_HALF: int = 96
const STREAM_RADIUS: int = 3 # Keep 7x7 neighbour chunks around the active player
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

func build(enable_fields: bool = false, seed: int = 64012, enable_streaming: bool = false) -> void:
	name = "VoxelAtmosphere"
	fields_enabled = enable_fields
	stream_enabled = enable_fields and enable_streaming
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
	update_streaming_for(point)

func _cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / float(CHUNK_SIZE)) * CHUNK_SIZE,
		floori(point.z / float(CHUNK_SIZE)) * CHUNK_SIZE)

func update_streaming_for(point: Vector3) -> void:
	if not stream_enabled:
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

func _build_ground_chunk(chunk_x: int, chunk_z: int) -> void:
	var key: Vector2i = Vector2i(chunk_x, chunk_z)
	if _loaded.has(key):
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(chunk_x, mini(chunk_x + CHUNK_SIZE, map_half)):
		for z in range(chunk_z, mini(chunk_z + CHUNK_SIZE, map_half)):
			var x0: float = float(x)
			var z0: float = float(z)
			var x1: float = x0 + 1.0
			var z1: float = z0 + 1.0
			var height: float = surface_y_at(x0 + 0.5, z0 + 0.5)
			PIXELS.quad(st,
				Vector3(x0, height, z0), Vector3(x0, height, z1),
				Vector3(x1, height, z1), Vector3(x1, height, z0),
				_ground_tile(x, z))
			# Exposed faces use the same heights even when the neighbour has
			# not been loaded yet: no seam when a chunk later streams in.
			var east: float = surface_y_at(x1 + 0.5, z0 + 0.5) if x < map_half - 1 else -2.2
			var west: float = surface_y_at(x0 - 0.5, z0 + 0.5) if x > -map_half else -2.2
			var south: float = surface_y_at(x0 + 0.5, z1 + 0.5) if z < map_half - 1 else -2.2
			var north: float = surface_y_at(x0 + 0.5, z0 - 0.5) if z > -map_half else -2.2
			if east < height - 0.01:
				PIXELS.quad(st, Vector3(x1, east, z1), Vector3(x1, east, z0), Vector3(x1, height, z0), Vector3(x1, height, z1), 3)
			if west < height - 0.01:
				PIXELS.quad(st, Vector3(x0, west, z0), Vector3(x0, west, z1), Vector3(x0, height, z1), Vector3(x0, height, z0), 3)
			if south < height - 0.01:
				PIXELS.quad(st, Vector3(x0, south, z1), Vector3(x1, south, z1), Vector3(x1, height, z1), Vector3(x0, height, z1), 3)
			if north < height - 0.01:
				PIXELS.quad(st, Vector3(x1, north, z0), Vector3(x0, north, z0), Vector3(x0, height, z0), Vector3(x1, height, z0), 3)
	var mesh: MeshInstance3D = PIXELS.as_instance(st, "GroundChunk_%d_%d" % [chunk_x, chunk_z])
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
	for i in range(13):
		var x: float = rng.randf_range(float(chunk_x) + 0.5, float(chunk_x + CHUNK_SIZE) - 0.5)
		var z: float = rng.randf_range(float(chunk_z) + 0.5, float(chunk_z + CHUNK_SIZE) - 0.5)
		if absf(x) < 24.0 and absf(z) < 24.0:
			continue
		var y: float = surface_y_at(x, z)
		if i == 0 and maxf(absf(x), absf(z)) > 28.0:
			PIXELS.box(st, Vector3(x, y + 0.73, z), Vector3(0.42, 1.42, 0.46), 8, 8)
			PIXELS.box(st, Vector3(x, y + 1.68, z), Vector3(1.4, 0.96, 1.44), 9, 10)
			PIXELS.box(st, Vector3(x, y + 2.3, z), Vector3(0.92, 0.66, 0.95), 1, 9)
		elif i % 3 == 0:
			PIXELS.box(st, Vector3(x, y + 0.17, z), Vector3(0.5, 0.31, 0.48), 9, 10)
		else:
			PIXELS.box(st, Vector3(x, y + 0.08, z), Vector3(0.1, 0.16, 0.12), 1, 9)
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
