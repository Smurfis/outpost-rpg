extends Node3D
## Outpost dungeons: five graph patterns, real KayKit CC0 architecture, multiple floors.
signal chest_selected(instance: Node3D)
signal stairs_selected(instance: Node3D)
signal bonus_selected(instance: Node3D, bonus_id: int)
signal prop_broken(instance: Node3D, prop_id: String, reward: Dictionary)
signal completed(instance: Node3D, reward: Dictionary)
signal floor_changed(instance: Node3D, current_floor: int, total_floors: int)

const RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
const GUARDIAN = preload("res://scripts/dungeons/dungeon_guardian.gd")
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
const LOOT = preload("res://scripts/dungeons/dungeon_loot.gd")
const ROOM_DECOR = preload("res://scripts/dungeons/dungeon_room_decor.gd")
const BREAKABLE = preload("res://scripts/dungeons/dungeon_breakable.gd")
const AFFIXES = preload("res://scripts/dungeons/dungeon_affixes.gd")
const ASSET_ROOT = "res://assets/third_party/kaykit_dungeon/"
# Bring paired doorframes closer together while keeping the seeded room graph
# and chest/guardian locations deterministic per entrance.
const STEP: float = 13.0
const HALF: float = 6.0
const ROOM_SIZE: float = 12.0
const CONNECTOR_LENGTH: float = 4.6
const CONNECTOR_WIDTH: float = 6.6
const CONNECTOR_WALL_OFFSET: float = 3.02
const NORTH: Vector2i = Vector2i(0, -1)
const SOUTH: Vector2i = Vector2i(0, 1)
const WEST: Vector2i = Vector2i(-1, 0)
const EAST: Vector2i = Vector2i(1, 0)
const DIRECTIONS: Array[Vector2i] = [NORTH, EAST, SOUTH, WEST]

var entrance_id: String = ""
var quality: int = 0
var hero: CharacterBody3D
var guards_remaining: int = 0
var claimed: bool = false
var chest_area: Area3D
var chest_label: Label3D
var chest_material: StandardMaterial3D
var floor_root: Node3D
var layout: Dictionary = {}
var floor_count: int = 1
var current_floor: int = 1
var exit_local: Vector3 = Vector3.ZERO
var spawn_local: Vector3 = Vector3.ZERO
var bonus_chests: Dictionary = {}
var claimed_bonuses: Dictionary = {}
var claimed_props: Dictionary = {}
var mesh_cache: Dictionary = {}
var material_cache: Dictionary = {}
var boss_alive: bool = false

func setup(id: String, tier: int, player: CharacterBody3D, first_floor: int = 1, already_broken: Array = []) -> void:
	entrance_id = id
	quality = RARITY.bounded(tier)
	hero = player
	floor_count = int(LAYOUT.profile(id, quality).get("floors", 1))
	current_floor = clampi(first_floor, 1, floor_count)
	name = "DungeonInstance_" + id.replace(":", "_")
	for prop_key in already_broken:
		claimed_props[str(prop_key)] = true
	_build_floor()

func hero_spawn_point() -> Vector3:
	return to_global(spawn_local)

func chest_world_position() -> Vector3:
	return to_global(exit_local)

func can_claim_chest() -> bool:
	return current_floor == floor_count and not claimed and guards_remaining == 0

func can_advance_floor() -> bool:
	return current_floor < floor_count and guards_remaining == 0 and not claimed

func guardian_defeated() -> void:
	guards_remaining = maxi(0, guards_remaining - 1)
	if guards_remaining == 0 and chest_label != null:
		chest_label.text = "FINAL TREASURE UNLOCKED" if current_floor == floor_count else "STAIRS UNLOCKED"
		if chest_material != null:
			chest_material.emission_enabled = true
			chest_material.emission = RARITY.color(quality)
			chest_material.emission_energy_multiplier = 1.9

func advance_floor() -> bool:
	if not can_advance_floor() or hero == null:
		return false
	if _distance_xz(hero.global_position, chest_world_position()) > 3.4:
		return false
	current_floor += 1
	claimed = false
	_build_floor()
	hero.global_position = hero_spawn_point()
	hero.velocity = Vector3.ZERO
	floor_changed.emit(self, current_floor, floor_count)
	return true

func claim_chest() -> bool:
	if not can_claim_chest() or hero == null:
		return false
	if _distance_xz(hero.global_position, chest_world_position()) > 3.4:
		return false
	claimed = true
	var reward: Dictionary = LOOT.chest(entrance_id, quality, current_floor - 1, floor_count, false)
	completed.emit(self, reward)
	return true

func nearest_bonus(player_at: Vector3, radius: float = 3.25) -> int:
	var selected: int = -1
	var distance: float = radius
	for key in bonus_chests:
		var id: int = int(key)
		if claimed_bonuses.has(id):
			continue
		var at: Vector3 = bonus_chests[key]
		var d: float = _distance_xz(player_at, to_global(at))
		if d < distance:
			distance = d
			selected = id
	return selected

func claim_bonus(id: int) -> Dictionary:
	if claimed_bonuses.has(id) or not bonus_chests.has(id) or hero == null:
		return {}
	if _distance_xz(hero.global_position, to_global(bonus_chests[id])) > 3.4:
		return {}
	claimed_bonuses[id] = true
	var node: Node = floor_root.get_node_or_null("Bonus_%d" % id)
	if node != null:
		node.queue_free()
	return LOOT.chest(entrance_id + ":bonus:" + str(id), quality, current_floor - 1, floor_count, true)

func _build_floor() -> void:
	if floor_root != null:
		remove_child(floor_root)
		floor_root.queue_free()
	floor_root = Node3D.new()
	floor_root.name = "Floor_%d" % current_floor
	add_child(floor_root)
	layout = LAYOUT.generate(entrance_id, quality, current_floor - 1)
	claimed_bonuses.clear()
	bonus_chests.clear()
	var rooms: Array = layout["rooms"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(layout["seed"])
	for room in rooms:
		_build_room(room, rooms, rng)
	for edge in layout["edges"]:
		var first: Vector2i = rooms[edge.x]["grid"]
		var second: Vector2i = rooms[edge.y]["grid"]
		_build_connector(first, second)
	spawn_local = _room_center(rooms[int(layout["start"])]) + Vector3(0, 0.35, 0)
	exit_local = _room_center(rooms[int(layout["exit"])])
	_make_chest()
	for room_id in layout["bonuses"]:
		_make_bonus(int(room_id), _room_center(rooms[int(room_id)]))
	_spawn_guards(rooms, rng)
	var heading := Label3D.new()
	heading.text = "%s  |  %s  |  FLOOR %d/%d" % [RARITY.quality_name(quality).to_upper(), str(layout["pattern"]).to_upper(), current_floor, floor_count]
	heading.modulate = RARITY.color(quality)
	heading.font_size = 44
	heading.pixel_size = 0.007
	heading.outline_size = 12
	heading.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heading.position = spawn_local + Vector3(0, 2.5, -2.0)
	floor_root.add_child(heading)

func _room_center(room: Dictionary) -> Vector3:
	var g: Vector2i = room["grid"]
	return Vector3(float(g.x) * STEP, 0.0, float(g.y) * STEP)

func _build_room(room: Dictionary, rooms: Array, rng: RandomNumberGenerator) -> void:
	var center: Vector3 = _room_center(room)
	_solid(Vector3(12.2, 0.56, 12.2), center + Vector3(0, -0.34, 0))
	for x in [-4.0, 0.0, 4.0]:
		for z in [-4.0, 0.0, 4.0]:
			var tile: String = "floor_tile_large_rocks" if rng.randf() < 0.10 else "floor_tile_large"
			_model(tile, center + Vector3(x, 0.02, z), Color("a3a69a") if tile == "floor_tile_large" else Color("828b87"))
	var grid: Vector2i = room["grid"]
	for delta in DIRECTIONS:
		var is_open: bool = false
		for adjacent in room["links"]:
			if rooms[int(adjacent)]["grid"] == grid + delta:
				is_open = true
				break
		var wall_yaw: float = PI / 2.0 if delta.x != 0 else 0.0
		var side_pos: Vector3 = center + Vector3(float(delta.x) * HALF, 0, float(delta.y) * HALF)
		var parts := [-4.0, 0.0, 4.0]
		for slot in range(3):
			var offset: float = parts[slot]
			var location: Vector3 = side_pos + Vector3(0, 0, offset) if delta.x != 0 else side_pos + Vector3(offset, 0, 0)
			var entrance: bool = is_open and slot == 1
			_model("wall_doorway" if entrance else "wall", location, Color("858e9b"), wall_yaw)
			if entrance:
				# Only side posts + overhead lintel. Width 2.0 safely exceeds player diameter.
				var along: Vector3 = Vector3(0, 0, 1) if delta.x != 0 else Vector3(1, 0, 0)
				for side_sign in [-1.0, 1.0]:
					_solid(Vector3(0.55, 3.2, 1.0) if delta.x != 0 else Vector3(1.0, 3.2, 0.55), location + along * side_sign * 1.50 + Vector3(0, 1.6, 0))
				_solid(Vector3(0.55, 0.5, 4) if delta.x != 0 else Vector3(4, 0.5, 0.55), location + Vector3(0, 2.96, 0))
			else:
				_solid(Vector3(0.65, 3.2, 4.0) if delta.x != 0 else Vector3(4.0, 3.2, 0.65), location + Vector3(0, 1.6, 0))
	if int(room["id"]) != 0:
		# Every interactive prop has a persistent per-floor ID. Pure rubble
		# and wall fragments remain batched decoration, not fake loot.
		if rng.randf() < 0.67:
			_spawn_breakable("barrel", center + Vector3(-4.35, 0.05, 4.25), int(room["id"]), 0)
		if rng.randf() < 0.43:
			_spawn_breakable("sealed_crate", center + Vector3(4.25, 0.05, -4.20), int(room["id"]), 1)
		if rng.randf() < 0.34:
			_spawn_breakable("urn", center + Vector3(4.3, 0.05, 4.25), int(room["id"]), 2)
		if rng.randf() < 0.24:
			_model("rubble_half", center + Vector3(4.5, 0.03, -4.4), Color("767f8b"), rng.randf() * TAU)
		if rng.randf() < 0.32:
			_model("pillar", center + Vector3(4.7, 0.0, 4.7), Color("909599"))
	if rng.randf() < 0.45:
		var torch := _model("torch_lit", center + Vector3(-4.8, 0.0, -4.8), RARITY.color(quality).lerp(Color("f2b36c"), 0.72))
		torch.scale = Vector3(0.92, 0.92, 0.92)
	# Add one batched nearest-filtered mesh for each room's unique archetype.
	# No new colliders inside traversable doors or guardian/chest locations.
	ROOM_DECOR.decorate(floor_root, room, center, quality, rooms)

func _build_connector(a: Vector2i, b: Vector2i) -> void:
	var a_center: Vector3 = Vector3(float(a.x) * STEP, 0.0, float(a.y) * STEP)
	var b_center: Vector3 = Vector3(float(b.x) * STEP, 0.0, float(b.y) * STEP)
	var middle: Vector3 = (a_center + b_center) * 0.5
	var along_x: bool = a.x != b.x
	# The prior bridge only had a 4x4 floor between 12.2-wide rooms, with
	# completely exposed outer edges. The new 6.6-wide collision deck spans
	# BOTH doorway lips and all three visible connector tile positions.
	var floor_size: Vector3 = Vector3(CONNECTOR_LENGTH, 0.56, CONNECTOR_WIDTH) if along_x else Vector3(CONNECTOR_WIDTH, 0.56, CONNECTOR_LENGTH)
	_solid(floor_size, middle + Vector3(0, -0.34, 0))
	# A contiguous visible stone slab matches the collision; the KayKit
	# centre tile adds detail without leaving decorative holes at the sides.
	var bridge_art := BoxMesh.new()
	bridge_art.size = Vector3(CONNECTOR_LENGTH, 0.12, CONNECTOR_WIDTH) if along_x else Vector3(CONNECTOR_WIDTH, 0.12, CONNECTOR_LENGTH)
	var bridge := MeshInstance3D.new()
	bridge.name = "ConnectorDeck"
	bridge.mesh = bridge_art
	bridge.position = middle + Vector3(0, -0.095, 0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("777f7c")
	stone.roughness = 0.94
	bridge.material_override = stone
	floor_root.add_child(bridge)
	_model("floor_tile_large", middle + Vector3(0, 0.02, 0), Color("a3a69a"))
	# Side parapets make it impossible to walk diagonally off the join even
	# while camera movement is held against its edge on a touchscreen.
	for direction in [-1.0, 1.0]:
		var offset: Vector3 = Vector3(0, 0, direction * CONNECTOR_WALL_OFFSET) if along_x else Vector3(direction * CONNECTOR_WALL_OFFSET, 0, 0)
		var wall_size: Vector3 = Vector3(CONNECTOR_LENGTH, 1.45, 0.65) if along_x else Vector3(0.65, 1.45, CONNECTOR_LENGTH)
		var wall_at: Vector3 = middle + offset + Vector3(0, 0.68, 0)
		_solid(wall_size, wall_at)
		var wall_art := BoxMesh.new()
		wall_art.size = wall_size
		var stone_wall := MeshInstance3D.new()
		stone_wall.name = "ConnectorParapet"
		stone_wall.mesh = wall_art
		stone_wall.position = wall_at
		stone_wall.material_override = stone
		floor_root.add_child(stone_wall)

func _solid(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	floor_root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _model(id: String, pos: Vector3, tint: Color, yaw: float = 0.0) -> MeshInstance3D:
	var mesh: Mesh
	if mesh_cache.has(id):
		mesh = mesh_cache[id]
	else:
		mesh = load(ASSET_ROOT + id + ".obj") as Mesh
		mesh_cache[id] = mesh
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.rotation.y = yaw
	var key: String = tint.to_html(false)
	if material_cache.has(key):
		node.material_override = material_cache[key]
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.90
		material_cache[key] = mat
		node.material_override = mat
	floor_root.add_child(node)
	return node

func _spawn_breakable(kind: String, at: Vector3, room_id: int, slot: int) -> void:
	var prop_id: String = "%d:%d:%d" % [current_floor, room_id, slot]
	if claimed_props.has(prop_id):
		return
	var prop := BREAKABLE.new()
	prop.position = at
	floor_root.add_child(prop)
	prop.setup(kind, LOOT.breakable(entrance_id, quality, current_floor, prop_id))
	prop.set_meta("dungeon_prop_id", prop_id)
	prop.shattered.connect(_on_prop_shattered.bind(prop_id))

func _on_prop_shattered(reward: Dictionary, prop_id: String) -> void:
	if claimed_props.has(prop_id):
		return
	claimed_props[prop_id] = true
	prop_broken.emit(self, prop_id, reward)

## KayKit stairs rise from local +Z toward -Z: their low step must face
## an actual doorway. Choose the first connected room deterministically.
func _stairs_yaw(rooms: Array) -> float:
	var exit_room: Dictionary = rooms[int(layout["exit"])]
	var links: Array = exit_room.get("links", [])
	if links.is_empty():
		return 0.0
	var delta: Vector2i = rooms[int(links[0])]["grid"] - exit_room["grid"]
	return atan2(float(delta.x), float(delta.y))

func _spawn_guards(rooms: Array, rng: RandomNumberGenerator) -> void:
	guards_remaining = RARITY.guard_count(quality) + current_floor - 1
	for i in range(guards_remaining):
		var room_id: int = 1 + (i % maxi(1, rooms.size() - 1))
		if current_floor == floor_count and i == guards_remaining - 1:
			room_id = int(layout["exit"])
		var center: Vector3 = _room_center(rooms[room_id])
		var x: float = rng.randf_range(-1.8, 1.8)
		var z: float = rng.randf_range(-1.8, 1.8)
		var guard := GUARDIAN.new()
		floor_root.add_child(guard)
		var boss: bool = current_floor == floor_count and i == guards_remaining - 1
		var creature_kind: String = ""
		if quality <= RARITY.RARE:
			# Deterministic skeleton/goblin variants
			creature_kind = "skeleton" if (int(layout["seed"]) + i + current_floor) % 2 == 0 else "goblin"
		guard.setup(hero, self, quality, center + Vector3(x, 0.16, z), creature_kind)
		guard.set_meta("encounter_slot", i) # Stable across every peer's seeded room copy.
		guard.hp *= pow(1.20, current_floor - 1) * (2.1 if boss else 1.0)
		guard.damage_multiplier = pow(1.12, current_floor - 1) * (1.40 if boss else 1.0)
		if boss:
			guard.name = "DungeonBoss"
			guard.scale *= 1.35
			guard.display_name = "Skeleton Champion" if creature_kind == "skeleton" else "Goblin Chieftain" if creature_kind == "goblin" else "Ancient Warden"
		guard.apply_affixes(AFFIXES.roll(entrance_id, current_floor, i, quality, boss))
	boss_alive = current_floor == floor_count

func _make_chest() -> void:
	chest_area = Area3D.new()
	chest_area.name = "FloorExit" if current_floor < floor_count else "FinalChest"
	chest_area.set_meta("world_kind", "chest")
	chest_area.set_meta("dungeon_exit", self)
	chest_area.set_meta("world_action", "Open" if current_floor == floor_count else "Use stairs")
	chest_area.position = exit_local
	chest_area.collision_layer = 8
	chest_area.collision_mask = 0
	chest_area.input_ray_pickable = true
	floor_root.add_child(chest_area)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 2.2, 2.8)
	collider.shape = shape
	collider.position.y = 1.1
	chest_area.add_child(collider)
	var art := MeshInstance3D.new()
	art.mesh = load(ASSET_ROOT + ("chest_gold.obj" if current_floor == floor_count else "stairs_wide.obj")) as Mesh
	if current_floor < floor_count:
		art.rotation.y = _stairs_yaw(layout["rooms"])
		art.set_meta("doorway_aligned", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = RARITY.color(quality).lerp(Color("c6ac79"), 0.6)
	mat.roughness = 0.72
	art.material_override = mat
	chest_area.add_child(art)
	chest_material = mat
	chest_label = Label3D.new()
	chest_label.text = "DEFEAT GUARDIANS — FINAL CHEST" if current_floor == floor_count else "DEFEAT GUARDIANS — STAIRS"
	chest_label.font_size = 35
	chest_label.pixel_size = 0.006
	chest_label.modulate = RARITY.color(quality)
	chest_label.outline_size = 10
	chest_label.position = Vector3(0, 2.7, 0)
	chest_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chest_area.add_child(chest_label)
	chest_area.input_event.connect(_on_exit_input)

func _make_bonus(id: int, position_at: Vector3) -> void:
	var at: Vector3 = position_at + Vector3(0.0, 0.0, 0.0)
	bonus_chests[id] = at
	var bonus := Area3D.new()
	bonus.name = "Bonus_%d" % id
	bonus.set_meta("world_kind", "chest")
	bonus.set_meta("dungeon_bonus", id)
	bonus.set_meta("world_action", "Open bonus cache")
	bonus.position = at
	bonus.collision_layer = 8
	bonus.collision_mask = 0
	bonus.input_ray_pickable = true
	floor_root.add_child(bonus)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 1.4, 2.1)
	collision.shape = box
	collision.position.y = 0.65
	bonus.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.mesh = load(ASSET_ROOT + "chest.obj") as Mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("a87845")
	visual.material_override = mat
	bonus.add_child(visual)
	var label := Label3D.new()
	label.text = "BONUS CACHE"
	label.pixel_size = 0.005
	label.font_size = 37
	label.position.y = 2.1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bonus.add_child(label)
	bonus.input_event.connect(_on_bonus_input.bind(id))

func _on_exit_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int) -> void:
	if hero != null and hero.game.get("controls") != null:
		return
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var touched: bool = event is InputEventScreenTouch and event.pressed
	if clicked or touched:
		if current_floor < floor_count:
			stairs_selected.emit(self)
		else:
			chest_selected.emit(self)
		get_viewport().set_input_as_handled()

func _on_bonus_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int, bonus_id: int) -> void:
	if hero != null and hero.game.get("controls") != null:
		return
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var touched: bool = event is InputEventScreenTouch and event.pressed
	if clicked or touched:
		bonus_selected.emit(self, bonus_id)
		get_viewport().set_input_as_handled()

func _distance_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
