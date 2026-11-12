extends Node3D
## Walkable, chunked voxel Fields biome. The existing Outpost clearing stays
## level and traversable; seeded Perlin noise forms one-voxel terraces outside.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")
const VOXEL_PROPS = preload("res://scripts/voxel/voxel_props.gd")
const FOLIAGE = preload("res://scripts/voxel/foliage_renderer.gd")
const HARVESTABLE = preload("res://scripts/resource_node.gd")
const WILD_BOAR = preload("res://scripts/enemy.gd")
const WATER_SHADER = preload("res://scripts/voxel/coastal_water.gdshader")
const ARCHIPELAGO = preload("res://scripts/world/island_archipelago.gd")
const SEA_LEVEL: float = -2.82
const SEABED_LEVEL: float = -4.20
const CHUNK_SIZE: int = 12
const MAP_HALF: int = 23
const FIELDS_MAP_HALF: int = 48
const STREAM_MAP_HALF: int = 96
const OCEAN_SWIM_HALF: float = 384.0 # Beyond island terrain, swimmer remains buoyant
const OCEAN_VISUAL_EXTENT: float = 4096.0 # Far beyond orthographic 120m clip
const OCEAN_HORIZON_MARGIN: float = 28.0
const STREAM_RADIUS: int = 3 # Keep 7x7 neighbour chunks around the active player
const CHUNK_CREATION_BUDGET: int = 2 # Avoid building all terrain in one frame.
const MOBILE_STREAM_RADIUS: int = 2 # 5x5 around the player on weaker Android GPUs.
const SAFE_CLEARING_RADIUS: float = 23.0
const HEIGHT_BLEND_BAND: float = 12.0
const MAX_ELEVATION: float = 3.0
# Signed coastal distance drives all height, shore texture and decoration masks.
const WET_SAND_BAND: float = 2.2
const DRY_SAND_BAND: float = 5.8
const SAND_GRASS_BAND: float = 9.3
const COAST_BLEND_END: float = 12.0
const TILE_DRY_SAND: int = 16
const TILE_WET_SAND: int = 17
const TILE_GRASS_SAND: int = 18
const TILE_COAST_SOIL: int = 19

var map_half: int = MAP_HALF
var map_world_half: int = MAP_HALF # Map can see remote islands while home terrain stays +/-96.
var archipelago
var fields_enabled: bool = false
var world_seed: int = 64012
var _noise: FastNoiseLite
var chunk_meshes: Array[MeshInstance3D] = []
var _shared_water_material: ShaderMaterial
var _distant_ocean: MeshInstance3D
var stream_enabled: bool = false
var _stream_center: Vector2i = Vector2i(99999, 99999)
var _loaded: Dictionary = {} # Vector2i cell -> [mesh, collider, decoration]
var defer_streaming: bool = false
var _pending_chunks: Array[Vector2i] = []
var _initial_total: int = 0
var _initial_built: int = 0
var _initial_completed: bool = true

func build(enable_fields: bool = false, seed: int = 64012, enable_streaming: bool = false, defer_initial_chunks: bool = false, enable_archipelago: bool = false) -> void:
	name = "VoxelAtmosphere"
	fields_enabled = enable_fields
	stream_enabled = enable_fields and enable_streaming
	defer_streaming = stream_enabled and defer_initial_chunks
	_pending_chunks.clear()
	_initial_total = 0
	_initial_built = 0
	_initial_completed = not defer_streaming
	map_half = STREAM_MAP_HALF if stream_enabled else FIELDS_MAP_HALF if fields_enabled else MAP_HALF
	map_world_half = 384 if stream_enabled and enable_archipelago else map_half
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
	if stream_enabled:
		_make_water_horizon()
		if enable_archipelago:
			archipelago = ARCHIPELAGO.new()
			add_child(archipelago)
			archipelago.setup(world_seed)
	else:
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
	# The original square/circular height band made a one-block wall when
	# walking *out* of the camp, even though perspective made it look lower.
	# Keep the full starter clearing level, then roll gently DOWN into fields.
	var outside: float = maxf(0.0, maxf(absf(x), absf(z)) - SAFE_CLEARING_RADIUS)
	if outside <= 0.0:
		return -0.055
	var edge_warp: float = _noise.get_noise_2d(x * 0.57 + 147.0, z * 0.57 - 93.0) * 5.5
	var blend: float = clampf((outside + edge_warp * clampf(outside / HEIGHT_BLEND_BAND, 0.0, 1.0)) / HEIGHT_BLEND_BAND, 0.0, 1.0)
	blend = blend * blend * (3.0 - 2.0 * blend)
	var sample: float = _noise.get_noise_2d(floorf(x) + 0.5, floorf(z) + 0.5)
	var descent: float = (-1.45 + sample * 1.35) * blend
	return -0.055 + clampf(roundf(descent), -3.0, 0.0)

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
	_update_water_horizon(point)
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

func _active_radius() -> int:
	return MOBILE_STREAM_RADIUS if OS.has_feature("mobile") else STREAM_RADIUS

func _queue_streaming_for(point: Vector3) -> void:
	if absf(point.x) >= float(map_half) or absf(point.z) >= float(map_half):
		return
	var center: Vector2i = _cell_at(point)
	if center == _stream_center:
		return
	_stream_center = center
	var wanted: Dictionary = {}
	var candidates: Array[Vector2i] = []
	for dx in range(-_active_radius(), _active_radius() + 1):
		for dz in range(-_active_radius(), _active_radius() + 1):
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
		_unregister_streamed_portal(cell)
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
	for dx in range(-_active_radius(), _active_radius() + 1):
		for dz in range(-_active_radius(), _active_radius() + 1):
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
		_unregister_streamed_portal(cell)
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

func _coast_margin(x: float, z: float) -> float:
	# Positive inland, negative offshore. Rotation-independent sampled world
	# coordinates ensure deterministic tiles, physical heights and collisions.
	if not stream_enabled:
		return minf(float(map_half) - absf(x), float(map_half) - absf(z))
	var distance: float = pow(pow(absf(x), 4.0) + pow(absf(z), 4.0), 0.25)
	var angle: float = atan2(z, x)
	var reach: float = float(map_half) - 4.0
	reach += 4.0 * sin(3.0 * angle + 0.5)
	reach += 3.0 * sin(7.0 * angle - 0.3)
	reach += 2.0 * sin(5.0 * angle + 1.1)
	if _noise != null:
		reach += 2.0 * _noise.get_noise_2d(x * 0.65 + 240.0, z * 0.65 - 180.0)
	reach = minf(reach, float(map_half) - 2.2)
	return minf(reach - distance,
		minf(float(map_half) - 1.0 - absf(x), float(map_half) - 1.0 - absf(z)))

func is_land_at(x: float, z: float) -> bool:
	return _coast_margin(x, z) > 0.0 or (archipelago != null and archipelago.is_land_at(x, z))

func _land_cell(x: int, z: int) -> bool:
	return _coast_margin(float(x) + 0.5, float(z) + 0.5) > 0.0

func coast_zone_at(x: float, z: float) -> String:
	if not stream_enabled:
		return "inland"
	var margin: float = _coast_margin(x, z)
	if margin <= 0.0:
		return "water"
	if margin < WET_SAND_BAND:
		return "wet_sand"
	if margin < DRY_SAND_BAND:
		return "dry_sand"
	if margin < SAND_GRASS_BAND:
		return "grass_sand"
	if margin < COAST_BLEND_END:
		return "coastal_soil"
	return "inland"

func map_cell_at(x: int, z: int) -> Dictionary:
	# Map consumers use the same cell heights and material choices as the
	# terrain mesher. An empty result means no generated terrain exists here.
	if x < -map_half or x >= map_half or z < -map_half or z >= map_half:
		if archipelago != null and absi(x) < map_world_half and absi(z) < map_world_half:
			return archipelago.map_cell_at(x, z)
		return {}
	var zone: String = coast_zone_at(float(x) + 0.5, float(z) + 0.5)
	var ground_height: float = _tile_height(x, z)
	return {
		"height": SEA_LEVEL if zone == "water" else ground_height,
		"ground_height": ground_height,
		"ground_tile": _ground_tile(x, z),
		"zone": zone,
	}

func _tile_height(x: int, z: int) -> float:
	var px: float = float(x) + 0.5
	var pz: float = float(z) + 0.5
	var margin: float = _coast_margin(px, pz)
	if stream_enabled and margin <= 0.0:
		# Sloping seabed remains below the solid opaque ocean mesh.
		return SEA_LEVEL - 0.38 - minf(-margin, 9.0) * 0.155
	var baseline: float = surface_y_at(px, pz)
	if not stream_enabled:
		return baseline
	# Clamp the sparse lowest inland steps to keep all playable terrain
	# ABOVE the opaque ocean. Original camp and quantized steps unchanged.
	var dry_inland: float = maxf(baseline, -2.055)
	if margin >= COAST_BLEND_END:
		return dry_inland
	# Continuous beach rise from surf to dry sand, dune and grassy slope.
	# Heights are shared by the rendered triangles and collision meshes.
	var beach_height: float = SEA_LEVEL + 0.28 + margin * 0.16
	return lerpf(beach_height, dry_inland, smoothstep(7.0, COAST_BLEND_END, margin))

func _cliff_tile(x: int, z: int) -> int:
	return TILE_DRY_SAND if stream_enabled and _coast_margin(float(x) + 0.5, float(z) + 0.5) < SAND_GRASS_BAND else 3


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
						if not is_equal_approx(high, next_high) or not is_equal_approx(adjacent, next_low) or _cliff_tile(x, z) != _cliff_tile(x, stop):
							break
						stop += 1
					var plane_x: float = float(x + 1 if side == "east" else x)
					if side == "east":
						GREEDY.tiled_quad(st, Vector3(plane_x, adjacent, stop), Vector3(plane_x, adjacent, z), Vector3(plane_x, high, z), Vector3(plane_x, high, stop), _cliff_tile(x, z), "x")
					else:
						GREEDY.tiled_quad(st, Vector3(plane_x, adjacent, z), Vector3(plane_x, adjacent, stop), Vector3(plane_x, high, stop), Vector3(plane_x, high, z), _cliff_tile(x, z), "x")
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
						if not is_equal_approx(high, next_high) or not is_equal_approx(adjacent, next_low) or _cliff_tile(x, z) != _cliff_tile(stop, z):
							break
						stop += 1
					var plane_z: float = float(z + 1 if side == "south" else z)
					if side == "south":
						GREEDY.tiled_quad(st, Vector3(x, adjacent, plane_z), Vector3(stop, adjacent, plane_z), Vector3(stop, high, plane_z), Vector3(x, high, plane_z), _cliff_tile(x, z), "z")
					else:
						GREEDY.tiled_quad(st, Vector3(stop, adjacent, plane_z), Vector3(x, adjacent, plane_z), Vector3(x, high, plane_z), Vector3(stop, high, plane_z), _cliff_tile(x, z), "z")
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
		# Water surfaces stream with the same 12x12 tiles as their seabed.
		# The former giant 352x352 plane was visible through unbuilt terrain
		# from camp and extended over unsupported ocean beyond the map.
		var ocean: MeshInstance3D = _chunk_water_surface(chunk_x, chunk_z)
		if ocean != null:
			add_child(ocean)
			members.append(ocean)
		var decor: MeshInstance3D = _chunk_decoration(chunk_x, chunk_z)
		if decor != null:
			add_child(decor)
			members.append(decor)
		# Tree silhouettes are a separate single-surface batch, not one node per tree.
		var foliage: MeshInstance3D = _chunk_foliage(chunk_x, chunk_z)
		if foliage != null:
			add_child(foliage)
			members.append(foliage)
		var surf: MeshInstance3D = _shore_foam(chunk_x, chunk_z)
		if surf != null:
			add_child(surf)
			members.append(surf)
		var interactables: Node3D = _spawn_chunk_interactables(chunk_x, chunk_z)
		if interactables != null:
			members.append(interactables)
	_loaded[key] = members
	_register_streamed_portal(chunk_x, chunk_z)

func _register_streamed_portal(chunk_x: int, chunk_z: int) -> void:
	# Real Play sessions stream discoverable dungeon gates outside the camp.
	# Direct-scene legacy tests retain the five predictable preview portals.
	if not defer_streaming or not stream_enabled:
		return
	var sample: int = posmod((chunk_x + 101) * 37 + (chunk_z + 101) * 43 + world_seed, 13)
	if sample != 0:
		return
	var x: float = float(chunk_x) + float(CHUNK_SIZE) * 0.5
	var z: float = float(chunk_z) + float(CHUNK_SIZE) * 0.5
	if maxf(absf(x), absf(z)) < 32.0 or not is_land_at(x, z):
		return
	var game: Node = get_parent()
	if game == null:
		return
	var dungeons: Node = game.get_node_or_null("Dungeons")
	if dungeons == null or not dungeons.has_method("register_chunk"):
		return
	var key: String = "fields_%d_%d" % [chunk_x, chunk_z]
	var distance: float = maxf(absf(x), absf(z))
	var tier: int = 0 if distance < 48.0 else 1 if distance < 72.0 else 2
	var entry: Vector3 = Vector3(x, surface_y_at(x, z) + 0.055, z)
	dungeons.register_chunk(key, Rect2(Vector2(float(chunk_x), float(chunk_z)), Vector2(CHUNK_SIZE, CHUNK_SIZE)), tier, [entry], false)

func _unregister_streamed_portal(cell: Vector2i) -> void:
	var game: Node = get_parent()
	if game == null:
		return
	var dungeons: Node = game.get_node_or_null("Dungeons")
	if dungeons != null and dungeons.has_method("unregister_chunk"):
		dungeons.unregister_chunk("fields_%d_%d" % [cell.x, cell.y])

func _spawn_chunk_interactables(chunk_x: int, chunk_z: int) -> Node3D:
	var game: Node = get_parent()
	if game == null or not game.has_method("spawn_resource"):
		return null
	var container := Node3D.new()
	container.name = "ChunkInteractables_%d_%d" % [chunk_x, chunk_z]
	add_child(container)
	var kinds: Array[String] = ["wood", "wood", "stone", "fiber", "berries", "iron", "coal", "clay", "herbs", "mushrooms", "reeds"]
	# Global six-metre cells have enough separation even across chunk borders.
	# Coordinate-derived seeds mean stream/load order never changes candidates.
	for x in range(chunk_x + 3, chunk_x + CHUNK_SIZE, 6):
		for z in range(chunk_z + 3, chunk_z + CHUNK_SIZE, 6):
			if maxf(absf(x), absf(z)) < 27.0 or _coast_margin(x, z) < SAND_GRASS_BAND:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(world_seed * 43 + x * 2257 + z * 4861)
			var site := Vector3(x + rng.randf_range(-0.25, 0.25), 0, z + rng.randf_range(-0.25, 0.25))
			var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
			var count: int = rng.randi_range(2, 3) if rng.randf() < 0.20 else 1
			# Reserve the possible portal footprint regardless of load order.
			var center := Vector2(chunk_x + CHUNK_SIZE * 0.5, chunk_z + CHUNK_SIZE * 0.5)
			var has_gate: bool = posmod((chunk_x + 101) * 37 + (chunk_z + 101) * 43 + world_seed, 13) == 0
			if has_gate and Vector2(site.x, site.z).distance_to(center) < 3.5 + game.PLACEMENT.radius_for(kind, count):
				continue
			game.spawn_resource(container, kind, site, count)
	# One shallow, shore-reachable pool per coastal chunk. Shrimp are the
	# first fish; deep ocean never spawns an unreachable fishing target.
	var pool_placed: bool = false
	if stream_enabled:
		for x in range(chunk_x + 1, chunk_x + CHUNK_SIZE - 1):
			for z in range(chunk_z + 1, chunk_z + CHUNK_SIZE - 1):
				var margin: float = _coast_margin(x + 0.5, z + 0.5)
				if margin < -1.2 or margin > -0.1 or pool_placed:
					continue
				var node = game.spawn_resource(container, "shrimp", Vector3(x + 0.5, SEA_LEVEL, z + 0.5))
				pool_placed = node != null
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(world_seed + chunk_x * 731 + chunk_z * 193)
	var hero = game.get("hero")
	var center := Vector3(chunk_x + 6, 0, chunk_z + 6)
	if hero != null and rng.randf() < 0.19 and maxf(absf(center.x), absf(center.z)) > 32 and _coast_margin(center.x, center.z) >= SAND_GRASS_BAND and game.prop_placement.available(center, 0.7):
		var boar = WILD_BOAR.new()
		container.add_child(boar)
		center.y = _tile_height(floori(center.x), floori(center.z)) + 0.08
		boar.setup(game, hero, center)
	if container.get_child_count() == 0:
		container.queue_free()
		return null
	return container

func _chunk_decoration(_chunk_x: int, _chunk_z: int) -> MeshInstance3D:
	# Resource-shaped scenery now belongs to the harvestable population.
	return null

func _chunk_foliage(_chunk_x: int, _chunk_z: int) -> MeshInstance3D:
	# Avoid a second, unharvestable copy of visible trees.
	return null

func _shore_foam_vertex(st: SurfaceTool, point: Vector2, opacity: float) -> void:
	# Cool-blue, low-alpha surf. Keeping the strip faint prevents a solid
	# white border along every square of the voxel coastline.
	st.set_color(Color(0.55, 0.79, 0.94, opacity))
	st.add_vertex(Vector3(point.x, SEA_LEVEL + 0.035, point.y))


func _append_shore_foam_edge(st: SurfaceTool, edge_start: Vector2, edge_end: Vector2,
		water_direction: Vector2, x: int, z: int, side: int,
		taper_start: bool, taper_end: bool) -> void:
	# Fade the strip at perpendicular shoreline joins. Otherwise two
	# translucent foam faces overlap at an inside corner and make bright
	# triangular wedges, even when the underlying water mesh is complete.
	const SEGMENTS: int = 3
	for segment in range(SEGMENTS):
		var t0: float = float(segment) / float(SEGMENTS)
		var t1: float = float(segment + 1) / float(SEGMENTS)
		var shore_a: Vector2 = edge_start.lerp(edge_end, t0) + water_direction * 0.008
		var shore_b: Vector2 = edge_start.lerp(edge_end, t1) + water_direction * 0.008
		var seed_a: int = posmod(x * 17 + z * 29 + side * 13 + segment * 7, 6)
		var seed_b: int = posmod(x * 17 + z * 29 + side * 13 + (segment + 1) * 7, 6)
		var width_a: float = 0.10 + 0.017 * float(seed_a)
		var width_b: float = 0.10 + 0.017 * float(seed_b)
		var alpha_a: float = 0.16 + 0.023 * float(seed_a)
		var alpha_b: float = 0.16 + 0.023 * float(seed_b)
		if taper_start and segment == 0:
			alpha_a = 0.0
		if taper_end and segment == SEGMENTS - 1:
			alpha_b = 0.0
		var water_a: Vector2 = shore_a + water_direction * width_a
		var water_b: Vector2 = shore_b + water_direction * width_b
		_shore_foam_vertex(st, shore_a, alpha_a)
		_shore_foam_vertex(st, shore_b, alpha_b)
		_shore_foam_vertex(st, water_b, 0.0)
		_shore_foam_vertex(st, shore_a, alpha_a)
		_shore_foam_vertex(st, water_b, 0.0)
		_shore_foam_vertex(st, water_a, 0.0)


func _shore_foam(chunk_x: int, chunk_z: int) -> MeshInstance3D:
	# Keep a subtle, feathered surf strip on genuine land/water edges only.
	# Neighbour checks use the same discrete cells as terrain and ocean meshes.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge_count: int = 0
	for x in range(chunk_x, mini(chunk_x + CHUNK_SIZE, map_half)):
		for z in range(chunk_z, mini(chunk_z + CHUNK_SIZE, map_half)):
			if _land_cell(x, z):
				continue
			var east_land: bool = _land_cell(x + 1, z)
			var west_land: bool = _land_cell(x - 1, z)
			var south_land: bool = _land_cell(x, z + 1)
			var north_land: bool = _land_cell(x, z - 1)
			if east_land:
				_append_shore_foam_edge(st, Vector2(x + 1, z), Vector2(x + 1, z + 1),
					Vector2(-1, 0), x, z, 0, north_land, south_land)
				edge_count += 1
			if west_land:
				_append_shore_foam_edge(st, Vector2(x, z), Vector2(x, z + 1),
					Vector2(1, 0), x, z, 1, north_land, south_land)
				edge_count += 1
			if south_land:
				_append_shore_foam_edge(st, Vector2(x, z + 1), Vector2(x + 1, z + 1),
					Vector2(0, -1), x, z, 2, west_land, east_land)
				edge_count += 1
			if north_land:
				_append_shore_foam_edge(st, Vector2(x, z), Vector2(x + 1, z),
					Vector2(0, 1), x, z, 3, west_land, east_land)
				edge_count += 1
	if edge_count == 0:
		return null
	var foam := MeshInstance3D.new()
	foam.name = "ShoreFoam_%d_%d" % [chunk_x, chunk_z]
	st.generate_normals()
	foam.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	foam.material_override = material
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return foam


func _ground_tile(x: int, z: int) -> int:
	if stream_enabled:
		var margin: float = _coast_margin(float(x) + 0.5, float(z) + 0.5)
		if margin <= 0.0:
			return 4 # Underwater stone floor.
		if margin < WET_SAND_BAND:
			return TILE_WET_SAND
		if margin < DRY_SAND_BAND:
			return TILE_DRY_SAND
		if margin < SAND_GRASS_BAND:
			return TILE_GRASS_SAND
		if margin < COAST_BLEND_END:
			return TILE_COAST_SOIL
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

func _water_material() -> ShaderMaterial:
	if _shared_water_material == null:
		_shared_water_material = ShaderMaterial.new()
		_shared_water_material.shader = WATER_SHADER
	return _shared_water_material


func _append_pixel_water_vertex(st: SurfaceTool, at: Vector3, shallow_amount: float) -> void:
	# All six vertices of a flooded cell share one shore tint. Per-corner
	# interpolation caused diagonal turquoise wedges along coastline tiles.
	st.set_color(Color(shallow_amount, 0.0, 0.0, 1.0))
	st.add_vertex(at)


func _chunk_water_surface(chunk_x: int, chunk_z: int) -> MeshInstance3D:
	# Use the EXACT tile mask as the visible ground, seabed and collision.
	# The previous continuous is_land_at() tests rejected individual water
	# triangles within a flooded tile, exposing dark seabed in triangular
	# notches along straight shores, inside corners and streamed chunk edges.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	for x in range(chunk_x, mini(chunk_x + CHUNK_SIZE, map_half)):
		for z in range(chunk_z, mini(chunk_z + CHUNK_SIZE, map_half)):
			if _land_cell(x, z):
				continue
			var a := Vector3(float(x), 0.0, float(z))
			var b := Vector3(float(x), 0.0, float(z + 1))
			var c := Vector3(float(x + 1), 0.0, float(z + 1))
			var d := Vector3(float(x + 1), 0.0, float(z))
			var offshore_distance: float = maxf(0.0,
				-_coast_margin(float(x) + 0.5, float(z) + 0.5))
			var shallow_amount: float = 1.0 - smoothstep(0.0, 5.2, offshore_distance)
			for vertex in [a, b, c, a, c, d]:
				_append_pixel_water_vertex(st, vertex, shallow_amount)
			count += 2
	if count == 0:
		return null
	var surface := MeshInstance3D.new()
	surface.name = "OceanSurface_%d_%d" % [chunk_x, chunk_z]
	surface.mesh = st.commit()
	surface.position.y = SEA_LEVEL
	surface.material_override = _water_material()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return surface


func _add_deep_ocean_quad(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float) -> void:
	# Exactly the same upward-facing winding and shader as the nearby water.
	# All four large strips lie OUTSIDE the streamed island square, never
	# across unloaded inland terrain. The central hole is kept completely dry.
	var a := Vector3(x0, 0.0, z0)
	var b := Vector3(x0, 0.0, z1)
	var c := Vector3(x1, 0.0, z1)
	var d := Vector3(x1, 0.0, z0)
	for vertex in [a, b, c, a, c, d]:
		# Far offshore is deep-blue only; shallow tint comes from true
		# streamed coastline cells so the seam stays clean.
		st.set_color(Color(0.0, 0.0, 0.0, 1.0))
		st.add_vertex(vertex)


func _make_water_horizon() -> void:
	# Endless-looking ocean must NEVER reuse the previous solid 352x352
	# overlay across the camp. Four wide surrounding strips instead of a
	# gigantic plane with land underneath = zero inland sea bleed.
	var sea := MeshInstance3D.new()
	sea.name = "DistantWaterHorizon"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: float = float(map_half)
	var far: float = OCEAN_VISUAL_EXTENT
	_add_deep_ocean_quad(st, -far, -edge, -far, far)  # west
	_add_deep_ocean_quad(st, edge, far, -far, far)    # east
	_add_deep_ocean_quad(st, -edge, edge, -far, -edge) # north
	_add_deep_ocean_quad(st, -edge, edge, edge, far)  # south
	sea.mesh = st.commit()
	sea.position.y = SEA_LEVEL
	sea.material_override = _water_material()
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.visible = false
	add_child(sea)
	_distant_ocean = sea


func _update_water_horizon(point: Vector3) -> void:
	if _distant_ocean == null:
		return
	# Only switch on near the true procedural coastline or out at sea.
	# Camp begins around 90m inland; its distant invisible chunks stay dry.
	# Private dungeons are outside the swimmable extent and remain isolated.
	var in_ocean_world: bool = absf(point.x) < OCEAN_SWIM_HALF and absf(point.z) < OCEAN_SWIM_HALF
	_distant_ocean.visible = in_ocean_world and _coast_margin(point.x, point.z) < OCEAN_HORIZON_MARGIN

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
	for x in range(-48, 48, CHUNK_SIZE):
		for z in range(-48, 48, CHUNK_SIZE):
			_spawn_chunk_interactables(x, z)

