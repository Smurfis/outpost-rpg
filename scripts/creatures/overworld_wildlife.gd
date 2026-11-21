extends CharacterBody3D
## Cube World pigs and raccoons wander/flee; wolves pursue/attack.
## All use original hit, collision, animation and loot plumbing.
const VISUAL = preload("res://scripts/creatures/cube_world_visual.gd")
const VOXEL_STEP = preload("res://scripts/world/voxel_step.gd")
const FEEDBACK = preload("res://scripts/vfx/pixel_feedback.gd")
const CRUMBLE = preload("res://scripts/vfx/voxel_death_crumble.gd")
var game: Node
var hero: CharacterBody3D
var species: String = "pig"
var max_hp: float = 22.0
var hp: float = 22.0
var alive: bool = true
var cooldown: float = 0.0
var respawn: float = 0.0
var death_display: float = 0.0
var spawn_pos: Vector3 = Vector3.ZERO
var visual: Node3D
var avatar
var wander_direction: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var panic: float = 0.0
var rng := RandomNumberGenerator.new()
var knockback_velocity: Vector3 = Vector3.ZERO
var burn_left: float = 0.0
var burn_tick: float = 0.0
@export var max_climb_height: float = 0.65

func setup(game_ref: Node, player_ref: CharacterBody3D, at: Vector3, kind: String) -> void:
	game = game_ref
	hero = player_ref
	species = kind if kind in ["wolf", "pig", "raccoon"] else "pig"
	name = "WildWolf" if species == "wolf" else "WildRaccoon" if species == "raccoon" else "WildPig"
	spawn_pos = at
	position = at
	rng.seed = int(absf(at.x) * 271.0 + absf(at.z) * 137.0 + (993 if species == "wolf" else 727 if species == "raccoon" else 311))
	hp = 38.0 if species == "wolf" else 24.0 if species == "raccoon" else 20.0
	max_hp = hp
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.43 if species == "wolf" else 0.38 if species == "raccoon" else 0.36
	capsule.height = 1.25 if species == "wolf" else 1.10 if species == "raccoon" else 1.05
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	avatar = VISUAL.new()
	visual.add_child(avatar)
	if not avatar.configure(species, 0.73 if species == "raccoon" else 0.78):
		push_warning("Outpost overworld wildlife model unavailable: " + species)
	add_to_group("enemies")
	add_to_group("overworld_wildlife")
	add_to_group("wild_wolves" if species == "wolf" else "wild_raccoons" if species == "raccoon" else "wild_pigs")
	add_to_group("map_creatures")
	_choose_wander()

func map_record() -> Dictionary:
	return {"id": "mob:%d" % get_instance_id(), "position": global_position,
		"category": "creature", "label": "Wolf" if species == "wolf" else "Raccoon" if species == "raccoon" else "Pig",
		"dimension": "overworld", "alive": alive, "visible_on_radar": visible,
		"disposition": "hostile" if species == "wolf" else "neutral" if species == "raccoon" else "passive"}

func _choose_wander() -> void:
	wander_timer = rng.randf_range(1.4, 4.1)
	if rng.randf() < 0.38:
		wander_direction = Vector3.ZERO
	else:
		var angle: float = rng.randf_range(0.0, TAU)
		wander_direction = Vector3(cos(angle), 0.0, sin(angle))

func _physics_process(delta: float) -> void:
	if not alive:
		if death_display > 0.0:
			death_display -= delta
			if death_display <= 0.0:
				visual.visible = false
		respawn -= delta
		if respawn <= 0.0:
			_respawn()
		return
	if hero == null or not is_instance_valid(hero):
		return
	if burn_left > 0.0:
		burn_left = maxf(0.0, burn_left - delta)
		burn_tick += delta
		if burn_tick >= 1.0:
			burn_tick -= 1.0
			receive_damage(3.0)
			if not alive:
				return
	panic = maxf(0.0, panic - delta)
	cooldown = maxf(0.0, cooldown - delta)
	var to_hero: Vector3 = hero.global_position - global_position
	to_hero.y = 0.0
	var distance: float = to_hero.length()
	var direction: Vector3 = Vector3.ZERO
	var speed: float = 0.0
	if species == "wolf" and distance < 9.0:
		if distance > 1.55:
			direction = to_hero.normalized()
			speed = 3.3
		elif cooldown <= 0.0:
			cooldown = 1.7
			avatar.play_event("Headbutt")
			hero.take_hit(7.5, global_position)
	elif species != "wolf" and (distance < 4.7 or panic > 0.0):
		if distance > 0.05:
			direction = -to_hero.normalized()
		else:
			direction = Vector3.FORWARD
		speed = 3.0
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			_choose_wander()
		var leash: Vector3 = spawn_pos - global_position
		leash.y = 0.0
		if leash.length() > 5.0:
			direction = leash.normalized()
		else:
			direction = wander_direction
		speed = 1.0 if species == "pig" else 1.15 if species == "raccoon" else 1.25
	# Keep creatures in their overworld neighbourhood, not on dungeon portals.
	var outward: Vector3 = global_position - spawn_pos
	outward.y = 0.0
	if outward.length() > 8.5 and direction.dot(outward) > 0.0:
		direction = -outward.normalized()
	velocity.x = direction.x * speed + knockback_velocity.x
	velocity.z = direction.z * speed + knockback_velocity.z
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 9.0)
	var grounded: bool = is_on_floor()
	velocity.y = -0.1 if grounded else velocity.y - 18.0 * delta
	move_and_slide()
	if grounded and is_on_wall() and speed > 0.0:
		VOXEL_STEP.try_step(self, direction * speed * delta, max_climb_height)
	# A wolf stops advancing at bite range, but must still turn to face its prey.
	# Pigs and raccoons face the direction they flee or wander.
	var facing: Vector3 = direction
	if species == "wolf" and distance <= 1.55 and distance > 0.02:
		facing = to_hero.normalized()
	if facing.length_squared() > 0.02:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 8.0))
	avatar.play_motion(speed if direction.length_squared() > 0.02 else 0.0, species != "wolf" and speed < 1.2 and wander_direction == Vector3.ZERO)

func _respawn() -> void:
	alive = true
	hp = max_hp
	burn_left = 0.0
	burn_tick = 0.0
	panic = 0.0
	cooldown = 1.5
	knockback_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = spawn_pos
	collision_layer = 2
	collision_mask = 1
	visible = true
	visual.visible = true
	avatar.revive()
	_choose_wander()

func apply_knockback(source: Vector3, strength: float = 4.0) -> void:
	var away: Vector3 = global_position - source
	away.y = 0.0
	if away.length_squared() > 0.001:
		knockback_velocity = away.normalized() * minf(strength, 7.0)

func ignite(seconds: float = 4.0) -> void:
	if alive:
		burn_left = maxf(burn_left, clampf(seconds, 0.0, 12.0))
		burn_tick = 0.0

func receive_damage(amount: float) -> void:
	if not alive:
		return
	var dealt: float = minf(hp, maxf(0.0, amount))
	hp -= amount
	panic = 5.0
	if hero != null and is_instance_valid(hero):
		apply_knockback(hero.global_position)
	FEEDBACK.emit_feedback(game, global_position + Vector3.UP * 0.7, dealt, Color("ffcd79"), hp <= 0.0, hp <= 0.0)
	if hp <= 0.0:
		alive = false
		respawn = 30.0
		death_display = 1.2
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		CRUMBLE.spawn(game, self, visual)
		visual.visible = false
		visible = false
		game.on_enemy_killed(species)
	else:
		avatar.play_event("Headbutt" if species != "wolf" else "Idle")
