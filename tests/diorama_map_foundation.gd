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
	check(cache.cell_at(96, 0) == biome.map_cell_at(96, 0) if biome.archipelago != null else cache.cell_at(96, 0).is_empty(),
		"Map samples extended ocean cells in the archipelago prototype; legacy mode remains bounded")
	cache.invalidate(Vector2i(-1, 0))
	check(cache.cell_at(-1, 0).is_empty(), "Invalidation removes a changed chunk")
	cache.request_chunk(Vector2i(-1, 0))
	cache.step(144)
	var initial_count: int = cache.sample_count
	cache.request_chunk(Vector2i(-1, 0))
	cache.step(2000)
	check(cache.sample_count == initial_count, "A completed chunk is never re-sampled by repeat requests")
	var service: Node = game.map_service
	var old_revision: int = service.revision
	service.observe_player()
	service.remember("station:foundation-qa", "QA Station", "stations", game.hero.global_position)
	check(service.revision > old_revision, "Map discovery and POI updates trigger geometry scheduling")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
