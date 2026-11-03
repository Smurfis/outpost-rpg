extends RefCounted
## Deterministic connected orthogonal graph for Outpost dungeon rooms.
## Independent from visual scenes, safe for procedural streaming and tests.
const BALANCE = "res://data/progression/balance.json"
const DELTAS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const DEFAULTS: Dictionary = {
	"floor_ranges": [[1, 1], [1, 2], [2, 3], [3, 4], [4, 5]],
	"room_ranges": [[4, 6], [5, 7], [6, 8], [7, 9], [8, 10]],
	"patterns": ["linear", "branching", "circular", "hub", "labyrinth"]
}

static func settings() -> Dictionary:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE))
	if source is Dictionary and source.has("dungeons"):
		return source["dungeons"]
	return DEFAULTS

static func stable_seed(text: String) -> int:
	# Explicit stable hash; no global RNG or platform-dependent randomisation.
	var result: int = 216613
	for character in text.to_utf8_buffer():
		result = (result * 33 + int(character)) % 2147483647
	return maxi(1, result)

static func profile(entrance_id: String, rarity: int) -> Dictionary:
	var cfg: Dictionary = settings()
	var r: int = clampi(rarity, 0, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = stable_seed(entrance_id + ":profile:" + str(r))
	var range_value: Array = cfg.get("floor_ranges", DEFAULTS["floor_ranges"])[r]
	return {
		"floors": rng.randi_range(int(range_value[0]), int(range_value[1])),
		"quality": r,
		"seed": stable_seed(entrance_id),
		"reward_multiplier": float(cfg.get("final_chest_floor_multiplier", 1.3))
	}

static func generate(entrance_id: String, rarity: int, floor_index: int, pattern_override: String = "") -> Dictionary:
	var cfg: Dictionary = settings()
	var rarity_index: int = clampi(rarity, 0, 4)
	var total_floors: int = int(profile(entrance_id, rarity_index)["floors"])
	var index: int = clampi(floor_index, 0, total_floors - 1)
	var seed: int = stable_seed("%s:%d:%d" % [entrance_id, rarity_index, index])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var patterns: Array = cfg.get("patterns", DEFAULTS["patterns"])
	var pattern: String = pattern_override if pattern_override in patterns else str(patterns[rng.randi_range(0, patterns.size() - 1)])
	var count_range: Array = cfg.get("room_ranges", DEFAULTS["room_ranges"])[rarity_index]
	var count: int = rng.randi_range(int(count_range[0]), int(count_range[1]))
	var coords: Array[Vector2i] = [Vector2i.ZERO]
	var links: Array[Vector2i] = []
	var occupied: Dictionary = {str(Vector2i.ZERO): 0}
	if pattern == "circular":
		# Four connected rooms with a shortcut closing the cycle.
		for point in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			_add_room(coords, links, occupied, point, coords.size() - 1)
		_connect(links, 3, 0)
	elif pattern == "hub":
		for direction in DELTAS:
			if coords.size() >= count:
				break
			_add_room(coords, links, occupied, direction, 0)

	var latest: int = coords.size() - 1
	for step in range(160):
		if coords.size() >= count:
			break
		var parent: int = 0
		if pattern == "linear":
			parent = latest if rng.randf() < 0.79 else rng.randi_range(0, coords.size() - 1)
		elif pattern == "hub":
			parent = rng.randi_range(1, coords.size() - 1) if coords.size() > 1 else 0
		elif pattern == "labyrinth":
			parent = latest if rng.randf() < 0.65 else rng.randi_range(0, coords.size() - 1)
		else:
			parent = rng.randi_range(0, coords.size() - 1)
		var direction: Vector2i = DELTAS[rng.randi_range(0, 3)]
		var point: Vector2i = coords[parent] + direction
		if occupied.has(str(point)):
			continue
		_add_room(coords, links, occupied, point, parent)
		latest = coords.size() - 1
	# Guarantee target count with a deterministic growth fallback.
	while coords.size() < count:
		var found: bool = false
		for i in range(coords.size()):
			for direction in DELTAS:
				var point: Vector2i = coords[i] + direction
				if occupied.has(str(point)):
					continue
				_add_room(coords, links, occupied, point, i)
				found = true
				break
			if found:
				break
		if not found:
			break

	if pattern in ["circular", "labyrinth", "branching"]:
		# Interconnect adjacent but previously unlinked rooms. New edges are
		# always between orthogonal neighbors: door placement stays valid.
		for i in range(coords.size()):
			for j in range(i + 1, coords.size()):
				if _distance(coords[i], coords[j]) == 1 and not _has_edge(links, i, j):
					var probability: float = 0.65 if pattern == "labyrinth" else 0.35 if pattern == "circular" else 0.12
					if rng.randf() < probability:
						_connect(links, i, j)

	var adjacency: Array = []
	for i in range(coords.size()):
		adjacency.append([])
	for edge in links:
		adjacency[edge.x].append(edge.y)
		adjacency[edge.y].append(edge.x)
	var distances: Dictionary = {0: 0}
	var queue: Array[int] = [0]
	var cursor: int = 0
	while cursor < queue.size():
		var from: int = queue[cursor]
		cursor += 1
		for neighbor in adjacency[from]:
			var node_id: int = int(neighbor)
			if distances.has(node_id):
				continue
			distances[node_id] = int(distances[from]) + 1
			queue.append(node_id)
	var exit_id: int = 0
	for i in range(coords.size()):
		if int(distances.get(i, -1)) > int(distances.get(exit_id, -1)):
			exit_id = i
	var bonus: Array[int] = []
	for i in range(1, coords.size()):
		if i == exit_id:
			continue
		if adjacency[i].size() == 1 or rng.randf() < 0.09:
			bonus.append(i)
	if bonus.is_empty() and coords.size() >= 5:
		bonus.append(1 if exit_id != 1 else 2)
	var rooms: Array = []
	for i in range(coords.size()):
		rooms.append({
			"id": i,
			"grid": coords[i],
			"links": adjacency[i].duplicate(),
			"role": "start" if i == 0 else "stairs" if i == exit_id and index < total_floors - 1 else "boss" if i == exit_id else "treasure" if i in bonus else "normal"
		})
	return {
		"seed": seed,
		"pattern": pattern,
		"rarity": rarity_index,
		"floor": index + 1,
		"floors": total_floors,
		"rooms": rooms,
		"edges": links,
		"start": 0,
		"exit": exit_id,
		"bonuses": bonus
	}

static func validate(layout: Dictionary) -> bool:
	var rooms: Array = layout.get("rooms", [])
	var edges: Array = layout.get("edges", [])
	if rooms.is_empty() or int(layout.get("start", -1)) != 0:
		return false
	var coords: Dictionary = {}
	for room in rooms:
		var key: String = str(room.get("grid", Vector2i(-99, -99)))
		if coords.has(key):
			return false
		coords[key] = true
	var neighbor_lists: Array = []
	for i in range(rooms.size()):
		neighbor_lists.append([])
	for edge in edges:
		if not (edge is Vector2i):
			return false
		if edge.x < 0 or edge.y < 0 or edge.x >= rooms.size() or edge.y >= rooms.size():
			return false
		if _distance(rooms[edge.x]["grid"], rooms[edge.y]["grid"]) != 1:
			return false
		neighbor_lists[edge.x].append(edge.y)
		neighbor_lists[edge.y].append(edge.x)
	var seen: Dictionary = {0: true}
	var queue: Array[int] = [0]
	var cursor: int = 0
	while cursor < queue.size():
		var index: int = queue[cursor]
		cursor += 1
		for node_id in neighbor_lists[index]:
			if not seen.has(node_id):
				seen[node_id] = true
				queue.append(node_id)
	if seen.size() != rooms.size() or not seen.has(int(layout.get("exit", -1))):
		return false
	for i in range(rooms.size()):
		var links: Array = rooms[i].get("links", [])
		if links.size() != neighbor_lists[i].size():
			return false
		for neighbor in neighbor_lists[i]:
			if neighbor not in links:
				return false
	return true

static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _has_edge(edges: Array[Vector2i], a: int, b: int) -> bool:
	return Vector2i(a, b) in edges or Vector2i(b, a) in edges

static func _connect(edges: Array[Vector2i], a: int, b: int) -> void:
	if not _has_edge(edges, a, b):
		edges.append(Vector2i(a, b))

static func _add_room(coords: Array[Vector2i], edges: Array[Vector2i], occupied: Dictionary, point: Vector2i, parent: int) -> void:
	var index: int = coords.size()
	coords.append(point)
	occupied[str(point)] = index
	_connect(edges, parent, index)
