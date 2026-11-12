extends SceneTree

const CACHE = preload("res://scripts/map/overworld_map_cache.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
	else:
		print("MAP PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var biome = game.get_node("VoxelAtmosphere")
	var cache = CACHE.new(biome)
	cache.request_chunk(Vector2i(-1, 0))
	cache.request_chunk(Vector2i(-1, 0))
	cache.step(13)
	check(cache.sample_count == 13 and cache.cell_at(-1, 0).is_empty(), "Work budget is respected and partial chunks remain hidden")
	cache.step(131)
	var cell: Dictionary = cache.cell_at(-1, 0)
	check(cache.sample_count == 144 and cell == biome.map_cell_at(-1, 0), "Cached negative-coordinate cells match actual biome data")
	check(is_equal_approx(float(cell.height), biome._tile_height(-1, 0)), "Land height matches terrain geometry")
	cache.request_chunk(Vector2i(8, 0))
	cache.step(144)
	check(cache.cell_at(96, 0).is_empty(), "No terrain is generated beyond the finite world")
	cache.invalidate(Vector2i(-1, 0))
	check(cache.cell_at(-1, 0).is_empty(), "Invalidation removes a changed chunk")
	var minimap = game.hud.root.get_node("LiveWorldMinimap")
	game.diorama_map_enabled = true
	minimap._process(0.01)
	var initial_count: int = minimap._map_cache.sample_count
	game.camera_angle += TAU
	minimap._process(0.01)
	check(minimap._map_cache.sample_count - initial_count <= 12, "Orbit does not enqueue a terrain rebuild or exceed the frame budget")
	minimap._map_cache.step(2000)
	initial_count = minimap._map_cache.sample_count
	game.camera_angle += TAU
	minimap._process(3.0)
	check(minimap._map_cache.sample_count == initial_count, "A completed cache performs no work on camera orbit")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
