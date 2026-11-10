extends CharacterBody3D
const VOXEL_STEP = preload("res://scripts/world/voxel_step.gd")
## Simple boar with pursuit, melee range damage and respawn.
const VOXEL_CREATURES = preload("res://scripts/voxel/voxel_creatures.gd")
const PIXEL_FEEDBACK = preload("res://scripts/vfx/pixel_feedback.gd")
var hero
var game
var max_hp: float = 32.0
var hp := 32.0
var alive := true
var cooldown := 1.5
var respawn := 0.0
var spawn_pos := Vector3.ZERO
var visual: Node3D
var knockback_velocity: Vector3 = Vector3.ZERO
var hit_lift: float = 0.0
@export var max_climb_height: float = 0.62
@export var can_fly: bool = false
@export var flight_height: float = 1.5
var visual_step_offset: Vector3 = Vector3.ZERO
var burn_left: float = 0.0
var burn_tick: float = 0.0
var burn_flame: Node3D

func setup(game_ref: Node, hero_ref: CharacterBody3D, at: Vector3) -> void:
	game = game_ref
	hero = hero_ref
	position = at
	spawn_pos = at
	name = "WildBoar"
	collision_layer = 2 # Melee checks use distance. Ignore player collision layer 1.
	collision_mask = 1 # Still collide with terrain.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46
	capsule.height = 1.1
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.55
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	if game != null and bool(game.get("voxel_art_enabled")):
		# Single mesh/draw call, shared 16x16 pixel atlas and nearest filter.
		visual.add_child(VOXEL_CREATURES.create_boar())
	else:
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
	add_to_group("wild_boars")

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
			hp = max_hp
			global_position = spawn_pos
			visible = true
			knockback_velocity = Vector3.ZERO
			hit_lift = 0.0
			burn_left = 0.0
			burn_tick = 0.0
			if burn_flame != null:
				burn_flame.visible = false
			visual_step_offset = Vector3.ZERO
			collision_layer = 2
			collision_mask = 1
		return
	# Flames mirror the existing fiery-weapon status; the damage model is unchanged.
	if burn_flame != null:
		burn_flame.visible = burn_left > 0.0
	# Fire continues to damage the creature without extending combat cooldown.
	if burn_left > 0.0:
		burn_left = maxf(0.0, burn_left - delta)
		burn_tick += delta
		if burn_tick >= 1.0:
			burn_tick -= 1.0
			receive_damage(3.0, false)
			if not alive:
				return
	var direction: Vector3 = hero.global_position - global_position
	direction.y = 0
	var dist := direction.length()
	var pursuit := Vector3.ZERO
	if dist < 8.0 and dist > 1.45:
		pursuit = direction.normalized()
	# A physical short recoil breaks up pursuit without teleportation.
	velocity.x = pursuit.x * 2.0 + knockback_velocity.x
	velocity.z = pursuit.z * 2.0 + knockback_velocity.z
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 12.0)
	var grounded: bool = is_on_floor()
	if can_fly:
		var target_y: float = hero.global_position.y + flight_height
		velocity.y = clampf((target_y - global_position.y) * 2.5, -4.0, 4.0)
	else:
		velocity.y = -0.1 if grounded else velocity.y - 18.0 * delta
		if hit_lift > 0.0:
			velocity.y = hit_lift
			hit_lift = 0.0
	move_and_slide()
	if not can_fly and grounded and is_on_wall() and pursuit.length_squared() > 0.01:
		var before: Vector3 = global_position
		var step_rise: float = VOXEL_STEP.try_step(self, pursuit * 2.0 * delta, max_climb_height)
		if step_rise > 0.0:
			visual_step_offset += before - global_position
			visual_step_offset = visual_step_offset.limit_length(1.0)
	visual_step_offset = visual_step_offset.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))
	visual.position = visual_step_offset
	if pursuit.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-pursuit.x, -pursuit.z), minf(delta * 10.0, 1.0))
	cooldown -= delta
	if dist < 1.8 and cooldown <= 0.0:
		cooldown = 1.7
		hero.take_hit(9.0, global_position)

func apply_knockback(source: Vector3, strength: float = 6.8) -> void:
	var push: Vector3 = global_position - source
	push.y = 0.0
	if push.length_squared() < 0.001:
		push = Vector3(0.0, 0.0, 1.0)
	knockback_velocity = push.normalized() * clampf(strength, 0.0, 10.0)
	hit_lift = 1.7

func ignite(seconds: float = 4.0) -> void:
	if alive:
		burn_left = maxf(burn_left, clampf(seconds, 0.0, 12.0))
		burn_tick = 0.0
		if burn_flame == null:
			var preset_path: String = "res://addons/pyrolux_fx/presets/3d/fire_torch.tscn"
			if ResourceLoader.exists(preset_path):
				var flame_scene: PackedScene = load(preset_path) as PackedScene
				if flame_scene != null:
					burn_flame = flame_scene.instantiate() as Node3D
					if burn_flame != null:
						burn_flame.name = "PyroLuxBurnEffect"
						burn_flame.position = Vector3(0, 0.35, 0)
						burn_flame.scale = Vector3.ONE * 0.55
						add_child(burn_flame)
		if burn_flame != null:
			burn_flame.visible = true

func receive_damage(amount: float, trigger_recoil: bool = true) -> void:
	if not alive:
		return
	var dealt: float = minf(hp, maxf(0.0, amount))
	hp -= amount
	if trigger_recoil and hp > 0.0 and is_instance_valid(hero):
		apply_knockback(hero.global_position)
	PIXEL_FEEDBACK.emit_feedback(game, global_position + Vector3.UP * 0.74, dealt, Color("ffcd79"), hp <= 0.0)
	if hp <= 0.0:
		alive = false
		visible = false
		collision_layer = 0
		collision_mask = 0
		respawn = 20.0
		game.on_enemy_killed()
