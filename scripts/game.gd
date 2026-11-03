extends Node3D
## Outpost 0.4: an original single-player, Android-first vertical slice.
const PLAYER = preload("res://scripts/player.gd")
const NODE = preload("res://scripts/resource_node.gd")
const ENEMY = preload("res://scripts/enemy.gd")
const HUD = preload("res://scripts/hud.gd")
const MENU = preload("res://scripts/menu.gd")
const STATION = preload("res://scripts/station.gd")
const SAVE = "user://outpost_progress_v02.json"

var hero
var hud
var camera: Camera3D
var inventory: Dictionary = {"wood": 0, "stone": 0, "hide": 0, "coins": 0, "fiber": 0, "berries": 0, "meal": 0, "axe": 0, "pickaxe": 0, "shield": 0, "spear": 0, "satchel": 0, "iron": 0, "coal": 0, "clay": 0, "herbs": 0, "mushrooms": 0, "reeds": 0, "iron_ingot": 0, "iron_blade": 0, "bricks": 0, "linen": 0, "cloak": 0, "tonic": 0, "stew": 0}
var menu
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
	_load()
	menu = MENU.new()
	menu.setup(self)
	add_child(menu)
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
	if hero == null or hud == null:
		return
	var goal: String = "Gather wood and stone, then craft a spear at the workbench"
	if spear_crafted or int(inventory.get("iron_blade", 0)) > 0:
		goal = "Hunt one wild boar in the forest" if kills == 0 else "Starter quest finished: craft new gear, explore and survive"
	var resource = _nearest_resource()
	var enemy = _nearest_enemy()
	var hint: String = "Explore: iron, coal, clay, herbs, reeds, mushrooms and more."
	if resource != null:
		hint = "Nearby: %s • gather (%d hits remaining)" % [resource.kind.capitalize(), resource.hits_left]
	elif enemy != null:
		hint = "Wild boar nearby • use ATTACK"
	elif closest_station() != "":
		hint = "%s nearby • open CRAFT to make items" % closest_station().capitalize()
	hud.render_status(hero.health, inventory, experience, kills, spear_crafted, goal, hint)
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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a6c4c9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f0e3c6")
	env.ambient_light_energy = 0.85
	w.environment = env
	add_child(w)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -30, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	add_child(sun)

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
	block(Vector3(46, 0.98, 46), Vector3(0, -0.55, 0), Color("597a4d"))
	block(Vector3(4.2, 0.03, 34), Vector3(0, -0.045, 0), Color("927957"))
	block(Vector3(31, 0.03, 3.4), Vector3(0, -0.04, 0), Color("a58b60"))
	block(Vector3(10, 0.035, 7), Vector3(-1, -0.035, -1), Color("a18b66"))
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
	# Invisible boundary
	_wall(Vector3(-23, 1.5, 0), Vector3(0.5, 3, 46))
	_wall(Vector3(23, 1.5, 0), Vector3(0.5, 3, 46))
	_wall(Vector3(0, 1.5, -23), Vector3(46, 3, 0.5))
	_wall(Vector3(0, 1.5, 23), Vector3(46, 3, 0.5))

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
	if item == "":
		return
	var amount: int = 1
	if item == "wood" and int(inventory.get("axe", 0)) > 0:
		amount = 2
	elif item in ["stone", "iron", "coal"] and int(inventory.get("pickaxe", 0)) > 0:
		amount = 2
	elif item in ["fiber", "reeds"] and int(inventory.get("satchel", 0)) > 0:
		amount = 2
	inventory[item] = int(inventory.get(item, 0)) + amount
	experience += 2 * amount
	hud.toast("+%d %s  •  +%d XP" % [amount, item.capitalize(), 2 * amount])
	_save()
	_refresh_menu()

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

func _refresh_menu() -> void:
	if menu != null:
		menu.refresh()

func _recipe_by_id(id: String) -> Dictionary:
	for entry in recipes:
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return entry
	return {}

func owns_unique(item_id: String) -> bool:
	return item_id in ["spear", "axe", "pickaxe", "shield", "satchel", "iron_blade", "cloak"] and int(inventory.get(item_id, 0)) > 0

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
		hero.set_spear(true)
	if result == "shield":
		hero.set_shield(true)
	if result == "iron_blade":
		hero.set_spear(true)
	if result == "cloak":
		hero.set_cloak(true)
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
	if attack_delay > 0.0 or menu != null and menu.visible:
		return
	var target = _nearest_enemy()
	if target == null:
		return # No popup spam when outside combat range.
	attack_delay = 0.55
	hero.swing()
	var damage: float = 24.0 if int(inventory.get("iron_blade", 0)) > 0 else 16.0 if spear_crafted else 8.0
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

func _save() -> void:
	var data: Dictionary = {"version": 4, "inventory": inventory, "experience": experience, "kills": kills, "spear": spear_crafted}
	var f: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not (data is Dictionary):
		return
	var version: int = int(data.get("version", 0))
	if version not in [2, 3, 4]:
		return
	var stored: Variant = data.get("inventory", {})
	if stored is Dictionary:
		for key in inventory:
			inventory[key] = maxi(0, int(stored.get(key, 0)))
	experience = maxi(0, int(data.get("experience", 0)))
	kills = maxi(0, int(data.get("kills", 0)))
	spear_crafted = bool(data.get("spear", false)) or int(inventory.get("spear", 0)) > 0
	if spear_crafted:
		inventory["spear"] = maxi(1, int(inventory.get("spear", 0)))
	hero.set_spear(spear_crafted or int(inventory.get("iron_blade", 0)) > 0)
	hero.set_shield(int(inventory.get("shield", 0)) > 0)
	hero.set_cloak(int(inventory.get("cloak", 0)) > 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()
