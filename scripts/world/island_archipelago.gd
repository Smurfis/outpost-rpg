extends Node3D
## Feature-branch-only remote island streamer. Never mutates the original
## Outpost chunks or its coastline. The far-ocean horizon supplies the water.
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const CAVES = preload("res://scripts/world/stepped_cave_tunnels.gd")
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const PROPS = preload("res://scripts/voxel/voxel_props.gd")
const WORLD_OBJECT = preload("res://scripts/interaction/world_object.gd")
const HERO_OUTLINE = preload("res://scripts/voxel/occluded_hero_outline.gdshader")
const CHUNK: int = 12
const BUILD_BUDGET: int = 2
const CAVE_OVERHEAD_BLOCK_RADIUS: int = 1 # Exactly 3x3 roof blocks, centred on the avatar.
const CAVE_HEAD_CLEARANCE: float = 1.25
var terrain
var _loaded: Dictionary = {} # chunk origin -> meshes/collision/chest nodes
var _pending: Array[Vector2i] = []
var _center := Vector2i(99999, 99999)
var _roof_nodes: Array[MeshInstance3D] = []
var _cutaway_material: ShaderMaterial
var _cave_mode: bool = false
var _cutaway_focus: Vector3 = Vector3.ZERO
var _cutaway_eye: Vector3 = Vector3.ZERO
var _cutaway_radius: float = 1.5
var _outline_material: ShaderMaterial
var _outline_meshes: Array[MeshInstance3D] = []
var _outline_active: bool = false

func setup(world_seed: int) -> void:
	terrain = DATA.new(world_seed)
	name = "FractalArchipelago"
	# Never mutate GREEDY's global material: other Fields chunks must not cut
	# holes when the remote island camera enters a tunnel or a deep ravine.
	_cutaway_material = GREEDY.material().duplicate() as ShaderMaterial
	_cutaway_material.set_shader_parameter("island_cutaway_enabled", false)
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = HERO_OUTLINE

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
		if _cutaway_material != null:
			_cutaway_material.set_shader_parameter("island_cutaway_enabled", false)
		_set_hero_outline(hero, false)
		if not _loaded.is_empty():
			_clear_stream()
		return
	_queue_near(position)
	_build_pending()
	_update_cutaway(game, position)
	_update_hero_visibility(game, hero)

func _is_below_terrain(position: Vector3) -> bool:
	# Actual tunnel cells are definitive. A steep drop with high walls on
	# several sides is also treated as a crevice, even outside carved caves.
	var xi: int = floori(position.x)
	var zi: int = floori(position.z)
	var floor_y: int = terrain.caves.floor_at(xi, zi)
	if floor_y != CAVES.INVALID_FLOOR and position.y < float(terrain.height_at(xi, zi)) - 0.8:
		return true
	var elevated: int = 0
	for offset in [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(0, 3),
			Vector2i(-3, -3), Vector2i(3, 3)]:
		if float(terrain.height_at(xi + offset.x, zi + offset.y)) >= position.y + 3.5:
			elevated += 1
	return elevated >= 3

func _update_cutaway(game: Node, position: Vector3) -> void:
	if _cutaway_material == null:
		return
	var view: Camera3D = game.get("camera") as Camera3D
	if view == null:
		_cutaway_material.set_shader_parameter("island_cutaway_enabled", false)
		return
	_cave_mode = _is_below_terrain(position)
	var xi: int = floori(position.x)
	var zi: int = floori(position.z)
	var cave_floor: int = terrain.caves.floor_at(xi, zi)
	# Outdoor crevices use the highlighted avatar, not missing mountains.
	var inside_roofed_cave: bool = cave_floor != CAVES.INVALID_FLOOR and _cave_mode
	_cutaway_focus = position + Vector3.UP * 0.95
	_cutaway_eye = view.global_position
	_cutaway_radius = 1.5 # Limit the hole to the 3x3 overhead voxel footprint.
	_cutaway_material.set_shader_parameter("island_cutaway_enabled", inside_roofed_cave)
	_cutaway_material.set_shader_parameter("island_cave_mode", _cave_mode)
	_cutaway_material.set_shader_parameter("island_cutaway_focus", _cutaway_focus)
	_cutaway_material.set_shader_parameter("island_cutaway_eye", _cutaway_eye)
	_cutaway_material.set_shader_parameter("island_cutaway_radius", _cutaway_radius)
	for roof in _roof_nodes:
		if is_instance_valid(roof):
			roof.visible = true

func _is_cut_overhead_block(at: Vector3, normal: Vector3) -> bool:
	# Keep the pick-through rule identical to the voxel-snapped roof shader:
	# one block to either side of the player's current X/Z voxel, and only
	# horizontal faces higher than the hero's head. Never disable collision.
	if absf(normal.y) <= 0.88 or at.y <= _cutaway_focus.y + CAVE_HEAD_CLEARANCE:
		return false
	var block := Vector2i(floori(at.x - 0.001), floori(at.z - 0.001))
	var player_block := Vector2i(floori(_cutaway_focus.x), floori(_cutaway_focus.z))
	return absi(block.x - player_block.x) <= CAVE_OVERHEAD_BLOCK_RADIUS and \
		absi(block.y - player_block.y) <= CAVE_OVERHEAD_BLOCK_RADIUS


func cutaway_hides_hit(hit: Dictionary) -> bool:
	# Ray picking passes ONLY the exact overhead roof cells hidden by the
	# shader. No body-wide exclusions; sidewalls and terrain floors remain.
	if _cutaway_material == null or _cutaway_material.get_shader_parameter("island_cutaway_enabled") != true:
		return false
	var collider: Variant = hit.get("collider")
	if not collider is CollisionObject3D or not collider.has_meta("island_roof_shape_index"):
		return false
	if int(hit.get("shape", -1)) != int(collider.get_meta("island_roof_shape_index")):
		return false
	return _is_cut_overhead_block(hit.get("position", Vector3.ZERO),
		hit.get("normal", Vector3.ZERO))

func _set_hero_outline(hero: Node3D, enabled: bool) -> void:
	if not hero is CollisionObject3D or _outline_material == null:
		return
	if _outline_meshes.is_empty():
		var rig: Variant = hero.get("visual")
		if not rig is Node3D:
			return
		for child in rig.find_children("*", "MeshInstance3D", true, false):
			if child is MeshInstance3D:
				_outline_meshes.append(child)
	if _outline_active == enabled:
		return
	_outline_active = enabled
	for mesh in _outline_meshes:
		if not is_instance_valid(mesh):
			continue
		if enabled:
			if mesh.material_overlay == null:
				mesh.material_overlay = _outline_material
		elif mesh.material_overlay == _outline_material:
			mesh.material_overlay = null


func _update_hero_visibility(game: Node, hero: Node3D) -> void:
	if not hero is CollisionObject3D:
		return
	var view: Camera3D = game.get("camera") as Camera3D
	if view == null:
		_set_hero_outline(hero, false)
		return
	var focus: Vector3 = hero.global_position + Vector3.UP * 0.98
	var origin: Vector3 = view.global_position
	var direction: Vector3 = (focus - origin).normalized()
	var end: Vector3 = focus
	var covered: bool = false
	# A clipped ceiling still has collision. Skip only cutaway roof hits,
	# then highlight the avatar if a genuinely visible wall occludes it.
	for attempt in range(18):
		var query := PhysicsRayQueryParameters3D.create(origin, end, 1, [hero.get_rid()])
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		if cutaway_hides_hit(hit) and hit.position.distance_to(end) > 1.5:
			origin = hit.position + direction * 0.11
			if origin.distance_to(end) < 0.3:
				break
			continue
		var collider: Variant = hit.get("collider")
		covered = collider is Node and str(collider.name).begins_with("IslandCollision_") and hit.position.distance_to(focus) > 1.15
		break
	_set_hero_outline(hero, covered)


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
		# Exterior cliffs and walking surfaces never become transparent.
		ground.material_override = GREEDY.material()
		add_child(ground)
		members.append(ground)
		meshed.append(ground)
	if roof_faces > 0:
		var lid := MeshInstance3D.new()
		lid.name = "CaveCutaway_%d_%d" % [key.x, key.y]
		lid.mesh = PALETTE.create_mesh(roof)
		lid.material_override = _cutaway_material
		add_child(lid)
		members.append(lid)
		meshed.append(lid)
		_roof_nodes.append(lid)
	if not meshed.is_empty():
		var body := StaticBody3D.new()
		body.name = "IslandCollision_%d_%d" % [key.x, key.y]
		body.collision_layer = 1
		body.collision_mask = 1
		var shape_index: int = 0
		for mesh in meshed:
			if mesh.name.begins_with("CaveCutaway_"):
				body.set_meta("island_roof_shape_index", shape_index)
			var collider := CollisionShape3D.new()
			var collision_mesh: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
			# Match the established Outpost terrain collision contract.
			# Without double-sided triangles the avatar can collide with
			# cliff edges but miss the adjoining top face and fall/stall.
			collision_mesh.backface_collision = true
			collider.shape = collision_mesh
			body.add_child(collider)
			shape_index += 1
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
