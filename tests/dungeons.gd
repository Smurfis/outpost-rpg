extends SceneTree
## Integration contract: real scene, real hero, deterministic preview entrances and rewards.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var test_save: String = "user://outpost_dungeon_test_only.json"
	var file_path: String = ProjectSettings.globalize_path(test_save)
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(file_path)
	var source: PackedScene = load("res://scenes/main.tscn")
	check(source != null, "Outpost with dungeon manager loads")
	if source == null:
		quit(1)
		return
	var game = source.instantiate()
	var initial_manager = game.get_node_or_null("Dungeons")
	if initial_manager != null:
		initial_manager.save_path = test_save
	root.add_child(game)
	await process_frame
	await process_frame
	var manager = game.get_node_or_null("Dungeons")
	check(manager != null, "Dungeon manager attached to the main scene")
	if manager == null:
		quit(1)
		return
	check(manager.entrances.size() == 5, "Starter demonstration has five entrances")
	check(manager.chunks.size() == 5, "Demo entrances are assigned to five independent chunks")
	var qualities: Dictionary = {}
	for portal in manager.entrances.values():
		qualities[int(portal.quality)] = true
		check(portal.label != null and portal.label.text.contains("•"), "Portal includes colored world-space quality label")
	check(qualities.size() == 5, "All Common through Legendary tiers are represented")
	var rarity = load("res://scripts/dungeons/dungeon_rarity.gd")
	check(rarity.max_entrances(0) == 1 and rarity.max_entrances(4) == 3, "Chunk capacity scales with quality")
	check(rarity.color(4).to_html(false) == "ff8000", "Legendary uses exact WoW rarity orange")
	manager.register_chunk("integration_dynamic", Rect2(100.0, 100.0, 40.0, 40.0), 4)
	check(manager.chunks.has("integration_dynamic"), "External chunk registration works")
	var dynamic_state: Dictionary = manager.chunks["integration_dynamic"]
	check((dynamic_state.get("portals", []) as Array).size() <= 3, "Legendary chunk never exceeds three entrance slots")
	manager.register_chunk("integration_dynamic", Rect2(100.0, 100.0, 40.0, 40.0), 4)
	check(manager.chunks.size() == 6, "Repeated register calls do not duplicate entrances")
	manager.unregister_chunk("integration_dynamic")
	check(not manager.chunks.has("integration_dynamic"), "Chunk unload removes tracked entrance nodes")

	var portal = manager.entrances["preview_rare:0"]
	var cleared_id: String = portal.entrance_id
	game.hero.global_position = portal.global_position + Vector3(6.0, 0.35, 0)
	manager._on_portal_selected(portal)
	check(game.hero.interaction_moving, "Tapping from far away triggers run-to-portal")
	game.hero.global_position = portal.global_position + Vector3(1, 0.35, 0)
	await process_frame
	check(manager.dimmer.visible, "Approaching portal opens confirmation dialog")
	check(game.hero.interaction_locked, "Confirmation temporarily disables walking")
	manager._cancel_dialog()
	check(not manager.dimmer.visible and not game.hero.interaction_locked, "Cancel restores controls")
	manager._on_portal_selected(portal)
	manager._enter_confirmed()
	check(manager.active_instance != null, "Confirm creates a separate dungeon instance")
	check(manager.active_instance.guards_remaining == 3, "Rare dungeon requires three guardians")
	check(game.hero.global_position.distance_to(manager.active_instance.hero_spawn_point()) < 0.2, "Entering relocates the hero inside the instanced cell")
	var instance = manager.active_instance
	var gold_before: int = int(game.inventory.get("coins", 0))
	for enemy in get_nodes_in_group("enemies"):
		if enemy.name == "CryptGuardian" and enemy.dungeon == instance:
			enemy.receive_damage(10000.0)
	check(instance.guards_remaining == 0 and instance.can_claim_chest(), "Guardians unlock final chest")
	game.hero.global_position = instance.chest_world_position() + Vector3(0, 0.35, 1.5)
	check(instance.claim_chest(), "Chest can be claimed only after clearing")
	check(manager.active_instance == null, "Claiming chest ends and unloads the dungeon")
	check(manager.completed_ids.has(cleared_id), "Completed entrance ID recorded")
	check(not manager.entrances.has(cleared_id), "Completed entrance disappears from world")
	check(int(game.inventory.get("coins", 0)) > gold_before, "Final chest awards persistent currency")
	check(FileAccess.file_exists(test_save), "Clears saved separately from Outpost inventory")
	manager.unregister_chunk("preview_rare")
	manager.register_chunk("preview_rare", Rect2(Vector2(-21, 11), Vector2(14, 14)), 2, [Vector3(-18, 0, 18)], true)
	check(not manager.entrances.has(cleared_id), "Cleared entrance never respawns after chunk reload")

	var remaining = manager.entrances["preview_uncommon:0"]
	game.hero.global_position = remaining.global_position + Vector3(0.5, 0.35, 0)
	manager._on_portal_selected(remaining)
	manager._enter_confirmed()
	check(manager.active_instance != null, "Second entrance can instantiate another dungeon")
	manager._leave_pressed()
	check(manager.active_instance == null, "Leaving without chest unloads dungeon")
	check(manager.entrances.has("preview_uncommon:0"), "Abandoned entrance remains available to retry")
	check(not manager.completed_ids.has("preview_uncommon:0"), "Abandoning does not record a clear")

	game.hero.global_position = remaining.global_position + Vector3(0.5, 0.35, 0)
	manager._on_portal_selected(remaining)
	manager._enter_confirmed()
	check(manager.active_instance != null, "Abandoned dungeon can be re-entered")
	game.hero.health = 1.0
	game.hero.take_hit(200.0)
	manager._physics_process(0.016)
	check(manager.active_instance == null, "Death releases active dungeon instance")
	check(game.hero.global_position.distance_to(Vector3(0, 0.35, 0)) < 1.0, "Death preserves existing outpost respawn position")
	check(manager.entrances.has("preview_uncommon:0"), "Death does not consume entrance")

	game.queue_free()
	DirAccess.remove_absolute(file_path)
	print("DUNGEON RESULT: %d failed assertion(s)." % failures)
	quit(0 if failures == 0 else 1)
