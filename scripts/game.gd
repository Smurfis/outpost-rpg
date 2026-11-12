extends Node3D
## Outpost 0.5: an original single-player, Android-first vertical slice.
const PLAYER = preload("res://scripts/player.gd")
const NODE = preload("res://scripts/resource_node.gd")
const ENEMY = preload("res://scripts/enemy.gd")
const DUNGEON_RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
const WILDLIFE = preload("res://scripts/creatures/overworld_wildlife.gd")
const HUD = preload("res://scripts/hud.gd")
const MENU = preload("res://scripts/menu.gd")
const STATION = preload("res://scripts/station.gd")
const STATION_PATH = preload("res://scripts/navigation/crafting_station_path.gd")
const QUALITY = preload("res://scripts/crafting/equipment_quality.gd")
const VOXEL_BIOME = preload("res://scripts/voxel/voxel_biome.gd")
const VOXEL_PROPS = preload("res://scripts/voxel/voxel_props.gd")
const FOLIAGE = preload("res://scripts/voxel/foliage_renderer.gd")
const VOXEL_PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const NIGHTFALL = preload("res://scripts/world/day_night_cycle.gd")
const COOP = preload("res://scripts/network/coop_session.gd")
const CARRY = preload("res://scripts/inventory/carry_capacity.gd")
const LEVELS = preload("res://scripts/progression/character_levels.gd")
const CONTROLS = preload("res://scripts/interaction/player_controls.gd")
const PLACEMENT = preload("res://scripts/world/prop_placement.gd")
const WORLD_OBJECT = preload("res://scripts/interaction/world_object.gd")
const MAP_SERVICE = preload("res://scripts/map/map_service.gd")
const WORLD_MAP = preload("res://scripts/ui/world_map.gd")
const PC_CHAT = preload("res://scripts/ui/outpost_pc_chat.gd")
var map_service: Node
var world_map: CanvasLayer
var chat: CanvasLayer
var controls
var prop_placement = PLACEMENT.new()
var focus_target: Node3D
# Last successfully attacked enemy stays in the central target HUD briefly.
var recent_attack_target: Node3D
var recent_target_seconds: float = 0.0
const TARGET_HUD_NEARBY_RADIUS: float = 12.0
var opened_world_objects: Dictionary = {}
const FOOD_IDS: Array[String] = ["meal", "stew", "cooked_shrimp"]
@export var voxel_art_enabled: bool = true
@export var fields_biome_enabled: bool = true # Original outpost clearing remains flat.
@export var chunk_streaming_enabled: bool = true # Stream finite 192x192 Fields in 12x12 cells.
@export var diorama_map_enabled: bool = true # Disable to retain the legacy minimap fallback.
@export var experimental_archipelago_enabled: bool = true # Feature branch: remote fractal islands and caves.
const SAVE = "user://outpost_progress_v02.json"
@export var save_path: String = SAVE # Existing default; tests can isolate their saves.

var hero
var hud
var camera: Camera3D
var camera_angle: float = atan2(17.0, 20.0)
var camera_angle_target: float = atan2(17.0, 20.0)
var camera_occlusion_rise: float = 0.0
var _camera_clearance_query: PhysicsShapeQueryParameters3D
var camera_focus_smooth: Vector3 = Vector3.ZERO
const CAMERA_DRAG_RADIANS_PER_PIXEL: float = 0.006
var equipment: Dictionary = {"weapon": "training_blade", "offhand": "", "back": "", "bag": "", "tool_wood": "", "tool_mining": "", "tool_forage": ""}
var bag_quality: Dictionary = {} # One maintained 0-3 star quality per owned bag type.
var best_craft_rolls: Dictionary = {} # Highest scoring crafted roll retained per equipment ID.
var last_craft_roll: Dictionary = {}
var last_craft_improved: bool = false
var overflow_loot: Dictionary = {} # No reward is discarded when over capacity.
var death_tombstones: Dictionary = {} # Persisted grave-id -> position, contents, and crafted metadata.
var next_tombstone_id: int = 1
var tombstone_nodes: Dictionary = {}
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
# Three real damage checks across the 0.9s weapon animation. Per-tick
# damage is 40% of the old single hit (120% total if all three land).
const WHIRLWIND_TICK_TIMES: Array[float] = [0.0, 0.30, 0.60]
var whirlwind_tick_clock: float = -1.0
var whirlwind_ticks_done: int = 0
var whirlwind_tick_damage: float = 0.0
var whirlwind_tick_weapon: String = ""
var whirlwind_unique_hits: Dictionary = {}
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
	inventory.merge({"shrimp": 0, "cooked_shrimp": 0, "shrimp_net": 0})
	equipment["tool_fishing"] = ""
	gathering_skill_xp["fishing"] = 0
	for point in station_positions.values():
		prop_placement.reserve(point, 1.7)
	prop_placement.reserve(Vector3(-6.1, 0, 2.8), 2.2)
	for point in [Vector3(-18, 0, -18), Vector3(18, 0, -18), Vector3(-18, 0, 18), Vector3(18, 0, 18), Vector3(0, 0, -19)]:
		prop_placement.reserve(point, 3.2)
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
	map_service = MAP_SERVICE.new()
	add_child(map_service)
	map_service.setup(self)
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
	controls = CONTROLS.new()
	add_child(controls)
	controls.setup(self)
	world_map = WORLD_MAP.new()
	add_child(world_map)
	world_map.setup(self, map_service)
	chat = PC_CHAT.new()
	chat.setup(self)
	add_child(chat)
	hud.toast("Welcome to OUTPOST! Find resources and visit a crafting station.")

func toggle_world_map() -> void:
	if world_map == null:
		return
	if world_map.is_open():
		world_map.close_map()
	elif controls == null or not controls.modal_open():
		world_map.open_map()

func _register_keys() -> void:
	var binds := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "ability_1": [KEY_1], "ability_2": [KEY_2], "ability_3": [KEY_3], "potion": [KEY_Q], "food": [KEY_E], "tool_cycle": [KEY_T], "bag": [KEY_I], "character": [KEY_C], "skills": [KEY_K], "cancel": [KEY_ESCAPE], "focus": [KEY_TAB], "gather": [], "interact": [KEY_SPACE], "attack": [], "craft": [], "heal": [], "camera_left": [], "camera_right": []}
	if InputMap.has_action("outpost_jump"):
		InputMap.erase_action("outpost_jump")
	binds["map"] = [KEY_M]
	for action in binds:
		var key_name: String = "outpost_" + str(action)
		if not InputMap.has_action(key_name):
			InputMap.add_action(key_name)
		InputMap.action_erase_events(key_name)
		for code in binds[action]:
			var event := InputEventKey.new()
			event.physical_keycode = int(code)
			InputMap.action_add_event(key_name, event)

func _unhandled_input(event: InputEvent) -> void:
	pass # Shared controller routes InputMap actions after GUI consumption.

func _process(delta: float) -> void:
	_update_station_walk(delta)
	_update_crafting(delta)
	attack_delay = maxf(0.0, attack_delay - delta)
	gather_delay = maxf(0.0, gather_delay - delta)
	recent_target_seconds = maxf(0.0, recent_target_seconds - delta)
	_advance_whirlwind_ticks(delta)
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
	var resource = _nearest_resource() if controls == null or not controls.desktop else null
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
	elif closest_station() != "":
		hint = "%s Crafting Station • tap or CRAFT" % closest_station().capitalize()
	hud.render_status(hero.health, inventory, experience, kills, str(equipment.get("weapon", "training_blade")), goal, hint)
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
	# A doorway/tree between the hero and camera is visual occlusion, not
	# camera collision. Raising the framing for that ray hit displaced the
	# hero on screen without clearing the obstruction. Only protect the
	# actual camera position, keeping player and world collisions unchanged.
	camera_occlusion_rise = lerpf(camera_occlusion_rise, _camera_clearance_rise(destination), 1.0 - exp(-5.0 * t))
	# Old position interpolation lagged behind smoothed yaw, so look_at()
	# changed pitch unpredictably when users swiped sideways very quickly.
	# Yaw and focus are already smoothed; rebuild the *exact* orbital offset
	# each frame to guarantee a constant pitch and zero roll.
	var raised_focus: Vector3 = focus + Vector3.UP * camera_occlusion_rise
	camera.global_position = raised_focus + orbit
	camera.look_at(raised_focus, Vector3.UP)

func _camera_clearance_rise(destination: Vector3) -> float:
	if _camera_clearance_query == null:
		_camera_clearance_query = PhysicsShapeQueryParameters3D.new()
		var probe := SphereShape3D.new()
		probe.radius = 0.35
		_camera_clearance_query.shape = probe
		_camera_clearance_query.collision_mask = 1
		_camera_clearance_query.collide_with_areas = false
		_camera_clearance_query.exclude = [hero.get_rid()]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	# Usually one query. Extra probes are bounded and only run when solid
	# geometry overlaps the camera itself, never for a blocked sightline.
	for rise in range(8):
		_camera_clearance_query.transform = Transform3D(Basis.IDENTITY, destination + Vector3.UP * float(rise))
		if space.intersect_shape(_camera_clearance_query, 1).is_empty():
			return float(rise)
	return 7.0

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
		landscape.build(fields_biome_enabled, 64012, chunk_streaming_enabled, loading_entry, experimental_archipelago_enabled)
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
		var shelter_object = WORLD_OBJECT.new()
		add_child(shelter_object)
		shelter_object.position = shelter.position
		shelter.position = Vector3.ZERO
		shelter_object.setup(self, "camp_shelter", "Camp shelter", "inspect", shelter)
		shelter_object.message = "Outpost shelter. Nearby stations craft equipment and cook food."
	else:
		var tent := CylinderMesh.new()
		tent.top_radius = 0.0
		tent.bottom_radius = 2.1
		tent.height = 2.9
		part(tent, Vector3(-6.1, 1.38, 2.8), Color("d5b77b"))
		block(Vector3(1.9, 0.13, 2.0), Vector3(-6.1, 0.05, 2.8), Color("4d412e"))
	# Every visible bush is now a harvestable, spaced against all other props.
	var rng := RandomNumberGenerator.new()
	rng.seed = 512309
	for i in range(20):
		var site := Vector3(rng.randf_range(-21.0, 21.0), 0, rng.randf_range(-21.0, 21.0))
		if absf(site.x) > 6.0 or absf(site.z) > 6.0:
			spawn_resource(self, "herbs" if i % 4 == 0 else "fiber", site)
	# Deliberate counted timber/stone bundles replace untracked overlapping props.
	spawn_resource(self, "wood", Vector3(-10, 0, 7), 3, true)
	spawn_resource(self, "stone", Vector3(3, 0, 11), 2, true)
	# The camp guide is a stationary NPC, NOT a second player. A unique
	# outfit, hat, and permanent nameplate prevent confusing it with a ghost
	# avatar when returning via Leave Game > Continue.
	var guide = WORLD_OBJECT.new()
	guide.name = "CampGuideNPC"
	add_child(guide)
	guide.position = Vector3(0, 0, 4.5)
	var guide_art := Node3D.new()
	guide_art.name = "GuideOutfit"
	for part_id in ["adventurer_torso", "adventurer_head"]:
		var piece: MeshInstance3D = preload("res://scripts/voxel/voxel_character.gd").create_part(part_id)
		if piece != null:
			if part_id == "adventurer_head":
				piece.position.y = 1.89
			var dye := StandardMaterial3D.new()
			dye.albedo_color = Color("#e7be87") if part_id == "adventurer_head" else Color("#447c55")
			dye.roughness = 1.0
			piece.material_override = dye
			guide_art.add_child(piece)
	var guide_hat := MeshInstance3D.new()
	guide_hat.name = "GuideWideBrimHat"
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.49
	hat_mesh.bottom_radius = 0.49
	hat_mesh.height = 0.16
	guide_hat.mesh = hat_mesh
	guide_hat.position = Vector3(0.0, 2.28, 0.0)
	var hat_material := StandardMaterial3D.new()
	hat_material.albedo_color = Color("#775a36")
	hat_material.roughness = 1.0
	guide_hat.material_override = hat_material
	guide_art.add_child(guide_hat)
	var guide_name := Label3D.new()
	guide_name.name = "NPCNameplate"
	guide_name.text = "OUTPOST GUIDE"
	guide_name.position = Vector3(0.0, 2.65, 0.0)
	guide_name.font_size = 36
	guide_name.pixel_size = 0.006
	guide_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guide_art.add_child(guide_name)
	guide.setup(self, "camp_guide", "Outpost guide", "npc", guide_art)
	guide.message = "Gather fibre, craft a Shrimp net at the Workbench, then fish coastal pools. Cook shrimp at the Campfire."
	prop_placement.reserve(guide.position, 0.6, guide)
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
	if id in ["oak_tree", "rock_deposit"]:
		spawn_resource(self, "wood" if id == "oak_tree" else "stone", where, 1, true)
		return
	# Nearby crafting benches reserve their work areas. Move supply crates
	# to valid nearby ground rather than silently removing every blocked chest.
	var site: Vector3 = where
	if not prop_placement.available(site, 0.8):
		var found: bool = false
		for i in range(1, 49):
			var search_angle: float = float(i) * 2.39996
			var radius: float = 1.6 + float(i / 8)
			var candidate: Vector3 = where + Vector3(cos(search_angle) * radius, 0, sin(search_angle) * radius)
			if absf(candidate.x) <= 21.0 and absf(candidate.z) <= 21.0 and prop_placement.available(candidate, 0.8):
				site = candidate
				found = true
				break
		if not found:
			push_warning("Unable to place camp supply chest near " + str(where))
			return
	if terrain_surface != null:
		site.y = terrain_surface._tile_height(floori(site.x), floori(site.z)) + 0.055
	var chest = WORLD_OBJECT.new()
	add_child(chest)
	chest.position = site
	var art: MeshInstance3D = VOXEL_PROPS.crate()
	art.scale = Vector3.ONE * size_factor
	art.rotation.y = angle
	chest.setup(self, "camp_crate_%s_%s" % [where.x, where.z], "Supply chest", "chest", art, {"wood": 2, "fiber": 2})
	prop_placement.reserve(site, 0.8, chest)

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
		spawn_resource(self, "wood", pos, 1, true)
	for pos in [Vector3(-6, 0, 7), Vector3(6, 0, 7), Vector3(11, 0, -7), Vector3(-13, 0, -9), Vector3(15, 0, 14)]:
		spawn_resource(self, "stone", pos, 1, true)
	for pos in [Vector3(-4, 0, -9), Vector3(3, 0, -12), Vector3(12, 0, 9), Vector3(-15, 0, 4)]:
		spawn_resource(self, "fiber", pos, 1, true)
	for pos in [Vector3(-10, 0, 3), Vector3(8, 0, -3), Vector3(-17, 0, 16)]:
		spawn_resource(self, "berries", pos, 1, true)
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
			spawn_resource(self, str(item_id), pos, 1, true)


func _enemies() -> void:
	# Original voxel boar spawns are untouched. Quaternius pigs and wolves
	# are separate animated creatures; a pig is not a boar replacement.
	for pos in [Vector3(10, 0.2, 11), Vector3(-14, 0.2, -10), Vector3(16, 0.2, -13)]:
		var boar = ENEMY.new()
		add_child(boar)
		boar.setup(self, hero, pos)
	for pos in [Vector3(6, 0.2, -9), Vector3(-7, 0.2, 13)]:
		var pig = WILDLIFE.new()
		add_child(pig)
		pig.setup(self, hero, pos, "pig")
	for pos in [Vector3(15, 0.2, 7), Vector3(-17, 0.2, -5)]:
		var wolf = WILDLIFE.new()
		add_child(wolf)
		wolf.setup(self, hero, pos, "wolf")

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
	if enemy.is_in_group("wild_wolves"):
		return "Wolf"
	if enemy.is_in_group("wild_pigs"):
		return "Pig"
	return enemy.name.replace("_", " ").capitalize()

## Fixed screen-space target frame: recent attack takes priority, then an
## explicit focus, then the closest living creature within radar distance.
## Never display another dungeon floor or an already dead/unloaded target.
func remember_attacked_enemy(target: Node3D) -> void:
	if target_available(target) and target.is_in_group("enemies"):
		recent_attack_target = target
		recent_target_seconds = 6.0

func target_for_hud() -> Node3D:
	if hero == null:
		return null
	if recent_target_seconds > 0.0 and is_instance_valid(recent_attack_target) and target_available(recent_attack_target):
		if hero.global_position.distance_to(recent_attack_target.global_position) <= 24.0:
			return recent_attack_target
	if valid_focus() and hero.global_position.distance_to(focus_target.global_position) <= 24.0:
		return focus_target
	var nearest: Node3D
	var closest: float = TARGET_HUD_NEARBY_RADIUS
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var creature: Node3D = candidate as Node3D
		if not target_available(creature):
			continue
		var offset: Vector3 = creature.global_position - hero.global_position
		if absf(offset.y) > 3.3:
			continue
		var distance: float = offset.length()
		if distance < closest:
			closest = distance
			nearest = creature
	return nearest

func target_frame_data(target: Node3D) -> Dictionary:
	if not target_available(target) or not target.is_in_group("enemies"):
		return {}
	# Test dummies and non-health actors may still carry the enemies group.
	# Only actual numeric combat health may enter the HUD: float(null) errors
	# at runtime on GDScript's Variant constructor path.
	var raw_hp: Variant = target.get("hp")
	if not (raw_hp is float or raw_hp is int):
		return {}
	var hp: float = maxf(0.0, float(raw_hp))
	var raw_max: Variant = target.get("max_hp")
	var maximum: float = maxf(1.0, hp)
	if raw_max is float or raw_max is int:
		maximum = maxf(1.0, float(raw_max))
	var rank: String = ""
	var accent: Color = Color("#907e71")
	var name_color: Color = Color("#f8ecdb")
	var coloured_affixes: Array[Dictionary] = []
	if target.is_in_group("dungeon_guardians"):
		var rarity: int = DUNGEON_RARITY.bounded(int(target.get("quality")))
		# Official dungeon rarity sets the creature portion of the name.
		# Keep the existing gold/silver boss and elite frame accents separate.
		name_color = DUNGEON_RARITY.color(rarity)
		if rarity in [DUNGEON_RARITY.RARE, DUNGEON_RARITY.EPIC]:
			name_color = name_color.lightened(0.22) # Readable against dark backing.
		if target.name == "DungeonBoss":
			rank = "BOSS"
			accent = Color("#e3ae63")
		elif rarity >= 3:
			rank = "ELITE"
			accent = Color("#d9ad57")
		elif rarity >= 2:
			rank = "RARE"
			accent = Color("#b5c5d4")
		elif rarity == 1:
			rank = "UNCOMMON"
			accent = Color("#9bba9e")
		var original_affixes: Variant = target.get("affix_entries")
		if original_affixes is Array:
			for raw in original_affixes:
				if not (raw is Dictionary):
					continue
				var label: String = str(raw.get("name", "")).strip_edges()
				var tint: Variant = raw.get("colour", name_color)
				if not label.is_empty() and tint is Color:
					coloured_affixes.append({"text": label, "color": tint})
	return {"id": target.get_instance_id(), "name": enemy_display_name(target),
		"hp": hp, "max_hp": maximum, "rank": rank, "accent": accent,
		"name_color": name_color, "affixes": coloured_affixes}

func _nearest_breakable():
	if hero == null:
		return null
	var nearest: Node3D
	var radius: float = 3.1
	for prop in get_tree().get_nodes_in_group("dungeon_breakables"):
		if not is_instance_valid(prop) or not prop.active:
			continue
		var distance: float = hero.global_position.distance_to(prop.global_position)
		if distance < radius:
			radius = distance
			nearest = prop
	return nearest

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

func valid_focus() -> bool:
	if not is_instance_valid(focus_target) or not target_available(focus_target) or hero.global_position.distance_to(focus_target.global_position) > 32.0:
		focus_target = null
		return false
	return true

func focus_nearest_enemy() -> void:
	var nearest: Node3D
	var distance: float = 24.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not target_available(enemy):
			continue
		var delta: float = hero.global_position.distance_to(enemy.global_position)
		if delta < distance:
			distance = delta
			nearest = enemy
	focus_target = nearest
	recent_target_seconds = 0.0
	if nearest == null:
		hud.toast("No enemy nearby to focus.")

func perform_action(action: String) -> void:
	match action:
		"ability_1", "ability_2", "ability_3": use_weapon_skill(int(action.right(1)) - 1)
		"potion": use_quick_consumable("potion")
		"food": use_quick_consumable("consumable")
		"tool_cycle": hud._cycle_quick_tool()
		"bag": show_inventory()
		"character": show_equipment()
		"skills": hud._show_skill_details()
		"focus": focus_nearest_enemy()
		"interact": smart_interact()

func target_available(target: Node3D) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or not target.is_visible_in_tree():
		return false
	if target.is_in_group("resources"):
		return target.active
	if target.is_in_group("enemies"):
		return target.alive
	return target.has_meta("world_kind") or target.is_in_group("stations")

func target_range(target: Node3D) -> float:
	if target.is_in_group("enemies"):
		return 3.4
	if target.is_in_group("resources"):
		return 3.3
	if target.is_in_group("stations"):
		return 3.0
	return 2.8

func target_in_range(target: Node3D) -> bool:
	if not target_available(target) or hero == null:
		return false
	return hero.global_position.distance_to(target.global_position) < target_range(target)

func target_on_cooldown(target: Node3D) -> bool:
	return (target.is_in_group("enemies") and attack_delay > 0.0) or (target.is_in_group("resources") and gather_delay > 0.0)

func interact_target(target: Node3D) -> void:
	if not target_in_range(target) or (menu != null and menu.visible):
		return
	if target.is_in_group("enemies"):
		focus_target = target
		attack(target)
	elif target.is_in_group("resources"):
		gather(target)
	elif target.is_in_group("stations"):
		if near_station(target.station_id):
			show_crafting()
	elif target.has_method("interact"):
		target.interact(hero)
	elif target.has_meta("dungeon_bonus"):
		var dungeon = get_node_or_null("Dungeons")
		if dungeon != null:
			dungeon._claim_bonus(int(target.get_meta("dungeon_bonus")))
	elif target.has_meta("dungeon_exit"):
		var dungeon = get_node_or_null("Dungeons")
		if dungeon != null:
			dungeon._on_chest_selected(target.get_meta("dungeon_exit"))
	elif target.has_signal("selected"):
		target.selected.emit(target)

static func healing_for(item: String) -> float:
	return 65.0 if item == "tonic" else 75.0 if item == "stew" else 30.0 if item == "cooked_shrimp" else 40.0

func spawn_resource(parent: Node3D, kind: String, point: Vector3, count: int = 1, relocate: bool = false):
	var radius: float = PLACEMENT.radius_for(kind, count)
	var site: Vector3 = point
	if not prop_placement.available(site, radius):
		if not relocate:
			return null
		var found: bool = false
		for i in range(1, 49):
			var angle: float = float(i) * 2.39996
			var offset := Vector3(cos(angle), 0, sin(angle)) * (2.0 + float(i / 8))
			site = point + offset
			if prop_placement.available(site, radius):
				found = true
				break
		if not found:
			return null
	if terrain_surface != null:
		site.y = -2.78 if kind == "shrimp" else terrain_surface._tile_height(floori(site.x), floori(site.z)) + 0.055
	var resource = NODE.new()
	parent.add_child(resource)
	resource.global_position = site
	resource.setup(kind, count)
	prop_placement.reserve(site, radius, resource)
	return resource

func gather(selected: Node3D = null) -> void:
	if gather_delay > 0.0 or (menu != null and menu.visible):
		return
	var resource = selected if selected != null else _nearest_resource()
	if not target_available(resource) or not target_in_range(resource):
		return
	var expected_item: String = str(resource.kind)
	var tool: String = "axe" if expected_item == "wood" else "pickaxe" if expected_item in ["stone", "iron", "coal"] else "shrimp_net" if expected_item == "shrimp" else "satchel"
	if selected != null and int(inventory.get(tool, 0)) > 0 and not is_equipped(tool):
		equip_item(tool)
	if expected_item == "shrimp" and (str(equipment.get("tool_fishing", "")) != "shrimp_net" or int(inventory.get("shrimp_net", 0)) < 1):
		hud.toast("Craft a Shrimp net from 6 fibre at the Workbench first.")
		return
	if tool in ["axe", "pickaxe", "shrimp_net"] and is_equipped(tool):
		hero.set_held_tool(tool)
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
	gather_delay = 1.0 if expected_item == "shrimp" else 0.33
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
	if item_id == "shrimp_net":
		return "tool_fishing"
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
	if int(inventory.get("shrimp_net", 0)) > 0:
		candidates.append("shrimp_net")
	return candidates

func select_quick_tool(item_id: String) -> bool:
	if item_id not in QUICK_TOOL_IDS and item_id != "shrimp_net":
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
	if valid_focus():
		return {"kind": "attack", "label": "ATTACK", "icon": "sword"}
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
	if _nearest_breakable() != null:
		return {"kind": "break", "label": "SMASH", "icon": "sword"}
	if active_quick_tool == "torch" and int(inventory.get("torch", 0)) > 0:
		return {"kind": "torch", "label": "TORCH", "icon": "hand"}
	return {"kind": "none", "label": "INTERACT", "icon": "hand"}

func smart_interact() -> void:
	if menu != null and menu.visible:
		return
	if valid_focus():
		if target_in_range(focus_target):
			attack(focus_target)
		elif controls != null:
			controls.approach(focus_target)
		return
	var action: String = str(smart_context().get("kind", "none"))
	match action:
		"attack":
			attack()
		"gather":
			gather()
		"break":
			var prop = _nearest_breakable()
			if prop != null:
				prop.interact(hero)
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
			hud.record_loot("copper" if item_id == "coins" else item_id, fitting)
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

func can_discard_item(item_id: String) -> bool:
	# The starter weapon and wallet are not bag stacks. Equipped items must
	# be unequipped before a player can destroy them deliberately.
	return item_id != "" and item_id not in ["training_blade", "coins", "copper", "silver", "gold", "gems"] and int(inventory.get(item_id, 0)) > 0 and not is_equipped(item_id)

func discard_item(item_id: String, amount: int) -> bool:
	if amount <= 0 or not can_discard_item(item_id):
		return false
	var count: int = mini(amount, int(inventory.get(item_id, 0)))
	inventory[item_id] = int(inventory.get(item_id, 0)) - count
	if int(inventory[item_id]) <= 0:
		best_craft_rolls.erase(item_id)
		weapon_enchants.erase(item_id)
		bag_quality.erase(item_id)
		for slot in quick_slots:
			if str(quick_slots[slot]) == item_id:
				quick_slots[slot] = ""
		if active_quick_tool == item_id:
			active_quick_tool = "training_blade"
	_save()
	_refresh_menu()
	if hud != null:
		hud.toast("Destroyed %d × %s." % [count, item_id.replace("_", " ").capitalize()])
	return true

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
	if (not new_bag or not already_owned) and not (QUALITY.is_gear(result_id) and already_owned):
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
	if owns_unique(result) and not QUALITY.is_gear(result):
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
	var removing: bool = is_equipped(item_id)
	if removing:
		equipment[slot] = "training_blade" if slot == "weapon" else ""
	else:
		equipment[slot] = item_id
	# Equipping an axe/pickaxe from Gear should actually put it in the hand.
	# Removing it should put away the model, without deleting inventory.
	if item_id in ["axe", "pickaxe"]:
		if removing and active_quick_tool == item_id:
			active_quick_tool = str(equipment.get("weapon", "training_blade"))
		elif not removing:
			active_quick_tool = item_id
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
		"duration": maxf(1.4, float(recipe.get("seconds", 2.0)))
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
	# Compatibility with legacy station actions; no repeated tapping required.
	return false

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
	var first_craft: bool = int(inventory.get(result, 0)) == 0
	last_craft_roll.clear()
	last_craft_improved = false
	if QUALITY.is_gear(result):
		# Reforging is an RNG attempt, not an extra inventory duplicate.
		# A failed upgrade never replaces the player's strongest existing roll.
		last_craft_roll = QUALITY.roll_item(result)
		last_craft_improved = QUALITY.is_upgrade(last_craft_roll, best_craft_rolls.get(result, {}))
		if last_craft_improved:
			best_craft_rolls[result] = last_craft_roll.duplicate(true)
		inventory[result] = maxi(1, int(inventory.get(result, 0)))
	elif is_bag:
		if first_craft:
			inventory[result] = 1
		bag_quality[result] = mini(3, int(bag_quality.get(result, 0)) + 1)
	else:
		inventory[result] = int(inventory.get(result, 0)) + maxi(1, int(recipe.get("amount", 1)))
	if hud != null and not result.is_empty() and (not QUALITY.is_gear(result) or first_craft):
		hud.record_loot(result, 1 if is_bag or QUALITY.is_gear(result) else maxi(1, int(recipe.get("amount", 1))))
	if result == "spear":
		spear_crafted = true
	# Newly crafted equipment is immediately equipped, but can be swapped/removed.
	var slot: String = equipment_slot(result)
	if slot != "":
		equipment[slot] = result
		_apply_equipment()
	gain_experience(8)
	if hud != null:
		if QUALITY.is_gear(result):
			var rank_name: String = QUALITY.rarity_name(int(last_craft_roll.get("rarity", 0)))
			var feedback: String = "%s %s • +8 XP" % [rank_name, str(recipe.get("name", result))]
			if not last_craft_improved:
				feedback += " • best roll retained"
			hud.toast(feedback)
		else:
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
	var skill: String = "fishing" if resource_id == "shrimp" else "woodcutting" if resource_id == "wood" else "mining" if resource_id in ["stone", "iron", "coal", "clay"] else "foraging"
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

## Armour Break is a real timed vulnerability status, not just a renamed hit.
## Keep it per-enemy in metadata so it works for boars and dungeon guardians,
## disappears after six seconds and does not migrate or affect co-op authority.
func _armor_break_damage_multiplier(target: Node3D) -> float:
	if not is_instance_valid(target):
		return 1.0
	return 1.0 + LEVELS.ARMOR_BREAK_BONUS if float(target.get_meta("outpost_armor_break_until", -1.0)) > world_time else 1.0

func _whirlwind_targets() -> Array[Node3D]:
	var hits: Array[Node3D] = []
	if hero == null:
		return hits
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var target: Node3D = candidate as Node3D
		if not target_available(target):
			continue
		var difference: Vector3 = target.global_position - hero.global_position
		if absf(difference.y) > 2.3:
			continue
		if Vector2(difference.x, difference.z).length() > LEVELS.WHIRLWIND_RADIUS:
			continue
		hits.append(target)
		# One physical hit per enemy per cast; cap the fan-out for mobile.
		if hits.size() >= 12:
			break
	return hits

## Hit anything currently inside the AoE on EACH swing, not a cached list
## from the first frame. New entrants can be hit on subsequent passes.
func _apply_whirlwind_tick() -> void:
	if whirlwind_ticks_done >= WHIRLWIND_TICK_TIMES.size() or hero == null:
		return
	for enemy in _whirlwind_targets():
		if not is_instance_valid(enemy):
			continue
		var hit_point: Vector3 = enemy.global_position
		remember_attacked_enemy(enemy)
		enemy.receive_damage(whirlwind_tick_damage * _armor_break_damage_multiplier(enemy))
		apply_crafted_lifesteal()
		hero.show_weapon_hit_effect(hit_point)
		if str(weapon_enchants.get(whirlwind_tick_weapon, "")) == "fire" and enemy.has_method("ignite"):
			enemy.ignite(4.0)
		whirlwind_unique_hits[enemy.get_instance_id()] = true
	whirlwind_ticks_done += 1
	if whirlwind_ticks_done >= WHIRLWIND_TICK_TIMES.size():
		if not whirlwind_unique_hits.is_empty():
			var victims: int = whirlwind_unique_hits.size()
			gain_weapon_mastery(whirlwind_tick_weapon, 12 + 5 * mini(victims, 5))
			gain_experience(3 + mini(victims, 4))
		whirlwind_tick_clock = -1.0
		whirlwind_tick_weapon = ""
		whirlwind_unique_hits.clear()

func _advance_whirlwind_ticks(delta: float) -> void:
	if whirlwind_tick_clock < 0.0 or whirlwind_ticks_done >= WHIRLWIND_TICK_TIMES.size():
		return
	if hero == null or not is_instance_valid(hero) or hero.health <= 0.0:
		whirlwind_tick_clock = -1.0
		whirlwind_ticks_done = WHIRLWIND_TICK_TIMES.size()
		whirlwind_unique_hits.clear()
		return
	whirlwind_tick_clock += maxf(0.0, delta)
	while whirlwind_ticks_done < WHIRLWIND_TICK_TIMES.size() and whirlwind_tick_clock >= WHIRLWIND_TICK_TIMES[whirlwind_ticks_done]:
		_apply_whirlwind_tick()

func crafting_bonus(stat: String) -> float:
	var total: float = 0.0
	var seen: Dictionary = {}
	for slot in equipment:
		var equipped: String = str(equipment[slot])
		if equipped.is_empty() or seen.has(equipped):
			continue
		seen[equipped] = true
		var roll: Dictionary = best_craft_rolls.get(equipped, {})
		var boosts: Dictionary = roll.get("bonuses", {})
		total += float(boosts.get(stat, 0))
	return total

func has_crafting_affix(affix: String) -> bool:
	for equipped in equipment.values():
		var roll: Dictionary = best_craft_rolls.get(str(equipped), {})
		if str(roll.get("affix", "")) == affix:
			return true
	return false

func crafted_damage(base: float) -> float:
	var result: float = base + crafting_bonus("damage")
	if has_crafting_affix("Brutal"):
		result *= 1.08
	if has_crafting_affix("Titanic"):
		result *= 1.12
	if randf() * 100.0 < minf(40.0, crafting_bonus("crit_chance")):
		result *= 1.5
	return result

func crafted_attack_delay(base: float) -> float:
	var speed: float = crafting_bonus("attack_speed")
	if has_crafting_affix("Swift"):
		speed += 6.0
	if has_crafting_affix("Titanic"):
		speed -= 8.0
	return base / maxf(0.65, 1.0 + speed * 0.01)

func apply_crafted_lifesteal() -> void:
	if hero != null and has_crafting_affix("Vampiric"):
		hero.health = minf(100.0, hero.health + 2.0)

func use_weapon_skill(slot: int) -> bool:
	if slot < 0 or slot >= unlocked_skill_slots() or hero == null or (menu != null and menu.visible):
		return false
	# LAN dungeon combat remains host-authoritative; never apply local
	# ability damage that could desynchronise an encounter.
	if coop != null and coop.in_party_dungeon():
		if hud != null:
			hud.toast("Skills in co-op dungeons require host combat support.")
		return false
	var skill: String = LEVELS.skill_for_slot(slot)
	if skill == "" or float(skill_cooldowns.get(skill, 0.0)) > 0.0 or attack_delay > 0.0:
		return false
	var target: Node3D = focus_target if valid_focus() else _nearest_enemy()
	if skill != "whirlwind" and (target == null or not target_in_range(target)):
		return false
	var mana_cost: float = 6.0 + 3.0 * float(slot)
	if mana < mana_cost:
		if hud != null:
			hud.toast("Need %d MP for this ability." % int(mana_cost))
		return false
	var weapon: String = current_weapon_id()
	var base: float = 24.0 if weapon == "iron_blade" else 16.0 if weapon == "spear" else 8.0
	var dealt: float = crafted_damage(base) * LEVELS.multiplier_for_skill(skill)
	mana = maxf(0.0, mana - mana_cost)
	skill_cooldowns[skill] = LEVELS.cooldown_for_skill(skill)
	attack_delay = LEVELS.WHIRLWIND_DURATION if skill == "whirlwind" else crafted_attack_delay(0.55)
	if skill == "whirlwind":
		# A first hit on cast, then the second and third hits at 0.30s and
		# 0.60s. Every tick checks live positions and creates sword-tip sparks.
		if active_quick_tool != weapon:
			select_quick_tool(weapon)
		hero.play_whirlwind()
		whirlwind_tick_clock = 0.0
		whirlwind_ticks_done = 0
		whirlwind_tick_weapon = weapon
		whirlwind_tick_damage = dealt * 0.40
		whirlwind_unique_hits.clear()
		_apply_whirlwind_tick()
	else:
		hero.swing()
		remember_attacked_enemy(target)
		target.receive_damage(dealt * _armor_break_damage_multiplier(target))
		apply_crafted_lifesteal()
		hero.show_weapon_hit_effect(target.global_position)
		if skill == "armor_break" and target_available(target):
			# A real follow-up damage increase for six seconds. Applying it
			# AFTER this impact prevents double-dipping on the opening hit.
			target.set_meta("outpost_armor_break_until", world_time + LEVELS.ARMOR_BREAK_SECONDS)
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
		pool.append_array(FOOD_IDS)
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
	if item == "" and slot == "potion" and int(inventory.get("tonic", 0)) > 0:
		item = "tonic"
		quick_slots[slot] = item
	if item == "" or int(inventory.get(item, 0)) <= 0:
		hud.toast("No healing potion available." if slot == "potion" else "No food equipped. Assign food from Inventory.")
		return false
	if hero == null or hero.health >= 99.9:
		return false
	var amount: float = healing_for(item)
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
	hero.health = minf(100.0, hero.health + heal + crafting_bonus("ability_power"))
	hud.toast("Used %s: +%d health" % [item_id.capitalize(), int(heal)])
	_save()
	_refresh_menu()

func use_meal() -> void:
	consume("meal", 40.0)

func attack(selected: Node3D = null) -> void:
	if attack_delay > 0.0 or menu != null and menu.visible:
		return
	var target = selected if selected != null else focus_target if valid_focus() else _nearest_enemy()
	if not target_available(target) or not target_in_range(target):
		return
	remember_attacked_enemy(target)
	if coop != null and coop.in_party_dungeon():
		var guardian = target
		if guardian == null or not guardian.has_meta("encounter_slot"):
			return
		attack_delay = 0.55
		hero.swing()
		coop.request_strike(int(guardian.get_meta("encounter_slot")))
		return
	if target == null:
		return # No popup spam when outside combat range.
	attack_delay = crafted_attack_delay(0.55)
	hero.swing()
	var weapon: String = str(equipment.get("weapon", "training_blade"))
	var base_damage: float = 24.0 if weapon == "iron_blade" else 16.0 if weapon == "spear" else 8.0
	target.receive_damage(crafted_damage(base_damage) * _armor_break_damage_multiplier(target))
	apply_crafted_lifesteal()
	hero.show_weapon_hit_effect(target.global_position)
	if str(weapon_enchants.get(weapon, "")) == "fire" and target.has_method("ignite"):
		target.ignite(4.0)
	gain_weapon_mastery(weapon, 12)
	# World-space damage numbers already come from each mob's hit feedback.
	# No giant per-swing notification is needed, and no boar assumptions.

func on_enemy_killed(kind: String = "boar") -> void:
	kills += 1
	var is_wolf: bool = kind == "wolf"
	var hide: int = 2 if is_wolf else 1
	var coins: int = 5 if is_wolf else 2 if kind == "pig" else 3
	var xp: int = 16 if is_wolf else 8 if kind == "pig" else 12
	var label: String = "Wolf" if is_wolf else "Pig" if kind == "pig" else "Boar"
	grant_item("hide", hide, true)
	grant_item("coins", coins, true)
	gain_experience(xp)
	hud.record_combat_event(label + " defeated")
	hud.toast(label + " defeated! Loot sent to bag or stored if full.")
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
		hud.toast("Party dungeon cleared! +%d copper • +%d XP" % [int(reward.get("coins", 0)), int(reward.get("xp", 0))])
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

func _tombstone_position(at: Vector3) -> Vector3:
	# Snap to ground where available so the grave does not float, while
	# retaining the death location in tunnels and on unusual terrain.
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 8.0, 1 | 2 | 8)
	if hero != null:
		ray.exclude = [hero.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		return Vector3(at.x, float(hit.position.y) + 0.05, at.z)
	return at

func _spawn_tombstone_node(tombstone_id: String) -> void:
	if tombstone_nodes.has(tombstone_id) or not death_tombstones.has(tombstone_id):
		return
	var record: Dictionary = death_tombstones[tombstone_id]
	var coords: Array = record.get("position", [])
	if coords.size() != 3:
		return
	var art := Node3D.new()
	var base := MeshInstance3D.new()
	base.name = "TombstoneBase"
	var plinth := BoxMesh.new()
	plinth.size = Vector3(1.0, 0.22, 0.76)
	base.mesh = plinth
	base.position.y = 0.11
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#555864")
	base.material_override = stone
	art.add_child(base)
	var head := MeshInstance3D.new()
	head.name = "TombstoneHead"
	var slab := BoxMesh.new()
	slab.size = Vector3(0.7, 0.95, 0.22)
	head.mesh = slab
	head.position = Vector3(0, 0.65, -0.09)
	head.material_override = stone
	art.add_child(head)
	var grave = WORLD_OBJECT.new()
	grave.name = "DeathTombstone_" + tombstone_id
	add_child(grave)
	grave.global_position = Vector3(float(coords[0]), float(coords[1]), float(coords[2]))
	grave.setup(self, tombstone_id, "Your Tombstone", "tombstone", art, record.get("contents", {}))
	tombstone_nodes[tombstone_id] = grave

func on_player_defeated(at: Vector3) -> void:
	# Transfer once, before teleporting. No starter weapon is an inventory
	# item. Currency and all carried equipment/resources are included.
	var carried: Dictionary = {}
	for raw_id in inventory:
		var item_id: String = str(raw_id)
		var amount: int = int(inventory.get(item_id, 0))
		if amount > 0:
			carried[item_id] = amount
			inventory[item_id] = 0
	for slot in equipment:
		equipment[slot] = "training_blade" if slot == "weapon" else ""
	active_quick_tool = "training_blade"
	for slot in quick_slots:
		quick_slots[slot] = ""
	if not carried.is_empty():
		var site: Vector3 = _tombstone_position(at)
		var tombstone_id: String = "grave_%d" % next_tombstone_id
		next_tombstone_id += 1
		death_tombstones[tombstone_id] = {
			"position": [site.x, site.y, site.z],
			"contents": carried,
			"bag_quality": bag_quality.duplicate(true),
			"best_craft_rolls": best_craft_rolls.duplicate(true),
			"weapon_enchants": weapon_enchants.duplicate(true)
		}
		bag_quality.clear()
		best_craft_rolls.clear()
		weapon_enchants.clear()
		_spawn_tombstone_node(tombstone_id)
	_apply_equipment()
	_save()
	if hud != null:
		hud.toast("Defeated! Your items are in a tombstone near where you fell." if not carried.is_empty() else "Defeated! Respawned at Outpost.")

func tombstone_contents(tombstone_id: String) -> Dictionary:
	if not death_tombstones.has(tombstone_id):
		return {}
	return (death_tombstones[tombstone_id].get("contents", {}) as Dictionary).duplicate(true)

func open_tombstone(tombstone_id: String) -> void:
	if menu == null or not death_tombstones.has(tombstone_id):
		return
	menu.open_storage("YOUR TOMBSTONE  •  RECOVER", tombstone_contents(tombstone_id), tombstone_id)

func take_tombstone_item(tombstone_id: String, item_id: String) -> int:
	if not death_tombstones.has(tombstone_id):
		return 0
	var record: Dictionary = death_tombstones[tombstone_id]
	var contents: Dictionary = record.get("contents", {})
	var available: int = maxi(0, int(contents.get(item_id, 0)))
	if available <= 0:
		return 0
	var already_owned: bool = int(inventory.get(item_id, 0)) > 0
	var taken: int = grant_item(item_id, available)
	if taken <= 0:
		return 0
	var left: int = available - taken
	if left > 0:
		contents[item_id] = left
	else:
		contents.erase(item_id)
		if not already_owned:
			for field in ["bag_quality", "best_craft_rolls", "weapon_enchants"]:
				var archived: Dictionary = record.get(field, {})
				if archived.has(item_id):
					match field:
						"bag_quality":
							bag_quality[item_id] = archived[item_id]
						"best_craft_rolls":
							best_craft_rolls[item_id] = archived[item_id]
						"weapon_enchants":
							weapon_enchants[item_id] = archived[item_id]
	if contents.is_empty():
		death_tombstones.erase(tombstone_id)
		if tombstone_nodes.has(tombstone_id):
			var grave: Node = tombstone_nodes[tombstone_id]
			tombstone_nodes.erase(tombstone_id)
			if is_instance_valid(grave):
				grave.queue_free()
	else:
		record["contents"] = contents
		death_tombstones[tombstone_id] = record
	_save()
	if hud != null:
		hud.toast("Recovered %d × %s." % [taken, item_id.replace("_", " ").capitalize()])
	return taken

func save_and_return_to_title() -> void:
	# Single exit path for solo and LAN. Dismantle active sessions before saving
	# so the next title visit starts offline and no ghost avatars remain.
	if coop != null:
		coop.disconnect_session()
	_save()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func _save() -> void:
	var data: Dictionary = {"version": 5, "equipment": equipment, "inventory": inventory, "experience": experience, "kills": kills, "spear": spear_crafted, "day_phase": day_night.phase if day_night != null else 0.38, "night_quote_seen": night_quote_seen, "coop_reward_receipts": coop_reward_receipts, "active_quick_tool": active_quick_tool, "bag_quality": bag_quality, "best_craft_rolls": best_craft_rolls, "overflow_loot": overflow_loot, "weapon_mastery_xp": weapon_mastery_xp, "gathering_skill_xp": gathering_skill_xp, "mana": mana, "last_trained_skill": last_trained_skill, "weapon_enchants": weapon_enchants, "quick_slots": quick_slots, "opened_world_objects": opened_world_objects, "death_tombstones": death_tombstones, "next_tombstone_id": next_tombstone_id}
	var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if map_service != null:
		data["map_state"] = map_service.export_state()
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()
		if map_service != null:
			map_service.dirty = false

func _load() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (data is Dictionary):
		return
	var version: int = int(data.get("version", 0))
	if version not in [2, 3, 4, 5]:
		return
	if map_service != null:
		map_service.import_state(data.get("map_state", {}))
	if data.get("opened_world_objects", {}) is Dictionary:
		opened_world_objects = data["opened_world_objects"].duplicate(true)
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
			quick_slots[slot] = chosen if chosen in (["tonic"] if slot == "potion" else FOOD_IDS) else ""
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
	if data.get("best_craft_rolls", {}) is Dictionary:
		for raw_id in data["best_craft_rolls"]:
			var item_id: String = str(raw_id)
			if QUALITY.is_gear(item_id) and int(inventory.get(item_id, 0)) > 0:
				var clean_roll: Dictionary = QUALITY.sanitise_roll(data["best_craft_rolls"][raw_id])
				if not clean_roll.is_empty():
					best_craft_rolls[item_id] = clean_roll
	active_quick_tool = str(data.get("active_quick_tool", "training_blade"))
	if (active_quick_tool not in QUICK_TOOL_IDS and active_quick_tool != "shrimp_net") or (active_quick_tool != "training_blade" and int(inventory.get(active_quick_tool, 0)) < 1):
		active_quick_tool = "training_blade"
	experience = maxi(0, int(data.get("experience", 0)))
	kills = maxi(0, int(data.get("kills", 0)))
	spear_crafted = bool(data.get("spear", false)) or int(inventory.get("spear", 0)) > 0
	# A past quest completion must not silently recreate a spear discarded
	# by the player or left behind in a tombstone on loading a save.
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
	next_tombstone_id = maxi(1, int(data.get("next_tombstone_id", 1)))
	if data.get("death_tombstones", {}) is Dictionary:
		for raw_id in data["death_tombstones"]:
			var id: String = str(raw_id)
			var record: Variant = data["death_tombstones"][raw_id]
			if id.length() > 64 or not record is Dictionary:
				continue
			var contents: Variant = record.get("contents", {})
			var pos: Variant = record.get("position", [])
			if not contents is Dictionary or not pos is Array or pos.size() != 3:
				continue
			var clean_contents: Dictionary = {}
			for key in contents:
				var key_id: String = str(key)
				if not key_id.is_empty() and key_id.length() <= 64 and int(contents[key]) > 0:
					clean_contents[key_id] = maxi(0, int(contents[key]))
			if clean_contents.is_empty():
				continue
			var clean_record: Dictionary = {
				"position": pos.duplicate(),
				"contents": clean_contents,
				"bag_quality": record.get("bag_quality", {}),
				"best_craft_rolls": record.get("best_craft_rolls", {}),
				"weapon_enchants": record.get("weapon_enchants", {})
			}
			death_tombstones[id] = clean_record
			_spawn_tombstone_node(id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()
