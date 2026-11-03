extends Node3D
## Frontier prototype: deterministic connected 3x3 world, without committing to
## a future zone/grid or fully streamed infinite topology. Android-light geometry.
const ORE_NODE = preload("res://scripts/resource_node.gd")
const ORE_SETTINGS: String = "res://data/world/ore_veins.json"
const WIDTH: float = 46.0
const CELL_EXTENT: int = 1

var world_seed: int = 387441
var cells: Dictionary = {}
var deposits: Array = []
var world_root: Node3D

static func _hash_cell(cell: Vector2i, seed: int) -> int:
	var value: int = 83117 + seed
	value = posmod(value * 31 + cell.x * 17239 + cell.y * 98317, 2147483647)
	return maxi(1, value)

static func generate_ore_sites(cell: Vector2i, seed: int = 387441) -> Array:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORE_SETTINGS))
	if not (value is Dictionary):
		return []
	var settings: Dictionary = value
	var ore_defs: Array = settings.get("ores", [])
	var ore_count: int = maxi(1, int(settings.get("ore_deposits_per_frontier_cell", 7)))
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_cell(cell, seed)
	var chosen: Array = []
	var occupancies: Array[Vector2] = []
	var key: String = "%d,%d" % [cell.x, cell.y]
	var hotspot: String = str(settings.get("hotspot_cells", {}).get(key, ""))
	for i in range(ore_count):
		var name: String = hotspot if i == 0 and hotspot != "" else ""
		if name == "":
			var allowed: Array = []
			var total_weight: int = 0
			for ore in ore_defs:
				var tier: int = int(ore.get("tier", 1))
				var edge_depth: int = absi(cell.x) + absi(cell.y)
				if tier > 4 and edge_depth < 2:
					continue
				var weight: int = maxi(0, int(ore.get("weight", 0)))
				total_weight += weight
				allowed.append({"id": str(ore.get("id", "")), "weight": weight})
			var ticket: int = rng.randi_range(1, maxi(1, total_weight))
			for ore in allowed:
				ticket -= int(ore.get("weight", 0))
				if ticket <= 0:
					name = str(ore.get("id", "copper"))
					break
		if name == "":
			name = "copper"
		var result: Vector2 = Vector2.ZERO
		var found: bool = false
		for attempt in range(70):
			# Keep positions well inside each sector; every adjacent tile remains
			# traversable, with seams entirely open to the central outpost.
			var point := Vector2(rng.randf_range(-19.0, 19.0), rng.randf_range(-19.0, 19.0))
			if point.length() < 5.5:
				continue
			var valid: bool = true
			for previous in occupancies:
				if point.distance_to(previous) < 5.5:
					valid = false
					break
			if valid:
				result = point
				found = true
				break
		if not found:
			continue
		occupancies.append(result)
		chosen.append({
			"kind": name,
			"cell": cell,
			"position": Vector3(float(cell.x) * WIDTH + result.x, 0.0, float(cell.y) * WIDTH + result.y),
			"seed": _hash_cell(cell, seed)
		})
	return chosen

func populate(_game: Node3D) -> void:
	name = "Frontier"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORE_SETTINGS))
	if parsed is Dictionary:
		world_seed = int(parsed.get("seed", world_seed))
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("5c7952")
	ground_material.roughness = 1.0
	for x in range(-CELL_EXTENT, CELL_EXTENT + 1):
		for z in range(-CELL_EXTENT, CELL_EXTENT + 1):
			var tile := Vector2i(x, z)
			if tile == Vector2i.ZERO:
				continue
			_add_ground(tile, ground_material)
			var sites: Array = generate_ore_sites(tile, world_seed)
			for entry in sites:
				var resource = ORE_NODE.new()
				add_child(resource)
				resource.position = entry["position"]
				resource.setup(str(entry["kind"]))
				deposits.append(resource)
			_add_scenery(tile)
			cells["%d,%d" % [x, z]] = {"count": sites.size(), "sites": sites}
	_add_boundaries()

func _add_ground(tile: Vector2i, material: Material) -> void:
	var origin := Vector3(float(tile.x) * WIDTH, -0.55, float(tile.y) * WIDTH)
	var body := StaticBody3D.new()
	body.name = "FrontierGround_%d_%d" % [tile.x, tile.y]
	body.position = origin
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH + 0.12, 1.0, WIDTH + 0.12)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var visible_shape := BoxMesh.new()
	visible_shape.size = Vector3(WIDTH + 0.12, 0.98, WIDTH + 0.12)
	mesh.mesh = visible_shape
	mesh.material_override = material
	body.add_child(mesh)

func _add_scenery(tile: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_cell(tile, world_seed + 197)
	var rock_mesh: Mesh = load("res://assets/models/rock_deposit.obj") as Mesh
	var tree_mesh: Mesh = load("res://assets/models/oak_tree.obj") as Mesh
	for i in range(8):
		var x: float = float(tile.x) * WIDTH + rng.randf_range(-19.0, 19.0)
		var z: float = float(tile.y) * WIDTH + rng.randf_range(-19.0, 19.0)
		var model := MeshInstance3D.new()
		model.mesh = tree_mesh if i < 3 else rock_mesh
		model.position = Vector3(x, 0, z)
		model.scale = Vector3.ONE * rng.randf_range(0.5, 0.82)
		model.rotation.y = rng.randf_range(0, TAU)
		model.name = "FrontierScenery"
		add_child(model)
	var rocky_tint := StandardMaterial3D.new()
	rocky_tint.albedo_color = Color("6c7870")
	rocky_tint.roughness = 0.96
	for i in range(6):
		var piece := MeshInstance3D.new()
		piece.mesh = rock_mesh
		piece.material_override = rocky_tint
		piece.position = Vector3(float(tile.x) * WIDTH + rng.randf_range(-20,20), 0, float(tile.y) * WIDTH + rng.randf_range(-20,20))
		piece.scale = Vector3.ONE * rng.randf_range(0.19, 0.37)
		piece.rotation.y = rng.randf_range(0, TAU)
		add_child(piece)

func _add_boundaries() -> void:
	# Prototype safeguard at 69m: future systems may replace these with
	# zone transitions, vertical landscapes or streaming. Nothing is infinite yet.
	var edge: float = (float(CELL_EXTENT) + 0.5) * WIDTH
	for side in [-1.0, 1.0]:
		_wall(Vector3(side * edge, 1.65, 0), Vector3(0.35, 3.3, edge * 2.0))
		_wall(Vector3(0, 1.65, side * edge), Vector3(edge * 2.0, 3.3, 0.35))

func _wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
