extends Node3D
## Bounded sector preview. Crossing a gateway replaces the local scene;
## global integer addresses never enter Godot transforms.
const Sector = preload("res://scripts/world/city_lab_dungeon_sector.gd")
const Mesher = preload("res://scripts/world/city_lab_mesher.gd")
const Edits = preload("res://scripts/world/city_lab_edits.gd")
const Dungeon = preload("res://scripts/world/city_lab_dungeon_connectors.gd")
var sector := Sector.new()
var mesher := Mesher.new()
var files := Edits.new()
var seed_value: int = 64012
var sx: int = 0
var sz: int = 0
var custom: Variant = null
var geometry: Node3D
var camera: Camera3D
var player: MeshInstance3D
var label: Label
var blocks: Dictionary = {}
var walk: Dictionary = {}
var grid := AStarGrid2D.new()
var path: Array[Vector2i] = []
var material := StandardMaterial3D.new()
var yaw := 0.75
var zoom := 35.0
var ready_to_walk := false

func _ready() -> void:
	get_tree().auto_accept_quit = true
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.roughness = 1.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#181e28")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dfd6ca")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60,-40,0)
	sun.light_energy = 1.1
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	player = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.35
	body.height = 1.5
	player.mesh = body
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("#eab45d")
	player.material_override = skin
	add_child(player)
	_ui()
	_build(Vector2i(37,37))

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(10,10)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	label = Label.new()
	column.add_child(label)
	var row := HBoxContainer.new()
	column.add_child(row)
	_button(row,"City Lab",func(): get_tree().change_scene_to_file("res://scenes/terrain_city_lab.tscn"))
	_button(row,"New seed",_new_seed)
	_button(row,"Import module",_import_module)
	_button(row,"Default pack",_default_pack)
	_button(row,"Rotate",func(): yaw+=PI/4)
	_button(row,"Zoom +",func(): zoom=maxf(15.0,zoom-8.0))
	_button(row,"Zoom -",func(): zoom=minf(90.0,zoom+8.0))
	var gates := HBoxContainer.new()
	column.add_child(gates)
	for d in range(4):
		_button(gates,["North gate","East gate","South gate","West gate"][d],_go_gate.bind(d))
	var help := Label.new()
	help.text = "Click/tap floor to walk. Reach a gateway to enter the adjacent sector."
	column.add_child(help)

func _button(row: HBoxContainer, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0,40)
	button.pressed.connect(action)
	row.add_child(button)

func _new_seed() -> void:
	seed_value += 1
	_build(Vector2i(37,37))

func _default_pack() -> void:
	custom = null
	_build(Vector2i(37,37))

func _import_module() -> void:
	var asset: Variant = files.read_json("user://city_lab_connector.json")
	var validator := Dungeon.new()
	if not validator.load_defaults() or not validator.register_asset(asset):
		label.text = "Custom module rejected: invalid bounds, socket or geometry"
		return
	custom = asset
	_build(Vector2i(37,37))

func _build(spawn: Vector2i) -> void:
	ready_to_walk = false
	path.clear()
	if not sector.generate(seed_value,sx,sz,custom):
		label.text = "Sector generation failed"
		return
	if geometry != null:
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node3D.new()
	add_child(geometry)
	blocks = sector.materialize()
	walk.clear()
	for p: Vector2i in sector.solver.modules:
		var reachable := sector.solver._reachable(sector.solver.materialize(p))
		for cell: Vector2i in reachable: walk[p*Dungeon.SIDE+cell] = true
	var buckets := mesher.bucket(blocks)
	for key: Vector3i in buckets:
		var result := mesher.rectangles(blocks,buckets[key],key)
		if result["quads"].is_empty(): continue
		var node := MeshInstance3D.new()
		node.mesh = mesher.build_mesh(result)
		node.material_override = material
		geometry.add_child(node)
		node.position = Vector3(key*Mesher.SECTION)
	grid.clear()
	grid.region = Rect2i(0,0,Sector.SIDE,Sector.SIDE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for z in range(Sector.SIDE):
		for x in range(Sector.SIDE):
			var p := Vector2i(x,z)
			if not walk.has(p): grid.set_point_solid(p,true)
	if not walk.has(spawn):
		label.text = "Invalid spawn"
		return
	player.position = _standing(spawn)
	ready_to_walk = true
	_update_camera()
	var custom_count := 0
	if custom != null:
		for p in sector.solver.modules:
			if sector.solver.modules[p]["id"] == custom["id"]: custom_count+=1
	label.text = "DUNGEON | Seed %d | Sector %d,%d | 25 modules | Custom: %d | %d meshes" % [seed_value,sx,sz,custom_count,geometry.get_child_count()]
	print("DUNGEON LAB READY: ",label.text)

func _standing(p: Vector2i) -> Vector3:
	return Vector3(p.x+0.5,1.75,p.y+0.5)

func _cell() -> Vector2i:
	return Vector2i(floori(player.position.x),floori(player.position.z))

func _go_gate(d: int) -> void:
	_route(sector.gate_cell(d))

func _route(to: Vector2i) -> void:
	if not ready_to_walk or not walk.has(to) or not walk.has(_cell()): return
	path.clear()
	for p in grid.get_id_path(_cell(),to): path.append(p)
	if not path.is_empty(): path.pop_front()

func _pick(screen: Vector2) -> void:
	if not ready_to_walk: return
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	for i in range(1200):
		var point := origin+direction*(i*0.125)
		var v := Vector3i(floori(point.x),floori(point.y),floori(point.z))
		if not blocks.has(v): continue
		if v.y == 0: _route(Vector2i(v.x,v.z))
		return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: _pick(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom=maxf(15.0,zoom-5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom=minf(90.0,zoom+5.0)
	elif event is InputEventScreenTouch and event.pressed: _pick(event.position)

func _update_camera() -> void:
	var target := player.position
	camera.position = target+Vector3(cos(yaw)*62,65,sin(yaw)*62)
	camera.look_at(target,Vector3.UP)
	camera.size = zoom

func _process(delta: float) -> void:
	if not ready_to_walk: return
	if not path.is_empty():
		var target := _standing(path[0])
		player.position = player.position.move_toward(target,10.0*delta)
		if player.position.distance_to(target)<0.03:
			player.position = target
			var arrived: Vector2i = path.pop_front()
			for d in range(4):
				if arrived != sector.gate_cell(d): continue
				# Guard int64 overflow at the theoretical address limit.
				if (d==1 and sx==9223372036854775807) or (d==3 and sx==(-9223372036854775807-1)) or (d==2 and sz==9223372036854775807) or (d==0 and sz==(-9223372036854775807-1)): break
				sx += Sector.DIRS[d].x
				sz += Sector.DIRS[d].y
				_build(sector.entry_cell((d+2)%4))
				return
	_update_camera()
