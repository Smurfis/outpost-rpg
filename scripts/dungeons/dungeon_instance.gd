extends Node3D
## A fresh, enclosed single-player dungeon cell for each entry; no external scene edits.
signal chest_selected(instance: Node3D)
signal completed(instance: Node3D, reward: Dictionary)

const RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
const GUARDIAN = preload("res://scripts/dungeons/dungeon_guardian.gd")
const CHEST_LOCATION: Vector3 = Vector3(0, 0.0, -16.0)
const SPAWN_LOCATION: Vector3 = Vector3(0, 0.35, 11.0)

var entrance_id: String = ""
var quality: int = 0
var hero: CharacterBody3D
var guards_remaining: int = 0
var claimed: bool = false
var chest_area: Area3D
var chest_label: Label3D
var chest_material: StandardMaterial3D

func setup(id: String, tier: int, player: CharacterBody3D) -> void:
	entrance_id = id
	quality = RARITY.bounded(tier)
	hero = player
	name = "DungeonInstance_" + id.replace(":", "_")
	_make_arena()
	_spawn_guards()
	_make_chest()

func hero_spawn_point() -> Vector3:
	return to_global(SPAWN_LOCATION)

func chest_world_position() -> Vector3:
	return to_global(CHEST_LOCATION)

func can_claim_chest() -> bool:
	return not claimed and guards_remaining == 0

func guardian_defeated() -> void:
	guards_remaining = maxi(0, guards_remaining - 1)
	if chest_label != null and guards_remaining == 0:
		chest_label.text = "TREASURE UNLOCKED"
		chest_material.emission_enabled = true
		chest_material.emission = RARITY.color(quality)
		chest_material.emission_energy_multiplier = 1.7

func claim_chest() -> bool:
	if not can_claim_chest() or hero == null:
		return false
	var displacement: Vector3 = hero.global_position - chest_world_position()
	displacement.y = 0.0
	if displacement.length() > 3.2:
		return false
	claimed = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var reward: Dictionary = RARITY.roll_chest(quality, rng)
	completed.emit(self, reward)
	return true

func _make_arena() -> void:
	_solid(Vector3(14.0, 0.65, 36.0), Vector3(0, -0.38, -3), Color("353f4b"))
	_solid(Vector3(0.55, 3.2, 36.0), Vector3(-7.1, 1.6, -3), Color("515766"))
	_solid(Vector3(0.55, 3.2, 36.0), Vector3(7.1, 1.6, -3), Color("515766"))
	_solid(Vector3(14.7, 3.2, 0.6), Vector3(0, 1.6, 14.6), Color("515766"))
	_solid(Vector3(14.7, 3.2, 0.6), Vector3(0, 1.6, -20.6), Color("515766"))
	var accent: Color = RARITY.color(quality)
	for index in range(8):
		var z: float = 11.0 - float(index) * 4.1
		for side in [-1.0, 1.0]:
			_solid(Vector3(0.65, 2.5, 0.76), Vector3(side * 6.55, 1.25, z), Color("697482"))
			var flame := SphereMesh.new()
			flame.radius = 0.24
			flame.height = 0.48
			_decor(flame, Vector3(side * 6.11, 2.3, z), accent, true)
	# Floor seams and a golden rune at the final chest.
	for index in range(7):
		var plank := BoxMesh.new()
		plank.size = Vector3(12.2, 0.045, 0.13)
		_decor(plank, Vector3(0, 0.01, 10.0 - float(index) * 4.3), Color("75818a"))
	var platform := CylinderMesh.new()
	platform.top_radius = 1.60
	platform.bottom_radius = 1.74
	platform.height = 0.18
	platform.radial_segments = 12
	_decor(platform, CHEST_LOCATION + Vector3(0, 0.01, 0), accent, false)
	var heading := Label3D.new()
	heading.text = "%s  •  %s" % [RARITY.quality_name(quality).to_upper(), RARITY.dungeon_name(quality)]
	heading.modulate = accent
	heading.font_size = 43
	heading.pixel_size = 0.008
	heading.outline_size = 14
	heading.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heading.position = Vector3(0, 3.2, 9.0)
	add_child(heading)

func _solid(size: Vector3, at: Vector3, tint: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	var mesh := BoxMesh.new()
	mesh.size = size
	var model := MeshInstance3D.new()
	model.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.9
	model.material_override = mat
	body.add_child(model)

func _decor(mesh: Mesh, at: Vector3, tint: Color, glow: bool = false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.70
	if glow:
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = 1.2
	item.material_override = mat
	add_child(item)
	return item

func _spawn_guards() -> void:
	guards_remaining = RARITY.guard_count(quality)
	for index in range(guards_remaining):
		var guard := GUARDIAN.new()
		add_child(guard)
		var x: float = -1.6 if index % 2 == 0 else 1.6
		guard.setup(hero, self, quality, Vector3(x, 0.16, 5.5 - float(index) * 3.7))

func _make_chest() -> void:
	chest_area = Area3D.new()
	chest_area.name = "FinalChest"
	chest_area.position = CHEST_LOCATION
	chest_area.collision_layer = 8
	chest_area.collision_mask = 0
	chest_area.input_ray_pickable = true
	add_child(chest_area)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.8, 1.8)
	collision.shape = box
	collision.position.y = 0.90
	chest_area.add_child(collision)
	var bottom := BoxMesh.new()
	bottom.size = Vector3(1.72, 0.74, 1.13)
	_chest_part(bottom, Vector3(0, 0.56, 0), Color("75472e"))
	var lid := BoxMesh.new()
	lid.size = Vector3(1.86, 0.34, 1.18)
	_chest_part(lid, Vector3(0, 1.11, 0), Color("9a6435"))
	var band := BoxMesh.new()
	band.size = Vector3(0.24, 1.01, 1.24)
	_chest_part(band, Vector3(0, 0.80, 0), Color("e4b75f"))
	var emblem := BoxMesh.new()
	emblem.size = Vector3(0.32, 0.25, 0.12)
	var clasp := _chest_part(emblem, Vector3(0, 0.85, -0.66), RARITY.color(quality))
	chest_material = clasp.material_override as StandardMaterial3D
	chest_label = Label3D.new()
	chest_label.text = "DEFEAT THE GUARDIANS"
	chest_label.font_size = 36
	chest_label.pixel_size = 0.006
	chest_label.outline_size = 12
	chest_label.modulate = RARITY.color(quality)
	chest_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chest_label.position = Vector3(0, 2.8, 0)
	chest_area.add_child(chest_label)
	chest_area.input_event.connect(_on_chest_input)

func _chest_part(mesh: Mesh, where: Vector3, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = where
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.25
	node.material_override = mat
	chest_area.add_child(node)
	return node

func _on_chest_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int) -> void:
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var touched: bool = event is InputEventScreenTouch and event.pressed
	if clicked or touched:
		chest_selected.emit(self)
		get_viewport().set_input_as_handled()
