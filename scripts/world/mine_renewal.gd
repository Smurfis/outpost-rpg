extends RefCounted
## One explicit development request advances one durable checkpoint. A loaded
## chunk keeps its current mesh and collider until it streams out normally.
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const REGISTRY = preload("res://scripts/dungeons/world_site_registry.gd")
const MINE = preload("res://scripts/world/physical_mineshaft.gd")

static func advance(island, game) -> String:
	if OS.get_environment("OUTPOST_TEST_MINE_LIFECYCLE") != "1" or island.mine == null:
		return "unavailable"
	var manager = game.get_node("Dungeons")
	var id: String = island.mine.site_id
	var site: Dictionary = manager.world_sites.sites.get(id, {})
	if not manager.world_site_save_valid or not game.player_save_valid_for_mine or site.get("state") != "ready_for_renewal" or not site.has("world_event") or not island.mine.access.closed:
		return "unavailable"
	if site.cycle == 1:
		return "committed"
	if not island.mine._supplies_claimed(game.opened_world_objects):
		return "outstanding_rewards"
	if game.hero == null or game.controls.navigating or game.hero.interaction_moving or Vector2(game.hero.velocity.x, game.hero.velocity.z).length_squared() > 0.001 or absf(game.hero.velocity.y) > 0.11 or manager.active_instance != null or (game.coop != null and game.coop.mode != "solo"):
		return "occupied"
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
			affected[island._cell_at(Vector3(cell.x + step.x, 0, cell.y + step.y))] = true
	if changes.is_empty() or not _walkable(terrain, next):
		return "invalid_layout"
	for block: Vector3i in game.building.blocks:
		if cells.has(Vector2i(block.x, block.z)):
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
	if phase == "":
		updated.renewal = {"phase":"prepared", "cycle":1, "seed":descriptor.layout_seed, "digest":digest}
		phase = "prepared"
	else:
		for key in affected:
			if island._loaded.has(key):
				return "awaiting_unload"
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
			phase = "committed"
	# Existing atomic save replacement is the commit point. Until this
	# succeeds a restart always constructs cycle zero, including mid-publish.
	manager.world_sites.sites[id] = updated
	if not manager._save_clears():
		manager.world_sites.sites[id] = site
		return "save_failed"
	if phase == "committed":
		island.invalidate_section_geometry()
		island._reveal_cell = Vector2i.MAX
		island.terrain.caves = terrain.caves
		island.mine = candidate
		candidate.manager = manager
	return phase

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
