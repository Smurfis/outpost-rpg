extends CharacterBody3D
## Outpost v0.5: modular original OBJ adventurer with animated limbs and equipment.
const MODEL_ROOT: String = "res://assets/models/"
const VOXEL_CHARACTER = preload("res://scripts/voxel/voxel_character.gd")

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
var torch_pivot: Node3D
var torch_light: OmniLight3D
var cloak_pivot: Node3D
var sword_mesh: MeshInstance3D
var weapon_grip: Node3D
var combat_phase: float = 0.0
var gather_phase: float = 0.0
var walking_phase: float = 0.0
var walk_amount: float = 0.0
var last_gather: String = ""
@export var auto_step_enabled: bool = true
@export_range(0.1, 1.5, 0.05) var max_auto_step_height: float = 1.05
const STEP_LANDING_TOLERANCE: float = 0.06
const STEP_CAPSULE_PROBE: float = 0.46 # Move the sample past the capsule front edge.
# Dungeon portal interaction state: manually operated by default.
var interaction_target: Vector3 = Vector3.ZERO
var interaction_moving: bool = false
var interaction_locked: bool = false

func move_to_interaction(target: Vector3) -> void:
	interaction_target = target
	interaction_moving = true

func stop_interaction_move() -> void:
	interaction_moving = false

func setup(game_ref: Node, hud_ref: CanvasLayer, camera_ref: Camera3D) -> void:
	game = game_ref
	hud = hud_ref
	camera = camera_ref
	# Descend a one-voxel terrace without bouncing or requiring a jump press.
	floor_snap_length = 1.15 if bool(game.get("voxel_art_enabled")) else 0.1
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
	# Attach equipment to the wrist instead of letting a blade point vertically
	# through the adventurer's upper arm. The blade's OBJ/voxel local +Y points
	# from the hilt to the tip, so rotate it toward the ground and slightly forward.
	weapon_grip = Node3D.new()
	weapon_grip.name = "WeaponGrip"
	weapon_grip.position = Vector3(0.03, -0.60, -0.11)
	right_arm.add_child(weapon_grip)
	sword_mesh = _model("steel_sword", weapon_grip, Vector3.ZERO)
	shield_mesh = _model("kite_shield", left_arm, Vector3(-0.07, -0.46, -0.29))
	shield_mesh.visible = false
	# Independent off-hand torch, compatible with the existing shield slot.
	torch_pivot = Node3D.new()
	torch_pivot.name = "OffhandTorch"
	torch_pivot.position = Vector3(-0.07, -0.46, -0.25)
	left_arm.add_child(torch_pivot)
	var lantern: MeshInstance3D = VOXEL_CHARACTER.create_part("hand_torch")
	if lantern != null:
		torch_pivot.add_child(lantern)
	torch_light = OmniLight3D.new()
	torch_light.name = "TorchLight"
	torch_light.position = Vector3(0, 0.88, 0)
	torch_light.light_color = Color("ffb665")
	torch_light.light_energy = 1.75
	torch_light.omni_range = 7.4
	torch_light.shadow_enabled = false # One cheap, shadowless local light for mobile.
	torch_pivot.add_child(torch_light)
	torch_pivot.visible = false
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
	var model: MeshInstance3D
	if game != null and bool(game.get("voxel_art_enabled")):
		model = VOXEL_CHARACTER.create_part(id)
	if model == null:
		model = MeshInstance3D.new()
		model.mesh = load(MODEL_ROOT + id + ".obj") as Mesh
	model.name = id
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
	# The neutral sword hangs diagonally beside the right thigh. The longer
	# spear points forward, rather than vertically through the right arm.
	# This is cosmetic: item stats, hitboxes and save IDs are unchanged.
	if weapon_grip != null:
		weapon_grip.rotation = Vector3(PI + (0.85 if id == "spear" else 0.64), 0.05, 0.29)
	var pixel_mode: bool = game != null and bool(game.get("voxel_art_enabled"))
	if pixel_mode:
		# The voxel character shares a nearest-filtered atlas with the world.
		# Never tint the pixel sword with the old smooth OBJ override material.
		var visual_id: String = "iron_blade" if id == "iron_blade" else "steel_spear" if id == "spear" else "steel_sword"
		var replacement: MeshInstance3D = VOXEL_CHARACTER.create_part(visual_id)
		if replacement != null:
			sword_mesh.mesh = replacement.mesh
			sword_mesh.material_override = replacement.material_override
		sword_mesh.scale = Vector3(0.85, 0.84, 0.85) if id == "iron_blade" else Vector3(0.81, 0.78, 0.81) if id == "spear" else Vector3(0.76, 0.76, 0.76)
	elif id == "iron_blade":
		sword_mesh.scale = Vector3(0.90, 0.84, 0.90)
		sword_mesh.material_override = _material(Color("b7d7e2"))
	elif id == "spear":
		sword_mesh.scale = Vector3(0.78, 0.72, 0.78)
		sword_mesh.material_override = _material(Color("d2b782"))
	else:
		sword_mesh.scale = Vector3(0.76, 0.76, 0.76)
		sword_mesh.material_override = _material(Color("b2b6a9"))

func set_spear(equipped: bool) -> void:
	set_weapon("spear" if equipped else "training_blade")

func set_shield(equipped: bool) -> void:
	if shield_mesh != null:
		shield_mesh.visible = equipped

func set_torch(equipped: bool) -> void:
	if torch_pivot != null:
		torch_pivot.visible = equipped
	if torch_light != null:
		torch_light.visible = equipped

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
	var modal_open: bool = (game.menu != null and game.menu.visible) or (game.coop != null and game.coop.ui != null and game.coop.ui.visible) or interaction_locked
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
	if interaction_moving and not modal_open:
		if control.length() > 0.15:
			stop_interaction_move()
		else:
			var towards: Vector3 = interaction_target - global_position
			towards.y = 0.0
			if towards.length() <= 2.4:
				stop_interaction_move()
				direction = Vector3.ZERO
			else:
				direction = towards.normalized()
	var speed: float = 6.0 if str(game.equipment.get("back", "")) == "cloak" else 5.1
	if gather_phase > 0.0:
		speed *= 0.42
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	var grounded_before_motion: bool = is_on_floor()
	velocity.y = -0.1 if grounded_before_motion else velocity.y - 18.0 * delta
	move_and_slide()
	if auto_step_enabled and not modal_open and grounded_before_motion and is_on_wall() and direction.length_squared() > 0.02:
		_try_auto_step(direction * speed * delta)
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
	# Combat once left the wrist rolled inward permanently until another attack.
	# Restore the relaxed, slightly outward arm pose after every swing or harvest.
	if combat_phase <= 0.0:
		right_arm.rotation.z = lerpf(right_arm.rotation.z, 0.12, minf(1.0, delta * 11.0))
	cloak_pivot.rotation.x = 0.07 * sin(walking_phase * 0.6) * walk_amount
	if elapsed - last_hit > 6.0:
		health = minf(100.0, health + delta * 2.0)

func _try_auto_step(horizontal_motion: Vector3) -> bool:
	# The Fields biome needs one-block ledge climbing, NOT a wall-climb exploit.
	# Do not step during an active dungeon run or while airborne.
	var manager: Node = game.get_node_or_null("Dungeons") if game != null else null
	if manager != null and manager.get("active_instance") != null:
		return false
	if horizontal_motion.length_squared() < 0.0001 or not bool(game.get("voxel_art_enabled")):
		return false
	var up: Vector3 = Vector3.UP * (max_auto_step_height + STEP_LANDING_TOLERANCE)
	var original: Transform3D = global_transform
	if test_move(original, up):
		return false # Low ceiling or other obstacle directly above the player.
	var raised: Transform3D = original.translated(up)
	# A 0.38-radius capsule contacts the wall BEFORE its centre reaches the
	# top tile. Extend the safe probe past that radius, or normal joystick
	# movement would never find the landing surface.
	var probe_motion: Vector3 = horizontal_motion + horizontal_motion.normalized() * STEP_CAPSULE_PROBE
	if test_move(raised, probe_motion):
		return false # The elevated path is blocked by a full-height wall.
	var candidate: Vector3 = original.origin + probe_motion
	var start: Vector3 = candidate + Vector3.UP * (max_auto_step_height + 0.28)
	var end: Vector3 = candidate - Vector3.UP * 0.25
	var query := PhysicsRayQueryParameters3D.create(start, end, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if normal.dot(Vector3.UP) < 0.75:
		return false
	var rise: float = float((hit["position"] as Vector3).y - original.origin.y)
	if rise <= 0.045 or rise > max_auto_step_height:
		return false
	# Revalidate horizontally at the final elevation before moving the body.
	var landing: Transform3D = original.translated(Vector3.UP * (rise + STEP_LANDING_TOLERANCE))
	if test_move(landing, probe_motion):
		return false
	global_position = candidate + Vector3.UP * (rise + STEP_LANDING_TOLERANCE)
	velocity.y = 0.0
	apply_floor_snap()
	return true

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
