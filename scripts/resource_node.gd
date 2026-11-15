extends Node3D
## Ten harvestables; optional voxel art changes visuals, never harvesting rules.
const VOXEL_PROPS = preload("res://scripts/voxel/voxel_props.gd")
const FOLIAGE = preload("res://scripts/voxel/foliage_renderer.gd")
const PIXEL_FEEDBACK = preload("res://scripts/vfx/pixel_feedback.gd")
const PICKER = preload("res://scripts/interaction/world_picker.gd")
const SOLID = preload("res://scripts/interaction/resource_collision.gd")
# Zero uses the model bounds (including bundles); positive values override
# the local-space height or X/Z footprint for gameplay tuning.
@export_range(0.0, 20.0, 0.05) var collision_height: float = 0.0
@export_range(0.0, 20.0, 0.05) var collision_width: float = 0.0
@export_range(0.1, 2.0, 0.05) var tree_trunk_width: float = 0.65
@export_range(1.8, 4.0, 0.05) var tree_canopy_clearance: float = 2.05
var resource_body: StaticBody3D
var _harvest_tween: Tween
var _mesh_scales: Dictionary = {}
var bundle_count: int = 1
var max_hits: int = 3
var kind: String = "wood"
var active: bool = true
var hits_left: int = 3
var cooldown: float = 0.0
var recovery: float = 18.0
var initial_scale: Vector3 = Vector3.ONE
var target_label: Label3D
var target_ring: MeshInstance3D

func setup(resource_type: String, count: int = 1) -> void:
	kind = resource_type
	bundle_count = clampi(count, 1, 3)
	name = kind.capitalize() + "Node"
	match kind:
		"wood":
			_pine()
		"stone":
			_rock()
		"fiber":
			_bush(false)
		"berries":
			_bush(true)
		"iron":
			_ore(Color("717b86"), Color("dfe5e8"))
		"coal":
			_ore(Color("303b44"), Color("63737e"))
		"clay":
			_clay()
		"herbs":
			_herbs()
		"mushrooms":
			_mushrooms()
		"reeds":
			_reeds()
		"shrimp":
			_shrimp_pool()
	if bundle_count > 1:
		var originals: Array[Node] = get_children()
		for i in range(1, bundle_count):
			for original in originals:
				if original is MeshInstance3D:
					var bundled: Node3D = original.duplicate()
					bundled.position += Vector3(-0.8 if i == 1 else 0.8, 0, 0.65)
					bundled.scale *= 0.72
					add_child(bundled)
	max_hits = (3 if kind in ["wood", "stone", "iron", "coal", "clay", "shrimp"] else 2) * bundle_count
	hits_left = max_hits
	recovery = 28.0 if kind in ["iron", "coal", "herbs"] else 18.0
	initial_scale = scale
	if kind in ["wood", "stone", "iron", "coal", "clay"]:
		resource_body = SOLID.new()
		add_child(resource_body)
		resource_body.configure(self, collision_height, collision_width)
	for child in get_children():
		if child is MeshInstance3D:
			_mesh_scales[child] = child.scale
	PICKER.attach(self, "resource")
	_setup_target_marker()
	add_to_group("resources")

func _is_voxel_skin() -> bool:
	var node: Node = get_parent()
	# Harvestables may be children of streamed-chunk containers, not the game.
	while node != null:
		if node.has_method("_world") and bool(node.get("voxel_art_enabled")):
			return true
		node = node.get_parent()
	return false

func _model(id: String, size_factor: Vector3) -> void:
	var model: MeshInstance3D
	if _is_voxel_skin():
		if id == "oak_tree":
			# Deterministic species based on world position. Harvesting remains
			# handled by this resource node; only the mesh/material changes.
			model = FOLIAGE.tree(FOLIAGE.species_at(global_position.x, global_position.z),
				posmod(roundi(global_position.x * 7.0 + global_position.z * 11.0), 3))
		elif id == "rock_deposit":
			model = VOXEL_PROPS.rock()
	if model == null:
		model = MeshInstance3D.new()
		model.mesh = load("res://assets/models/" + id + ".obj") as Mesh
	model.name = "HarvestableModel"
	model.scale = size_factor
	add_child(model)

func _setup_target_marker() -> void:
	target_label = Label3D.new()
	target_label.text = kind.capitalize() + " • " + str(hits_left) + " hits"
	target_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	target_label.font_size = 43
	target_label.pixel_size = 0.006
	target_label.position = Vector3(0, 1.85, 0)
	target_label.modulate = Color("fff0c4")
	target_label.visible = false
	add_child(target_label)
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 1.11
	halo_mesh.outer_radius = 1.22
	halo_mesh.rings = 9
	halo_mesh.ring_segments = 28
	target_ring = MeshInstance3D.new()
	target_ring.mesh = halo_mesh
	target_ring.position = Vector3(0, 0.05, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("cdb270")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	target_ring.material_override = mat
	target_ring.visible = false
	add_child(target_ring)

func set_targeted(selected: bool) -> void:
	if target_label != null:
		target_label.visible = selected and active
		target_label.text = "%s%s · %d actions" % ["Shrimp pool" if kind == "shrimp" else kind.capitalize(), " ×%d" % bundle_count if bundle_count > 1 else "", hits_left]
	if target_ring != null:
		target_ring.visible = selected and active

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	return m

func _part(mesh: Mesh, at: Vector3, stretch: Vector3, tint: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = at
	n.scale = stretch
	n.material_override = _material(tint)
	add_child(n)
	return n

func _spike(bottom: float, top: float, height: float, at: Vector3, color: Color, segments: int = 7) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	return _part(mesh, at, Vector3.ONE, color)

func _orb(at: Vector3, stretch: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.rings = 3
	return _part(mesh, at, stretch, tint)

func _block(size: Vector3, at: Vector3, color: Color) -> void:
	var m := BoxMesh.new()
	m.size = size
	_part(m, at, Vector3.ONE, color)

func _pine() -> void:
	# Original OBJ, with a twisted trunk and layered low-poly foliage.
	_model("oak_tree", Vector3(0.83, 0.83, 0.83))

func _rock() -> void:
	_model("rock_deposit", Vector3.ONE)

func _ore(base: Color, vein: Color) -> void:
	if _is_voxel_skin():
		add_child(VOXEL_PROPS.rock(kind))
		return
	var points := [Vector3(-0.48, 0.52, 0.10), Vector3(0.42, 0.62, 0.26), Vector3(0.10, 0.39, -0.49)]
	for i in range(3):
		var p := _orb(points[i], Vector3(1.4, 1.25, 1.30), base.lightened(float(i) * 0.12))
		p.rotation.y = float(i) * 0.47
	for i in range(3):
		var c := _spike(0.24, 0.03, 0.76 + 0.16 * float(i), Vector3(-0.37 + 0.38 * float(i), 0.92, -0.32), vein, 5)
		c.rotation.z = 0.10 * float(i - 1)

func _bush(berries: bool) -> void:
	if _is_voxel_skin():
		add_child(VOXEL_PROPS.bush(berries))
		return
	for p in [Vector3(-0.38, 0.50, 0.22), Vector3(0.25, 0.63, 0), Vector3(0.60, 0.36, -0.14)]:
		_orb(p, Vector3(1.50, 1.0, 1.42), Color("49714d") if berries else Color("75a47a"))
	if berries:
		for p in [Vector3(-0.48, 0.89, -0.48), Vector3(0.42, 0.90, -0.54), Vector3(0.64, 0.57, 0.34)]:
			_orb(p, Vector3(0.28, 0.30, 0.28), Color("c24d5f"))
	else:
		for x in [-0.45, 0.1, 0.54]:
			_spike(0.07, 0.0, 1.25, Vector3(x, 0.87, 0.15), Color("dec686"), 4)

func _clay() -> void:
	if _is_voxel_skin():
		add_child(VOXEL_PROPS.rock("clay"))
		return
	for p in [Vector3(-0.45, 0.40, 0.0), Vector3(0.4, 0.36, 0.25), Vector3(-0.05, 0.51, -0.34)]:
		_orb(p, Vector3(1.55, 0.84, 1.20), Color("bd7658") if p.x < 0.0 else Color("9a564b"))
	_orb(Vector3(0.18, 0.72, 0.24), Vector3(0.80, 0.30, 0.5), Color("d79f77"))

func _herbs() -> void:
	for x in [-0.48, 0.0, 0.40]:
		_spike(0.055, 0.025, 1.05, Vector3(x, 0.52, 0), Color("96ab6c"), 5)
		_orb(Vector3(x - 0.18, 0.77, 0), Vector3(0.6, 0.23, 0.32), Color("76b393"))
		_orb(Vector3(x + 0.16, 0.52, 0.16), Vector3(0.55, 0.24, 0.28), Color("a2c69a"))
		_orb(Vector3(x, 1.11, 0), Vector3(0.26, 0.28, 0.26), Color("d5c5a0"))

func _mushrooms() -> void:
	if _is_voxel_skin():
		add_child(VOXEL_PROPS.mushrooms())
		return
	for p in [Vector3(-0.55, 0, 0.0), Vector3(0.15, 0, 0.2), Vector3(0.65, 0, -0.3)]:
		var scale_by: float = 1.1 if p.x < 0.0 else 0.80
		_spike(0.12, 0.10, 0.65 * scale_by, p + Vector3(0, 0.33 * scale_by, 0), Color("dfd3b3"), 6)
		_spike(0.59 * scale_by, 0.06, 0.42 * scale_by, p + Vector3(0, 0.75 * scale_by, 0), Color("a9544b"), 7)
		_orb(p + Vector3(0, 0.83 * scale_by, 0), Vector3(0.22, 0.12, 0.22), Color("d3a387"))

func _reeds() -> void:
	for i in range(8):
		var x: float = -0.70 + 0.19 * float(i)
		var z: float = 0.27 if i % 2 == 0 else -0.24
		var height: float = 1.3 + 0.18 * float(i % 4)
		_spike(0.055, 0.027, height, Vector3(x, height * 0.5, z), Color("a9ad6a"), 5)
		_spike(0.12, 0.09, 0.33, Vector3(x, height - 0.09, z), Color("a78851"), 5)
		_orb(Vector3(x + 0.16, height * 0.60, z), Vector3(0.46, 0.14, 0.20), Color("74a88a"))

func _process(delta: float) -> void:
	if not active:
		cooldown -= delta
		if cooldown <= 0.0:
			active = true
			if resource_body != null:
				resource_body.set_deferred("collision_layer", 1)
			hits_left = max_hits
			visible = true
			scale = initial_scale

func harvest() -> String:
	if not active:
		return ""
	hits_left -= 1
	var game_node: Node = get_parent()
	while game_node != null and not game_node.has_method("_world"):
		game_node = game_node.get_parent()
	if game_node is Node3D:
		PIXEL_FEEDBACK.emit_feedback(game_node, global_position + Vector3.UP * 0.55, 0, Color("d9ba87"), hits_left <= 0)
	if target_label != null:
		target_label.text = kind.capitalize() + " • " + str(hits_left) + " hits"
	# Animate art only: a player standing on a resource must not be pushed
	# around by its harvest feedback or an overlapping scale tween.
	if _harvest_tween != null:
		_harvest_tween.kill()
	_harvest_tween = create_tween().set_parallel(true)
	for mesh in _mesh_scales:
		_harvest_tween.tween_property(mesh, "scale", _mesh_scales[mesh] * 1.07, 0.07)
	_harvest_tween.chain()
	for mesh in _mesh_scales:
		_harvest_tween.tween_property(mesh, "scale", _mesh_scales[mesh], 0.10)
	if hits_left <= 0:
		active = false
		if resource_body != null:
			resource_body.set_deferred("collision_layer", 0)
		visible = false
		cooldown = recovery
	return kind

func _shrimp_pool() -> void:
	# Open ripples and small voxel shrimp at the water surface, no water disk.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.78
	ring.outer_radius = 0.82
	ring.rings = 4
	ring.ring_segments = 20
	_part(ring, Vector3(0, 0.02, 0), Vector3.ONE, Color("9bccbd"))
	for i in range(5):
		var angle: float = TAU * float(i) / 5.0
		var at := Vector3(cos(angle) * 0.45, 0.04, sin(angle) * 0.45)
		_block(Vector3(0.22, 0.06, 0.12), at, Color("d8947c"))
		_block(Vector3(0.08, 0.06, 0.16), at + Vector3(0.11, 0, 0.06), Color("b77465"))
