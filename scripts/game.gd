extends Node3D
## Outpost 0.2: an original single-player, Android-first vertical slice.
const PLAYER = preload("res://scripts/player.gd")
const NODE = preload("res://scripts/resource_node.gd")
const ENEMY = preload("res://scripts/enemy.gd")
const HUD = preload("res://scripts/hud.gd")
const SAVE = "user://outpost_progress_v02.json"

var hero
var hud
var camera: Camera3D
var inventory: Dictionary = {"wood": 0, "stone": 0, "hide": 0, "coins": 0}
var experience: int = 0
var kills: int = 0
var spear_crafted: bool = false
var attack_delay: float = 0.0
var workshop: Vector3 = Vector3(3.5, 0.0, 0.6)

func _ready() -> void:
	_register_keys()
	_lighting()
	_world()
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
	_camera(1.0)
	hud.toast("Welcome to OUTPOST! Gather 3 wood and 2 stone.")

func _register_keys() -> void:
	var binds := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "gather": [KEY_E], "attack": [KEY_F, KEY_SPACE], "craft": [KEY_C]}
	for action in binds:
		var key_name := "outpost_" + action
		if not InputMap.has_action(key_name):
			InputMap.add_action(key_name)
		for code in binds[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(key_name, event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("outpost_gather"):
		gather()
	elif event.is_action_pressed("outpost_attack"):
		attack()
	elif event.is_action_pressed("outpost_craft"):
		craft()

func _process(delta: float) -> void:
	attack_delay = maxf(0.0, attack_delay - delta)
	_camera(delta)
	if hero == null or hud == null:
		return
	var goal := "Gather 3 wood + 2 stone; craft a spear"
	if spear_crafted:
		goal = "Defeat a wild boar" if kills == 0 else "Quest complete! Explore & collect"
	var hint := "Explore the forest to find trees and stone."
	var resource = _nearest_resource()
	if resource != null:
		hint = "GATHER: %s (%d hits left)" % [resource.kind.capitalize(), resource.hits_left]
	elif hero.global_position.distance_to(workshop) < 3.3:
		hint = "CRAFT: Workshop requires 3 wood + 2 stone"
	elif _nearest_enemy() != null:
		hint = "ATTACK: Wild boar"
	hud.render_status(hero.health, inventory, experience, kills, spear_crafted, goal, hint)

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

func part(mesh: Mesh, at: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.material_override = material(color)
	parent.add_child(inst)
	return inst

func block(size: Vector3, at: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return part(mesh, at, color, parent)

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
	# Timber crafting bench and work area
	block(Vector3(3.0, 0.22, 1.5), workshop + Vector3(0, 0.85, 0), Color("8b5f3c"))
	for x in [-1.12, 1.12]:
		for z in [-0.48, 0.48]:
			block(Vector3(0.22, 0.86, 0.22), workshop + Vector3(x, 0.4, z), Color("5e3e29"))
	for i in range(4):
		block(Vector3(0.18, 0.07, 1.3), workshop + Vector3(-1.1 + i * 0.74, 0.99, 0), Color("b88750"))
	var sign := Label3D.new()
	sign.text = "OUTPOST WORKSHOP"
	sign.font_size = 48
	sign.pixel_size = 0.006
	sign.position = workshop + Vector3(0, 2.35, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)
	# Campfire logs, embers and shelter
	block(Vector3(1.6, 0.1, 1.6), Vector3(-2.8, 0, 2.8), Color("53483e"))
	var fire := SphereMesh.new()
	fire.radius = 0.46
	fire.height = 0.9
	var glow := part(fire, Vector3(-2.8, 0.35, 2.8), Color("ffc45e"))
	glow.scale = Vector3(0.7, 1.15, 0.7)
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
		mesh.radius = rng.randf_range(0.15, 0.38)
		mesh.height = 0.40
		var tuft := part(mesh, Vector3(x, 0.12, z), Color("456f41") if i % 3 == 0 else Color("89a566"))
		tuft.scale = Vector3(1.4, 0.53, 1.0)
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

func gather() -> void:
	var resource = _nearest_resource()
	if resource == null:
		hud.toast("Stand next to a tree or rock.")
		return
	var item: String = resource.harvest()
	if item == "":
		return
	inventory[item] = int(inventory.get(item, 0)) + 1
	experience += 2
	hud.toast("+1 %s  +2 XP" % item.capitalize())
	_save()

func craft() -> void:
	if spear_crafted:
		hud.toast("Forest Spear already crafted.")
		return
	if hero.global_position.distance_to(workshop) > 3.3:
		hud.toast("Go to the outpost workbench.")
		return
	if int(inventory["wood"]) < 3 or int(inventory["stone"]) < 2:
		hud.toast("Need 3 wood and 2 stone.")
		return
	inventory["wood"] -= 3
	inventory["stone"] -= 2
	spear_crafted = true
	hero.set_spear(true)
	experience += 10
	hud.toast("FOREST SPEAR EQUIPPED! +10 XP")
	_save()

func attack() -> void:
	if attack_delay > 0.0:
		return
	attack_delay = 0.6
	var target = _nearest_enemy()
	if target == null:
		hud.toast("Move close to a boar to attack.")
		return
	target.receive_damage(14.0 if spear_crafted else 7.0)
	if target.alive:
		hud.toast("Hit! Boar health: %d" % int(ceilf(target.hp)))

func on_enemy_killed() -> void:
	kills += 1
	inventory["hide"] += 1
	inventory["coins"] += 3
	experience += 12
	hud.toast("Wild boar defeated! +1 hide, +3 coins")
	_save()

func _save() -> void:
	var data := {"version": 2, "inventory": inventory, "experience": experience, "kills": kills, "spear": spear_crafted}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != 2:
		return
	var stored = data.get("inventory", {})
	if typeof(stored) == TYPE_DICTIONARY:
		for key in inventory:
			inventory[key] = maxi(0, int(stored.get(key, 0)))
	experience = maxi(0, int(data.get("experience", 0)))
	kills = maxi(0, int(data.get("kills", 0)))
	spear_crafted = bool(data.get("spear", false))
	hero.set_spear(spear_crafted)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()
