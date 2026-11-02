extends Node3D
## Low-poly evergreen or mineral deposit; 2 gathering hits then respawn.
var kind := "wood"
var active := true
var hits_left := 2
var cooldown := 0.0

func setup(resource_type: String) -> void:
	kind = resource_type
	name = "PineTree" if kind == "wood" else "Ironstone"
	if kind == "wood":
		_pine()
	else:
		_rock()
	add_to_group("resources")

func _part(mesh: Mesh, pos: Vector3, scale_by: Vector3, color: Color) -> void:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.scale = scale_by
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	n.material_override = m
	add_child(n)

func _pine() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.37
	trunk.height = 2.6
	_part(trunk, Vector3(0, 1.3, 0), Vector3.ONE, Color("75513b"))
	for i in range(3):
		var crown := CylinderMesh.new()
		crown.top_radius = 0.0
		crown.bottom_radius = 1.6 - i * 0.25
		crown.height = 1.55
		_part(crown, Vector3(0, 2.25 + i * 0.83, 0), Vector3.ONE, Color("305e47") if i % 2 == 0 else Color("497b54"))

func _rock() -> void:
	var colors := [Color("82929a"), Color("a4a9a1"), Color("667d84")]
	var centers := [Vector3(0, 0.58, 0), Vector3(0.83, 0.37, 0.20), Vector3(-0.62, 0.37, -0.22)]
	for i in range(3):
		var m := SphereMesh.new()
		m.radius = 0.72
		m.height = 1.44
		_part(m, centers[i], Vector3(1.16 - i * 0.18, 0.75 - i * 0.10, 0.99), colors[i])

func _process(delta: float) -> void:
	if not active:
		cooldown -= delta
		if cooldown <= 0.0:
			active = true
			hits_left = 2
			visible = true

func harvest() -> String:
	if not active:
		return ""
	hits_left -= 1
	if hits_left <= 0:
		active = false
		visible = false
		cooldown = 18.0
	return kind
