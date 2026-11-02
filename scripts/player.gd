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
var shield_visual: MeshInstance3D
var strike_phase: float = 0.0
var walking_phase: float = 0.0

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
	_box(Vector3(0.56, 0.20, 0.48), Vector3(0, 1.54, 0), Color("d7c5a3"))
	_box(Vector3(0.87, 0.19, 0.62), Vector3(0, 0.82, 0), Color("624638"))
	_sphere(Vector3(-0.5, 1.45, 0), Vector3(0.45, 0.36, 0.55), Color("7c8684"))
	_sphere(Vector3(0.5, 1.45, 0), Vector3(0.45, 0.36, 0.55), Color("7c8684"))
	_box(Vector3(0.55, 0.12, 0.50), Vector3(-0.21, 0.12, -0.1), Color("4a342c"))
	_box(Vector3(0.55, 0.12, 0.50), Vector3(0.21, 0.12, -0.1), Color("4a342c"))
	shield_visual = _box(Vector3(0.22, 0.80, 0.58), Vector3(-0.72, 1.15, -0.12), Color("ab8452"))
	shield_visual.visible = false
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
	mesh.radial_segments = 10
	mesh.rings = 5
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

func set_shield(equipped: bool) -> void:
	if shield_visual != null:
		shield_visual.visible = equipped

func swing() -> void:
	strike_phase = 1.0

func _physics_process(delta: float) -> void:
	elapsed += delta
	var control: Vector2 = Input.get_vector("outpost_left", "outpost_right", "outpost_up", "outpost_down")
	if game.menu != null and game.menu.visible:
		control = Vector2.ZERO
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
		walking_phase += delta * 11.0
		visual.position.y = absf(sin(walking_phase)) * 0.065
	else:
		visual.position.y = lerpf(visual.position.y, 0.0, minf(delta * 9.0, 1.0))
	strike_phase = maxf(0.0, strike_phase - delta * 3.4)
	if blade != null:
		blade.rotation.x = sin(strike_phase * PI) * -1.7
	if elapsed - last_hit > 6.0:
		health = minf(100.0, health + delta * 2.0)

func take_hit(amount: float) -> void:
	var protection: float = 0.6 if int(game.inventory.get("shield", 0)) > 0 else 1.0
	var actual: float = amount * protection
	health = maxf(0.0, health - actual)
	last_hit = elapsed
	if health <= 0.0:
		health = 100.0
		global_position = Vector3(0, 0.35, 0)
		game.hud.toast("Defeated! Respawned at outpost; items kept.")
	else:
		game.hud.toast("Ouch! -%d HP" % int(roundf(actual)))
