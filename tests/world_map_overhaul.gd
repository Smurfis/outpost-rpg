extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("MAP PASS: " + message)
	else:
		failures += 1
		push_error("MAP FAIL: " + message)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	root.set_meta("outpost_input_mode", "desktop")
	var scene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	game.save_path = "res://.map-test-save.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.hero.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var service = game.map_service
	service.set_process(false)
	service.observe_player()
	service.refresh_entities()
	var map = game.world_map
	var camera_before: Transform3D = game.camera.global_transform
	var hero_before: Vector3 = game.hero.global_position
	var chunks_before: int = service.biome.loaded_chunk_count()
	check(map.open_map(), "Map opens outside combat")
	var revision_before_marker: int = service.revision
	service.remember("station:map-qa", "Map QA", "stations", hero_before)
	check(service.revision == revision_before_marker + 1, "Newly discovered POIs invalidate relief without moving the player")
	var actor = load("res://tests/support/map_actor.gd").new()
	game.add_child(actor)
	actor.position = game.hero.position + Vector3(3,0,0)
	actor.add_to_group("map_creatures")
	service.refresh_entities()
	check(service.markers().any(func(record): return record.get("id") == "fixture" and record.disposition == "passive"), "Passive creature uses its explicit disposition")
	actor.disposition = "hostile"
	check(service.markers().any(func(record): return record.get("id") == "fixture" and record.disposition == "hostile"), "Live aggression changes marker disposition without a terrain rebuild")
	check(map.is_open() and not game.hero.in_combat, "Seeing a hostile alone does not enter combat")
	actor.alive = false
	check(not service.markers().any(func(record): return record.get("id") == "fixture"), "Dead creature markers disappear immediately")
	actor.alive = true
	actor.dimension = "dungeon:other"
	check(not service.markers().any(func(record): return record.get("id") == "fixture"), "Dungeon entities cannot leak onto overworld radar")
	actor.queue_free()
	check(map.focus.distance_to(map.target_focus) < 0.01 and map.view_span > 200,
		"Default overview frames the full discovered and undiscovered archipelago")
	check(map.map_viewport.find_world_3d() != game.get_world_3d(), "Map uses an isolated world with no gameplay simulation")
	check(map.mini_viewport.find_world_3d() == map.map_viewport.find_world_3d(), "Minimap shares map geometry")
	check(absf(float(map.map_viewport.size.x) / map.map_viewport.size.y - map.screen.size.x / map.screen.size.y) < 0.01, "Map viewport matches widescreen aspect without stretching")
	var discovery_before: int = service.discovered.size()
	map.pan(Vector2(5000, 2000))
	map._process(1.0)
	service.observe_player()
	check(map.focus.length() > service.biome.map_half, "Free panning extends beyond current world bounds")
	check(service.discovered.size() == discovery_before and service.biome.loaded_chunk_count() == chunks_before, "Panning neither reveals land nor loads gameplay chunks")
	check(game.hero.global_position == hero_before and game.camera.global_transform.is_equal_approx(camera_before), "Map navigation leaves player and gameplay camera untouched")
	map.zoom_by(0.0001)
	check(map.target_span == map.MIN_VIEW_SIZE, "Zoom-in is clamped")
	map.zoom_by(100000)
	check(map.target_span <= maxf(512.0, service.biome.map_world_half * 8.0),
		"Zoom-out remains clamped beyond the extended island world scale")
	map.overview()
	map._process(1.0)
	var down := InputEventScreenTouch.new()
	down.index = 1
	down.position = Vector2(500, 300)
	down.pressed = true
	map._canvas_input(down)
	down = down.duplicate()
	down.index = 2
	down.position = Vector2(600, 300)
	map._canvas_input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(650, 300)
	var old_span: float = map.target_span
	map._canvas_input(drag)
	check(map.target_span < old_span, "Pinch zooms the map")
	map.fingers.clear()
	var old_mana: float = game.mana
	await key(KEY_1)
	await key(KEY_SPACE)
	check(game.mana == old_mana and game.controls.modal_open(), "Map focus blocks abilities and Space interaction")
	check(service.search("forge").size() == 1 and service.search("secret undiscovered").is_empty(), "Search lists only discovered POIs")
	check(service.visibility_at(Vector3(80,0,80)) == 0, "Unvisited distant land stays concealed")
	game.hero.global_position = Vector3(50,0,0)
	service.observe_player()
	check(service.visibility_at(hero_before) == 1 and service.visibility_at(game.hero.global_position) == 2, "Explored terrain dims while nearby player terrain is visible")
	game.hero.global_position = hero_before
	map.close_map()
	game.hero.update_combat(7)
	check(map.open_map(), "Map reopens without combat")
	game.hero.take_hit(1)
	check(not map.is_open() and game.hero.in_combat, "Actual damage closes the map immediately")
	check(not map.open_map(), "Combat prevents reopening")
	game.hero.update_combat(7)
	check(map.open_map(), "Combat timeout permits reopening")
	await key(KEY_M)
	check(not map.is_open(), "M closes the map")
	await key(KEY_M)
	check(map.is_open(), "M opens the map")
	await key(KEY_ESCAPE)
	check(not map.is_open(), "Escape closes the map")
	map.input_guard_until = 0
	var mini_tap := InputEventScreenTouch.new()
	mini_tap.device = 0
	mini_tap.index = 7
	mini_tap.pressed = true
	mini_tap.position = game.hud.minimap.get_global_rect().get_center() + Vector2(10, 10)
	map._input(mini_tap)
	check(not map.is_open() and map.mini_touch_index == 7, "Minimap touch reserves movement instead of expanding the map")
	mini_tap.pressed = false
	map._input(mini_tap)
	check(not map.is_open() and map.mini_touch_index == -1, "Minimap release does not open the world map")
	check(game.hud.map_expand_button.get_node_or_null("ExpandArrowsIcon") != null, "Dedicated gold two-arrow expand button is separate from circular minimap")
	var zone_rect: Rect2 = game.hud.zone_pill.get_global_rect()
	var expand_rect: Rect2 = game.hud.map_expand_button.get_global_rect()
	check(expand_rect.position.x >= zone_rect.end.x + 1.0 and absf(expand_rect.get_center().y - zone_rect.get_center().y) <= 8.0, "Map-expand icon is beside zone name, not covering its text")
	check(not map._minimap_hit(game.hud.map_expand_button.get_global_rect().get_center()), "Expand button cannot accidentally trigger map click-to-move")
	game.hud.map_expand_button.pressed.emit()
	check(map.is_open(), "Dedicated expand button opens full-screen island map")
	map.close_map()
	map.relief.schedule(game.hero.global_position)
	for i in range(300): map.relief.tick()
	var samples: int = service.cache.sample_count
	var builds: int = map.relief.build_count
	game.camera_angle += TAU
	for i in range(30): map._process(0.1)
	check(service.cache.sample_count == samples and map.relief.build_count == builds, "Stationary camera orbit does not rebuild completed terrain")
	check(map.relief.meshes.size() <= map.relief.MAX_MESHES, "Map mesh memory budget is bounded")
	game.inventory.wood = 17
	game._save()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(saved.map_state.world_id == service.world_id and saved.inventory.wood == 17, "Map state saves alongside existing player data")
	var count: int = service.discovered.size()
	var changed_seed: Dictionary = saved.map_state.duplicate(true)
	changed_seed.world_id = "fields:other"
	service.import_state(changed_seed)
	check(service.discovered.is_empty(), "Exploration cannot cross world seeds")
	var invalid_cells: Dictionary = saved.map_state.duplicate(true)
	invalid_cells["cells"] = [[999999, 999999], [-999999, -999999], [0, 0]]
	service.import_state(invalid_cells)
	check(service.discovered.size() == 1 and service.discovered.has(Vector2i.ZERO), "Off-island save data cannot stall incremental map geometry")
	service.import_state(saved.map_state)
	check(service.discovered.size() == count, "Discovery survives JSON serialization")
	game.queue_free()
	await process_frame
	var continued = scene.instantiate()
	continued.save_path = "res://.map-test-save.json"
	root.add_child(continued)
	await process_frame
	check(continued.inventory.wood == 17 and continued.map_service.discovered.size() >= count, "Continue restores both exploration and inventory")
	saved.erase("map_state")
	var legacy := FileAccess.open(continued.save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify(saved))
	legacy.close()
	continued._load()
	check(continued.inventory.wood == 17 and continued.map_service.discovered.is_empty(), "Old saves keep inventory and begin without inherited exploration")
	continued.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.map-test-save.json"))
	print("WORLD MAP RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
