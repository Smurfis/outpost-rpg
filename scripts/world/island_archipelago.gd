extends Node3D
## Feature-branch-only remote island streamer. Never mutates the original
## Outpost chunks or its coastline. The far-ocean horizon supplies the water.
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const CAVES = preload("res://scripts/world/stepped_cave_tunnels.gd")
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const PROPS = preload("res://scripts/voxel/voxel_props.gd")
const WORLD_OBJECT = preload("res://scripts/interaction/world_object.gd")
const CHUNK: int = 12
const BUILD_BUDGET: int = 2
var terrain
var _loaded: Dictionary = {} # chunk origin -> meshes/collision/chest nodes
var _pending: Array[Vector2i] = []
var _center := Vector2i(99999, 99999)
var _roof_nodes: Array[MeshInstance3D] = []

func setup(world_seed: int) -> void:
	terrain = DATA.new(world_seed)
	name = "FractalArchipelago"

func _process(_delta: float) -> void:
	if terrain == null:
		return
	var game: Node = get_parent().get_parent()
	if game == null:
		return
	var hero: Node3D = game.get("hero")
	if hero == null:
		return
	var position: Vector3 = hero.global_position
	if not terrain.near_island(position):
		if not _loaded.is_empty():
			_clear_stream()
		return
	_queue_near(position)
	_build_pending()
	# A physics-independent isometric cutaway: cave ceilings and overlying
	# top faces fade out only while the hero is below the local surface.
	var xi: int = floori(position.x)
	var zi: int = floori(position.z)
	var cave_floor: int = terrain.caves.floor_at(xi, zi)
	var underground: bool = cave_floor != CAVES.INVALID_FLOOR and position.y < float(terrain.height_at(xi, zi)) - 0.8
	for roof in _roof_nodes:
		if is_instance_valid(roof):
			roof.visible = not underground

func is_land_at(x: float, z: float) -> bool:
	return terrain != null and terrain.is_land_at(x, z)

func map_cell_at(x: int, z: int) -> Dictionary:
	return terrain.map_cell_at(x, z) if terrain != null else {}

func height_at(x: int, z: int) -> float:
	return float(terrain.height_at(x, z)) if terrain != null else -5.0

func loaded_chunk_count() -> int:
	return _loaded.size()

func _active_radius() -> int:
	return 3 if OS.has_feature("mobile") else 4

func _cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / float(CHUNK)) * CHUNK,
		floori(point.z / float(CHUNK)) * CHUNK)

func _queue_near(point: Vector3) -> void:
	var center: Vector2i = _cell_at(point)
	if center == _center:
		return
	_center = center
	var wanted: Dictionary = {}
	var candidates: Array[Vector2i] = []
	for dx in range(-_active_radius(), _active_radius() + 1):
		for dz in range(-_active_radius(), _active_radius() + 1):
			var cell: Vector2i = center + Vector2i(dx, dz) * CHUNK
			if not terrain.chunk_near_land(cell.x, cell.y, CHUNK):
				continue
			wanted[cell] = true
			if not _loaded.has(cell):
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	_pending = candidates
	for key in _loaded.keys():
		if not wanted.has(key):
			_unload(key)

func _build_pending() -> void:
	for _i in range(mini(BUILD_BUDGET, _pending.size())):
		var key: Vector2i = _pending.pop_front()
		if not _loaded.has(key):
			_build_chunk(key)

func _clear_stream() -> void:
	_pending.clear()
	for key in _loaded.keys():
		_unload(key)
	_center = Vector2i(99999, 99999)

func _unload(key: Vector2i) -> void:
	var members: Array = _loaded.get(key, [])
	for node in members:
		if node != null and is_instance_valid(node):
			if node is MeshInstance3D:
				_roof_nodes.erase(node)
			node.queue_free()
	_loaded.erase(key)

func _emit_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tile: int, axes: String) -> void:
	GREEDY.tiled_quad(st, a, b, c, d, tile, axes)

func _build_chunk(key: Vector2i) -> void:
	# Cull invisible interior voxels. The same world-coordinate occupancy
	# sample is used on chunk boundaries, so seams cannot expose rock faces.
	var surface := SurfaceTool.new()
	var roof := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var surface_faces: int = 0
	var roof_faces: int = 0
	for x in range(key.x, key.x + CHUNK):
		for z in range(key.y, key.y + CHUNK):
			var top: int = terrain.height_at(x, z)
			var cave_here: bool = terrain.caves.has_cave(x, z)
			if cave_here:
				top = maxi(top, terrain.caves.floor_at(x, z)) # Include guaranteed stone step foundations.
			if top <= DATA.BEDROCK:
				continue
			for y in range(DATA.BEDROCK, top):
				if not terrain.is_solid(x, y, z):
					continue
				var xf: float = float(x)
				var yf: float = float(y)
				var zf: float = float(z)
				var tile: int = terrain.top_tile(x, z) if y == top - 1 else 4
				if not terrain.is_solid(x, y + 1, z):
					var cutaway: bool = cave_here and y + 1 == top and terrain.caves.floor_at(x, z) < top - 1
					var st: SurfaceTool = roof if cutaway else surface
					_emit_face(st, Vector3(xf, yf + 1, zf), Vector3(xf, yf + 1, zf + 1),
						Vector3(xf + 1, yf + 1, zf + 1), Vector3(xf + 1, yf + 1, zf), tile, "top")
					if cutaway:
						roof_faces += 1
					else:
						surface_faces += 1
				if not terrain.is_solid(x, y - 1, z):
					var st: SurfaceTool = roof if cave_here else surface
					_emit_face(st, Vector3(xf, yf, zf + 1), Vector3(xf, yf, zf),
						Vector3(xf + 1, yf, zf), Vector3(xf + 1, yf, zf + 1), 4, "top")
					if cave_here:
						roof_faces += 1
					else:
						surface_faces += 1
				if not terrain.is_solid(x + 1, y, z):
					_emit_face(surface, Vector3(xf + 1, yf, zf + 1), Vector3(xf + 1, yf, zf),
						Vector3(xf + 1, yf + 1, zf), Vector3(xf + 1, yf + 1, zf + 1), 4, "x")
					surface_faces += 1
				if not terrain.is_solid(x - 1, y, z):
					_emit_face(surface, Vector3(xf, yf, zf), Vector3(xf, yf, zf + 1),
						Vector3(xf, yf + 1, zf + 1), Vector3(xf, yf + 1, zf), 4, "x")
					surface_faces += 1
				if not terrain.is_solid(x, y, z + 1):
					_emit_face(surface, Vector3(xf, yf, zf + 1), Vector3(xf + 1, yf, zf + 1),
						Vector3(xf + 1, yf + 1, zf + 1), Vector3(xf, yf + 1, zf + 1), 4, "z")
					surface_faces += 1
				if not terrain.is_solid(x, y, z - 1):
					_emit_face(surface, Vector3(xf + 1, yf, zf), Vector3(xf, yf, zf),
						Vector3(xf, yf + 1, zf), Vector3(xf + 1, yf + 1, zf), 4, "z")
					surface_faces += 1
	var members: Array = []
	var meshed: Array[MeshInstance3D] = []
	if surface_faces > 0:
		var ground := MeshInstance3D.new()
		ground.name = "IslandRock_%d_%d" % [key.x, key.y]
		ground.mesh = PALETTE.create_mesh(surface)
		ground.material_override = GREEDY.material()
		add_child(ground)
		members.append(ground)
		meshed.append(ground)
	if roof_faces > 0:
		var lid := MeshInstance3D.new()
		lid.name = "CaveCutaway_%d_%d" % [key.x, key.y]
		lid.mesh = PALETTE.create_mesh(roof)
		lid.material_override = GREEDY.material()
		add_child(lid)
		members.append(lid)
		meshed.append(lid)
		_roof_nodes.append(lid)
	if not meshed.is_empty():
		var body := StaticBody3D.new()
		body.name = "IslandCollision_%d_%d" % [key.x, key.y]
		body.collision_layer = 1
		body.collision_mask = 1
		for mesh in meshed:
			var collider := CollisionShape3D.new()
			collider.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(collider)
		add_child(body)
		members.append(body)
	# The cavern chest uses the existing persistent loot contract.
	var game: Node = get_parent().get_parent()
	for index in range(terrain.caves.chests.size()):
		var at: Vector3 = terrain.caves.chests[index]
		if at.x < key.x or at.x >= key.x + CHUNK or at.z < key.y or at.z >= key.y + CHUNK:
			continue
		var chest := WORLD_OBJECT.new()
		chest.name = "IslandCaveChest_%d" % index
		chest.position = at + Vector3(0.0, 0.08, 0.0)
		add_child(chest)
		chest.setup(game, "island_cave_%d_%d" % [terrain.seed, index],
			"Cavern cache", "chest", PROPS.crate(), {"stone": 3, "iron": 1})
		members.append(chest)
	_loaded[key] = members
