extends Node
## Shared exploration/marker truth. Camera movement never reveals cells.
signal changed
const CACHE = preload("res://scripts/map/overworld_map_cache.gd")
const ZONES = preload("res://scripts/world/outpost_zone_names.gd")
const RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
const CELL: int = 4
const REVEAL_RADIUS: float = 18.0
const LIVE_RADIUS: float = 24.0
var game: Node
var biome: Node
var cache: RefCounted
var world_id: String
var discovered: Dictionary = {}
var known: Dictionary = {}
var scenery: Dictionary = {}
var chunk_versions: Dictionary = {}
var creatures: Array[Dictionary] = []
var resources: Array[Dictionary] = []
var preferences: Dictionary = {"mobs": true, "stations": true, "portals": true, "zones": true, "resources": false, "resource_type": "all"}
var revision: int = 0
var clock: float = 0.0
var save_clock: float = 0.0
var dirty: bool = false

func setup(owner_game: Node) -> void:
	game = owner_game
	biome = game.get_node_or_null("VoxelAtmosphere")
	if biome == null:
		return
	world_id = "fields:%s" % str(biome.world_seed)
	cache = CACHE.new(biome)

func in_overworld() -> bool:
	var dungeon: Node = game.get_node_or_null("Dungeons")
	return dungeon == null or dungeon.active_instance == null

func cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))

func inside(point: Vector3) -> bool:
	return biome != null and absf(point.x) < biome.map_half and absf(point.z) < biome.map_half

func visibility_at(point: Vector3) -> int:
	if not inside(point) or not discovered.has(cell_at(point)):
		return 0
	if in_overworld() and Vector2(point.x - game.hero.global_position.x, point.z - game.hero.global_position.z).length() <= REVEAL_RADIUS:
		return 2
	return 1

func _process(delta: float) -> void:
	if biome == null or game.hero == null:
		return
	clock += delta
	save_clock += delta
	if clock >= 0.5:
		clock = 0.0
		if in_overworld():
			observe_player()
			refresh_entities()
		else:
			creatures.clear()
			resources.clear()
	if dirty and save_clock >= 10.0:
		save_clock = 0.0
		game._save()

func observe_player() -> void:
	var point: Vector3 = game.hero.global_position
	if not inside(point):
		return
	var center := cell_at(point)
	var added := false
	for z in range(-5, 6):
		for x in range(-5, 6):
			var cell := center + Vector2i(x, z)
			var at := Vector3((cell.x + 0.5) * CELL, 0, (cell.y + 0.5) * CELL)
			if not inside(at) or Vector2(at.x - point.x, at.z - point.z).length() > REVEAL_RADIUS:
				continue
			if not discovered.has(cell):
				discovered[cell] = true
				_touch_chunk(at)
				added = true
	var zone: String = ZONES.resolve(point, biome)
	remember("zone:" + zone, zone, "zones", point)
	if added:
		revision += 1
		dirty = true
		changed.emit()

func remember(id: String, label: String, category: String, point: Vector3, extra: Dictionary = {}) -> void:
	if known.has(id) or visibility_at(point) == 0:
		return
	var record := {"id": id, "label": label, "category": category, "position": point}
	record.merge(extra)
	known[id] = record
	_touch_chunk(point)
	dirty = true
	changed.emit()

func _touch_chunk(point: Vector3) -> void:
	var key := Vector2i(floori(point.x / CACHE.CHUNK_SIZE), floori(point.z / CACHE.CHUNK_SIZE))
	chunk_versions[key] = int(chunk_versions.get(key, 0)) + 1

func refresh_entities() -> void:
	creatures.clear()
	resources.clear()
	for id in game.stations:
		var station: Node3D = game.stations[id]
		remember("station:" + id, str(id).capitalize(), "stations", station.global_position)
	var dungeon: Node = game.get_node_or_null("Dungeons")
	if dungeon != null:
		for id in dungeon.entrances:
			var portal: Node3D = dungeon.entrances[id]
			remember("portal:" + id, portal.dungeon_title, "portals", portal.global_position, {"quality": portal.quality})
	# Only currently loaded client entities are eligible. No seed-spawned mobs.
	for entity in get_tree().get_nodes_in_group("map_creatures"):
		if not entity.has_method("map_record"):
			continue
		var record: Dictionary = entity.map_record()
		if record.get("dimension", "") != "overworld" or not record.get("alive", false) or not record.get("visible_on_radar", false):
			continue
		var at: Vector3 = record.position
		if visibility_at(at) != 2 or at.distance_to(game.hero.global_position) > LIVE_RADIUS:
			continue
		record["entity"] = weakref(entity)
		creatures.append(record)
		if creatures.size() >= 64:
			break
	var scenery_changed := false
	for resource in get_tree().get_nodes_in_group("resources"):
		var at: Vector3 = resource.global_position
		if visibility_at(at) != 2:
			continue
		var id: String = "%s:%d:%d" % [resource.kind, roundi(at.x * 10), roundi(at.z * 10)]
		if not resource.active:
			if scenery.erase(id):
				_touch_chunk(at)
				scenery_changed = true
			continue
		resources.append({"id": id, "position": at, "label": str(resource.kind).capitalize(), "category": "resources", "kind": resource.kind})
		if resource.kind not in ["wood", "stone", "iron", "coal", "clay"] or scenery.has(id):
			continue
		var dimensions := Vector3.ONE
		if resource.resource_body != null and resource.resource_body.get_child_count() > 0:
			dimensions = resource.resource_body.visual_dimensions * resource.global_basis.get_scale()
		scenery[id] = {"position": at, "kind": resource.kind, "size": dimensions}
		_touch_chunk(at)
		scenery_changed = true
	if scenery_changed:
		revision += 1
		dirty = true
		changed.emit()

func markers(close_zoom: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in known.values():
		if preferences.get(entry.category, true) and visibility_at(entry.position) > 0:
			result.append(entry)
	if close_zoom and preferences.mobs:
		for record in creatures:
			var entity: Node = record.entity.get_ref()
			if entity == null or not entity.is_inside_tree() or entity.is_queued_for_deletion(): continue
			var live: Dictionary = entity.map_record()
			if live.alive and live.visible_on_radar and live.dimension == "overworld" and visibility_at(live.position) == 2:
				result.append(live)
	if close_zoom and preferences.resources:
		for entry in resources:
			if preferences.resource_type == "all" or entry.kind == preferences.resource_type:
				result.append(entry)
	return result

func search(query: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in known.values():
		if visibility_at(entry.position) > 0 and query.to_lower() in str(entry.label).to_lower():
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.label) < str(b.label))
	return result

func export_state() -> Dictionary:
	var cells: Array = []
	for cell in discovered:
		cells.append([cell.x, cell.y])
	var pins: Array = []
	for entry in known.values():
		var saved: Dictionary = entry.duplicate()
		var point: Vector3 = entry.position
		saved.position = [point.x, point.y, point.z]
		pins.append(saved)
	var objects: Array = []
	for id in scenery:
		var entry: Dictionary = scenery[id]
		objects.append({"id": id, "kind": entry.kind, "position": [entry.position.x, entry.position.y, entry.position.z], "size": [entry.size.x, entry.size.y, entry.size.z]})
	return {"schema": 1, "world_id": world_id, "cells": cells, "known": pins, "scenery": objects, "preferences": preferences.duplicate()}

func import_state(data: Variant) -> void:
	discovered.clear()
	known.clear()
	scenery.clear()
	chunk_versions.clear()
	if not data is Dictionary or data.get("schema") != 1 or data.get("world_id") != world_id:
		revision += 1
		changed.emit()
		return
	if data.get("cells") is Array:
		for entry in data.cells.slice(0, 65536):
			if entry is Array and entry.size() == 2:
				discovered[Vector2i(int(entry[0]), int(entry[1]))] = true
	for list_id in ["known", "scenery"]:
		if not data.get(list_id) is Array:
			continue
		for entry in data[list_id].slice(0, 4096):
			if not entry is Dictionary or not entry.get("position") is Array or entry.position.size() != 3:
				continue
			var record: Dictionary = entry.duplicate()
			record.position = Vector3(float(entry.position[0]), float(entry.position[1]), float(entry.position[2]))
			if visibility_at(record.position) == 0:
				continue
			if list_id == "known" and record.get("category", "") in ["zones", "stations", "portals"] and record.get("label") is String:
				known[str(record.get("id", ""))] = record
			elif list_id == "scenery" and record.get("size") is Array and record.size.size() == 3 and record.get("kind", "") in ["wood", "stone", "iron", "coal", "clay"]:
				record.size = Vector3(float(record.size[0]), float(record.size[1]), float(record.size[2])).clamp(Vector3.ONE * 0.1, Vector3.ONE * 20)
				scenery[str(record.get("id", ""))] = record
	if data.get("preferences") is Dictionary:
		for key in preferences:
			if key == "resource_type":
				preferences[key] = str(data.preferences.get(key, "all"))
			elif data.preferences.get(key) is bool:
				preferences[key] = data.preferences[key]
	revision += 1
	changed.emit()
