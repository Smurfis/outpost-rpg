extends CharacterBody3D
## Simple boar with pursuit, melee range damage and respawn.
var hero
var game
var hp := 32.0
var alive := true
var cooldown := 1.5
var respawn := 0.0
var spawn_pos := Vector3.ZERO
var visual: Node3D

func setup(game_ref: Node, hero_ref: CharacterBody3D, at: Vector3) -> void:
	game = game_ref
	hero = hero_ref
	position = at
	spawn_pos = at
	name = "WildBoar"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46
	capsule.height = 1.1
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.55
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	_sphere(Vector3(0, 0.63, 0), Vector3(1.55, 0.95, 1.85), Color("794d3b"))
	_sphere(Vector3(0, 0.72, -0.63), Vector3(0.96, 0.80, 0.85), Color("906048"))
	_sphere(Vector3(0, 0.53, -1.02), Vector3(0.62, 0.40, 0.42), Color("ca9b82"))
	for x in [-0.30, 0.30]:
		_sphere(Vector3(x, 1.02, -0.82), Vector3(0.12, 0.14, 0.12), Color("f9d5a4"))
		_sphere(Vector3(x, 1.03, -0.90), Vector3(0.062, 0.070, 0.06), Color("242a29"))
		_sphere(Vector3(x, 0.32, -0.95), Vector3(0.13, 0.22, 0.15), Color("f0d4a0"))
	_sphere(Vector3(0, 0.93, 0.82), Vector3(0.15, 0.15, 0.66), Color("5f3c31"))
	for x in [-0.47, 0.47]:
		_box(Vector3(0.22, 0.52, 0.30), Vector3(x, 0.22, 0.55), Color("51382f"))
		_box(Vector3(0.22, 0.52, 0.30), Vector3(x, 0.22, -0.55), Color("51382f"))
		_sphere(Vector3(x * 0.75, 1.17, -0.50), Vector3(0.42, 0.52, 0.23), Color("684536"))
	add_to_group("enemies")

func _sphere(pos: Vector3, scale_by: Vector3, c: Color) -> void:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 9
	mesh.rings = 5
	n.mesh = mesh
	n.position = pos
	n.scale = scale_by
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	n.material_override = mat
	visual.add_child(n)

func _box(size: Vector3, at: Vector3, tint: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	body.material_override = mat
	visual.add_child(body)

func _physics_process(delta: float) -> void:
	if not alive:
		respawn -= delta
		if respawn <= 0.0:
			alive = true
			hp = 32.0
			global_position = spawn_pos
			visible = true
			collision_layer = 1
			collision_mask = 1
		return
	var direction: Vector3 = hero.global_position - global_position
	direction.y = 0
	var dist := direction.length()
	var pursuit := Vector3.ZERO
	if dist < 8.0 and dist > 1.45:
		pursuit = direction.normalized()
	velocity.x = pursuit.x * 2.0
	velocity.z = pursuit.z * 2.0
	velocity.y = -0.1 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	if pursuit.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-pursuit.x, -pursuit.z), minf(delta * 10.0, 1.0))
	cooldown -= delta
	if dist < 1.8 and cooldown <= 0.0:
		cooldown = 1.7
		hero.take_hit(9.0)

func receive_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		alive = false
		visible = false
		collision_layer = 0
		collision_mask = 0
		respawn = 20.0
		game.on_enemy_killed()
