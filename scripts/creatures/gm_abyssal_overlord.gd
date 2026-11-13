extends "res://scripts/enemy.gd"
## Original GM-only Abyssal Overlord boss, using the animated Quaternius
## Cube World Demon.gltf (CC0, commercially reusable). No Warcraft assets.
const CUBE_ART = preload("res://scripts/creatures/cube_world_visual.gd")
const TELEGRAPH = preload("res://scripts/vfx/attack_telegraph.gd")
var heavy_timer: float = 4.5
var charge_left: float = 0.0
var warning: Node3D

func setup_gm(game_ref: Node, player_ref: CharacterBody3D, at: Vector3) -> void:
	super.setup(game_ref, player_ref, at)
	name = "AbyssalOverlordBoss"
	map_label = "Abyssal Overlord"
	kill_kind = "overlord"
	remove_on_death = true
	remove_from_group("wild_boars")
	add_to_group("gm_overlords")
	max_hp = 420.0
	hp = max_hp
	move_speed = 2.05
	aggro_radius = 17.0
	stop_distance = 2.4
	attack_reach = 3.0
	melee_damage = 21.0
	attack_event = "Attack"
	max_climb_height = 0.95
	var colliders: Array[Node] = find_children("*", "CollisionShape3D", false, false)
	if not colliders.is_empty():
		var collider: CollisionShape3D = colliders[0] as CollisionShape3D
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.80
		capsule.height = 3.1
		collider.shape = capsule
		collider.position.y = capsule.height * 0.5
	for old_visual in visual.get_children():
		visual.remove_child(old_visual)
		old_visual.queue_free()
	avatar = null
	var demon = CUBE_ART.new()
	visual.add_child(demon)
	if demon.configure("demon", 1.16):
		avatar = demon
	else:
		push_error("GM Abyssal Overlord requires the existing CC0 Quaternius demon model.")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not alive or hero == null or not is_instance_valid(hero):
		_cancel_warning()
		return
	if charge_left > 0.0:
		charge_left -= delta
		if charge_left <= 0.0:
			if is_instance_valid(warning) and warning.has_method("contains_position"):
				if warning.contains_position(hero.global_position):
					hero.take_hit(33.0, global_position)
			if avatar != null:
				avatar.play_event("Attack")
			_cancel_warning()
		return
	heavy_timer -= delta
	if heavy_timer > 0.0:
		return
	var toward: Vector3 = hero.global_position - global_position
	toward.y = 0.0
	if toward.length() > 6.0 or toward.length_squared() < 0.04:
		return
	_begin_warning(toward.normalized())
	heavy_timer = 6.0

func _begin_warning(toward: Vector3) -> void:
	if get_parent() == null or get_world_3d() == null:
		return
	var ground: Vector3 = global_position
	var probe := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 2.0, global_position - Vector3.UP * 5.0,
		1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(probe)
	if not hit.is_empty():
		ground.y = (hit["position"] as Vector3).y
	var marker = TELEGRAPH.new()
	get_parent().add_child(marker)
	marker.global_position = ground + Vector3.UP * 0.065
	marker.configure("cone", toward, 5.8, 1.1)
	warning = marker
	charge_left = 1.1

func _cancel_warning() -> void:
	charge_left = 0.0
	if is_instance_valid(warning):
		warning.queue_free()
	warning = null

func receive_damage(amount: float, trigger_recoil: bool = true) -> void:
	super.receive_damage(amount, trigger_recoil)
	if not alive:
		_cancel_warning()

func _exit_tree() -> void:
	_cancel_warning()
