extends CharacterBody3D
## Camera-relative isometric movement, primitive adventurer with visible equipment.
var game
var hud
var camera: Camera3D
var health := 100.0
var elapsed := 0.0
var last_hit := -100.0
var visual: Node3D
var blade: MeshInstance3D

func setup(game_ref: Node, hud_ref: CanvasLayer, camera_ref: Camera3D) -> void:
	game = game_ref
	hud = hud_ref
	camera = camera_ref
	name = "Adventurer"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	_sphere(Vector3(0, 1.06, 0), Vector3(0.75, 1.2, 0.52), Color("405d71"))
	_sphere(Vector3(0, 1.72, 0), Vector3(0.50, 0.52, 0.5), Color("e7b487"))
	_sphere(Vector3(0, 1.95, 0), Vector3(0.55, 0.18, 0.55), Color("50534b"))
	_box(Vector3(0.68, 0.18, 0.36), Vector3(0, 1.0, -0.34), Color("a66a45"))
	for x in [-0.47, 0.47]:
		_box(Vector3(0.22, 0.77, 0.22), Vector3(x, 1.09, 0), Color("bf986a"))
	for x in [-0.20, 0.20]:
		_box(Vector3(0.23, 0.60, 0.26), Vector3(x, 0.36, 0), Color("42484c"))
	_box(Vector3(0.85, 1.1, 0.12), Vector3(0, 1.15, 0.30), Color("933d34"))
	blade = _box(Vector3(0.10, 0.90, 0.12), Vector3(0.62, 1.04, -0.22), Color("b9d2d2"))
	_box(Vector3(0.34, 0.11, 0.12), Vector3(0.62, 0.65, -0.22), Color("d1ad5c"))

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func _sphere(pos: Vector3, scale: Vector3, c: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.scale = scale
	n.material_override = _mat(c)
	visual.add_child(n)

func _box(size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(c)
	visual.add_child(n)
	return n

func set_spear(equipped: bool) -> void:
	if blade != null:
		blade.scale.y = 1.75 if equipped else 1.0
		blade.material_override = _mat(Color("e6d4a3") if equipped else Color("b9d2d2"))

func _physics_process(delta: float) -> void:
	elapsed += delta
	var control := Input.get_vector("outpost_left", "outpost_right", "outpost_up", "outpost_down")
	if hud != null and hud.move_vector.length() > 0.12:
		control = hud.move_vector
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var direction: Vector3 = (right * control.x - forward * control.y).normalized()
	velocity.x = direction.x * 5.2
	velocity.z = direction.z * 5.2
	velocity.y = -0.1 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	if direction.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 12.0, 1.0))
	if elapsed - last_hit > 6.0:
		health = minf(100.0, health + delta * 2.0)

func take_hit(amount: float) -> void:
	health = maxf(0.0, health - amount)
	last_hit = elapsed
	if health <= 0.0:
		health = 100.0
		global_position = Vector3(0, 0.35, 0)
		game.hud.toast("Defeated! Respawned at outpost; items kept.")
	else:
		game.hud.toast("Ouch! -%d HP" % int(amount))
