extends SceneTree

var failures := 0

func _initialize() -> void:
	# Exercise the portal registry separately from the physical mine.
	OS.set_environment("OUTPOST_TEST_PROCEDURAL_CAVE","1")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS SITE STREAM: " + message)
	else:
		failures += 1
		push_error("FAIL SITE STREAM: " + message)

func run() -> void:
	var id := "%d_%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
	var save := "user://site_stream_%s.json" % id
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://site_player_%s.json" % id
	game.get_node("Dungeons").save_path = save
	root.set_meta("outpost_new_adventure", true)
	root.add_child(game)
	await process_frame
	var manager = game.get_node("Dungeons")
	var island = game.terrain_surface.archipelago
	island.set_process(false)
	var at: Vector3 = island.terrain.caves.entrances[0]
	var cell: Vector2i = island._cell_at(at)
	island._build_chunk(cell)
	var site_id: String = island.MINE_SITE_ID
	check(manager.world_sites.sites.has(site_id), "Island chunk registers its persistent site")
	check(manager.world_site_nodes.has(site_id), "Entrance is spawned")
	var portal = manager.world_site_nodes[site_id]
	var original: Vector3 = portal.global_position
	print("MINE TEST LOCATION: ", original)
	check(original == at, "Entrance matches existing cave coordinates")
	manager.register_world_site(site_id, island.terrain.seed, Vector3i(0, 0, 0), "island_%d_%d" % [cell.x, cell.y])
	check(manager.world_site_nodes.size() == 1 and manager.world_site_nodes[site_id] == portal, "Duplicate registration leaves one entrance")
	manager._prompt_to_enter(portal)
	check(manager.world_sites.sites[site_id].state == "discovered", "Inspection persists discovery")
	manager._cancel_dialog()
	island._unload(cell)
	check(manager.world_sites.sites.has(site_id) and not manager.world_site_nodes.has(site_id), "Unload retains record but removes runtime entrance")
	await process_frame
	island._build_chunk(cell)
	check(manager.world_site_nodes[site_id].global_position == original, "Reload restores exact entrance position")
	portal = manager.world_site_nodes[site_id]
	manager._prompt_to_enter(portal)
	var balance: int = int(game.inventory.get("coins", 0))
	manager._enter_confirmed()
	check(manager.active_instance != null and manager.active_instance.goblin_site, "Entrance opens the existing dungeon with goblins")
	check(manager.world_sites.sites[site_id].state == "active", "Entry persists active site state")
	check(manager.world_sites.claim_reward(site_id, "fixture", "test"), "Registry accepts a claim identifier without distributing a reward")
	manager._on_dungeon_completed(manager.active_instance, {"coins": 999})
	check(manager.world_sites.sites[site_id].state == "cleared" and int(game.inventory.get("coins", 0)) == balance, "Completion persists without issuing site rewards")
	check(not manager.completed_ids.has(site_id), "Site does not become a removed portal dungeon")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(save))
	check(saved is Dictionary and saved.get("version") == 4, "Versioned dungeon save was written")
	var copy = load("res://scripts/dungeons/dungeon_manager.gd").new()
	copy.save_path = save
	copy._load_clears()
	check(copy.world_sites.sites.has(site_id) and copy.world_sites.sites[site_id].state == "cleared", "Completion survives save and load")
	check(copy.world_sites.sites[site_id].reward_claims.has("0:fixture:test"), "Reward claim identifier survives save and load")
	check(FileAccess.file_exists(save + ".bak"), "Previous save is retained as a backup")
	var recovered_path := "user://site_recovery_%s.json" % id
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(save), ProjectSettings.globalize_path(recovered_path + ".bak")) == OK, "Recovery fixture created")
	var recovered = load("res://scripts/dungeons/dungeon_manager.gd").new()
	recovered.save_path = recovered_path
	recovered._load_clears()
	check(recovered.world_sites.sites.has(site_id) and recovered.world_sites.sites[site_id].state == "cleared", "Missing primary recovers from backup")
	recovered.free()
	var legacy_path := "user://legacy_dungeon_%s.json" % id
	var legacy := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 3, "completed": ["old_portal"], "checkpoints": {"old_portal_2": 2}, "broken_props": {}}))
	legacy.close()
	var old_manager = load("res://scripts/dungeons/dungeon_manager.gd").new()
	old_manager.save_path = legacy_path
	old_manager._load_clears()
	check(old_manager.completed_ids.has("old_portal") and old_manager.floor_checkpoints.get("old_portal_2") == 2, "Legacy portal progress loads unchanged")
	old_manager.free()
	copy.free()
	game.queue_free()
	await process_frame
	print("SITE STREAM RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
