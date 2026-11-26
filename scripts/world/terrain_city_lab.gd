extends Node3D
## Standalone in-engine lab; deliberately never reads/writes RPG saves.
const Plan = preload("res://scripts/world/terrain_city_lab_plan.gd")
const Mesher = preload("res://scripts/world/city_lab_mesher.gd")
var mesher := Mesher.new()
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

func _ready() -> void:
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
	for entry in ["New seed","Rotate left","Rotate right","Zoom in","Zoom out","Go to keep","Far region"]:
		var button := Button.new()
		button.text = entry
		button.custom_minimum_size = Vector2(85,42)
		bar.add_child(button)
		match entry:
			"New seed": button.pressed.connect(_next_seed)
			"Rotate left": button.pressed.connect(func(): angle -= PI/4)
			"Rotate right": button.pressed.connect(func(): angle += PI/4)
			"Zoom in": button.pressed.connect(func(): zoom = maxf(18.0,zoom-6.0))
			"Zoom out": button.pressed.connect(func(): zoom = minf(100.0,zoom+6.0))
			"Go to keep": button.pressed.connect(func(): _route(plan.goal))
			"Far region": button.pressed.connect(_far_region)

func _far_region() -> void:
	region_x = 1000000000000 if region_x == 0 else 0
	region_z = -1000000000000 if region_x != 0 else 0
	_build()

func _next_seed() -> void:
	seed_value += 1
	_build()

func _build() -> void:
	path.clear()
	if city != null:
		remove_child(city)
		city.queue_free()
	city = Node3D.new()
	add_child(city)
	if not plan.generate(seed_value,region_x,region_z):
		status.text = "City validation failed for seed %d — choose New seed" % seed_value
		return
	var buckets := mesher.bucket(plan.blocks)
	var face_count := 0
	var quad_count := 0
	for key: Vector3i in buckets:
		var result := mesher.rectangles(plan.blocks,buckets[key],key)
		face_count += int(result["exposed"])
		quad_count += result["quads"].size()
		if result["quads"].is_empty(): continue
		var instance := MeshInstance3D.new()
		instance.mesh = mesher.build_mesh(result)
		instance.material_override = material
		city.add_child(instance)
		instance.position = Vector3(key*Mesher.SECTION)
	grid.clear()
	grid.region = Rect2i(0,0,Plan.SIZE,Plan.SIZE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for p in plan.blocked:
		grid.set_point_solid(p,true)
	player.position = _standing(plan.start)
	_update_camera()
	status.text = "CITY LAB | %d | Region %d,%d | %d lots | %d BSP rooms | %d meshes | %d/%d quads" % [seed_value,region_x,region_z,plan.districts.size(),plan.rooms.size(),city.get_child_count(),quad_count,face_count]

func _standing(p: Vector2i) -> Vector3:
	return Vector3(p.x+0.5,plan.height_at(p)+1.0,p.y+0.5)

func _player_cell() -> Vector2i:
	return Vector2i(floori(player.position.x),floori(player.position.z))

func _route(to: Vector2i) -> void:
	if not plan.walkable(to) or not plan.walkable(_player_cell()): return
	path.clear()
	for cell in grid.get_id_path(_player_cell(),to):
		path.append(cell)
	if not path.is_empty(): path.pop_front()

func _pick(screen: Vector2) -> void:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	# Pick the first terrain column under the ray; buildings are ignored intentionally
	# for roofless diorama navigation. The grid rejects blocked cells.
	for i in range(700):
		var point := origin+direction*(i*0.25)
		var cell := Vector2i(floori(point.x),floori(point.z))
		if plan.walkable(cell) and point.y <= plan.height_at(cell)+1.0:
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
	if not path.is_empty():
		var target := _standing(path[0])
		player.position = player.position.move_toward(target,8.0*delta)
		if player.position.distance_to(target) < 0.03:
			player.position = target
			path.pop_front()
	_update_camera()
