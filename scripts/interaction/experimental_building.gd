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
var preview_support: WeakRef
const ROOM_SCAN_RADIUS := 8
var _room_clock := 0.0
var _room_cell := Vector3i(99999, 99999, 99999)
var _room_block_count := -1
var _room_cells: Dictionary = {}

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

func _process(delta: float) -> void:
	if game == null or game.hero == null or game.camera == null or blocks.is_empty():
		return
	_room_clock += delta
	if _room_clock < 0.15:
		return
	_room_clock = 0.0
	_update_interior_cutaway()

func _update_interior_cutaway() -> void:
	var position: Vector3 = game.hero.global_position
	var head := Vector3i(floori(position.x), floori(position.y + 1.0), floori(position.z))
	if head != _room_cell or blocks.size() != _room_block_count:
		_room_cell = head
		_room_block_count = blocks.size()
		_room_cells = _enclosed_room(head)
	var view := Vector2(game.camera.global_position.x - position.x, game.camera.global_position.z - position.z).normalized()
	for cell in blocks:
		var body: StaticBody3D = blocks[cell]
		if not is_instance_valid(body):
			continue
		var column := Vector2i(cell.x, cell.z)
		var roof: bool = cell.y > head.y and _room_cells.has(column)
		var foreground := false
		if cell.y >= head.y and not _room_cells.is_empty():
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var inside: Vector2i = column + offset
				if _room_cells.has(inside) and Vector2(-offset.x, -offset.y).dot(view) > 0.45:
					foreground = true
					break
		var hide: bool = roof or foreground
		var visual: MeshInstance3D = body.get_node_or_null("VisibleBlock")
		if visual != null:
			visual.visible = not hide
		body.set_meta("building_cutaway_hidden", hide)

func _enclosed_room(head: Vector3i) -> Dictionary:
	if blocks.has(head):
		return {}
	var roof_y := _roof_height(head.x, head.z, head.y)
	if roof_y > head.y:
		return _roofed_room(head, roof_y)
	var start := Vector2i(head.x, head.z)
	var found := {start: true}
	var pending: Array[Vector2i] = [start]
	var index := 0
	while index < pending.size():
		var cell: Vector2i = pending[index]
		index += 1
		if absi(cell.x - start.x) >= ROOM_SCAN_RADIUS or absi(cell.y - start.y) >= ROOM_SCAN_RADIUS:
			return {} # Open terrain or a room too large to safely classify.
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if found.has(next) or blocks.has(Vector3i(next.x, head.y, next.y)):
				continue
			found[next] = true
			pending.append(next)
	return found

func _roof_height(x: int, z: int, head_y: int) -> int:
	# Allow useful headroom while keeping the scan bounded; a distant bridge
	# overhead must not classify the surrounding terrain as a building.
	for y in range(head_y + 1, head_y + 5):
		if blocks.has(Vector3i(x, y, z)):
			return y
	return head_y

func _roofed_room(head: Vector3i, roof_y: int) -> Dictionary:
	# Follow only supported roof columns, so an open doorway onto uncovered
	# ground does not make the whole building appear to be outdoor space.
	var start := Vector2i(head.x, head.z)
	var found := {start: true}
	var pending: Array[Vector2i] = [start]
	var index := 0
	while index < pending.size():
		var cell: Vector2i = pending[index]
		index += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if found.has(next) or absi(next.x - start.x) > ROOM_SCAN_RADIUS or absi(next.y - start.y) > ROOM_SCAN_RADIUS:
				continue
			if blocks.has(Vector3i(next.x, head.y, next.y)) or not blocks.has(Vector3i(next.x, roof_y, next.y)):
				continue
			# A narrow doorway is a boundary, not permission to reveal all
			# rooms beyond it. The player's own doorway cell is still usable.
			var side_a := Vector3i(next.x - 1, head.y, next.y)
			var side_b := Vector3i(next.x + 1, head.y, next.y)
			var side_c := Vector3i(next.x, head.y, next.y - 1)
			var side_d := Vector3i(next.x, head.y, next.y + 1)
			if (blocks.has(side_a) and blocks.has(side_b)) or (blocks.has(side_c) and blocks.has(side_d)):
				continue
			found[next] = true
			pending.append(next)
	return found

func update_preview(screen: Vector2) -> void:
	preview_valid = false
	preview_support = null
	if not enabled or game.controls.point_over_ui(screen):
		preview.hide()
		return
	var hit: Dictionary = PICKER.resolve(game, screen)
	if hit.is_empty() or hit.get("target") != null:
		preview.hide()
		return
	var support: Variant = hit.get("collider")
	if not support is StaticBody3D or not is_instance_valid(support):
		preview.hide()
		return
	preview_support = weakref(support)
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
	var dungeon: Node = game.get_node_or_null("Dungeons")
	if dungeon != null and dungeon.get("active_instance") != null:
		return false
	if game.terrain_surface != null and game.terrain_surface.archipelago != null:
		var caves: Variant = game.terrain_surface.archipelago.terrain.caves
		if caves.has_cave(cell.x, cell.z):
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
	var support: Object = preview_support.get_ref() if preview_support != null else null
	if not enabled or not preview_valid or not is_instance_valid(support) or support.is_queued_for_deletion() or not can_place(preview_cell):
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
	mesh.name = "VisibleBlock"
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9a6a3b")
	mesh.material_override = material
	body.add_child(mesh)
	var shadow := MeshInstance3D.new()
	shadow.name = "BlockShadow"
	shadow.mesh = box
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	body.add_child(shadow)
	blocks[cell] = body
	_room_block_count = -1
