extends RefCounted
## One main-thread request advances one durable checkpoint. Staging and the
## resident-owner exchange run synchronously, outside physics callbacks.
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const REGISTRY = preload("res://scripts/dungeons/world_site_registry.gd")
const MINE = preload("res://scripts/world/physical_mineshaft.gd")

static func advance(island, game) -> String:
	if OS.get_environment("OUTPOST_TEST_MINE_LIFECYCLE") != "1" or island.mine == null:
		return "unavailable"
	var manager = game.get_node("Dungeons")
	var id: String = island.mine.site_id
	var site: Dictionary = manager.world_sites.sites.get(id, {})
	if not manager.world_site_save_valid or (not game.player_save_valid_for_mine and not game.mine_started_without_saves) or site.get("state") != "ready_for_renewal" or not site.has("world_event"):
		return "unavailable"
	if site.get("reopened",false):
		return "open"
	if not island.mine.access.closed or Engine.is_in_physics_frame():
		return "busy"
	if site.cycle == 0 and not island.mine._supplies_claimed(game.opened_world_objects):
		return "outstanding_rewards"
	if game.hero == null or game.controls.navigating or game.hero.interaction_moving or Vector2(game.hero.velocity.x, game.hero.velocity.z).length_squared() > 0.001 or absf(game.hero.velocity.y) > 0.11 or manager.active_instance != null or (game.coop != null and game.coop.mode != "solo"):
		return "occupied"
	if game.controls.modal_open() or game.station_walk_target != "" or is_instance_valid(game.controls.target) or is_instance_valid(game.controls.inspected):
		return "busy"
	if site.cycle == 1:
		return _reopen(island,game,manager,site)
	# Reconstruct in an isolated terrain object. Only cave data is transferred
	# on commit so references held by unrelated island occupants remain valid.
	var terrain = DATA.new(island.terrain.seed)
	var descriptor := site.duplicate(true)
	descriptor.cycle = 1
	descriptor.layout_seed = REGISTRY.cycle_seed(terrain.seed, id, 1, site.event_id)
	var candidate = MINE.new()
	if not candidate.configure(island, descriptor, terrain) or candidate.entrance != island.mine.entrance:
		return "invalid_layout"
	var current = island.mine.access
	var next = candidate.access
	var cells: Dictionary = current.footprint.duplicate()
	cells.merge(next.footprint)
	var protected_columns := cells.duplicate()
	var keys := cells.keys()
	keys.sort()
	var changes := []
	var affected := {}
	for cell: Vector2i in keys:
		var key: Vector2i = island._cell_at(Vector3(cell.x, 0, cell.y))
		affected[key] = true
		var old_bits: int = island.terrain.solid_column(cell.x, cell.y)
		var new_bits: int = terrain.solid_column(cell.x, cell.y)
		if old_bits == new_bits:
			continue
		changes.append([cell.x, cell.y, old_bits, new_bits])
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			protected_columns[cell+step] = true
			affected[island._cell_at(Vector3(cell.x + step.x, 0, cell.y + step.y))] = true
	if changes.is_empty() or not _walkable(terrain, next):
		return "invalid_layout"
	for block: Vector3i in game.building.blocks:
		if protected_columns.has(Vector2i(block.x, block.z)):
			return "protected"
	for other_id in manager.world_sites.sites:
		if other_id == id:
			continue
		for key: Vector2i in affected:
			if "island_%d_%d" % [key.x,key.y] in manager.world_sites.sites[other_id].chunks:
				return "protected"
	for record: Dictionary in game.death_tombstones.values():
		var pos: Array = record.get("position", [])
		if pos.size() != 3 or cells.has(Vector2i(floori(pos[0]), floori(pos[2]))):
			return "protected"
	for actor in [game.hero] + game.get_tree().get_nodes_in_group("enemies"):
		if not current.clear_of_player(actor.global_position) or not next.clear_of_player(actor.global_position):
			return "occupied"
	for target in [game.focus_target,game.recent_attack_target]:
		if is_instance_valid(target) and affected.has(island._cell_at(target.global_position)):
			return "occupied"
	var natural = island.terrain.caves.natural
	if natural != null:
		for cell in natural.floors:
			if cells.has(cell):
				return "protected"
		terrain.caves.natural = natural
	# Carry the live world's unaffected columns across by identity of location.
	# The generator is authoritative only inside the two mine footprints.
	var merged: Dictionary = island.terrain.caves.floors.duplicate()
	for cell: Vector2i in cells:
		if next.footprint.has(cell):
			merged[cell] = next.footprint[cell]
		else:
			merged.erase(cell)
	terrain.caves.floors = merged
	var digest := JSON.stringify(changes).sha256_text()
	var journal: Dictionary = site.get("renewal", {})
	if not journal.is_empty() and journal.digest != digest:
		return "layout_changed"
	var updated := site.duplicate(true)
	var phase: String = journal.get("phase", "")
	var staged := {}
	if phase == "":
		updated.renewal = {"phase":"prepared", "from_cycle":0, "generator_version":REGISTRY.GENERATOR_VERSION, "cycle":1, "seed":descriptor.layout_seed, "digest":digest}
		phase = "prepared"
	else:
		# Streaming, camera and input run on the same thread. No await from
		# this snapshot of resident keys through owner exchange.
		for child in island.get_children():
			if child.is_queued_for_deletion():
				return "awaiting_unload"
		if phase == "prepared":
			phase = "publishing"
			updated.renewal.phase = phase
		else:
			updated = descriptor
			updated.erase("renewal")
			updated.chunks = []
			for cell: Vector2i in next.footprint:
				var key: Vector2i = island._cell_at(Vector3(cell.x, 0, cell.y))
				var name := "island_%d_%d" % [key.x,key.y]
				if name not in updated.chunks:
					updated.chunks.append(name)
			for key: Vector2i in affected:
				if island._loaded.has(key):
					var nodes: Array = island._build_chunk_geometry(key,terrain)
					staged[key] = nodes
					if not _has_terrain_collision(nodes):
						_discard(staged)
						return "invalid_collision"
			phase = "committed"
	# Existing atomic save replacement is the commit point. Until this
	# succeeds a restart always constructs cycle zero, including mid-publish.
	manager.world_sites.sites[id] = updated
	if not manager._save_clears():
		manager.world_sites.sites[id] = site
		_discard(staged)
		return "save_failed"
	if phase == "committed":
		island.invalidate_section_geometry()
		island._reveal_cell = Vector2i.MAX
		for key in staged:
			for node in island._loaded[key]:
				if node is MeshInstance3D:
					island._roof_nodes.erase(node)
				island.remove_child(node)
				node.queue_free()
			island._loaded.erase(key)
		island.terrain.caves = terrain.caves
		island.mine = candidate
		candidate.manager = manager
		for key in staged:
			island._install_chunk(key,staged[key])
	return phase

static func _discard(staged: Dictionary) -> void:
	for nodes in staged.values():
		for node in nodes:
			node.free()

static func _has_terrain_collision(nodes: Array) -> bool:
	for node in nodes:
		if node is StaticBody3D and node.name.begins_with("IslandCollision_"):
			if node.get_child_count() == 0:
				return false
			for collider in node.get_children():
				if not collider is CollisionShape3D or not collider.shape is ConcavePolygonShape3D:
					return false
			return true
	return false

static func _reopen(island,game,manager,site: Dictionary) -> String:
	var mine = island.mine
	if mine.layout_seed != site.layout_seed or not _walkable(island.terrain,mine.access):
		return "invalid_layout"
	for actor in [game.hero] + game.get_tree().get_nodes_in_group("enemies"):
		if not mine.access.clear_of_player(actor.global_position):
			return "occupied"
	for block: Vector3i in game.building.blocks:
		if mine.access.footprint.has(Vector2i(block.x,block.z)):
			return "protected"
	for key in island._loaded:
		if "island_%d_%d" % [key.x,key.y] in site.chunks:
			if not _has_terrain_collision(island._loaded[key]):
				return "invalid_collision"
	site.reopened = true
	if not manager._save_clears():
		site.erase("reopened")
		return "save_failed"
	for key in mine.access.seal_chunks:
		var nodes: Array = island._loaded.get(key,[])
		for node in nodes.duplicate():
			if node.has_meta("mine_bulkhead"):
				nodes.erase(node)
				island.remove_child(node)
				node.queue_free()
	mine.access.closed = false
	return "open"

static func _walkable(terrain, access) -> bool:
	var start: Vector3 = terrain.caves.entrances[0]
	var queue: Array[Vector2i] = [Vector2i(floori(start.x), floori(start.z))]
	var seen := {queue[0]:true}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		var y: int = access.footprint[cell]
		if not terrain.is_solid(cell.x, y-1, cell.y):
			return false
		for dy in access.height:
			if terrain.is_solid(cell.x, y+dy, cell.y):
				return false
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var other := cell + step
			if not seen.has(other) and access.footprint.has(other) and absi(access.footprint[other]-y) <= 1:
				seen[other] = true
				queue.append(other)
	return seen.size() == access.footprint.size()
