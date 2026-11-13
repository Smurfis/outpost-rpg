extends CharacterBody3D
const VOXEL_STEP = preload("res://scripts/world/voxel_step.gd")
## Lightweight dungeon guardian; compatible with Outpost's existing melee targeting.
const RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
const CUBE_VISUAL = preload("res://scripts/creatures/cube_world_visual.gd")
const ATTACK_TELEGRAPH = preload("res://scripts/vfx/attack_telegraph.gd")
const CRUMBLE = preload("res://scripts/vfx/voxel_death_crumble.gd")
var hero: CharacterBody3D
var dungeon: Node3D
var max_hp: float = 24.0
var hp: float = 24.0
var alive: bool = true
var cooldown: float = 0.0
var visual: Node3D
var avatar
var appearance: String = ""
var death_left: float = 0.0
var quality: int = 0
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var damage_taken_multiplier: float = 1.0
var affix_ids: Array[String] = []
# Keep authoritative affix names/colours for the player target nameplate.
var affix_entries: Array[Dictionary] = []
var affix_details: String = ""
var display_name: String = "Crypt Guardian"
var affix_label: Label3D
@export var max_climb_height: float = 1.05
@export var can_fly: bool = false
@export var flight_height: float = 1.8
var visual_step_offset: Vector3 = Vector3.ZERO
var burn_left: float = 0.0
var burn_tick: float = 0.0
# Power attacks lock their angle at wind-up start so moving out of the red zone dodges.
var heavy_charge_left: float = 0.0
var heavy_attack_cooldown: float = 4.2
var heavy_telegraph
var heavy_shape: String = ""

func setup(player: CharacterBody3D, instance: Node3D, tier: int, at: Vector3, creature_kind: String = "") -> void:
	hero = player
	dungeon = instance
	quality = RARITY.bounded(tier)
	heavy_attack_cooldown = 4.2
	heavy_charge_left = 0.0
	position = at
	hp = 24.0 + float(quality) * 15.0
	max_hp = hp
	name = "CryptGuardian"
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46
	capsule.height = 1.55
	collider.shape = capsule
	collider.position.y = 0.78
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	# Only Common, Uncommon and Rare use the imported Skeleton / Goblin art.
	# Keep the original higher-tier guardian until those variants are designed.
	if quality <= RARITY.RARE and creature_kind in ["skeleton", "goblin"]:
		var imported = CUBE_VISUAL.new()
		visual.add_child(imported)
		if imported.configure(creature_kind, 0.57):
			avatar = imported
			appearance = creature_kind
			display_name = "Crypt Skeleton" if creature_kind == "skeleton" else "Crypt Goblin"
			add_to_group("enemies")
			add_to_group("dungeon_guardians")
			return
		imported.queue_free()
	var stone: Color = Color("525d65")
	_piece(Vector3(0, 0.85, 0), Vector3(0.83, 1.28, 0.73), stone)
	var armour := MeshInstance3D.new()
	armour.mesh = load("res://assets/models/adventurer_torso.obj") as Mesh
	armour.position = Vector3(0, 0, 0)
	armour.material_override = _material(Color("596773"))
	visual.add_child(armour)
	_piece(Vector3(0, 1.73, 0), Vector3(0.55, 0.48, 0.53), Color("8d9aa1"))
	var mask := MeshInstance3D.new()
	mask.mesh = load("res://assets/models/adventurer_head.obj") as Mesh
	mask.position = Vector3(0, 1.82, -0.02)
	mask.material_override = _material(Color("88959d"))
	visual.add_child(mask)
	_piece(Vector3(-0.64, 0.82, 0), Vector3(0.27, 1.00, 0.29), stone)
	_piece(Vector3(0.64, 0.82, 0), Vector3(0.27, 1.00, 0.29), stone)
	_piece(Vector3(-0.24, 0.16, 0), Vector3(0.32, 0.46, 0.35), Color("404a51"))
	_piece(Vector3(0.24, 0.16, 0), Vector3(0.32, 0.46, 0.35), Color("404a51"))
	_piece(Vector3(-0.15, 1.77, -0.27), Vector3(0.12, 0.09, 0.04), RARITY.color(quality))
	_piece(Vector3(0.15, 1.77, -0.27), Vector3(0.12, 0.09, 0.04), RARITY.color(quality))
	var weapon := MeshInstance3D.new()
	weapon.mesh = load("res://assets/models/steel_sword.obj") as Mesh
	weapon.position = Vector3(0.72, 0.40, -0.22)
	weapon.material_override = _material(RARITY.color(quality).lerp(Color("a8bbc4"), 0.58))
	visual.add_child(weapon)
	add_to_group("enemies")
	add_to_group("dungeon_guardians")

## Called after boss and floor scaling, so the same affixes modify the
## actual final stats rather than being silently overwritten by progression.
func apply_affixes(entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	var names := PackedStringArray()
	var details := PackedStringArray()
	var accent: Color = Color("f3cc87")
	for entry in entries:
		affix_entries.append(entry.duplicate(true))
		affix_ids.append(str(entry.get("id", "")))
		names.append(str(entry.get("name", "")))
		details.append(str(entry.get("description", "")))
		hp *= float(entry.get("hp", 1.0))
		damage_multiplier *= float(entry.get("damage", 1.0))
		speed_multiplier *= float(entry.get("speed", 1.0))
		damage_taken_multiplier *= float(entry.get("defence", 1.0))
		accent = entry.get("colour", accent)
	max_hp = hp
	display_name = "%s %s" % [" ".join(names), display_name]
	affix_details = " • ".join(details)
	affix_label = Label3D.new()
	affix_label.name = "GuardianAffixLabel"
	affix_label.text = "%s\n%s" % [display_name.to_upper(), affix_details]
	affix_label.font_size = 30
	affix_label.pixel_size = 0.005
	affix_label.outline_size = 8
	affix_label.modulate = accent
	affix_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	affix_label.position = Vector3(0, 2.95, 0)
	add_child(affix_label)

func _material(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.78
	return mat

func _piece(at: Vector3, size: Vector3, tint: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.82
	instance.material_override = mat
	visual.add_child(instance)

func _physics_process(delta: float) -> void:
	if not alive:
		if death_left > 0.0:
			death_left -= delta
			if death_left <= 0.0:
				queue_free()
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
	var to_player: Vector3 = hero.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var direction := Vector3.ZERO
	if distance > 1.5 and distance < 8.0 and heavy_charge_left <= 0.0:
		direction = to_player.normalized()
	velocity.x = direction.x * (2.0 + float(quality) * 0.24) * speed_multiplier
	velocity.z = direction.z * (2.0 + float(quality) * 0.24) * speed_multiplier
	var grounded: bool = is_on_floor()
	if can_fly:
		velocity.y = clampf((hero.global_position.y + flight_height - global_position.y) * 2.5, -4.0, 4.0)
	else:
		velocity.y = -0.1 if grounded else velocity.y - 18.0 * delta
	move_and_slide()
	if not can_fly and grounded and is_on_wall() and direction.length_squared() > 0.01:
		var before: Vector3 = global_position
		if VOXEL_STEP.try_step(self, direction * (2.0 + float(quality) * 0.24) * speed_multiplier * delta, max_climb_height) > 0.0:
			visual_step_offset += before - global_position
			visual_step_offset = visual_step_offset.limit_length(1.4)
	visual_step_offset = visual_step_offset.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))
	visual.position = visual_step_offset
	if avatar != null:
		avatar.play_motion(direction.length() * (2.0 + float(quality) * 0.24))
	# Closing to attack range zeroes movement, but should not freeze facing.
	var facing: Vector3 = direction
	if distance <= 1.5 and distance > 0.02:
		facing = to_player.normalized()
	if facing.length_squared() > 0.02 and heavy_charge_left <= 0.0:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 8.0))
	cooldown = maxf(0.0, cooldown - delta)
	heavy_attack_cooldown = maxf(0.0, heavy_attack_cooldown - delta)
	if heavy_charge_left > 0.0:
		heavy_charge_left = maxf(0.0, heavy_charge_left - delta)
		if heavy_charge_left <= 0.0:
			_finish_heavy_attack()
		return
	if cooldown <= 0.0 and distance < 4.2 and heavy_attack_cooldown <= 0.0:
		_begin_heavy_attack(to_player)
	elif distance < 1.75 and cooldown <= 0.0:
		cooldown = 1.7
		if avatar != null:
			avatar.play_event("Attack")
		hero.take_hit((6.0 + float(quality) * 2.1) * damage_multiplier, global_position)

## Goblins sweep a broad cone; skeletons thrust in a line. Higher-tier
## original guardians use a cone. The red ground mesh is the real hit area.
func _begin_heavy_attack(to_player: Vector3) -> void:
	if heavy_charge_left > 0.0 or get_parent() == null:
		return
	heavy_shape = "line" if appearance == "skeleton" else "cone"
	var reach: float = 5.0 if heavy_shape == "line" else 4.0
	heavy_charge_left = 1.1 if quality >= 2 else 0.95
	heavy_attack_cooldown = 6.0 if quality >= 2 else 5.0
	var facing: Vector3 = Vector3(to_player.x, 0.0, to_player.z).normalized()
	if facing.length_squared() < 0.01:
		facing = Vector3.FORWARD
	# Snap the facing rig at commit time and keep the ground area stationary.
	visual.rotation.y = atan2(-facing.x, -facing.z)
	var origin: Vector3 = global_position
	if get_world_3d() != null:
		var ray := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 1.5, global_position - Vector3.UP * 3.0,
			1, [get_rid()])
		var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if not floor_hit.is_empty():
			origin.y = (floor_hit["position"] as Vector3).y
	var marker = ATTACK_TELEGRAPH.new()
	get_parent().add_child(marker)
	marker.global_position = origin + Vector3.UP * 0.065
	marker.configure(heavy_shape, facing, reach, heavy_charge_left)
	heavy_telegraph = marker

func _finish_heavy_attack() -> void:
	cooldown = 1.7
	if avatar != null:
		avatar.play_event("Attack")
	if hero != null and is_instance_valid(hero) and is_instance_valid(heavy_telegraph):
		if heavy_telegraph.contains_position(hero.global_position):
			hero.take_hit((6.0 + float(quality) * 2.1) * damage_multiplier * 1.65, global_position)
	_cancel_heavy_attack()

func _cancel_heavy_attack() -> void:
	heavy_charge_left = 0.0
	if is_instance_valid(heavy_telegraph):
		heavy_telegraph.queue_free()
	heavy_telegraph = null

func ignite(seconds: float = 4.0) -> void:
	if alive:
		burn_left = maxf(burn_left, clampf(seconds, 0.0, 12.0))
		burn_tick = 0.0

func receive_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount * damage_taken_multiplier
	if hp <= 0.0:
		_cancel_heavy_attack()
		alive = false
		collision_layer = 0
		collision_mask = 0
		remove_from_group("enemies")
		# All guardian appearances, including old handcrafted/elite meshes,
		# crumble using the actor\'s actual material and mesh surface colours.
		CRUMBLE.spawn(dungeon if dungeon != null else get_parent(), self, visual)
		visual.visible = false
		death_left = 1.05
		if dungeon != null and is_instance_valid(dungeon):
			dungeon.guardian_defeated()
		if death_left <= 0.0:
			queue_free()
	elif avatar != null:
		avatar.play_event("HitRecieve")
