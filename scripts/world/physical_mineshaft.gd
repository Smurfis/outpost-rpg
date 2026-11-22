extends RefCounted
## Runtime occupants of the first island's carved mine. Each chunk owns a
## removable group of props and actors. Only the registry owns progression.
var site_id: String
const REGISTRY = preload("res://scripts/dungeons/world_site_registry.gd")
const GOBLIN = preload("res://scripts/world/mine_goblin.gd")
const TREASURE = preload("res://scripts/world/mine_treasure.gd")
const OBJECT = preload("res://scripts/interaction/world_object.gd")
const PROPS = preload("res://scripts/voxel/voxel_props.gd")
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
var island
var manager
var slots := {}
var entrance: Vector3
var layout_seed: int
var access = preload("res://scripts/world/mine_access.gd").new()

func configure(streamer, site: Dictionary = {}) -> bool:
	island = streamer
	var terrain = island.terrain
	site_id = "fractal_physical_goblin_mine_1_%d" % terrain.seed
	layout_seed = REGISTRY.cycle_seed(terrain.seed,site_id,0,"initial")
	if not site.is_empty():
		if site.get("site_id") != site_id or int(site.get("world_seed", -1)) != terrain.seed:
			push_error("Physical mine identity does not match the saved site")
			return false
		layout_seed = int(site.layout_seed)
	if not terrain.caves.carve_mine(terrain,layout_seed):
		return false
	entrance = terrain.caves.entrances[0]
	access.configure(island, entrance)
	access.closed = site.get("state", "") in REGISTRY.CLOSED
	_slot("entrance_timber",entrance+Vector3.BACK*0.5)
	var branches: Array = terrain.caves.branches
	for i in branches.size():
		var branch: Dictionary = branches[i]
		var at := _point(branch.center)
		var edge := float(branch.size.x)/2.0-0.30
		_slot("support",_point(branch.threshold)+Vector3.RIGHT*0.5)
		_slot("ore",at+Vector3.LEFT*edge,"ore_%d" % i)
		_slot("crate",at+Vector3.RIGHT*edge,"supplies_%d" % i)
		if i == 0:
			_slot("guard",at,"miner")
	var end: Vector3 = terrain.caves.chests[0]
	_slot("guard",end+Vector3(0,0,1),"foreman")
	_slot("treasure",end+Vector3(-1,0,-1),"treasure")
	return true

func _point(cell: Vector2i) -> Vector3:
	return Vector3(cell.x+0.5,island.terrain.caves.floor_at(cell.x,cell.y),cell.y+0.5)

func _slot(kind: String, at: Vector3, id := "") -> void:
	var key: Vector2i = island._cell_at(at)
	if not slots.has(key):
		slots[key] = []
	slots[key].append({"kind":kind,"at":at,"id":id})

func _register(game: Node) -> bool:
	manager = game.get_node_or_null("Dungeons")
	if manager == null or not manager.world_site_save_valid:
		return false
	if not manager.world_sites.sites.has(site_id):
		var chunks := {}
		for cell: Vector2i in access.footprint:
			var key: Vector2i = island._cell_at(Vector3(cell.x,0,cell.y))
			chunks["island_%d_%d" % [key.x,key.y]] = true
		manager.world_sites.register_site(site_id,island.terrain.seed,Vector3i(entrance.floor()),chunks.keys(),REGISTRY.MINE)
		manager._save_clears()
	access.closed = manager.world_sites.sites[site_id].state in REGISTRY.CLOSED
	return true

func visit(pos: Vector3) -> void:
	if manager == null or not manager.world_sites.sites.has(site_id):
		return
	var site: Dictionary = manager.world_sites.sites[site_id]
	if site.state not in ["undiscovered","discovered"] or pos.distance_squared_to(entrance)>64*64:
		return
	var cell := Vector2i(floori(pos.x),floori(pos.z))
	var floor_y: int = island.terrain.caves.floor_at(cell.x,cell.y)
	var inside: bool = absf(pos.y-floor_y)<1.5 and pos.y+1<island.terrain.height_at(cell.x,cell.y)
	var changed := false
	if site.state == "undiscovered" and (pos.distance_squared_to(entrance)<16 or inside):
		changed = manager.world_sites.transition(site_id,"discovered")
	if inside and site.state == "discovered":
		changed = manager.world_sites.transition(site_id,"active")
	if changed:
		manager._save_clears()

func populate(key: Vector2i, game: Node, members: Array) -> void:
	if not slots.has(key) and not access.seal_chunks.has(key) and key != island._cell_at(entrance):
		return
	if not _register(game):
		return
	access.populate(key, island, members)
	if not slots.has(key):
		return
	var room_state: Dictionary = manager.world_sites.sites[site_id].room_state
	var group := Node3D.new()
	island.add_child(group)
	members.append(group)
	for slot: Dictionary in slots.get(key,[]):
		var id: String = slot.id
		var at: Vector3 = slot.at
		match slot.kind:
			"guard":
				if room_state.has(id):
					continue
				var guard := GOBLIN.new()
				group.add_child(guard)
				guard.terrain = island.terrain
				guard.setup(game.hero,null,0,at+Vector3.UP*0.08,"goblin")
				guard.display_name = "Goblin Foreman" if id == "foreman" else "Goblin Miner"
				guard.set_meta("mine_slot",id)
				guard.slain.connect(_defeated.bind(id))
			"support","entrance_timber":
				var timber := SurfaceTool.new()
				timber.begin(Mesh.PRIMITIVE_TRIANGLES)
				for x in [-1.0,1.0]:
					PIXELS.box(timber,Vector3(x,1.33,0),Vector3(0.18,2.66,0.28),11,8)
				PIXELS.box(timber,Vector3(0,2.78,0),Vector3(2.18,0.26,0.32),11,8)
				var frame := PIXELS.as_instance(timber,"PitTimber")
				group.add_child(frame)
				frame.position = at
				if slot.kind == "entrance_timber":
					frame.rotation.y = PI/2
			"treasure":
				var chest := TREASURE.new()
				group.add_child(chest)
				chest.position = at
				chest.mine = self
				var art := MeshInstance3D.new()
				art.mesh = preload("res://assets/third_party/kaykit_dungeon/chest_gold.obj")
				var brass := StandardMaterial3D.new()
				brass.albedo_color = Color("b18b47")
				art.material_override = brass
				chest.setup(game,site_id+"_treasure","Foreman's strongbox","chest",art,{"coins":18,"iron":3})
				chest.reconcile()
			"ore","crate":
				var object := OBJECT.new()
				var ore: bool = slot.kind=="ore"
				var art := PROPS.rock("iron") if ore else PROPS.crate()
				art.scale = Vector3.ONE*0.58
				group.add_child(object)
				object.position = at
				object.setup(game,site_id+"_"+id,"Iron deposit" if ore else "Mine supplies","loot" if ore else "chest",art,{"iron":2} if ore else {"wood":2})
				if ore and object.remaining().is_empty():
					object.hide()

func _defeated(id: String) -> void:
	var site: Dictionary = manager.world_sites.sites[site_id]
	if site.state == "undiscovered":
		manager.world_sites.transition(site_id,"discovered")
	if site.state == "discovered":
		manager.world_sites.transition(site_id,"active")
	if manager.world_sites.record_mine_defeat(site_id, id):
		manager._save_clears()

func _supplies_claimed(opened: Dictionary) -> bool:
	# Claims must include unloaded chunks. A partially opened crate retains
	# its undelivered contents in the existing player-side object ledger.
	for chunk_slots: Array in slots.values():
		for slot: Dictionary in chunk_slots:
			if slot.kind in ["ore", "crate"]:
				var contents: Variant = opened.get(site_id + "_" + slot.id)
				if not contents is Dictionary or not contents.is_empty():
					return false
	return true

# Development trigger. The existing lifecycle flag gates all world changes.
func trigger_reoccupation_for_test() -> bool:
	return advance_for_test("sealed", true)

# Called only on explicit request by a lifecycle test, never by the streamer.
func advance_for_test(next: String, reoccupation := false) -> bool:
	if OS.get_environment("OUTPOST_TEST_MINE_LIFECYCLE") != "1" or manager == null or not manager.world_site_save_valid:
		return false
	var game = manager.get_parent()
	if game.hero == null or (game.coop != null and game.coop.mode != "solo") or manager.active_instance != null:
		return false
	if game.hero.interaction_moving or game.controls.navigating or access.seal_chunks.is_empty():
		return false
	var site: Dictionary = manager.world_sites.sites[site_id]
	if next == "sealed" and not _supplies_claimed(game.opened_world_objects):
		return false
	if reoccupation and (next != "sealed" or site.has("world_event")):
		return false
	var previous: String = site.state
	var previous_event: Variant = site.get("world_event").duplicate(true) if site.has("world_event") else null
	if not manager.world_sites.advance_mine(site_id, next, access.clear_of_player(game.hero.global_position)):
		return false
	if reoccupation:
		site.world_event = {"id": "goblin_reoccupation", "site_id": site_id,
			"phase": "reported", "seed": REGISTRY.cycle_seed(island.terrain.seed, site_id, 1, "goblin_reoccupation"),
			"objective": "Investigate the disturbance at the Goblin Mine.", "completed": false}
	elif next == "ready_for_renewal" and site.has("world_event"):
		site.world_event.phase = "ready_for_renewal"
	if not manager._save_clears():
		site.state = previous
		if previous_event == null:
			site.erase("world_event")
		else:
			site.world_event = previous_event
		return false
	if not access.closed:
		access.closed = true
		for key: Vector2i in access.seal_chunks:
			if island._loaded.has(key):
				access.populate(key, island, island._loaded[key])
	if reoccupation:
		game.hud.toast("Goblin activity has been reported near the abandoned mine.")
	return true
