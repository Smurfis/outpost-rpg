extends RefCounted
const GUARD = preload("res://scripts/world/natural_cave_goblin.gd")
const OBJECT = preload("res://scripts/interaction/world_object.gd")
const PROPS = preload("res://scripts/voxel/voxel_props.gd")
var guard_at: Vector3
var ore_at: Vector3
var guard_key: Vector2i
var ore_key: Vector2i
var encounter_id: String
var ore_id: String
var pending := false
var last_cell := Vector3i.MAX

func configure(island) -> void:
	var cave = island.terrain.caves.natural
	guard_at = Vector3(cave.guard_cell.x+0.5,cave.floors[cave.guard_cell]+0.08,cave.guard_cell.y+0.5)
	ore_at = Vector3(cave.ore_cell.x+0.5,cave.floors[cave.ore_cell],cave.ore_cell.y+0.5)
	guard_key = island._cell_at(guard_at)
	ore_key = island._cell_at(ore_at)
	var prefix := "natural_cave_%d_island2_" % int(island.terrain.seed)
	encounter_id = prefix+"goblin_0"
	ore_id = prefix+"iron_0"

func populate(island, game, key: Vector2i, members: Array) -> void:
	if key == ore_key:
		var ore := OBJECT.new()
		island.add_child(ore)
		ore.position = ore_at
		var art := PROPS.rock("iron")
		art.scale = Vector3.ONE*0.6
		ore.setup(game, ore_id, "Cave iron", "loot", art, {"iron":3})
		ore.visible = not ore.remaining().is_empty()
		members.append(ore)
	if key == guard_key and game.natural_cave_encounters.get(encounter_id, 1.0) > 0:
		pending = true
		last_cell = Vector3i.MAX
		try_spawn(island, game)

func try_spawn(island, game) -> void:
	if not pending or not island._loaded.has(guard_key):
		return
	var hero: Vector3 = game.hero.global_position
	var cell := Vector3i(hero.floor())
	if last_cell == cell:
		return
	last_cell = cell
	var sight := guard_at + Vector3.UP - (hero+Vector3.UP)
	var distance := sight.length()
	if distance < 13 or (game.hero.torch_light.visible and distance <= game.hero.torch_light.omni_range):
		return
	var terrain = island.terrain
	if terrain.caves.natural.floors.has(Vector2i(cell.x,cell.z)) and game.camera.is_position_in_frustum(guard_at + Vector3.UP):
		return # A cutaway can reveal a room even when solid rock separates the actors.
	var foot := Vector3i(guard_at.floor())
	if terrain.height_at(foot.x,foot.z) - terrain.caves.ceiling_at(foot.x,foot.z,foot.y) < 1:
		return
	# Sample original rock: unloaded collision bodies cannot provide LOS.
	for i in range(1, ceili(distance*2)):
		var p := Vector3i((hero+Vector3.UP+sight.normalized()*i*0.5).floor())
		if not terrain.is_solid(p.x,p.y,p.z):
			continue
		# The goblin frees itself after its death animation. Only the stable
		# chunk owner belongs in the streamer's visual/collision member list.
		var group := Node3D.new()
		island.add_child(group)
		island._loaded[guard_key].append(group)
		var goblin := GUARD.new()
		goblin.encounter_id = encounter_id
		goblin.terrain = terrain
		group.add_child(goblin)
		goblin.setup(game.hero,null,0,guard_at,"goblin")
		goblin.display_name = "Cave goblin"
		goblin.hp = game.natural_cave_encounters.get(encounter_id,goblin.max_hp)
		pending = false
		return
