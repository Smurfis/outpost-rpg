extends Node3D
## Four readable 3D crafting stations. Built-in meshes; original, mobile-friendly.
var station_id: String = "workbench"
var activity: float = 0.0
var effect: MeshInstance3D
var time: float = 0.0

func setup(id: String) -> void:
	station_id = id
	name = id.capitalize() + "Station"
	_build()
	add_to_group("stations")

func _part(mesh: Mesh, at: Vector3, tint: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = mesh
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.85
	mesh_node.material_override = mat
	add_child(mesh_node)
	return mesh_node

func _block(size: Vector3, at: Vector3, tint: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _part(shape, at, tint)

func _rod(bottom: float, top: float, height: float, at: Vector3, tint: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 7
	return _part(shape, at, tint)

func _label(message: String, tint: Color) -> void:
	var tag := Label3D.new()
	tag.text = message
	tag.font_size = 42
	tag.pixel_size = 0.006
	tag.position = Vector3(0, 2.55, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = tint
	add_child(tag)

func _build() -> void:
	match station_id:
		"workbench":
			_block(Vector3(3.0, 0.2, 1.6), Vector3(0, 0.88, 0), Color("9f7446"))
			for x in [-1.13, 1.13]:
				for z in [-0.51, 0.51]:
					_block(Vector3(0.19, 0.86, 0.19), Vector3(x, 0.43, z), Color("5e402f"))
			for i in range(5):
				_block(Vector3(0.15, 0.08, 1.5), Vector3(-1.19 + float(i) * 0.59, 1.05, 0), Color("d0a165"))
			effect = _block(Vector3(0.42, 0.14, 0.28), Vector3(0.10, 1.20, 0), Color("d5d9cb"))
			_label("WOODWORK | [CRAFT]", Color("f3dc9e"))
		"forge":
			_block(Vector3(3.2, 0.35, 2.5), Vector3(0, 0.18, 0), Color("6b6660"))
			for x in [-1.14, 1.14]:
				_block(Vector3(0.32, 1.1, 2.0), Vector3(x, 0.73, 0), Color("777a75"))
			_block(Vector3(2.1, 0.23, 1.65), Vector3(0, 0.55, 0), Color("3a3934"))
			effect = _rod(0.54, 0.26, 0.6, Vector3(0, 0.92, 0), Color("f3a34b"))
			_block(Vector3(1.1, 0.18, 0.85), Vector3(0, 1.04, 1.15), Color("7f979b"))
			_rod(0.40, 0.35, 1.6, Vector3(-0.91, 1.0, -0.78), Color("81776e"))
			_label("FORGE | [CRAFT]", Color("f7b56e"))
		"loom":
			for x in [-1.18, 1.18]:
				_block(Vector3(0.23, 2.15, 0.28), Vector3(x, 1.1, 0), Color("856545"))
			for y in [0.65, 1.95]:
				_block(Vector3(2.62, 0.18, 0.24), Vector3(0, y, 0), Color("b69059"))
			for i in range(13):
				_block(Vector3(0.038, 1.3, 0.045), Vector3(-1.03 + float(i) * 0.17, 1.28, 0.05), Color("d8d1b2"))
			effect = _block(Vector3(1.92, 0.52, 0.12), Vector3(0, 1.04, 0.2), Color("7b9e88"))
			_label("WEAVING LOOM | [CRAFT]", Color("d9dfb4"))
		"campfire":
			for i in range(8):
				var a: float = TAU * float(i) / 8.0
				_rod(0.30, 0.28, 0.24, Vector3(cos(a) * 0.9, 0.12, sin(a) * 0.9), Color("a9a19a"))
			_block(Vector3(1.65, 0.16, 0.25), Vector3(0, 0.28, 0), Color("6b4c32"))
			_block(Vector3(0.25, 0.16, 1.65), Vector3(0, 0.30, 0), Color("805636"))
			effect = _rod(0.40, 0.0, 0.8, Vector3(0, 0.68, 0), Color("f2a649"))
			_rod(0.73, 0.73, 0.25, Vector3(0, 1.18, 0), Color("525d5d"))
			for x in [-0.62, 0.62]:
				_rod(0.07, 0.07, 0.56, Vector3(x, 1.25, 0), Color("555d5a"))
			_label("CAMPFIRE | [CRAFT]", Color("f2c583"))
	if effect != null:
		effect.position.y += 0.01

func set_activity(progress: float) -> void:
	activity = progress

func stroke() -> void:
	if effect != null:
		var tween := create_tween()
		tween.tween_property(effect, "scale", Vector3(1.18, 1.27, 1.18), 0.08)
		tween.tween_property(effect, "scale", Vector3.ONE, 0.18)

func _process(delta: float) -> void:
	time += delta
	if effect != null and station_id in ["forge", "campfire"]:
		effect.scale.x = 1.0 + 0.06 * sin(time * 6.0)
		effect.scale.z = 1.0 + 0.06 * sin(time * 6.0)
	if activity > 0.0 and effect != null:
		effect.rotation.y += delta * 0.24
