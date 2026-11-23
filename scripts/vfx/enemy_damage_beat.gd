extends Node3D
## Shared cosmetic hit flash and short fallen pose before the existing crumble.
const CRUMBLE = preload("res://scripts/vfx/voxel_death_crumble.gd")
const FLASH_TIME := 0.16
const FALL_TIME := 0.19
const CRUMBLE_TIME := 0.75
static var white_material: StandardMaterial3D
var meshes: Array[MeshInstance3D] = []
var previous: Array[Material] = []
var actor: Node3D
var rig: Node3D
var burst_parent: Node3D
var elapsed := 0.0
var lethal := false
var fallen := false

static func play(actor_node: Node3D, visual: Node3D, parent: Node3D, killed := false) -> void:
	if actor_node == null or visual == null or parent == null:
		return
	var existing = actor_node.get_node_or_null("EnemyDamageBeat")
	if existing != null:
		if killed:
			existing.lethal = true
			existing.elapsed = 0.0
		return
	var beat = load("res://scripts/vfx/enemy_damage_beat.gd").new()
	beat.name = "EnemyDamageBeat"
	beat.actor = actor_node
	beat.rig = visual
	beat.burst_parent = parent
	beat.lethal = killed
	actor_node.add_child(beat)

func _ready() -> void:
	if white_material == null:
		white_material = StandardMaterial3D.new()
		white_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		white_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		white_material.albedo_color = Color(1, 1, 1, 0.88)
		white_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		meshes.append(mesh)
		previous.append(mesh.material_overlay)
		mesh.material_overlay = white_material

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= FLASH_TIME and not meshes.is_empty():
		_restore()
	if not lethal:
		if elapsed >= FLASH_TIME:
			queue_free()
		return
	if not is_instance_valid(actor) or not is_instance_valid(rig):
		queue_free()
		return
	if elapsed >= FALL_TIME and not fallen:
		fallen = true
		rig.rotation.z = PI * 0.48
		rig.position.y = maxf(0.10, rig.position.y + 0.12)
	if elapsed >= CRUMBLE_TIME:
		CRUMBLE.spawn(burst_parent, actor, rig)
		rig.visible = false
		actor.visible = false
		queue_free()

func _restore() -> void:
	for index in meshes.size():
		if is_instance_valid(meshes[index]) and meshes[index].material_overlay == white_material:
			meshes[index].material_overlay = previous[index]
	meshes.clear()
	previous.clear()

func _exit_tree() -> void:
	_restore()
