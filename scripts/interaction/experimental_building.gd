extends Node3D
## Optional construction uses separate bodies; procedural terrain is untouched.
const PICKER = preload("res://scripts/interaction/world_picker.gd")
const MAX_REACH := 5.0
const MAX_BLOCKS := 1024
var game: Node3D
var enabled := false
var preview: MeshInstance3D
var preview_cell := Vector3i.ZERO
var preview_valid := false
var blocks: Dictionary = {}
var valid_material: StandardMaterial3D
var invalid_material: StandardMaterial3D

func setup(owner_game: Node3D, saved: Array) -> void:
	game = owner_game
	name = "ExperimentalBuilding"
	preview = MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.98
	preview.mesh = cube
	valid_material = _preview_material(Color(0.2, 0.9, 0.4, 0.45))
	invalid_material = _preview_material(Color(0.95, 0.2, 0.2, 0.45))
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(preview)
	preview.hide()
	for entry in saved.slice(0, MAX_BLOCKS):
		if entry is Array and entry.size() == 3 and (entry[0] is int or entry[0] is float) and (entry[1] is int or entry[1] is float) and (entry[2] is int or entry[2] is float):
			var cell := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
			if absi(cell.x) <= 384 and absi(cell.z) <= 384 and absi(cell.y) <= 128 and not blocks.has(cell):
				_spawn(cell)

func serialize() -> Array:
	var result: Array = []
	for cell in blocks:
		result.append([cell.x, cell.y, cell.z])
	return result

func set_enabled(value: bool) -> void:
	enabled = value
	preview.visible = value and preview_valid

func _preview_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material

func update_preview(screen: Vector2) -> void:
	preview_valid = false
	if not enabled or game.controls.point_over_ui(screen):
		preview.hide()
		return
	var hit: Dictionary = PICKER.resolve(game, screen)
	if hit.is_empty() or hit.get("target") != null:
		preview.hide()
		return
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	if normal.length_squared() < 0.5:
		preview.hide()
		return
	# A point just beyond the face selects the adjacent world-grid cell.
	var adjacent: Vector3 = point + normal.normalized() * 0.05
	preview_cell = Vector3i(floori(adjacent.x), floori(adjacent.y), floori(adjacent.z))
	if normal.y > 0.7:
		# Starter ground is slightly below zero rather than exactly on grid.
		preview_cell.y = ceili(point.y - 0.01)
	var center := Vector3(preview_cell) + Vector3.ONE * 0.5
	preview_valid = can_place(preview_cell)
	preview.global_position = center
	preview.material_override = valid_material if preview_valid else invalid_material
	preview.show()

func can_place(cell: Vector3i) -> bool:
	if blocks.has(cell) or blocks.size() >= MAX_BLOCKS or int(game.inventory.get("wood", 0)) < 1:
		return false
	var center := Vector3(cell) + Vector3.ONE * 0.5
	if center.distance_to(game.hero.global_position + Vector3.UP * 0.8) > MAX_REACH:
		return false
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 0.94
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1 | 2 | 8
	query.collide_with_areas = true
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func place_preview() -> bool:
	if not enabled or not preview_valid or not can_place(preview_cell):
		return false
	game.inventory["wood"] = int(game.inventory.get("wood", 0)) - 1
	_spawn(preview_cell)
	game._save()
	preview_valid = false
	return true

func _spawn(cell: Vector3i) -> void:
	var body := StaticBody3D.new()
	body.name = "PlacedWood_%d_%d_%d" % [cell.x, cell.y, cell.z]
	body.position = Vector3(cell) + Vector3.ONE * 0.5
	body.collision_layer = 1
	add_child(body)
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3.ONE
	shape.shape = cube
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9a6a3b")
	mesh.material_override = material
	body.add_child(mesh)
	blocks[cell] = body
