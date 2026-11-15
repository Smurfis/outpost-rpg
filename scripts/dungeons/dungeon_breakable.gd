extends Area3D
## Real, attackable dungeon scenery; click to hit on desktop or use the
## single smart Interact control on touch. Art uses the shared nearest atlas.
signal shattered(reward: Dictionary)
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const STONE: int = 12
const MOSS: int = 7
const WOOD: int = 8
const IRON: int = 4
const GOLD: int = 5

var active: bool = true
var durability: int = 1
var reward: Dictionary = {}
var prop_kind: String = "barrel"

func setup(kind: String, payout: Dictionary) -> void:
	prop_kind = kind
	reward = payout.duplicate(true)
	name = "Breakable_" + kind
	durability = 2 if kind == "sealed_crate" else 1
	collision_layer = 8
	collision_mask = 0
	input_ray_pickable = true
	set_meta("world_kind", "breakable")
	set_meta("world_action", "Smash")
	add_to_group("dungeon_breakables")
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.35, 1.65, 1.35)
	collider.position = Vector3(0, 0.78, 0)
	collider.shape = shape
	add_child(collider)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"sealed_crate":
			PIXELS.box(st, Vector3(0, 0.52, 0), Vector3(1.24, 1.03, 1.20), WOOD, WOOD)
			for y in [0.16, 0.88]:
				PIXELS.box(st, Vector3(0, y, -0.62), Vector3(1.28, 0.14, 0.12), IRON, IRON)
				PIXELS.box(st, Vector3(0, y, 0.62), Vector3(1.28, 0.14, 0.12), IRON, IRON)
			PIXELS.box(st, Vector3(0, 1.10, 0), Vector3(1.30, 0.14, 1.30), GOLD, WOOD)
		"urn":
			PIXELS.box(st, Vector3(0, 0.09, 0), Vector3(0.48, 0.18, 0.48), MOSS, STONE)
			PIXELS.box(st, Vector3(0, 0.39, 0), Vector3(0.86, 0.48, 0.86), STONE, STONE)
			PIXELS.box(st, Vector3(0, 0.74, 0), Vector3(0.69, 0.22, 0.69), MOSS, STONE)
			PIXELS.box(st, Vector3(0, 0.92, 0), Vector3(0.86, 0.12, 0.86), GOLD, STONE)
		_:
			# Multi-sided staves + separate hoops read as a barrel rather
			# than another solid test cube, without dozens of draw calls.
			PIXELS.box(st, Vector3(0, 0.48, 0), Vector3(0.87, 0.88, 0.88), WOOD, WOOD)
			for side in [-0.48, 0.48]:
				PIXELS.box(st, Vector3(side, 0.48, 0), Vector3(0.13, 0.80, 0.67), WOOD, WOOD)
				PIXELS.box(st, Vector3(0, 0.48, side), Vector3(0.67, 0.80, 0.13), WOOD, WOOD)
			for y in [0.20, 0.78]:
				PIXELS.box(st, Vector3(0, y, 0), Vector3(1.09, 0.10, 1.09), IRON, IRON)
			PIXELS.box(st, Vector3(0, 0.96, 0), Vector3(0.74, 0.12, 0.74), WOOD, WOOD)
	var art := PIXELS.as_instance(st, "BreakableArt")
	add_child(art)

func interact(hero: CharacterBody3D) -> void:
	if not active or hero == null:
		return
	if hero.global_position.distance_to(global_position) > 3.1:
		return
	hero.swing()
	receive_damage(1.0)

func receive_damage(amount: float) -> void:
	if not active or amount <= 0.0:
		return
	durability -= maxi(1, int(ceil(amount)))
	if durability > 0:
		var art: Node3D = get_node_or_null("BreakableArt")
		if art != null:
			var tween := create_tween()
			tween.tween_property(art, "rotation:z", 0.15, 0.07)
			tween.tween_property(art, "rotation:z", 0.0, 0.09)
		return
	active = false
	remove_from_group("dungeon_breakables")
	collision_layer = 0
	shattered.emit(reward.duplicate(true))
	queue_free()
