extends Area3D
## Oversized 16px-atlas voxel dungeon monument; unchanged tap/entrance IDs.
signal selected(entrance: Area3D)
const RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
var entrance_id: String = ""
var chunk_id: String = ""
var quality: int = 0
var dungeon_title: String = ""
var label: Label3D
var orb: MeshInstance3D
var aura: MeshInstance3D
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
	shape.size = Vector3(5.3, 5.8, 2.0)
	trigger.shape = shape
	trigger.position.y = 2.9
	add_child(trigger)

	# Entire architectural shell is ONE pixel-atlas mesh. The glow is kept
	# separate for rarity tint and a gentle emissive pulse.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	PIXELS.box(st, Vector3(0, 0.17, 0), Vector3(5.9, 0.34, 2.1), 12, 4)
	PIXELS.box(st, Vector3(0, 0.38, 0), Vector3(5.2, 0.26, 1.55), 4, 12)
	for side in [-1.0, 1.0]:
		var x: float = side * 1.99
		PIXELS.box(st, Vector3(x, 0.48, 0), Vector3(1.22, 0.94, 1.32), 12, 4)
		PIXELS.box(st, Vector3(x, 1.53, 0), Vector3(0.94, 1.24, 1.05), 4, 12)
		PIXELS.box(st, Vector3(x, 2.72, 0), Vector3(1.04, 1.18, 1.12), 12, 4)
		PIXELS.box(st, Vector3(x, 3.82, 0), Vector3(1.08, 1.08, 1.18), 4, 12)
		PIXELS.box(st, Vector3(x, 4.45, 0), Vector3(1.35, 0.38, 1.38), 7, 12)
		PIXELS.box(st, Vector3(x + side * 0.2, 4.96, 0), Vector3(0.9, 0.42, 1.22), 12, 4)
	PIXELS.box(st, Vector3(0, 5.03, 0), Vector3(4.9, 0.76, 1.28), 12, 4)
	PIXELS.box(st, Vector3(0, 5.48, 0), Vector3(2.05, 0.24, 1.43), 7, 12)
	PIXELS.box(st, Vector3(0, 5.76, 0), Vector3(0.80, 0.40, 0.92), 13, 12)
	add_child(PIXELS.as_instance(st, "VoxelStoneMonument"))

	var gate_mesh := BoxMesh.new()
	gate_mesh.size = Vector3(3.0, 3.9, 0.13)
	orb = _add_mesh(gate_mesh, Vector3(0, 2.5, 0), RARITY.color(quality))
	orb.name = "RarityGate"
	orb.material_override = _emissive(RARITY.color(quality), 1.75, 0.65)
	var inner := BoxMesh.new()
	inner.size = Vector3(2.46, 3.24, 0.12)
	aura = _add_mesh(inner, Vector3(0, 2.5, -0.1), RARITY.color(quality))
	aura.name = "RarityPulse"
	aura.material_override = _emissive(RARITY.color(quality).lightened(0.30), 1.3, 0.28)

	for x in [-2.08, 0.0, 2.08]:
		var glyph_mesh := BoxMesh.new()
		glyph_mesh.size = Vector3(0.32, 0.32, 0.25)
		var glyph: MeshInstance3D = _add_mesh(glyph_mesh,
			Vector3(x, 5.13 if x == 0.0 else 3.40, -0.70), RARITY.color(quality))
		glyph.material_override = _emissive(RARITY.color(quality), 1.2, 1.0)
		glyph.rotation.z = PI / 4.0

	label = Label3D.new()
	label.text = "%s  •  %s" % [RARITY.quality_name(quality).to_upper(), dungeon_title]
	label.modulate = RARITY.color(quality)
	label.outline_modulate = Color(0.05, 0.04, 0.08, 1)
	label.outline_size = 16
	label.font_size = 44
	label.pixel_size = 0.0062
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 6.12, 0)
	add_child(label)
	input_event.connect(_on_input_event)

func _add_mesh(mesh: Mesh, at: Vector3, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.8
	node.material_override = material
	add_child(node)
	return node

func _emissive(tint: Color, strength: float, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = strength
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _process(delta: float) -> void:
	clock += delta
	if orb != null:
		orb.scale.x = 1.0 + sin(clock * 1.9) * 0.025
		orb.scale.y = 1.0 + sin(clock * 1.4) * 0.025
	if aura != null:
		aura.scale.x = 1.0 + sin(clock * 1.34 + 1.0) * 0.055
		aura.scale.y = 1.0 + sin(clock * 1.18) * 0.035

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int) -> void:
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var touched: bool = event is InputEventScreenTouch and event.pressed
	if clicked or touched:
		selected.emit(self)
		get_viewport().set_input_as_handled()
