extends Node3D
## Four distinct harvestables with faceted, deliberately readable mobile silhouettes.
var kind: String = "wood"
var active: bool = true
var hits_left: int = 3
var cooldown: float = 0.0
var recovery: float = 18.0
var initial_scale: Vector3 = Vector3.ONE

func setup(resource_type: String) -> void:
	kind = resource_type
	name = kind.capitalize() + "Node"
	if kind == "wood":
		_pine()
	elif kind == "stone":
		_rock()
	elif kind == "fiber":
		_bush(false)
	else:
		_bush(true)
	hits_left = 3 if kind in ["wood", "stone"] else 2
	initial_scale = scale
	add_to_group("resources")

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material

func _part(mesh: Mesh, at: Vector3, stretch: Vector3, tint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.scale = stretch
	instance.material_override = _material(tint)
	add_child(instance)
	return instance

func _spike(bottom: float, top: float, height: float, at: Vector3, color: Color, segments: int = 7) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	_part(mesh, at, Vector3.ONE, color)

func _pine() -> void:
	_spike(0.34, 0.20, 2.8, Vector3(0, 1.4, 0), Color("765035"))
	for i in range(4):
		var width: float = 1.75 - float(i) * 0.31
		var high: float = 2.0 + float(i) * 0.75
		_spike(width, 0.08, 1.85, Vector3(0, high, 0), Color("24553e") if i % 2 == 0 else Color("3e7450"))
	# Bark bands and trunk-base reading at isometric distance
	_spike(0.46, 0.38, 0.16, Vector3(0, 0.13, 0), Color("55402e"))
	_spike(0.25, 0.25, 0.08, Vector3(0, 0.95, 0), Color("9d6941"))

func _rock() -> void:
	var shades := [Color("748991"), Color("a6aaa2"), Color("526e77"), Color("909b9b")]
	var coords := [Vector3(-0.55, 0.60, 0.12), Vector3(0.45, 0.65, 0.32), Vector3(0.0, 0.54, -0.48), Vector3(0.65, 0.36, -0.40)]
	for i in range(4):
		var mesh := SphereMesh.new()
		mesh.radius = 0.79
		mesh.height = 1.58
		mesh.radial_segments = 7
		mesh.rings = 3
		var n := _part(mesh, coords[i], Vector3(0.95, 0.82 - float(i) * 0.08, 0.95), shades[i])
		n.rotation.y = float(i) * 0.51
	# Exposed ore-colored crystal accents
	_spike(0.25, 0.04, 0.8, Vector3(0.14, 1.0, -0.20), Color("91bed0"), 5)
	_spike(0.17, 0.0, 0.5, Vector3(-0.48, 0.92, -0.2), Color("d0d0bb"), 5)

func _bush(berries: bool) -> void:
	var leaf_color := Color("557c49") if berries else Color("5e9b70")
	var leaf_highlight := Color("80a65c") if berries else Color("7dbca0")
	for pos in [Vector3(-0.5, 0.52, 0.12), Vector3(0.25, 0.71, -0.08), Vector3(0.57, 0.45, 0.15), Vector3(-0.20, 0.6, 0.50)]:
		var crown := SphereMesh.new()
		crown.radius = 0.65
		crown.height = 1.30
		crown.radial_segments = 7
		crown.rings = 3
		_part(crown, pos, Vector3(1, 0.78, 0.85), leaf_color if pos.x < 0.0 else leaf_highlight)
	if berries:
		for p in [Vector3(-0.6, 0.86, -0.35), Vector3(0.30, 1.05, -0.45), Vector3(0.55, 0.7, -0.48)]:
			var berry := SphereMesh.new()
			berry.radius = 0.15
			berry.height = 0.30
			berry.radial_segments = 7
			berry.rings = 3
			_part(berry, p, Vector3.ONE, Color("c4515e"))
	else:
		for x in [-0.52, 0.0, 0.45]:
			_spike(0.09, 0.0, 1.3, Vector3(x, 0.83, 0.2), Color("d0c884"), 4)

func _process(delta: float) -> void:
	if not active:
		cooldown -= delta
		if cooldown <= 0.0:
			active = true
			hits_left = 3 if kind in ["wood", "stone"] else 2
			visible = true
			scale = initial_scale

func harvest() -> String:
	if not active:
		return ""
	hits_left -= 1
	var bump := create_tween()
	bump.tween_property(self, "scale", initial_scale * 1.08, 0.08)
	bump.tween_property(self, "scale", initial_scale, 0.11)
	if hits_left <= 0:
		active = false
		visible = false
		cooldown = recovery
	return kind

