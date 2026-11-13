extends CharacterBody3D
const VOXEL_STEP = preload("res://scripts/world/voxel_step.gd")
## Wild boar: animated Cube World rig, bristled back and tusks, original hostile AI.
const VOXEL_CREATURES = preload("res://scripts/voxel/voxel_creatures.gd") # Model-import failure fallback.
const VISUAL = preload("res://scripts/creatures/cube_world_visual.gd")
const BOAR_STYLE = preload("res://scripts/creatures/boar_style.gd")
const PIXEL_FEEDBACK = preload("res://scripts/vfx/pixel_feedback.gd")
var hero
var game
var max_hp: float = 32.0
var hp := 32.0
var alive := true
var map_disposition: String = "hostile"
var map_label: String = "Wild boar"
var kill_kind: String = "boar"
var move_speed: float = 2.0
var aggro_radius: float = 8.0
var melee_damage: float = 9.0
var attack_reach: float = 1.8
var stop_distance: float = 1.45
var attack_event: String = "Headbutt"
var remove_on_death: bool = false

func map_record() -> Dictionary:
	return {"id": "mob:%d" % get_instance_id(), "position": global_position,
		"category": "creature", "label": map_label, "dimension": "overworld",
		"disposition": map_disposition, "alive": alive, "visible_on_radar": visible}
var cooldown := 1.5
var respawn := 0.0
var spawn_pos := Vector3.ZERO
var visual: Node3D
var avatar
var death_display: float = 0.0
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
	# Import the pack creature once per actor; visual animations do not own combat physics.
	avatar = VISUAL.new()
	visual.add_child(avatar)
	if avatar.configure("pig", 1.04):
		BOAR_STYLE.decorate(avatar.model)
	else:
		push_warning("Animated boar unavailable; using voxel boar fallback.")
		visual.remove_child(avatar)
		avatar.queue_free()
		avatar = null
		visual.add_child(VOXEL_CREATURES.create_boar())
	add_to_group("enemies")
	add_to_group("wild_boars")
	add_to_group("map_creatures")

func _physics_process(delta: float) -> void:
	if not alive:
		if death_display > 0.0:
			death_display -= delta
			if death_display <= 0.0:
				visual.visible = false
		if remove_on_death and death_display <= 0.0:
			queue_free()
			return
		respawn -= delta
		if not remove_on_death and respawn <= 0.0:
			alive = true
			hp = max_hp
			death_display = 0.0
			global_position = spawn_pos
			visible = true
			visual.visible = true
			if avatar != null:
				avatar.revive()
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
	if dist < aggro_radius and dist > stop_distance:
		pursuit = direction.normalized()
	# A physical short recoil breaks up pursuit without teleportation.
	velocity.x = pursuit.x * move_speed + knockback_velocity.x
	velocity.z = pursuit.z * move_speed + knockback_velocity.z
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
		var step_rise: float = VOXEL_STEP.try_step(self, pursuit * move_speed * delta, max_climb_height)
		if step_rise > 0.0:
			visual_step_offset += before - global_position
			visual_step_offset = visual_step_offset.limit_length(1.0)
	visual_step_offset = visual_step_offset.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))
	visual.position = visual_step_offset
	# Boars and GM bosses face the hero when stopping to attack.
	var facing: Vector3 = pursuit
	if dist <= stop_distance and dist > 0.02:
		facing = direction.normalized()
	if facing.length_squared() > 0.02:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), minf(delta * 10.0, 1.0))
	if avatar != null:
		avatar.play_motion(move_speed if pursuit.length_squared() > 0.02 else 0.0)
	cooldown -= delta
	if dist < attack_reach and cooldown <= 0.0:
		cooldown = 1.7
		if avatar != null:
			avatar.play_event(attack_event)
		hero.take_hit(melee_damage, global_position)

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
		death_display = 1.2
		if avatar != null:
			avatar.play_event("Death")
		collision_layer = 0
		collision_mask = 0
		respawn = 20.0
		game.on_enemy_killed(kill_kind)
