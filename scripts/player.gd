extends CharacterBody3D
## Outpost v0.5: modular original OBJ adventurer with animated limbs and equipment.
const MODEL_ROOT: String = "res://assets/models/"

var game
var hud
var camera: Camera3D
var health: float = 100.0
var elapsed: float = 0.0
var last_hit: float = -100.0

var visual: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var shield_mesh: MeshInstance3D
var cloak_pivot: Node3D
var sword_mesh: MeshInstance3D
var combat_phase: float = 0.0
var gather_phase: float = 0.0
var walking_phase: float = 0.0
var walk_amount: float = 0.0
var last_gather: String = ""

func setup(game_ref: Node, hud_ref: CanvasLayer, camera_ref: Camera3D) -> void:
	game = game_ref
	hud = hud_ref
	camera = camera_ref
	name = "Adventurer"
	collision_layer = 1
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	visual = Node3D.new()
	visual.name = "VisualRig"
	add_child(visual)
	_model("adventurer_torso", visual, Vector3.ZERO)
	_model("adventurer_head", visual, Vector3(0, 1.89, -0.035))
	left_arm = _pivot("LeftArm", Vector3(-0.54, 1.51, 0.02))
	right_arm = _pivot("RightArm", Vector3(0.54, 1.51, 0.02))
	left_leg = _pivot("LeftLeg", Vector3(-0.205, 0.78, 0.0))
	right_leg = _pivot("RightLeg", Vector3(0.205, 0.78, 0.0))
	_model("adventurer_arm", left_arm, Vector3.ZERO)
	_model("adventurer_arm", right_arm, Vector3.ZERO)
	_model("adventurer_leg", left_leg, Vector3.ZERO)
	_model("adventurer_leg", right_leg, Vector3.ZERO)
	sword_mesh = _model("steel_sword", right_arm, Vector3(0.01, -0.76, -0.03))
	shield_mesh = _model("kite_shield", left_arm, Vector3(-0.07, -0.46, -0.29))
	shield_mesh.visible = false
	cloak_pivot = _pivot("Cloak", Vector3(0, 1.50, 0.27))
	_model("cloth_cloak", cloak_pivot, Vector3.ZERO)
	cloak_pivot.visible = false
	set_weapon("training_blade")

func _pivot(id: String, location: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = id
	pivot.position = location
	visual.add_child(pivot)
	return pivot

func _model(id: String, parent: Node3D, position_at: Vector3) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	model.name = id
	model.mesh = load(MODEL_ROOT + id + ".obj") as Mesh
	model.position = position_at
	parent.add_child(model)
	return model

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.16
	mat.roughness = 0.72
	return mat

func set_weapon(id: String) -> void:
	if sword_mesh == null:
		return
	if id == "iron_blade":
		sword_mesh.scale = Vector3(1.13, 1.23, 1.13)
		sword_mesh.material_override = _material(Color("b7d7e2"))
	elif id == "spear":
		sword_mesh.scale = Vector3(0.83, 1.35, 0.83)
		sword_mesh.material_override = _material(Color("d2b782"))
	else:
		sword_mesh.scale = Vector3(0.82, 0.72, 0.82)
		sword_mesh.material_override = _material(Color("b2b6a9"))

func set_spear(equipped: bool) -> void:
	set_weapon("spear" if equipped else "training_blade")

func set_shield(equipped: bool) -> void:
	if shield_mesh != null:
		shield_mesh.visible = equipped

func set_cloak(equipped: bool) -> void:
	if cloak_pivot != null:
		cloak_pivot.visible = equipped

func swing() -> void:
	combat_phase = 1.0

func gather_swing(kind: String) -> void:
	last_gather = kind
	gather_phase = 1.0

func _physics_process(delta: float) -> void:
	elapsed += delta
	var modal_open: bool = game.menu != null and game.menu.visible
	var control: Vector2 = Input.get_vector("outpost_left", "outpost_right", "outpost_up", "outpost_down")
	if modal_open:
		control = Vector2.ZERO
	elif hud != null and hud.move_vector.length() > 0.12:
		control = hud.move_vector
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var direction: Vector3 = (right * control.x - forward * control.y).normalized()
	var speed: float = 6.0 if str(game.equipment.get("back", "")) == "cloak" else 5.1
	if gather_phase > 0.0:
		speed *= 0.42
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.1 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	walk_amount = move_toward(walk_amount, direction.length(), delta * 8.0)
	if direction.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 12.0, 1.0))
		walking_phase += delta * 10.6
	visual.position.y = absf(sin(walking_phase)) * 0.06 * walk_amount
	var step: float = sin(walking_phase) * 0.58 * walk_amount
	left_leg.rotation.x = step
	right_leg.rotation.x = -step
	left_arm.rotation.x = -step * 0.55
	right_arm.rotation.x = step * 0.55
	combat_phase = maxf(0.0, combat_phase - delta * 2.8)
	gather_phase = maxf(0.0, gather_phase - delta * 2.3)
	if combat_phase > 0.0:
		right_arm.rotation.x = -1.75 * sin(combat_phase * PI)
		right_arm.rotation.z = -0.31 * sin(combat_phase * PI)
	elif gather_phase > 0.0:
		# Tool swings are animated even before a real tool is owned.
		right_arm.rotation.x = -1.95 * sin(gather_phase * PI)
		left_arm.rotation.x = -0.42 * sin(gather_phase * PI)
		visual.rotation.z = 0.065 * sin(gather_phase * PI)
	else:
		visual.rotation.z = lerpf(visual.rotation.z, 0.0, minf(1.0, delta * 12.0))
	cloak_pivot.rotation.x = 0.07 * sin(walking_phase * 0.6) * walk_amount
	if elapsed - last_hit > 6.0:
		health = minf(100.0, health + delta * 2.0)

func take_hit(amount: float) -> void:
	var protection: float = 0.6 if str(game.equipment.get("offhand", "")) == "shield" else 1.0
	if int(game.inventory.get("cloak", 0)) > 0:
		protection *= 0.9
	var actual: float = amount * protection
	health = maxf(0.0, health - actual)
	last_hit = elapsed
	if health <= 0.0:
		health = 100.0
		global_position = Vector3(0, 0.35, 0)
		game.hud.toast("Defeated! Respawned at outpost; items kept.")
	else:
		game.hud.toast("Ouch! -%d HP" % int(roundf(actual)))
