extends Node3D
## Outpost 0.5: an original single-player, Android-first vertical slice.
const PLAYER = preload("res://scripts/player.gd")
const NODE = preload("res://scripts/resource_node.gd")
const ENEMY = preload("res://scripts/enemy.gd")
const HUD = preload("res://scripts/hud.gd")
const MENU = preload("res://scripts/menu.gd")
const STATION = preload("res://scripts/station.gd")
const STATION_PATH = preload("res://scripts/navigation/crafting_station_path.gd")
const VOXEL_BIOME = preload("res://scripts/voxel/voxel_biome.gd")
const VOXEL_PROPS = preload("res://scripts/voxel/voxel_props.gd")
const FOLIAGE = preload("res://scripts/voxel/foliage_renderer.gd")
const VOXEL_PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const NIGHTFALL = preload("res://scripts/world/day_night_cycle.gd")
const COOP = preload("res://scripts/network/coop_session.gd")
const CARRY = preload("res://scripts/inventory/carry_capacity.gd")
const LEVELS = preload("res://scripts/progression/character_levels.gd")
@export var voxel_art_enabled: bool = true
@export var fields_biome_enabled: bool = true # Original outpost clearing remains flat.
@export var chunk_streaming_enabled: bool = true # Stream finite 192x192 Fields in 12x12 cells.
const SAVE = "user://outpost_progress_v02.json"
@export var save_path: String = SAVE # Existing default; tests can isolate their saves.

var hero
var hud
var camera: Camera3D
var camera_angle: float = atan2(17.0, 20.0)
var camera_angle_target: float = atan2(17.0, 20.0)
var camera_occlusion_rise: float = 0.0
var camera_focus_smooth: Vector3 = Vector3.ZERO
const CAMERA_DRAG_RADIANS_PER_PIXEL: float = 0.006
var equipment: Dictionary = {"weapon": "training_blade", "offhand": "", "back": "", "bag": "", "tool_wood": "", "tool_mining": "", "tool_forage": ""}
var bag_quality: Dictionary = {} # One maintained 0-3 star quality per owned bag type.
var overflow_loot: Dictionary = {} # No reward is discarded when over capacity.
var active_quick_tool: String = "training_blade"
const QUICK_TOOL_IDS: Array[String] = ["training_blade", "spear", "iron_blade", "axe", "pickaxe", "satchel", "torch", "shield"]
var inventory: Dictionary = {"wood": 0, "stone": 0, "hide": 0, "coins": 0, "copper": 0, "silver": 0, "gold": 0, "gems": 0, "fiber": 0, "berries": 0, "meal": 0, "axe": 0, "pickaxe": 0, "shield": 0, "torch": 0, "spear": 0, "satchel": 0, "iron": 0, "coal": 0, "clay": 0, "herbs": 0, "mushrooms": 0, "reeds": 0, "iron_ingot": 0, "iron_blade": 0, "bricks": 0, "linen": 0, "cloak": 0, "tonic": 0, "stew": 0, "backpack_t1": 0, "backpack_t2": 0, "wood_satchel_t1": 0, "wood_satchel_t2": 0, "ore_satchel_t1": 0, "ore_satchel_t2": 0}
var menu
var coop
var recipes: Array = []
var crafting: Dictionary = {}
var craft_work_cooldown: float = 0.0
var stations: Dictionary = {}
var station_walk_target: String = ""
var station_walk_timeout: float = 0.0
var terrain_surface: Node3D
var station_positions: Dictionary = {"workbench": Vector3(3.5, 0.0, 0.6), "forge": Vector3(-12, 0.0, -1.0), "loom": Vector3(8.5, 0.0, 3.0), "campfire": Vector3(-2.8, 0.0, 2.8), "enchanting": Vector3(12.0, 0.0, -12.0)}
var experience: int = 0
var weapon_mastery_xp: Dictionary = {} # Stored per weapon, independent of character level.
var gathering_skill_xp: Dictionary = {"woodcutting": 0, "mining": 0, "foraging": 0}
var last_trained_skill: String = "training_blade"
var skill_cooldowns: Dictionary = {} # Runtime only.
const MAX_MANA: float = 35.0
const MANA_REGEN_PER_SECOND: float = 2.5
var mana: float = MAX_MANA
var weapon_enchants: Dictionary = {} # Owned weapon-id -> fire.
var quick_slots: Dictionary = {"potion":"", "consumable":""}
# Runtime-only recovery time: drawn as a genuine radial on the matching HUD slot.
const QUICK_USE_COOLDOWN: float = 4.0
var quick_use_cooldowns: Dictionary = {"potion": 0.0, "consumable": 0.0}
var kills: int = 0
var spear_crafted: bool = false
var attack_delay: float = 0.0
var gather_delay: float = 0.0
var world_time: float = 0.0
var day_night
var night_quote_seen: bool = false
var coop_reward_receipts: Dictionary = {}
var last_hit_node: Node3D
var workshop: Vector3 = Vector3(3.5, 0.0, 0.6)

func _ready() -> void:
	# Preserve fullscreen content scale on phones with extra-wide displays.
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
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
	var previous_skill_xp: int = int(gathering_skill_xp.get(last_trained_skill, 0)) if gathering_skill_xp.has(last_trained_skill) else int(weapon_mastery_xp.get(last_trained_skill, 0))
	hud.set_trained_skill(last_trained_skill, previous_skill_xp)
	menu = MENU.new()
	menu.setup(self)
	add_child(menu)
	if day_night != null:
		day_night.night_started.connect(_on_first_night)
	coop = COOP.new()
	add_child(coop)
	# Co-op is chosen in the title's adventure panel. LAN requests then pop
	# up during gameplay for the host; there is no persistent Co-op HUD tile.
	var requested_lan: String = str(get_tree().root.get_meta("outpost_lan_mode", "solo"))
	var lan_ip: String = str(get_tree().root.get_meta("outpost_lan_ip", ""))
	var lan_name: String = str(get_tree().root.get_meta("outpost_lan_name", "Adventurer"))
	for key in ["outpost_lan_mode", "outpost_lan_ip", "outpost_lan_name"]:
		if get_tree().root.has_meta(key):
			get_tree().root.remove_meta(key)
	if requested_lan == "host":
		coop.host_lan(lan_name)
	elif requested_lan == "join":
		coop.join_lan(lan_ip, lan_name)
	_camera(1.0)
	hud.toast("Welcome to OUTPOST! Find resources and visit a crafting station.")

func _register_keys() -> void:
	var binds := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "gather": [KEY_G], "interact": [KEY_E], "attack": [KEY_F, KEY_SPACE], "jump": [KEY_J], "craft": [KEY_C], "bag": [KEY_B, KEY_I], "heal": [KEY_H], "camera_left": [KEY_Q], "camera_right": [KEY_R]}
	for action in binds:
		var key_name: String = "outpost_" + str(action)
		if not InputMap.has_action(key_name):
			InputMap.add_action(key_name)
		for code in binds[action]:
			var event := InputEventKey.new()
			event.physical_keycode = int(code)
			InputMap.action_add_event(key_name, event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("outpost_interact"):
		smart_interact()
	elif event.is_action_pressed("outpost_gather"):
		gather()
	elif event.is_action_pressed("outpost_attack"):
		attack()
	elif event.is_action_pressed("outpost_craft"):
		craft()
	elif event.is_action_pressed("outpost_bag"):
		show_inventory()
	elif event.is_action_pressed("outpost_heal"):
		use_meal()
	elif event.is_action_pressed("outpost_camera_left"):
		rotate_camera(-1)
	elif event.is_action_pressed("outpost_camera_right"):
		rotate_camera(1)

func _process(delta: float) -> void:
	_update_station_walk(delta)
	_update_crafting(delta)
	attack_delay = maxf(0.0, attack_delay - delta)
	gather_delay = maxf(0.0, gather_delay - delta)
	for id in skill_cooldowns:
		skill_cooldowns[id] = maxf(0.0, float(skill_cooldowns[id]) - delta)
	for slot in quick_use_cooldowns:
		quick_use_cooldowns[slot] = maxf(0.0, float(quick_use_cooldowns[slot]) - delta)
	mana = minf(MAX_MANA, mana + MANA_REGEN_PER_SECOND * delta)
	world_time += delta
	_camera(delta)
	if day_night != null and hud != null:
		hud.set_day_clock(day_night.clock_text(), day_night.is_night(), str(equipment.get("offhand", "")) == "torch")
	if hero == null or hud == null:
		return
	# Swimming now handles the shore and surface. Only recover if the hero
	# somehow falls below the seabed; don't teleport normal swimmers home.
	# Dungeon instances remain isolated from overworld depth checks.
	# Failsafe for players that were already outside the submerged map
	# before upgrading an Alpha build. Private dungeons are far away and
	# must never be affected by this overworld-only recovery.
	if voxel_art_enabled and chunk_streaming_enabled and not hero.swimming and hero.global_position.y < -9.0 and absf(hero.global_position.x) < 110.0 and absf(hero.global_position.z) < 110.0:
		hero.global_position = Vector3(0, 0.35, 0)
		hero.velocity = Vector3.ZERO
		hero.knockback_velocity = Vector3.ZERO
		hud.toast("Recovered from beneath the seabed.")
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
		hint = "%s nearby • use ATTACK" % enemy_display_name(enemy)
	elif closest_station() != "":
		hint = "%s Crafting Station • tap or CRAFT" % closest_station().capitalize()
	hud.render_status(hero.health, inventory, experience, kills, str(equipment.get("weapon", "training_blade")), goal, hint)
	hud.set_enemy_target(enemy)
	hud.update_context(resource != null, enemy != null, closest_station() != "")


func rotate_camera(direction: int) -> void:
	# Keyboard-accessible 45 degree increments remain available on desktop.
	camera_angle_target += float(clampi(direction, -1, 1)) * PI / 4.0

func drag_camera(screen_pixels: float) -> void:
	# Continuous world-space orbit from Android one-finger drag or desktop
	# right mouse drag. It never changes movement/chunk ownership directly.
	# Cap pathological Android event deltas: one dropped touch frame must not
	# spin the world by a whole quarter turn.
	camera_angle_target -= clampf(screen_pixels, -90.0, 90.0) * CAMERA_DRAG_RADIANS_PER_PIXEL

func _camera(delta: float) -> void:
	if hero == null or camera == null:
		return
	var t: float = maxf(delta, 0.0)
	camera_angle = lerp_angle(camera_angle, camera_angle_target, 1.0 - exp(-6.5 * t))
	var desired_focus: Vector3 = hero.global_position + Vector3(0, 0.95, 0)
	if camera_focus_smooth == Vector3.ZERO or camera_focus_smooth.distance_to(desired_focus) > 36.0:
		camera_focus_smooth = desired_focus # Dungeon teleport / initial spawn
	else:
		# Vertical smoothing is slower so stepping down coastal terraces
		# never makes the isometric camera jerk up or down every voxel.
		camera_focus_smooth.x = lerpf(camera_focus_smooth.x, desired_focus.x, 1.0 - exp(-9.0 * t))
		camera_focus_smooth.z = lerpf(camera_focus_smooth.z, desired_focus.z, 1.0 - exp(-9.0 * t))
		camera_focus_smooth.y = lerpf(camera_focus_smooth.y, desired_focus.y, 1.0 - exp(-3.7 * t))
	var focus: Vector3 = camera_focus_smooth
	var orbit := Vector3(sin(camera_angle) * 26.25, 20.0, cos(camera_angle) * 26.25)
	var destination: Vector3 = focus + orbit
	var query := PhysicsRayQueryParameters3D.create(destination, desired_focus, 1, [hero.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var occluded: bool = not hit.is_empty() and (hit["position"] as Vector3).distance_to(desired_focus) > 1.8
	camera_occlusion_rise = lerpf(camera_occlusion_rise, 7.0 if occluded else 0.0, 1.0 - exp(-5.0 * t))
	# Old position interpolation lagged behind smoothed yaw, so look_at()
	# changed pitch unpredictably when users swiped sideways very quickly.
	# Yaw and focus are already smoothed; rebuild the *exact* orbital offset
	# each frame to guarantee a constant pitch and zero roll.
	var raised_focus: Vector3 = focus + Vector3.UP * camera_occlusion_rise
	camera.global_position = raised_focus + orbit
	camera.look_at(raised_focus, Vector3.UP)

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
		terrain_surface = landscape
		# Stream the first 7x7 region across frames. Loading UI can show honest progress.
		var loading_entry: bool = bool(get_tree().root.get_meta("outpost_defer_world_generation", false))
		landscape.build(fields_biome_enabled, 64012, chunk_streaming_enabled, loading_entry)
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
	var half_extent: float = 384.0 if voxel_art_enabled and fields_biome_enabled and chunk_streaming_enabled else 48.0 if voxel_art_enabled and fields_biome_enabled else 23.0
	var span: float = half_extent * 2.0
	if voxel_art_enabled and fields_biome_enabled and chunk_streaming_enabled:
		# Four inexpensive offshore seabed colliders support the genuinely
		# swimmable ocean outside the streamed terrain (+/-96). The ocean
		# remains afloat even if a knockback or delayed tile would otherwise
		# drop the player into the empty space below open water.
		var inner: float = 96.0
		var water_width: float = half_extent - inner
		var water_center: float = (half_extent + inner) * 0.5
		_wall(Vector3(-water_center, -7.0, 0.0), Vector3(water_width, 2.0, span))
		_wall(Vector3(water_center, -7.0, 0.0), Vector3(water_width, 2.0, span))
		_wall(Vector3(0.0, -7.0, -water_center), Vector3(inner * 2.0, 2.0, water_width))
		_wall(Vector3(0.0, -7.0, water_center), Vector3(inner * 2.0, 2.0, water_width))
	# Originally the border collider ended at Y=-1, above the sea level
	# (-2.82). The swimmer could pass beneath the wall into an unmeshed
	# infinite ocean, where swimming deactivated and gravity never stopped.
	# Extend only the streamed-island barriers below the actual seabed.
	var sea_border: bool = voxel_art_enabled and fields_biome_enabled and chunk_streaming_enabled
	var boundary_y: float = -7.0 if sea_border else 2.0
	var boundary_height: float = 24.0 if sea_border else 6.0
	_wall(Vector3(-half_extent, boundary_y, 0), Vector3(0.5, boundary_height, span))
	_wall(Vector3(half_extent, boundary_y, 0), Vector3(0.5, boundary_height, span))
	_wall(Vector3(0, boundary_y, -half_extent), Vector3(span, boundary_height, 0.5))
	_wall(Vector3(0, boundary_y, half_extent), Vector3(span, boundary_height, 0.5))

func _mesh_asset(id: String, where: Vector3, size_factor: float = 1.0, angle: float = 0.0) -> void:
	if voxel_art_enabled:
		var prop: MeshInstance3D
		match id:
			"oak_tree":
				prop = FOLIAGE.tree(FOLIAGE.species_at(where.x, where.z, 64012),
					posmod(roundi(where.x * 7.0 + where.z * 11.0), 3))
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

func station_at_screen(screen_pos: Vector2) -> String:
	# The station is a mesh, not a clickable full-screen GUI overlay. Using
	# camera projection keeps touch selection consistent during camera orbit.
	if camera == null or hero == null or (menu != null and menu.visible):
		return ""
	var closest: String = ""
	var threshold: float = clampf(get_viewport().get_visible_rect().size.y * 0.085, 43.0, 78.0)
	for station_id in stations:
		var node: Node3D = stations[station_id] as Node3D
		if node == null or camera.is_position_behind(node.global_position + Vector3.UP):
			continue
		var projected: Vector2 = camera.unproject_position(node.global_position + Vector3.UP * 0.9)
		var distance: float = screen_pos.distance_to(projected)
		if distance < threshold:
			threshold = distance
			closest = str(station_id)
	return closest

func visit_crafting_station(station_id: String) -> bool:
	if hero == null or menu == null or menu.visible or not station_positions.has(station_id):
		return false
	# If standing beside the clicked station, open immediately. Otherwise
	# navigate to the closest usable perimeter, never into the station mesh.
	var target: Vector3 = station_positions[station_id]
	var horizontal: float = Vector2(hero.global_position.x - target.x, hero.global_position.z - target.z).length()
	if horizontal <= 3.0 and closest_station() == station_id:
		hero.stop_interaction_move()
		station_walk_target = ""
		show_crafting()
		return true
	var path: PackedVector3Array = STATION_PATH.plan(hero.global_position, station_id, station_positions, terrain_surface)
	if path.is_empty():
		hud.toast("No safe route to this Crafting Station.")
		return false
	station_walk_target = station_id
	station_walk_timeout = 22.0
	hero.move_along_station_path(path)
	hud.toast("Walking to %s Crafting Station" % station_id.capitalize())
	return true

func cancel_station_walk() -> void:
	station_walk_target = ""
	station_walk_timeout = 0.0

func _update_station_walk(delta: float) -> void:
	if station_walk_target.is_empty() or hero == null:
		return
	station_walk_timeout -= delta
	if not hero.interaction_moving or station_walk_timeout <= 0.0:
		hero.stop_interaction_move()
		cancel_station_walk()
		return
	if menu != null and menu.visible:
		hero.stop_interaction_move()
		cancel_station_walk()
		return
	var point: Vector3 = station_positions[station_walk_target]
	var distance: float = Vector2(hero.global_position.x - point.x, hero.global_position.z - point.z).length()
	if distance <= 3.25 and closest_station() == station_walk_target:
		hero.stop_interaction_move()
		cancel_station_walk()
		show_crafting()

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

func enemy_display_name(enemy: Node) -> String:
	if enemy == null:
		return "Enemy"
	if enemy.is_in_group("dungeon_guardians"):
		return str(enemy.get("display_name"))
	if enemy.is_in_group("wild_boars") or enemy.name.begins_with("WildBoar"):
		return "Wild boar"
	return enemy.name.replace("_", " ").capitalize()

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
		return
	var expected_item: String = str(resource.kind)
	var desired: int = 1
	if expected_item == "wood" and str(equipment.get("tool_wood", "")) == "axe":
		desired = 2
	elif expected_item in ["stone", "iron", "coal"] and str(equipment.get("tool_mining", "")) == "pickaxe":
		desired = 2
	elif expected_item in ["fiber", "reeds"] and str(equipment.get("tool_forage", "")) == "satchel":
		desired = 2
	# Do not deplete a resource node when there is literally no bag room.
	if CARRY.max_fit(inventory, expected_item, desired, equipped_bag_id(), equipped_bag_stars()) <= 0:
		hud.toast("Bag full! Equip a larger bag or unload materials.")
		return
	gather_delay = 0.33
	var item: String = resource.harvest()
	if item == "":
		return
	hero.gather_swing(item)
	var amount: int = grant_item(item, desired)
	if amount > 0 and hud != null:
		hud.record_gather(item, amount)
	if amount <= 0:
		hud.toast("Bag full — gathering stopped.")
		return
	_show_gather_pickup(hero.global_position, item, amount)
	gain_experience(2 * amount)
	gain_gathering_skill(item, 2 * amount)
	_save()
	_refresh_menu()

func _show_gather_pickup(at: Vector3, resource_id: String, amount: int = 1) -> void:
	# A single faint world-space "+1 Wood" over the player replaces the
	# screen-corner Last Gathered card AND large resource toast.
	var pop := Label3D.new()
	pop.name = "FloatingGatherReceipt"
	pop.text = "+%d %s" % [maxi(1, amount), resource_id.replace("_", " ").capitalize()]
	pop.font_size = 37
	pop.pixel_size = 0.005
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	pop.position = at + Vector3(0.0, 2.45, 0.0)
	pop.modulate = Color(0.91, 0.83, 0.63, 0.80)
	pop.outline_modulate = Color(0.12, 0.09, 0.10, 0.65)
	pop.outline_size = 7
	add_child(pop)
	var tween := create_tween()
	tween.tween_property(pop, "position:y", pop.position.y + 0.75, 0.95)
	tween.parallel().tween_property(pop, "modulate:a", 0.0, 0.95)
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
	if CARRY.is_bag(item_id):
		return "bag"
	if item_id == "axe":
		return "tool_wood"
	if item_id == "pickaxe":
		return "tool_mining"
	if item_id == "satchel":
		return "tool_forage"
	return ""

func available_quick_tools() -> Array[String]:
	var candidates: Array[String] = ["training_blade"]
	for item in QUICK_TOOL_IDS:
		if item != "training_blade" and int(inventory.get(item, 0)) > 0:
			candidates.append(item)
	return candidates

func select_quick_tool(item_id: String) -> bool:
	if item_id not in QUICK_TOOL_IDS:
		return false
	if item_id != "training_blade" and int(inventory.get(item_id, 0)) <= 0:
		return false
	# Equip in its actual owned slot. Don't toggle OFF an already-equipped
	# tool just because the player chose it again in the quick selector.
	if item_id == "training_blade":
		equipment["weapon"] = "training_blade"
		_apply_equipment()
	elif not is_equipped(item_id) and not equip_item(item_id):
		return false
	active_quick_tool = item_id
	if hero != null:
		hero.set_held_tool(active_quick_tool)
	_save()
	_refresh_menu()
	return true

func smart_context() -> Dictionary:
	# One smart action, showing its REAL current intent; never a redundant
	# permanent hand beneath the sword/axe/pickaxe. The art is not a tooltip.
	var workshop: String = closest_station()
	if workshop != "":
		return {"kind": "craft", "label": "CRAFT", "icon": "hand"}
	var resource = _nearest_resource()
	var enemy = _nearest_enemy()
	var combat_tool: bool = active_quick_tool in ["training_blade", "spear", "iron_blade", "shield"]
	if enemy != null and (resource == null or combat_tool):
		return {"kind": "attack", "label": "ATTACK", "icon": "sword"}
	if resource != null:
		var kind: String = str(resource.kind)
		var tool_icon: String = "axe" if kind == "wood" else "pickaxe" if kind in ["stone", "iron", "coal"] else "hand"
		return {"kind": "gather", "label": "GATHER", "icon": tool_icon}
	if enemy != null:
		return {"kind": "attack", "label": "ATTACK", "icon": "sword"}
	if active_quick_tool == "torch" and int(inventory.get("torch", 0)) > 0:
		return {"kind": "torch", "label": "TORCH", "icon": "hand"}
	return {"kind": "none", "label": "INTERACT", "icon": "hand"}

func smart_interact() -> void:
	if menu != null and menu.visible:
		return
	var action: String = str(smart_context().get("kind", "none"))
	match action:
		"attack":
			attack()
		"gather":
			gather()
		"craft":
			# Resolve station again at the instant of the tap. A stale CRAFT
			# label must never open a different station or a generic recipe.
			if closest_station() != "":
				show_crafting()
		"torch":
			toggle_torch()
		_:
			pass

func equipped_bag_id() -> String:
	return str(equipment.get("bag", ""))

func equipped_bag_stars() -> int:
	return clampi(int(bag_quality.get(equipped_bag_id(), 0)), 0, 3)

func bag_load() -> float:
	return CARRY.used(inventory, equipped_bag_id(), equipped_bag_stars())

func bag_capacity() -> float:
	return CARRY.capacity(equipped_bag_id(), equipped_bag_stars())

func grant_item(item_id: String, amount: int, store_excess: bool = false) -> int:
	if amount <= 0:
		return 0
	var fitting: int = CARRY.max_fit(inventory, item_id, amount, equipped_bag_id(), equipped_bag_stars())
	if fitting > 0:
		inventory[item_id] = int(inventory.get(item_id, 0)) + fitting
		if hud != null:
			hud.record_loot(item_id, fitting)
	var excess: int = amount - fitting
	if excess > 0 and store_excess:
		overflow_loot[item_id] = int(overflow_loot.get(item_id, 0)) + excess
	return fitting

func claim_overflow() -> int:
	var moved: int = 0
	for item_id in overflow_loot.keys():
		var key: String = str(item_id)
		var pending: int = int(overflow_loot[key])
		var count: int = grant_item(key, pending)
		moved += count
		if count == pending:
			overflow_loot.erase(key)
		else:
			overflow_loot[key] = pending - count
	if moved > 0:
		_save()
		_refresh_menu()
	if hud != null:
		hud.toast("Recovered %d stored loot items." % moved if moved > 0 else "Make more room in your bag first.")
	return moved

func _craft_fits(recipe: Dictionary) -> bool:
	var staged: Dictionary = inventory.duplicate()
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for raw_key in ingredients:
		var key: String = str(raw_key)
		staged[key] = int(staged.get(key, 0)) - int(ingredients[raw_key])
	var result_id: String = str(recipe.get("result", ""))
	if str(recipe.get("id", "")) == "fiery_weapon":
		return CARRY.used(staged, equipped_bag_id(), equipped_bag_stars()) <= bag_capacity() + 0.0001
	var new_bag: bool = CARRY.is_bag(result_id)
	var already_owned: bool = int(staged.get(result_id, 0)) > 0
	if not new_bag or not already_owned:
		staged[result_id] = int(staged.get(result_id, 0)) + maxi(1, int(recipe.get("amount", 1)))
	var preview_bag: String = result_id if new_bag else equipped_bag_id()
	var preview_stars: int = (mini(3, int(bag_quality.get(result_id, 0)) + 1)) if new_bag else equipped_bag_stars()
	return CARRY.used(staged, preview_bag, preview_stars) <= CARRY.capacity(preview_bag, preview_stars) + 0.0001

func craft_block_reason(id: String) -> String:
	var recipe: Dictionary = _recipe_by_id(id)
	if recipe.is_empty():
		return "Recipe unavailable."
	if not crafting.is_empty():
		return "Finish your current crafting job first."
	var result: String = str(recipe.get("result", ""))
	if id == "fiery_weapon":
		var current_weapon: String = str(equipment.get("weapon", "training_blade"))
		if current_weapon not in ["spear", "iron_blade"]:
			return "Equip a crafted spear or iron blade to enchant."
		if str(weapon_enchants.get(current_weapon, "")) == "fire":
			return "This weapon already has Fiery Weapon."
		if character_level() < 3:
			return "Requires character level 3 and consumes one level."
	if owns_unique(result):
		return "You already own this unique item."
	if CARRY.is_bag(result) and int(inventory.get(result, 0)) > 0 and int(bag_quality.get(result, 0)) >= 3:
		return "This bag already has maximum 3-star quality."
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for key in ingredients:
		if int(inventory.get(str(key), 0)) < int(ingredients[key]):
			return "Missing %s materials." % str(key).replace("_", " ")
	if not _craft_fits(recipe):
		return "Not enough carry capacity for the crafted item."
	if not near_station(str(recipe.get("station", "workbench"))):
		return "Move to the correct crafting station."
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
	if slot == "bag" and bag_load() > bag_capacity() and hud != null:
		hud.toast("Overloaded! Change bag or unload materials.")
	return true

func _apply_equipment() -> void:
	if hero == null:
		return
	hero.set_weapon(str(equipment.get("weapon", "training_blade")))
	hero.set_held_tool(active_quick_tool)
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
	return craft_block_reason(id).is_empty()

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
	if not _craft_fits(recipe):
		hud.toast("Craft cancelled: not enough free bag capacity.")
		_refresh_menu()
		return
	if str(recipe.get("id", "")) == "fiery_weapon":
		var chosen_weapon: String = str(equipment.get("weapon", "training_blade"))
		if chosen_weapon not in ["spear", "iron_blade"] or weapon_enchants.get(chosen_weapon, "") == "fire" or character_level() < 3:
			hud.toast("Enchant cancelled: equip a valid weapon at level 3+.")
			return
		for ingredient in ingredients:
			inventory[str(ingredient)] = int(inventory.get(str(ingredient), 0)) - int(ingredients[ingredient])
		experience = LEVELS.spend_level(experience, 1)
		weapon_enchants[chosen_weapon] = "fire"
		hud.toast("Fiery Weapon! Your %s now burns enemies." % chosen_weapon.replace("_", " "))
		_save()
		if menu != null:
			menu.on_craft_completed("fiery_weapon")
		_refresh_menu()
		return
	for ingredient in ingredients:
		inventory[str(ingredient)] = int(inventory.get(str(ingredient), 0)) - int(ingredients[ingredient])
	var result: String = str(recipe.get("result", ""))
	var is_bag: bool = CARRY.is_bag(result)
	if is_bag:
		var existing: bool = int(inventory.get(result, 0)) > 0
		if not existing:
			inventory[result] = 1
		bag_quality[result] = mini(3, int(bag_quality.get(result, 0)) + 1)
	else:
		inventory[result] = int(inventory.get(result, 0)) + maxi(1, int(recipe.get("amount", 1)))
	if hud != null and not result.is_empty():
		hud.record_loot(result, 1 if is_bag else maxi(1, int(recipe.get("amount", 1))))
	if result == "spear":
		spear_crafted = true
	# Newly crafted equipment is immediately equipped, but can be swapped/removed.
	var slot: String = equipment_slot(result)
	if slot != "":
		equipment[slot] = result
		_apply_equipment()
	gain_experience(8)
	hud.toast("%s • %d stars! +8 XP" % [str(recipe.get("name", result)), int(bag_quality[result])] if is_bag else "Created %s! +8 XP" % str(recipe.get("name", result)))
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

func character_level() -> int:
	return LEVELS.level_for(experience)

func level_state() -> Dictionary:
	return LEVELS.level_state(experience)

func gain_experience(amount: int) -> void:
	if amount <= 0:
		return
	var before: int = character_level()
	experience += amount
	if character_level() > before and hud != null:
		hud.toast("LEVEL UP! Level %d — enchanting and skills grow stronger." % character_level())

func gain_gathering_skill(resource_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var skill: String = "woodcutting" if resource_id == "wood" else "mining" if resource_id in ["stone", "iron", "coal", "clay"] else "foraging"
	gathering_skill_xp[skill] = maxi(0, int(gathering_skill_xp.get(skill, 0)) + amount)
	last_trained_skill = skill
	if hud != null:
		hud.set_trained_skill(skill, int(gathering_skill_xp[skill]))

func current_weapon_id() -> String:
	return str(equipment.get("weapon", "training_blade"))

func mana_limit() -> float:
	return MAX_MANA

func mastery_rank(weapon_id: String = "") -> int:
	var id: String = current_weapon_id() if weapon_id == "" else weapon_id
	return LEVELS.mastery_rank(int(weapon_mastery_xp.get(id, 0)))

func unlocked_skill_slots() -> int:
	return LEVELS.available_skill_slots(int(weapon_mastery_xp.get(current_weapon_id(), 0)))

func gain_weapon_mastery(weapon_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var previous: int = LEVELS.available_skill_slots(int(weapon_mastery_xp.get(weapon_id, 0)))
	weapon_mastery_xp[weapon_id] = int(weapon_mastery_xp.get(weapon_id, 0)) + amount
	last_trained_skill = weapon_id
	if hud != null:
		hud.set_trained_skill(weapon_id, int(weapon_mastery_xp[weapon_id]))
	if LEVELS.available_skill_slots(int(weapon_mastery_xp.get(weapon_id, 0))) > previous and hud != null:
		hud.toast("Weapon mastery! New ability slot available.")

func use_weapon_skill(slot: int) -> bool:
	if slot < 0 or slot >= unlocked_skill_slots() or hero == null or (menu != null and menu.visible):
		return false
	# LAN dungeon combat remains host-authoritative; never apply local
	# skill damage that could desynchronise an encounter.
	if coop != null and coop.in_party_dungeon():
		if hud != null:
			hud.toast("Skills in co-op dungeons require host combat support.")
		return false
	var skill: String = LEVELS.skill_for_slot(slot)
	if float(skill_cooldowns.get(skill, 0.0)) > 0.0 or attack_delay > 0.0:
		return false
	var target = _nearest_enemy()
	if target == null:
		return false
	var mana_cost: float = 6.0 + 3.0 * float(slot)
	if mana < mana_cost:
		if hud != null:
			hud.toast("Need %d MP for this ability." % int(mana_cost))
		return false
	var weapon: String = current_weapon_id()
	var base: float = 24.0 if weapon == "iron_blade" else 16.0 if weapon == "spear" else 8.0
	var dealt: float = base * LEVELS.multiplier_for_skill(skill)
	mana = maxf(0.0, mana - mana_cost)
	skill_cooldowns[skill] = LEVELS.cooldown_for_skill(skill)
	attack_delay = 0.55
	hero.swing()
	target.receive_damage(dealt)
	if str(weapon_enchants.get(weapon, "")) == "fire" and target.has_method("ignite"):
		target.ignite(4.0)
	gain_weapon_mastery(weapon, 18)
	gain_experience(3)
	_save()
	return true

func available_quick_consumables(slot: String) -> Array[String]:
	var pool: Array[String] = []
	if slot == "potion":
		pool.append("tonic")
	elif slot == "consumable":
		pool.append("meal")
		pool.append("stew")
	var available: Array[String] = []
	for item in pool:
		if int(inventory.get(item, 0)) > 0:
			available.append(item)
	return available

func set_quick_consumable(slot: String, item_id: String) -> bool:
	if slot not in ["potion", "consumable"]:
		return false
	if item_id != "" and item_id not in available_quick_consumables(slot):
		return false
	quick_slots[slot] = item_id
	_save()
	return true

func use_quick_consumable(slot: String) -> bool:
	if slot not in ["potion", "consumable"]:
		return false
	if float(quick_use_cooldowns.get(slot, 0.0)) > 0.0:
		return false
	var item: String = str(quick_slots.get(slot, ""))
	if item == "" or int(inventory.get(item, 0)) <= 0:
		return false
	if hero == null or hero.health >= 99.9:
		return false
	var amount: float = 65.0 if item == "tonic" else 75.0 if item == "stew" else 40.0
	consume(item, amount)
	# Recovery starts only after an item actually heals, not on an empty tap.
	quick_use_cooldowns[slot] = QUICK_USE_COOLDOWN
	if int(inventory.get(item, 0)) <= 0:
		quick_slots[slot] = ""
		_save()
	return true

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
	if coop != null and coop.in_party_dungeon():
		var guardian = _nearest_enemy()
		if guardian == null or not guardian.has_meta("encounter_slot"):
			return
		attack_delay = 0.55
		hero.swing()
		coop.request_strike(int(guardian.get_meta("encounter_slot")))
		return
	var target = _nearest_enemy()
	if target == null:
		return # No popup spam when outside combat range.
	attack_delay = 0.55
	hero.swing()
	var weapon: String = str(equipment.get("weapon", "training_blade"))
	var damage: float = 24.0 if weapon == "iron_blade" else 16.0 if weapon == "spear" else 8.0
	target.receive_damage(damage)
	if str(weapon_enchants.get(weapon, "")) == "fire" and target.has_method("ignite"):
		target.ignite(4.0)
	gain_weapon_mastery(weapon, 12)
	# World-space damage numbers already come from each mob's hit feedback.
	# No giant per-swing notification is needed, and no boar assumptions.

func on_enemy_killed() -> void:
	kills += 1
	grant_item("hide", 1, true)
	grant_item("coins", 3, true)
	gain_experience(12)
	hud.record_combat_event("Boar defeated")
	hud.toast("Boar defeated! Loot sent to bag or stored if full.")
	_save()
	_refresh_menu()

func receive_coop_reward(receipt: String, reward: Dictionary) -> bool:
	# Receipts survive a restart and prevent duplicate host event delivery.
	if receipt.is_empty() or receipt.length() > 128 or coop_reward_receipts.has(receipt):
		return false
	if not receipt.begins_with("lan:"):
		return false
	coop_reward_receipts[receipt] = true
	grant_item("coins", maxi(0, int(reward.get("coins", 0))), true)
	gain_experience(maxi(0, int(reward.get("xp", 0))))
	var materials: Dictionary = reward.get("materials", {})
	for item_id in materials:
		var key: String = str(item_id)
		if not key.is_empty():
			grant_item(key, maxi(0, int(materials[item_id])), true)
	for book in reward.get("books", []):
		var key: String = str(book)
		if not key.is_empty():
			grant_item(key, 1, true)
	_save()
	_refresh_menu()
	if hud != null:
		hud.toast("Party dungeon cleared! +%d coins • +%d XP" % [int(reward.get("coins", 0)), int(reward.get("xp", 0))])
	return true

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

func save_and_return_to_title() -> void:
	# Single exit path for solo and LAN. Dismantle active sessions before saving
	# so the next title visit starts offline and no ghost avatars remain.
	if coop != null:
		coop.disconnect_session()
	_save()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func _save() -> void:
	var data: Dictionary = {"version": 5, "equipment": equipment, "inventory": inventory, "experience": experience, "kills": kills, "spear": spear_crafted, "day_phase": day_night.phase if day_night != null else 0.38, "night_quote_seen": night_quote_seen, "coop_reward_receipts": coop_reward_receipts, "active_quick_tool": active_quick_tool, "bag_quality": bag_quality, "overflow_loot": overflow_loot, "weapon_mastery_xp": weapon_mastery_xp, "gathering_skill_xp": gathering_skill_xp, "mana": mana, "last_trained_skill": last_trained_skill, "weapon_enchants": weapon_enchants, "quick_slots": quick_slots}
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
	mana = clampf(float(data.get("mana", MAX_MANA)), 0.0, MAX_MANA)
	night_quote_seen = bool(data.get("night_quote_seen", false))
	if data.get("weapon_mastery_xp", {}) is Dictionary:
		for key in data.get("weapon_mastery_xp", {}):
			weapon_mastery_xp[str(key)] = maxi(0, int(data["weapon_mastery_xp"][key]))
	if data.get("gathering_skill_xp", {}) is Dictionary:
		for key in gathering_skill_xp:
			gathering_skill_xp[key] = maxi(0, int(data["gathering_skill_xp"].get(key, 0)))
	var stored_training: String = str(data.get("last_trained_skill", "training_blade"))
	if gathering_skill_xp.has(stored_training) or stored_training in ["training_blade", "spear", "iron_blade"]:
		last_trained_skill = stored_training
	if data.get("weapon_enchants", {}) is Dictionary:
		for key in data.get("weapon_enchants", {}):
			if str(key) in ["spear", "iron_blade"] and str(data["weapon_enchants"][key]) == "fire":
				weapon_enchants[str(key)] = "fire"
	if data.get("quick_slots", {}) is Dictionary:
		for slot in ["potion", "consumable"]:
			var chosen: String = str(data["quick_slots"].get(slot, ""))
			quick_slots[slot] = chosen if chosen in (["tonic"] if slot == "potion" else ["meal", "stew"]) else ""
	if data.get("bag_quality", {}) is Dictionary:
		for bag_id in data.get("bag_quality", {}):
			var key: String = str(bag_id)
			if CARRY.is_bag(key):
				bag_quality[key] = clampi(int(data["bag_quality"][bag_id]), 0, 3)
	if data.get("overflow_loot", {}) is Dictionary:
		for item_id in data.get("overflow_loot", {}):
			var key: String = str(item_id)
			if key.length() <= 64 and key != "":
				overflow_loot[key] = maxi(0, int(data["overflow_loot"][item_id]))
	if data.get("coop_reward_receipts", {}) is Dictionary:
		coop_reward_receipts = (data.get("coop_reward_receipts", {}) as Dictionary).duplicate(true)
	if day_night != null:
		day_night.set_phase(clampf(float(data.get("day_phase", 0.38)), 0.0, 1.0))
	var stored: Variant = data.get("inventory", {})
	if stored is Dictionary:
		for key in inventory:
			inventory[key] = maxi(0, int(stored.get(key, 0)))
		# Preserve newly introduced skill books and dungeon material keys.
		for key in stored:
			if key is String and not inventory.has(key) and key.length() <= 64:
				inventory[key] = maxi(0, int(stored[key]))
	active_quick_tool = str(data.get("active_quick_tool", "training_blade"))
	if active_quick_tool not in QUICK_TOOL_IDS or (active_quick_tool != "training_blade" and int(inventory.get(active_quick_tool, 0)) < 1):
		active_quick_tool = "training_blade"
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
