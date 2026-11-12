extends RefCounted
## Incremental, world-aligned terrain samples. This cache contains no discovery
## permissions: callers must apply fog before displaying any sampled cell.
const CHUNK_SIZE: int = 12
const MAX_CHUNKS: int = 64

var biome: Node
var chunks: Dictionary = {}
var pending: Array[Vector2i] = []
var _working: Dictionary = {}
var _working_key: Vector2i
var _next_cell: int = 0
var sample_count: int = 0

func _init(source: Node) -> void:
	biome = source

func request_chunk(key: Vector2i) -> void:
	if chunks.has(key) or pending.has(key) or (not _working.is_empty() and key == _working_key):
		return
	var half: int = int(biome.get("map_world_half"))
	if key.x * CHUNK_SIZE >= half or (key.x + 1) * CHUNK_SIZE <= -half or key.y * CHUNK_SIZE >= half or (key.y + 1) * CHUNK_SIZE <= -half:
		return
	if pending.size() >= MAX_CHUNKS:
		pending.pop_front()
	pending.append(key)

func step(cell_budget: int) -> void:
	for _i in range(maxi(0, cell_budget)):
		if _working.is_empty():
			if pending.is_empty():
				return
			_working_key = pending.pop_front()
			_working = {"cells": {}}
			_next_cell = 0
		var x: int = _working_key.x * CHUNK_SIZE + _next_cell % CHUNK_SIZE
		var z: int = _working_key.y * CHUNK_SIZE + _next_cell / CHUNK_SIZE
		var sample: Dictionary = biome.map_cell_at(x, z)
		if not sample.is_empty():
			_working["cells"][Vector2i(x, z)] = sample
		sample_count += 1
		_next_cell += 1
		if _next_cell == CHUNK_SIZE * CHUNK_SIZE:
			if chunks.size() >= MAX_CHUNKS:
				chunks.erase(chunks.keys()[0])
			chunks[_working_key] = _working["cells"]
			_working = {}

func cell_at(x: int, z: int) -> Dictionary:
	var key := Vector2i(floori(float(x) / CHUNK_SIZE), floori(float(z) / CHUNK_SIZE))
	if not chunks.has(key):
		return {}
	return chunks[key].get(Vector2i(x, z), {})

func invalidate(key: Vector2i) -> void:
	chunks.erase(key)
	pending.erase(key)
	if not _working.is_empty() and key == _working_key:
		_working = {}
