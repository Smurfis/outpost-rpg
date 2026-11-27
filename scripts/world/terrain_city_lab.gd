extends Node3D
## Standalone in-engine lab; deliberately never reads/writes RPG saves.
const Plan = preload("res://scripts/world/terrain_city_lab_plan.gd")
const Mesher = preload("res://scripts/world/city_lab_mesher.gd")
const Prefab = preload("res://scripts/world/city_lab_prefab.gd")
const Edits = preload("res://scripts/world/city_lab_edits.gd")
const Dungeon = preload("res://scripts/world/city_lab_dungeon_connectors.gd")
var socket_checks: Array[CheckBox] = []
var module_weight: SpinBox
var prefab := Prefab.new()
var edits := Edits.new()
var mesher := Mesher.new()
var meshes: Dictionary = {}
var selection: Array[Vector3i] = []
var copied: Dictionary = {}
var turns := 0
var select_mode: OptionButton
var material_select: OptionButton
var y_offset: SpinBox
var edit_status: Label
var marker: MeshInstance3D
var unsaved := false
var plan := Plan.new()
var city: Node3D
var player: Node3D
var camera: Camera3D
var status: Label
var grid := AStarGrid2D.new()
var path: Array[Vector2i] = []
var seed_value := 64012
var region_x: int = 0
var region_z: int = 0
var angle := 0.75
var zoom := 44.0
var material := StandardMaterial3D.new()
var city_ready := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.roughness = 1.0
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#263944")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d7dfed")
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53,-35,0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	marker = MeshInstance3D.new()
	marker.visible = false
	var highlight := StandardMaterial3D.new()
	highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight.albedo_color = Color(0.95,0.72,0.2,0.24)
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = highlight
	add_child(marker)
	player = Node3D.new()
	add_child(player)
	_box(player,Vector3(0,0.43,0),Vector3(0.62,0.85,0.62),Color("#d2a650"))
	_box(player,Vector3(0,1.07,0),Vector3(0.66,0.55,0.66),Color("#f1d5a2"))
	_box(player,Vector3(0,1.4,0),Vector3(0.72,0.14,0.72),Color("#88423b"))
	_ui()
	_build()

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	instance.mesh = mesh
	parent.add_child(instance)
	instance.position = at

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12,12)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	status = Label.new()
	status.add_theme_font_size_override("font_size",18)
	column.add_child(status)
	var help := Label.new()
	help.text = "Click / tap ground to walk | WASD | Q/E rotate | wheel zoom"
	column.add_child(help)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	for entry in ["New seed","Previous seed","Reload","Rotate left","Rotate right","Zoom in","Zoom out","Go to keep","Far region"]:
		var button := Button.new()
		button.text = entry
		button.custom_minimum_size = Vector2(85,42)
		bar.add_child(button)
		match entry:
			"New seed": button.pressed.connect(_next_seed)
			"Previous seed": button.pressed.connect(_previous_seed)
			"Reload": button.pressed.connect(_reload)
			"Rotate left": button.pressed.connect(func(): angle -= PI/4)
			"Rotate right": button.pressed.connect(func(): angle += PI/4)
			"Zoom in": button.pressed.connect(func(): zoom = maxf(18.0,zoom-6.0))
			"Zoom out": button.pressed.connect(func(): zoom = minf(100.0,zoom+6.0))
			"Go to keep": button.pressed.connect(func(): _route(plan.goal))
			"Far region": button.pressed.connect(_far_region)

	_add_creator_ui(column)
	_add_connector_ui(column)

func _add_creator_ui(column: VBoxContainer) -> void:
	var tools := HBoxContainer.new()
	column.add_child(tools)
	select_mode = OptionButton.new()
	for name_value in ["Walk","Select solid","Select adjacent air"]:
		select_mode.add_item(name_value)
	tools.add_child(select_mode)
	material_select = OptionButton.new()
	for name_value in ["Grass","Road","Stone","Dark stone","Wood","Leaves","Red cloth"]:
		material_select.add_item(name_value)
	material_select.select(2)
	tools.add_child(material_select)
	y_offset = SpinBox.new()
	y_offset.min_value = -16
	y_offset.max_value = 16
	y_offset.value = 0
	y_offset.prefix = "Y "
	tools.add_child(y_offset)
	_tool(tools,"Fill",func(): _fill(material_select.selected))
	_tool(tools,"Erase",func(): _fill(-1))
	_tool(tools,"Undo",_undo)
	_tool(tools,"Save world",_save)
	var assets := HBoxContainer.new()
	column.add_child(assets)
	_tool(assets,"Capture",_capture)
	_tool(assets,"Rotate prefab",_rotate)
	_tool(assets,"Stamp",_stamp)
	_tool(assets,"Export prefab",_export_prefab)
	_tool(assets,"Import prefab",_import_prefab)
	_tool(assets,"Clear selection",_clear_selection)
	edit_status = Label.new()
	edit_status.text = "Creator: select two corners, then fill, erase or capture."
	column.add_child(edit_status)

func _add_connector_ui(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	column.add_child(row)
	var hint := Label.new()
	hint.text = "Module sockets:"
	row.add_child(hint)
	for direction in ["N","E","S","W"]:
		var check := CheckBox.new()
		check.text = direction
		row.add_child(check)
		socket_checks.append(check)
	module_weight = SpinBox.new()
	module_weight.min_value = 1
	module_weight.max_value = 100
	module_weight.value = 5
	module_weight.prefix = "Weight "
	row.add_child(module_weight)
	_tool(row,"Export module",_export_module)
	_tool(row,"Dungeon Lab",_open_dungeon)

func _export_module() -> void:
	if copied.is_empty():
		edit_status.text = "Capture a 15 x 5 x 15 module first"
		return
	var sockets: Array = []
	for d in range(4):
		if socket_checks[d].button_pressed:
			sockets.append({"direction":d,"type":"stone_corridor"})
	var asset := {"schema_version":1,"id":"creator:custom_module","weight":int(module_weight.value),"prefab":copied,"sockets":sockets}
	var validator := Dungeon.new()
	if not validator.register_asset(asset):
		edit_status.text = "Invalid module: check size, central 3x3 openings, floor and connectivity"
		return
	var ok := edits.write_json("user://city_lab_connector.json",asset)
	edit_status.text = "Module exported. Open Dungeon Lab and Import module." if ok else "Module export failed"

func _open_dungeon() -> void:
	if unsaved and not _save(): return
	get_tree().change_scene_to_file("res://scenes/city_lab_dungeon_preview.tscn")

func _tool(parent: HBoxContainer, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0,36)
	button.pressed.connect(action)
	parent.add_child(button)

func _clear_selection() -> void:
	selection.clear()
	marker.visible = false

func _select(p: Vector3i) -> void:
	p.y += int(y_offset.value)
	if not prefab.inside(p):
		edit_status.text = "Selection outside city bounds"
		return
	if selection.size() == 2: selection.clear()
	selection.append(p)
	var other: Vector3i = selection.back()
	var box := prefab.bounds(selection[0],other)
	var shape := BoxMesh.new()
	shape.size = box.size+Vector3.ONE*0.025
	marker.mesh = shape
	marker.position = box.get_center()
	marker.visible = true
	edit_status.text = "Selection: %s to %s" % [str(selection[0]),str(other)]

func _fill(value: int) -> void:
	if not city_ready or selection.is_empty(): return
	var patch: Dictionary = {}
	for p in prefab.selection(selection[0],selection.back()): patch[p] = value
	_apply(patch)

func _capture() -> void:
	if not city_ready or selection.is_empty(): return
	var captured := prefab.capture(plan.blocks,selection[0],selection.back())
	if captured.is_empty():
		edit_status.text = "Capture rejected: empty or larger than 24 blocks per axis"
		return
	copied = captured
	turns = 0
	edit_status.text = "Prefab captured: %d blocks" % copied["voxels"].size()

func _rotate() -> void:
	turns = posmod(turns+1,4)
	edit_status.text = "Prefab rotation: %d degrees" % (turns*90)

func _stamp() -> void:
	if not city_ready or selection.is_empty() or copied.is_empty(): return
	_apply(prefab.stamp(copied,selection[0],turns))

func _apply(patch: Dictionary) -> void:
	if not city_ready or not edits.apply(plan,patch,_player_cell()):
		edit_status.text = "Edit rejected: empty, too large, or blocks required navigation"
		return
	unsaved = true
	_refresh_after_edit(patch)

func _undo() -> void:
	if not city_ready: return
	var patch := edits.undo(plan,_player_cell())
	if patch.is_empty():
		edit_status.text = "Nothing safe to undo"
		return
	unsaved = true
	_refresh_after_edit(patch)

func _refresh_after_edit(patch: Dictionary) -> void:
	path.clear()
	# Snap to current valid cell before recalculating paths.
	player.position = _standing(_player_cell())
	var dirty := edits.dirty_sections(patch)
	for key: Vector3i in dirty:
		var cells: Array = []
		var origin := key*Mesher.SECTION
		for z in range(Mesher.SECTION):
			for y in range(Mesher.SECTION):
				for x in range(Mesher.SECTION):
					var p := origin+Vector3i(x,y,z)
					if plan.blocks.has(p): cells.append(p)
		_render_section(key,cells)
	_rebuild_grid()
	edit_status.text = "Edit applied: %d overlay blocks, %d dirty sections; save world" % [edits.changes.size(),dirty.size()]

func _save() -> bool:
	if not city_ready: return false
	var ok := edits.write_json(edits.filename(seed_value,region_x,region_z),edits.encode(seed_value,region_x,region_z))
	if ok: unsaved = false
	edit_status.text = "City edits saved" if ok else "Save failed; edits remain in memory"
	return ok

func _export_prefab() -> void:
	if copied.is_empty(): return
	var ok := edits.write_json("user://city_lab_prefab.json",copied)
	edit_status.text = "Prefab exported: user://city_lab_prefab.json" if ok else "Prefab export failed"

func _import_prefab() -> void:
	var value: Variant = edits.read_json("user://city_lab_prefab.json")
	if prefab.decode(value).is_empty():
		edit_status.text = "Prefab missing or invalid"
		return
	copied = value
	turns = 0
	edit_status.text = "Prefab imported; select an anchor and Stamp"

func _far_region() -> void:
	if unsaved and not _save(): return
	region_x = 1000000000000 if region_x == 0 else 0
	region_z = -1000000000000 if region_x != 0 else 0
	_build()

func _next_seed() -> void:
	if unsaved and not _save(): return
	seed_value += 1
	_build()

func _previous_seed() -> void:
	if unsaved and not _save(): return
	seed_value -= 1
	_build()

func _reload() -> void:
	if unsaved and not _save(): return
	_build()

func _build() -> void:
	city_ready = false
	unsaved = false
	_clear_selection()
	meshes.clear()
	path.clear()
	if city != null:
		remove_child(city)
		city.queue_free()
	city = Node3D.new()
	add_child(city)
	if not plan.generate(seed_value,region_x,region_z):
		status.text = "City validation failed for seed %d — choose New seed" % seed_value
		return
	edits.reset(plan.blocks)
	var save_path := edits.filename(seed_value,region_x,region_z)
	if FileAccess.file_exists(save_path):
		var saved: Variant = edits.decode(edits.read_json(save_path),seed_value,region_x,region_z)
		if saved == null or (not saved.is_empty() and not edits.apply(plan,saved,plan.start,false)):
			status.text = "Saved overlay invalid; not overwritten. Choose another region."
			return
	var buckets := mesher.bucket(plan.blocks)
	var face_count := 0
	var quad_count := 0
	for key: Vector3i in buckets:
		var result := _render_section(key,buckets[key])
		face_count += int(result["exposed"])
		quad_count += result["quads"].size()
	_rebuild_grid()
	player.position = _standing(plan.start)
	_update_camera()
	status.text = "CITY LAB | %d | Region %d,%d | %d lots | %d BSP rooms | %d meshes | %d/%d quads" % [seed_value,region_x,region_z,plan.districts.size(),plan.rooms.size(),city.get_child_count(),quad_count,face_count]

	city_ready = true
	print("CITY LAB READY: ",status.text)

func _render_section(key: Vector3i, cells: Array) -> Dictionary:
	if meshes.has(key):
		var previous: MeshInstance3D = meshes[key]
		city.remove_child(previous)
		previous.queue_free()
		meshes.erase(key)
	var result := mesher.rectangles(plan.blocks,cells,key)
	if not result["quads"].is_empty():
		var instance := MeshInstance3D.new()
		instance.mesh = mesher.build_mesh(result)
		instance.material_override = material
		city.add_child(instance)
		instance.position = Vector3(key*Mesher.SECTION)
		meshes[key] = instance
	return result

func _rebuild_grid() -> void:
	grid.clear()
	grid.region = Rect2i(0,0,Plan.SIZE,Plan.SIZE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for z in range(Plan.SIZE):
		for x in range(Plan.SIZE):
			var cell := Vector2i(x,z)
			if not plan.walkable(cell): grid.set_point_solid(cell,true)

func _standing(p: Vector2i) -> Vector3:
	return Vector3(p.x+0.5,plan.height_at(p)+1.0,p.y+0.5)

func _player_cell() -> Vector2i:
	return Vector2i(floori(player.position.x),floori(player.position.z))

func _route(to: Vector2i) -> void:
	if not city_ready or not plan.walkable(to) or not plan.walkable(_player_cell()): return
	path.clear()
	for cell in grid.get_id_path(_player_cell(),to):
		path.append(cell)
	if not path.is_empty(): path.pop_front()

func _pick(screen: Vector2) -> void:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	# Stop at first occupied voxel rather than selecting through visible walls.
	if not city_ready: return
	var previous := Vector3i(floori(origin.x),floori(origin.y),floori(origin.z))
	for i in range(1200):
		var point := origin+direction*(i*0.125)
		var voxel := Vector3i(floori(point.x),floori(point.y),floori(point.z))
		if not plan.blocks.has(voxel):
			previous = voxel
			continue
		if select_mode.selected != 0:
			_select(voxel if select_mode.selected == 1 else previous)
			return
		var cell := Vector2i(voxel.x,voxel.z)
		if plan.walkable(cell) and voxel.y == plan.height_at(cell):
			_route(cell)
		return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: _pick(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(18.0,zoom-4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(100.0,zoom+4.0)
	elif event is InputEventScreenTouch and event.pressed:
		_pick(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q: angle -= PI/4
		elif event.keycode == KEY_E: angle += PI/4
		else:
			var d := Vector2i.ZERO
			match event.keycode:
				KEY_W: d = Vector2i(0,-1)
				KEY_S: d = Vector2i(0,1)
				KEY_A: d = Vector2i(-1,0)
				KEY_D: d = Vector2i(1,0)
			if d != Vector2i.ZERO: _route(_player_cell()+d)

func _update_camera() -> void:
	var target := player.position+Vector3(0,1,0)
	camera.position = target+Vector3(cos(angle)*62,65,sin(angle)*62)
	camera.look_at(target,Vector3.UP)
	camera.size = zoom

func _process(delta: float) -> void:
	if player == null or camera == null: return
	if city_ready and not path.is_empty():
		var target := _standing(path[0])
		player.position = player.position.move_toward(target,8.0*delta)
		if player.position.distance_to(target) < 0.03:
			player.position = target
			path.pop_front()
	_update_camera()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not unsaved or _save(): get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if unsaved: _save()
