extends CharacterBody3D
## Lightweight dungeon guardian; compatible with Outpost's existing melee targeting.
const RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
var hero: CharacterBody3D
var dungeon: Node3D
var hp: float = 24.0
var alive: bool = true
var cooldown: float = 0.0
var visual: Node3D
var quality: int = 0
var damage_multiplier: float = 1.0
var display_name: String = "Crypt Guardian"

func setup(player: CharacterBody3D, instance: Node3D, tier: int, at: Vector3) -> void:
	hero = player
	dungeon = instance
	quality = RARITY.bounded(tier)
	position = at
	hp = 24.0 + float(quality) * 15.0
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
	if not alive or hero == null or not is_instance_valid(hero):
		return
	var to_player: Vector3 = hero.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var direction := Vector3.ZERO
	if distance > 1.5 and distance < 8.0:
		direction = to_player.normalized()
	velocity.x = direction.x * (2.0 + float(quality) * 0.24)
	velocity.z = direction.z * (2.0 + float(quality) * 0.24)
	velocity.y = -0.1 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	if direction.length() > 0.02:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))
	cooldown = maxf(0.0, cooldown - delta)
	if distance < 1.75 and cooldown <= 0.0:
		cooldown = 1.7
		hero.take_hit((6.0 + float(quality) * 2.1) * damage_multiplier)

func receive_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		alive = false
		collision_layer = 0
		collision_mask = 0
		remove_from_group("enemies")
		if dungeon != null and is_instance_valid(dungeon):
			dungeon.guardian_defeated()
		queue_free()
