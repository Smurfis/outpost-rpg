extends Node3D
## Outpost 0.5: an original single-player, Android-first vertical slice.
const PLAYER = preload("res://scripts/player.gd")
const NODE = preload("res://scripts/resource_node.gd")
const ENEMY = preload("res://scripts/enemy.gd")
const HUD = preload("res://scripts/hud.gd")
const MENU = preload("res://scripts/menu.gd")
const STATION = preload("res://scripts/station.gd")
const VOXEL_BIOME = preload("res://scripts/voxel/voxel_biome.gd")
const VOXEL_PROPS = preload("res://scripts/voxel/voxel_props.gd")
const NIGHTFALL = preload("res://scripts/world/day_night_cycle.gd")
const COOP = preload("res://scripts/network/coop_session.gd")
@export var voxel_art_enabled: bool = true
@export var fields_biome_enabled: bool = true # Original outpost clearing remains flat.
@export var chunk_streaming_enabled: bool = true # Stream finite 192x192 Fields in 12x12 cells.
const SAVE = "user://outpost_progress_v02.json"
@export var save_path: String = SAVE # Existing default; tests can isolate their saves.

var hero
var hud
var camera: Camera3D
var equipment: Dictionary = {"weapon": "training_blade", "offhand": "", "back": "", "tool_wood": "", "tool_mining": "", "tool_forage": ""}
var inventory: Dictionary = {"wood": 0, "stone": 0, "hide": 0, "coins": 0, "fiber": 0, "berries": 0, "meal": 0, "axe": 0, "pickaxe": 0, "shield": 0, "torch": 0, "spear": 0, "satchel": 0, "iron": 0, "coal": 0, "clay": 0, "herbs": 0, "mushrooms": 0, "reeds": 0, "iron_ingot": 0, "iron_blade": 0, "bricks": 0, "linen": 0, "cloak": 0, "tonic": 0, "stew": 0}
var menu
var coop
var recipes: Array = []
var crafting: Dictionary = {}
var craft_work_cooldown: float = 0.0
var stations: Dictionary = {}
var station_positions: Dictionary = {"workbench": Vector3(3.5, 0.0, 0.6), "forge": Vector3(-12, 0.0, -1.0), "loom": Vector3(8.5, 0.0, 3.0), "campfire": Vector3(-2.8, 0.0, 2.8)}
var experience: int = 0
var kills: int = 0
var spear_crafted: bool = false
var attack_delay: float = 0.0
var gather_delay: float = 0.0
var world_time: float = 0.0
var day_night
var night_quote_seen: bool = false
var last_hit_node: Node3D
var workshop: Vector3 = Vector3(3.5, 0.0, 0.6)

func _ready() -> void:
	_register_keys()
	_load_recipes()
	_lighting()
	_world()
	_stations()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	camera.far = 120.0
	camera.current = true
	add_child(camera)
	hud = HUD.new()
	hud.setup(self)
	add_child(hud)
	hero = PLAYER.new()
	add_child(hero)
	hero.position = Vector3(0, 0.35, 0)
	hero.setup(self, hud, camera)
	_resources()
	_enemies()
	# Title Play starts a fresh run; Continue reads the previous save.
	var fresh_start: bool = bool(get_tree().root.get_meta("outpost_new_adventure", false))
	if get_tree().root.has_meta("outpost_new_adventure"):
		get_tree().root.remove_meta("outpost_new_adventure")
	if not fresh_start:
		_load()
	menu = MENU.new()
	menu.setup(self)
	add_child(menu)
	if day_night != null:
		day_night.night_started.connect(_on_first_night)
	coop = COOP.new()
	add_child(coop)
	_camera(1.0)
	hud.toast("Welcome to OUTPOST! Find resources and visit a crafting station.")

func _register_keys() -> void:
	var binds := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "gather": [KEY_E], "attack": [KEY_F, KEY_SPACE], "craft": [KEY_C], "bag": [KEY_B, KEY_I], "heal": [KEY_H]}
	for action in binds:
		var key_name: String = "outpost_" + str(action)
		if not InputMap.has_action(key_name):
			InputMap.add_action(key_name)
		for code in binds[action]:
			var event := InputEventKey.new()
			event.physical_keycode = int(code)
			InputMap.action_add_event(key_name, event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("outpost_gather"):
		gather()
	elif event.is_action_pressed("outpost_attack"):
		attack()
	elif event.is_action_pressed("outpost_craft"):
		craft()
	elif event.is_action_pressed("outpost_bag"):
		show_inventory()
	elif event.is_action_pressed("outpost_heal"):
		use_meal()

func _process(delta: float) -> void:
	_update_crafting(delta)
	attack_delay = maxf(0.0, attack_delay - delta)
	gather_delay = maxf(0.0, gather_delay - delta)
	world_time += delta
	_camera(delta)
	if day_night != null and hud != null:
		hud.set_day_clock(day_night.clock_text(), day_night.is_night(), str(equipment.get("offhand", "")) == "torch")
	if hero == null or hud == null:
		return
	var goal: String = "Gather wood and stone, then craft a spear at the workbench"
	if spear_crafted or int(inventory.get("iron_blade", 0)) > 0:
		goal = "Hunt one wild boar in the forest" if kills == 0 else "Starter quest finished: craft new gear, explore and survive"
	var resource = _nearest_resource()
	if resource != last_hit_node:
		if is_instance_valid(last_hit_node):
			last_hit_node.set_targeted(false)
		if resource != null:
			resource.set_targeted(true)
		last_hit_node = resource
	var enemy = _nearest_enemy()
	var hint: String = "Explore: iron, coal, clay, herbs, reeds, mushrooms and more."
	if resource != null:
		hint = "Nearby: %s • gather (%d hits remaining)" % [resource.kind.capitalize(), resource.hits_left]
	elif enemy != null:
		hint = "Wild boar nearby • use ATTACK"
	elif closest_station() != "":
		hint = "%s nearby • open CRAFT to make items" % closest_station().capitalize()
	hud.render_status(hero.health, inventory, experience, kills, str(equipment.get("weapon", "training_blade")), goal, hint)
	hud.update_context(resource != null, enemy != null, closest_station() != "")


func _camera(delta: float) -> void:
	if hero == null:
		return
	var focus: Vector3 = hero.global_position + Vector3(0, 0.9, 0)
	var destination: Vector3 = focus + Vector3(17.0, 20.0, 20.0)
	if camera.global_position == Vector3.ZERO:
		camera.global_position = destination
	else:
		camera.global_position = camera.global_position.lerp(destination, clampf(delta * 6.0, 0.0, 1.0))
	camera.look_at(focus, Vector3.UP)

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func part(mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.material_override = material(color)
	add_child(inst)
	return inst

func block(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return part(mesh, at, color)

func _lighting() -> void:
	var w := WorldEnvironment.new()
	var env := Environment.new()
	var dawn: ProceduralSkyMaterial
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a6c4c9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f0e3c6")
	env.ambient_light_energy = 0.85
	if voxel_art_enabled:
		# Warm lavender sunrise with a peach horizon; cheap, mobile-friendly sky.
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		dawn = ProceduralSkyMaterial.new()
		dawn.sky_top_color = Color("5d81b7")
		dawn.sky_horizon_color = Color("efb49b")
		dawn.ground_bottom_color = Color("66677f")
		dawn.ground_horizon_color = Color("d9b8a6")
		sky.sky_material = dawn
		env.sky = sky
		env.ambient_light_color = Color("fff0d1")
		env.ambient_light_energy = 0.9
	w.environment = env
	add_child(w)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -30, 0)
	sun.light_energy = 1.25
	if voxel_art_enabled:
		sun.light_color = Color("ffe0a9")
		sun.light_energy = 1.45
	sun.shadow_enabled = false # Preserve Android budget on first visual pass.
	add_child(sun)
	day_night = NIGHTFALL.new()
	day_night.name = "DayNightCycle"
	add_child(day_night)
	day_night.configure(env, sun, dawn)

func _world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Terrain"
	floor_body.position.y = -0.55
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(46, 1, 46)
	collider.shape = shape
	floor_body.add_child(collider)
	add_child(floor_body)
	if voxel_art_enabled:
		var landscape = VOXEL_BIOME.new()
		add_child(landscape)
		landscape.build(fields_biome_enabled, 64012, chunk_streaming_enabled)
	else:
		block(Vector3(46, 0.98, 46), Vector3(0, -0.55, 0), Color("597a4d"))
		_terrain_path(Vector3(-18, 0, -1), Vector3(20, 0, 2), 2.05, Color("9a8464"))
		_terrain_path(Vector3(0, 0, -21), Vector3(-1, 0, 21), 1.45, Color("ac956f"))
		_terrain_path(Vector3(-1, 0, -4), Vector3(6, 0, 4), 2.95, Color("b09b75"))
	# Distinct 3D mesh assets for the skyline and outpost supplies.
	for position_at in [Vector3(-18, 0, -6), Vector3(17, 0, -4), Vector3(-11, 0, 16), Vector3(15, 0, 18), Vector3(-19, 0, 13)]:
		_mesh_asset("oak_tree", position_at, 0.82, position_at.x * 0.18)
	for position_at in [Vector3(-13.5, 0, -6), Vector3(13, 0, 5), Vector3(-19, 0, 17)]:
		_mesh_asset("rock_deposit", position_at, 0.79, position_at.z * 0.22)
	for position_at in [Vector3(1.7, 0, 1.8), Vector3(2.7, 0, 2.1), Vector3(7.2, 0, 5.2), Vector3(-9.5, 0, -0.9)]:
		_mesh_asset("supply_crate", position_at, 0.9, position_at.x * 0.34)
	if voxel_art_enabled:
		var shelter: MeshInstance3D = VOXEL_PROPS.tent()
		shelter.position = Vector3(-6.1, 0.0, 2.8)
		add_child(shelter)
	else:
		var tent := CylinderMesh.new()
		tent.top_radius = 0.0
		tent.bottom_radius = 2.1
		tent.height = 2.9
		part(tent, Vector3(-6.1, 1.38, 2.8), Color("d5b77b"))
		block(Vector3(1.9, 0.13, 2.0), Vector3(-6.1, 0.05, 2.8), Color("4d412e"))
	# Decorative shrubs and wildflowers (deterministic for stable map)
	var rng := RandomNumberGenerator.new()
	rng.seed = 512309
	for i in range(68):
		var x := rng.randf_range(-21.0, 21.0)
		var z := rng.randf_range(-21.0, 21.0)
		if absf(x) < 5.3 and absf(z) < 5.3:
			continue
		if voxel_art_enabled:
			if i % 2 == 0:
				var shrub: MeshInstance3D = VOXEL_PROPS.bush(i % 13 == 0)
				shrub.position = Vector3(x, 0, z)
				shrub.scale = Vector3.ONE * rng.randf_range(0.18, 0.40)
				add_child(shrub)
		else:
			var mesh := SphereMesh.new()
			mesh.radial_segments = 7
			mesh.rings = 3
			mesh.radius = rng.randf_range(0.15, 0.38)
			mesh.height = 0.40
			var tuft := part(mesh, Vector3(x, 0.12, z), Color("456f41") if i % 3 == 0 else Color("89a566"))
			tuft.scale = Vector3(1.4, 0.53, 1.0)
	# Details: timber palisade sections, supply crates, stumps and path stones
	for i in range(12):
		var px: float = -10.0 + float(i) * 1.75
		if i < 5 or i > 8:
			block(Vector3(0.25, 1.1, 0.25), Vector3(px, 0.55, 6.9), Color("735239"))
			block(Vector3(1.65, 0.16, 0.18), Vector3(px, 0.82, 6.9), Color("b1844c"))
	for x in [-4.2, -3.5, 2.4]:
		block(Vector3(0.85, 0.78, 0.85), Vector3(x, 0.39, 4.3), Color("946d45"))
		block(Vector3(0.90, 0.08, 0.9), Vector3(x, 0.82, 4.3), Color("be9867"))
	for i in range(17):
		var stones := CylinderMesh.new()
		stones.top_radius = 0.18
		stones.bottom_radius = 0.22
		stones.height = 0.045
		stones.radial_segments = 6
		part(stones, Vector3(-2.2 + float(i % 5) * 0.98, 0.02, -9.0 + float(i / 5.0) * 1.6), Color("a99a7b"))
	# Make the Fields truly walkable. Keep the original small camp collision
	# underneath its centre; outside it the chunk trimeshes own collision.
	var half_extent: float = 96.0 if voxel_art_enabled and fields_biome_enabled and chunk_streaming_enabled else 48.0 if voxel_art_enabled and fields_biome_enabled else 23.0
	var span: float = half_extent * 2.0
	_wall(Vector3(-half_extent, 2.0, 0), Vector3(0.5, 6.0, span))
	_wall(Vector3(half_extent, 2.0, 0), Vector3(0.5, 6.0, span))
	_wall(Vector3(0, 2.0, -half_extent), Vector3(span, 6.0, 0.5))
	_wall(Vector3(0, 2.0, half_extent), Vector3(span, 6.0, 0.5))

func _mesh_asset(id: String, where: Vector3, size_factor: float = 1.0, angle: float = 0.0) -> void:
	if voxel_art_enabled:
		var prop: MeshInstance3D
		match id:
			"oak_tree":
				prop = VOXEL_PROPS.tree()
			"rock_deposit":
				prop = VOXEL_PROPS.rock()
			"supply_crate":
				prop = VOXEL_PROPS.crate()
		if prop != null:
			# Stable unique names avoid Godot's auto-generated sibling names.
			prop.name = "%s_%d_%d" % [str(prop.name), roundi(where.x * 10.0), roundi(where.z * 10.0)]
			prop.position = where
			prop.scale = Vector3.ONE * size_factor
			prop.rotation.y = angle
			add_child(prop)
			return
	var mesh: Mesh = load("res://assets/models/" + id + ".obj") as Mesh
	if mesh == null:
		push_warning("Unable to import 3D model: " + id)
		return
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.name = id
	instance.position = where
	instance.scale = Vector3.ONE * size_factor
	instance.rotation.y = angle
	add_child(instance)

func _terrain_path(from: Vector3, to: Vector3, radius: float, shade: Color) -> void:
	var creator := SurfaceTool.new()
	creator.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axis: Vector3 = (to - from).normalized()
	var across: Vector3 = Vector3(-axis.z, 0.0, axis.x)
	var material_at := StandardMaterial3D.new()
	material_at.albedo_color = shade
	material_at.roughness = 1.0
	material_at.cull_mode = BaseMaterial3D.CULL_DISABLED
	var segments: int = 18
	for i in range(segments):
		var t0: float = float(i) / float(segments)
		var t1: float = float(i + 1) / float(segments)
		var jitter0: float = 0.80 + sin(t0 * 17.0) * 0.15
		var jitter1: float = 0.80 + sin(t1 * 17.0) * 0.15
		var center0: Vector3 = from.lerp(to, t0) + across * 0.14 * sin(t0 * 14.0)
		var center1: Vector3 = from.lerp(to, t1) + across * 0.14 * sin(t1 * 14.0)
		var a: Vector3 = center0 - across * radius * jitter0 + Vector3(0, 0.018, 0)
		var b: Vector3 = center0 + across * radius * jitter0 + Vector3(0, 0.018, 0)
		var c: Vector3 = center1 + across * radius * jitter1 + Vector3(0, 0.018, 0)
		var d: Vector3 = center1 - across * radius * jitter1 + Vector3(0, 0.018, 0)
		for vertex in [a, b, c, a, c, d]:
			creator.set_uv(Vector2(vertex.x * 0.05, vertex.z * 0.05))
			creator.add_vertex(vertex)
	creator.generate_normals()
	var path := MeshInstance3D.new()
	path.mesh = creator.commit()
	path.material_override = material_at
	add_child(path)

func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	add_child(body)

func _stations() -> void:
	for station_id in station_positions:
		var station = STATION.new()
		add_child(station)
		station.position = station_positions[station_id]
		station.setup(str(station_id))
		stations[station_id] = station

func closest_station() -> String:
	if hero == null:
		return ""
	var nearest: String = ""
	var distance: float = 4.0
	for station_id in station_positions:
		var pos: Vector3 = station_positions[station_id]
		var horizontal: Vector2 = Vector2(hero.global_position.x - pos.x, hero.global_position.z - pos.z)
		var d: float = horizontal.length()
		if d < distance:
			distance = d
			nearest = str(station_id)
	return nearest

func near_station(station_id: String) -> bool:
	return closest_station() == station_id

func _resources() -> void:
	for pos in [Vector3(-6, 0, -1), Vector3(-8, 0, -6), Vector3(6, 0, -7), Vector3(11, 0, 2), Vector3(-12, 0, 9), Vector3(7, 0, 12), Vector3(14, 0, -10)]:
		var tree = NODE.new()
		add_child(tree)
		tree.position = pos
		tree.setup("wood")
	for pos in [Vector3(-6, 0, 7), Vector3(6, 0, 7), Vector3(11, 0, -7), Vector3(-13, 0, -9), Vector3(15, 0, 14)]:
		var rock = NODE.new()
		add_child(rock)
		rock.position = pos
		rock.setup("stone")
	for pos in [Vector3(-4, 0, -9), Vector3(3, 0, -12), Vector3(12, 0, 9), Vector3(-15, 0, 4)]:
		var bush = NODE.new()
		add_child(bush)
		bush.position = pos
		bush.setup("fiber")
	for pos in [Vector3(-10, 0, 3), Vector3(8, 0, -3), Vector3(-17, 0, 16)]:
		var berry = NODE.new()
		add_child(berry)
		berry.position = pos
		berry.setup("berries")
	# Uncommon resource clusters on the edges of the forest.
	var points: Dictionary = {
		"iron": [Vector3(-19, 0, -12), Vector3(18, 0, 15), Vector3(15, 0, -15), Vector3(-17, 0, 18)],
		"coal": [Vector3(-19, 0, -3), Vector3(18, 0, -11), Vector3(-16, 0, -17)],
		"clay": [Vector3(-1, 0, 12), Vector3(13, 0, 18), Vector3(-18, 0, 11)],
		"herbs": [Vector3(-10, 0, -16), Vector3(16, 0, 7), Vector3(-19, 0, -18)],
		"mushrooms": [Vector3(3, 0, 15), Vector3(-15, 0, 14), Vector3(14, 0, -19)],
		"reeds": [Vector3(-1, 0, -15), Vector3(19, 0, -2), Vector3(-7, 0, 17)]
	}
	for item_id in points:
		for pos in points[item_id]:
			var node = NODE.new()
			add_child(node)
			node.position = pos
			node.setup(str(item_id))

	# The wider Fields has a few harvestable nodes beyond the original camp.
	# Do not move the starting resources or alter recipe/save data.
	if voxel_art_enabled and fields_biome_enabled:
		var landscape = get_node_or_null("VoxelAtmosphere")
		if landscape != null:
			var field_sites: Dictionary = {
				"wood": [Vector2(-34, -32), Vector2(32, -37), Vector2(-35, 29), Vector2(39, 24)],
				"stone": [Vector2(35, 34), Vector2(-38, 34), Vector2(-34, -38)],
				"berries": [Vector2(35, -31), Vector2(-37, 27)],
				"fiber": [Vector2(32, 27), Vector2(-32, -31)]
			}
			for kind in field_sites:
				for site in field_sites[kind]:
					var field_node = NODE.new()
					add_child(field_node)
					field_node.position = Vector3(site.x, landscape.surface_y_at(site.x, site.y) + 0.055, site.y)
					field_node.setup(str(kind))

func _enemies() -> void:
	for pos in [Vector3(10, 0.2, 11), Vector3(-14, 0.2, -10), Vector3(16, 0.2, -13)]:
		var boar = ENEMY.new()
		add_child(boar)
		boar.setup(self, hero, pos)

func _nearest_resource():
	var best = null
	var radius := 3.3
	for node in get_tree().get_nodes_in_group("resources"):
		if not node.active:
			continue
		var dist: float = hero.global_position.distance_to(node.global_position)
		if dist < radius:
			radius = dist
			best = node
	return best

func _nearest_enemy():
	var best = null
	var radius := 3.4
	for boar in get_tree().get_nodes_in_group("enemies"):
		if not boar.alive:
			continue
		var dist: float = hero.global_position.distance_to(boar.global_position)
		if dist < radius:
			radius = dist
			best = boar
	return best

func near_workshop() -> bool:
	return near_station("workbench")

func gather() -> void:
	if gather_delay > 0.0:
		return
	var resource = _nearest_resource()
	if resource == null:
		return # No alerts on empty interaction or held buttons.
	gather_delay = 0.33
	var item: String = resource.harvest()
	if item != "":
		hero.gather_swing(item)
		_show_gather_pickup(resource.global_position, item)
	if item == "":
		return
	var amount: int = 1
	if item == "wood" and str(equipment.get("tool_wood", "")) == "axe":
		amount = 2
	elif item in ["stone", "iron", "coal"] and str(equipment.get("tool_mining", "")) == "pickaxe":
		amount = 2
	elif item in ["fiber", "reeds"] and str(equipment.get("tool_forage", "")) == "satchel":
		amount = 2
	inventory[item] = int(inventory.get(item, 0)) + amount
	experience += 2 * amount
	hud.toast("+%d %s  •  +%d XP" % [amount, item.capitalize(), 2 * amount])
	_save()
	_refresh_menu()

func _show_gather_pickup(at: Vector3, resource_id: String) -> void:
	# Floating +resource above a struck gatherable. No persistent heavy particles.
	var pop := Label3D.new()
	pop.text = "+" + resource_id.replace("_", " ").capitalize()
	pop.font_size = 38
	pop.pixel_size = 0.006
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.position = at + Vector3(0.0, 2.1, 0.0)
	pop.modulate = Color("f4dba2")
	add_child(pop)
	var tween := create_tween()
	tween.tween_property(pop, "position:y", pop.position.y + 0.9, 0.70)
	tween.parallel().tween_property(pop, "modulate:a", 0.0, 0.70)
	tween.finished.connect(pop.queue_free)

func _load_recipes() -> void:
	var file: FileAccess = FileAccess.open("res://data/recipes.json", FileAccess.READ)
	if file == null:
		push_error("Missing data/recipes.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		recipes = parsed

func craft() -> void:
	show_crafting()

func show_crafting() -> void:
	if menu != null:
		menu.open("craft")

func show_inventory() -> void:
	if menu != null:
		menu.open("bag")

func show_equipment() -> void:
	if menu != null:
		menu.open("equipment")

func _refresh_menu() -> void:
	if menu != null:
		menu.refresh()

func _recipe_by_id(id: String) -> Dictionary:
	for entry in recipes:
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return entry
	return {}

func equipment_slot(item_id: String) -> String:
	if item_id in ["spear", "iron_blade"]:
		return "weapon"
	if item_id in ["shield", "torch"]:
		return "offhand"
	if item_id == "cloak":
		return "back"
	if item_id == "axe":
		return "tool_wood"
	if item_id == "pickaxe":
		return "tool_mining"
	if item_id == "satchel":
		return "tool_forage"
	return ""

func is_equipped(item_id: String) -> bool:
	var slot: String = equipment_slot(item_id)
	return slot != "" and str(equipment.get(slot, "")) == item_id

func equip_item(item_id: String) -> bool:
	if int(inventory.get(item_id, 0)) < 1:
		return false
	var slot: String = equipment_slot(item_id)
	if slot == "":
		return false
	if is_equipped(item_id):
		equipment[slot] = "training_blade" if slot == "weapon" else ""
	else:
		equipment[slot] = item_id
	_apply_equipment()
	_save()
	_refresh_menu()
	return true

func _apply_equipment() -> void:
	if hero == null:
		return
	hero.set_weapon(str(equipment.get("weapon", "training_blade")))
	hero.set_shield(str(equipment.get("offhand", "")) == "shield")
	hero.set_torch(str(equipment.get("offhand", "")) == "torch")
	hero.set_cloak(str(equipment.get("back", "")) == "cloak")

func owns_unique(item_id: String) -> bool:
	return item_id in ["spear", "axe", "pickaxe", "shield", "torch", "satchel", "iron_blade", "cloak"] and int(inventory.get(item_id, 0)) > 0

func can_craft(id: String) -> bool:
	var recipe: Dictionary = _recipe_by_id(id)
	if recipe.is_empty() or not crafting.is_empty():
		return false
	var station: String = str(recipe.get("station", "workbench"))
	if not near_station(station):
		return false
	var result_id: String = str(recipe.get("result", ""))
	if owns_unique(result_id):
		return false
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for key in ingredients:
		if int(inventory.get(str(key), 0)) < int(ingredients[key]):
			return false
	return true

func begin_craft(id: String) -> bool:
	if not can_craft(id):
		return false
	var recipe: Dictionary = _recipe_by_id(id)
	crafting = {
		"id": id,
		"station": str(recipe.get("station", "workbench")),
		"elapsed": 0.0,
		"duration": maxf(0.5, float(recipe.get("seconds", 2.0))),
		"strokes": 0,
		"required": maxi(1, int(recipe.get("strokes", 3)))
	}
	craft_work_cooldown = 0.0
	if menu != null:
		menu.on_craft_started()
	return true

func craft_item(id: String) -> void:
	# Compatibility entrypoint; now begins interactive crafting, not instant delivery.
	if not begin_craft(id):
		hud.toast("Cannot begin this recipe at the current station.")

func work_craft() -> bool:
	if crafting.is_empty() or craft_work_cooldown > 0.0:
		return false
	var strokes: int = int(crafting.get("strokes", 0))
	var required: int = int(crafting.get("required", 1))
	if strokes >= required:
		return false
	crafting["strokes"] = strokes + 1
	craft_work_cooldown = 0.18
	var active_station: String = str(crafting.get("station", ""))
	if stations.has(active_station):
		stations[active_station].stroke()
	_try_finish_craft()
	return true

func _update_crafting(delta: float) -> void:
	craft_work_cooldown = maxf(0.0, craft_work_cooldown - delta)
	if crafting.is_empty():
		return
	crafting["elapsed"] = float(crafting.get("elapsed", 0.0)) + delta
	var active_station: String = str(crafting.get("station", ""))
	if stations.has(active_station):
		stations[active_station].set_activity(minf(1.0, float(crafting["elapsed"]) / float(crafting["duration"])))
	_try_finish_craft()

func _try_finish_craft() -> void:
	if crafting.is_empty():
		return
	if float(crafting.get("elapsed", 0.0)) < float(crafting.get("duration", 1.0)):
		return
	if int(crafting.get("strokes", 0)) < int(crafting.get("required", 1)):
		return
	var recipe: Dictionary = _recipe_by_id(str(crafting.get("id", "")))
	var station_id: String = str(crafting.get("station", ""))
	crafting = {}
	if stations.has(station_id):
		stations[station_id].set_activity(0.0)
	if recipe.is_empty():
		return
	# Spend ingredients only on successful completion, not on starting an
	# interrupted task. Closing the app or cancelling never loses resources.
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for ingredient in ingredients:
		if int(inventory.get(str(ingredient), 0)) < int(ingredients[ingredient]):
			hud.toast("Craft cancelled: ingredients are no longer available.")
			_refresh_menu()
			return
	for ingredient in ingredients:
		inventory[str(ingredient)] = int(inventory.get(str(ingredient), 0)) - int(ingredients[ingredient])
	var result: String = str(recipe.get("result", ""))
	inventory[result] = int(inventory.get(result, 0)) + maxi(1, int(recipe.get("amount", 1)))
	if result == "spear":
		spear_crafted = true
	# Newly crafted equipment is immediately equipped, but can be swapped/removed.
	var slot: String = equipment_slot(result)
	if slot != "":
		equipment[slot] = result
		_apply_equipment()
	experience += 8
	hud.toast("Created %s! +8 XP" % str(recipe.get("name", result)))
	_save()
	if menu != null:
		menu.on_craft_completed(result)
	_refresh_menu()

func cancel_craft() -> void:
	if crafting.is_empty():
		return
	var station_id: String = str(crafting.get("station", ""))
	crafting = {}
	if stations.has(station_id):
		stations[station_id].set_activity(0.0)
	_refresh_menu()

func consume(item_id: String, heal: float) -> void:
	if int(inventory.get(item_id, 0)) <= 0 or hero.health >= 99.9:
		return
	inventory[item_id] = int(inventory[item_id]) - 1
	hero.health = minf(100.0, hero.health + heal)
	hud.toast("Used %s: +%d health" % [item_id.capitalize(), int(heal)])
	_save()
	_refresh_menu()

func use_meal() -> void:
	consume("meal", 40.0)

func attack() -> void:
	if coop != null and coop.in_party_dungeon():
		# Do not let independent clients kill local guardian copies or award
		# unverified loot. Server-authoritative co-op combat comes next.
		hud.toast("Co-op encounter preview: synchronized combat is not enabled.")
		return
	if attack_delay > 0.0 or menu != null and menu.visible:
		return
	var target = _nearest_enemy()
	if target == null:
		return # No popup spam when outside combat range.
	attack_delay = 0.55
	hero.swing()
	var weapon: String = str(equipment.get("weapon", "training_blade"))
	var damage: float = 24.0 if weapon == "iron_blade" else 16.0 if weapon == "spear" else 8.0
	target.receive_damage(damage)
	if target.alive:
		hud.toast("%d damage  •  boar %d HP" % [int(damage), int(ceilf(target.hp))])

func on_enemy_killed() -> void:
	kills += 1
	inventory["hide"] += 1
	inventory["coins"] += 3
	experience += 12
	hud.toast("Boar defeated! +1 hide  +3 coins  +12 XP")
	_save()
	_refresh_menu()

func toggle_torch() -> void:
	if int(inventory.get("torch", 0)) < 1:
		if hud != null:
			hud.toast("Craft a torch at the workbench to light the dark.")
		return
	equip_item("torch")

func _on_first_night() -> void:
	if night_quote_seen:
		return
	night_quote_seen = true
	if hud != null:
		hud.toast("I don't care how dark the world gets. You are its light.")
	_save()

func _save() -> void:
	var data: Dictionary = {"version": 5, "equipment": equipment, "inventory": inventory, "experience": experience, "kills": kills, "spear": spear_crafted, "day_phase": day_night.phase if day_night != null else 0.38, "night_quote_seen": night_quote_seen}
	var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()

func _load() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (data is Dictionary):
		return
	var version: int = int(data.get("version", 0))
	if version not in [2, 3, 4, 5]:
		return
	night_quote_seen = bool(data.get("night_quote_seen", false))
	if day_night != null:
		day_night.set_phase(clampf(float(data.get("day_phase", 0.38)), 0.0, 1.0))
	var stored: Variant = data.get("inventory", {})
	if stored is Dictionary:
		for key in inventory:
			inventory[key] = maxi(0, int(stored.get(key, 0)))
	experience = maxi(0, int(data.get("experience", 0)))
	kills = maxi(0, int(data.get("kills", 0)))
	spear_crafted = bool(data.get("spear", false)) or int(inventory.get("spear", 0)) > 0
	if spear_crafted:
		inventory["spear"] = maxi(1, int(inventory.get("spear", 0)))
	if version >= 5 and data.get("equipment", {}) is Dictionary:
		var saved_gear: Dictionary = data.get("equipment", {})
		for slot in equipment:
			var item: String = str(saved_gear.get(slot, equipment[slot]))
			if item == "" or item == "training_blade" or int(inventory.get(item, 0)) > 0:
				equipment[slot] = item
	else:
		# Migrate existing v2, v3 and v4 gear: previously auto-equipped.
		for item in ["spear", "iron_blade", "shield", "torch", "cloak", "axe", "pickaxe", "satchel"]:
			if int(inventory.get(item, 0)) > 0:
				equipment[equipment_slot(item)] = item
	_apply_equipment()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()
