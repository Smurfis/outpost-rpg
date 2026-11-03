extends Area3D
## Tappable 3D overworld dungeon entrance. Collision is for picking, not blocking movement.
signal selected(entrance: Area3D)

const RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
var entrance_id: String = ""
var chunk_id: String = ""
var quality: int = 0
var dungeon_title: String = ""
var label: Label3D
var orb: MeshInstance3D
var clock: float = 0.0

func configure(id: String, owner_chunk: String, tier: int) -> void:
	entrance_id = id
	chunk_id = owner_chunk
	quality = RARITY.bounded(tier)
	dungeon_title = RARITY.dungeon_name(quality)
	name = "DungeonEntrance_" + entrance_id.replace(":", "_")
	collision_layer = 8
	collision_mask = 0
	input_ray_pickable = true
	var trigger := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 3.4, 1.6)
	trigger.shape = shape
	trigger.position.y = 1.7
	add_child(trigger)

	var base := CylinderMesh.new()
	base.top_radius = 1.36
	base.bottom_radius = 1.56
	base.height = 0.30
	base.radial_segments = 16
	_add_mesh(base, Vector3(0, 0.11, 0), Color("303b40"))
	for i in range(12):
		var angle: float = float(i) / 12.0 * TAU
		var stone := BoxMesh.new()
		stone.size = Vector3(0.45, 0.48, 0.58)
		var block := _add_mesh(stone, Vector3(sin(angle) * 1.12, 1.75 + cos(angle) * 1.12, 0), Color("42434c"))
		block.rotation.z = -angle

	var ring := TorusMesh.new()
	ring.inner_radius = 0.88
	ring.outer_radius = 1.18
	ring.rings = 10
	ring.ring_segments = 32
	var rim := _add_mesh(ring, Vector3(0, 1.75, 0), RARITY.color(quality))
	rim.rotation_degrees.x = 90.0
	rim.material_override = _emissive(RARITY.color(quality), 1.65, 1.0)

	var glow := SphereMesh.new()
	glow.radius = 1.0
	glow.height = 2.0
	glow.radial_segments = 24
	glow.rings = 10
	orb = _add_mesh(glow, Vector3(0, 1.75, 0), RARITY.color(quality))
	orb.scale = Vector3(0.86, 0.96, 0.16)
	orb.material_override = _emissive(RARITY.color(quality), 1.25, 0.58)

	label = Label3D.new()
	label.text = "%s  •  %s" % [RARITY.quality_name(quality).to_upper(), dungeon_title]
	label.modulate = RARITY.color(quality)
	label.outline_modulate = Color(0.05, 0.04, 0.08, 1)
	label.outline_size = 16
	label.font_size = 37
	label.pixel_size = 0.0062
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.70, 0)
	add_child(label)
	input_event.connect(_on_input_event)

func _add_mesh(mesh: Mesh, at: Vector3, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.8
	node.material_override = mat
	add_child(node)
	return node

func _emissive(tint: Color, power: float, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = power
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _process(delta: float) -> void:
	clock += delta
	if orb != null:
		orb.scale.x = 0.86 + sin(clock * 1.9) * 0.045
		orb.scale.y = 0.96 + sin(clock * 1.4) * 0.055

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int) -> void:
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var touched: bool = event is InputEventScreenTouch and event.pressed
	if clicked or touched:
		selected.emit(self)
		get_viewport().set_input_as_handled()
