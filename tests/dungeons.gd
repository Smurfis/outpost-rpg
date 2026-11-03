extends SceneTree
## Integration: original PR #4 portal contract plus seeded rooms, stairs,
## bonus caches, persistent checkpoints, final completion and retry.
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _defeat_floor(instance: Node3D) -> void:
	var count: int = 0
	for enemy in get_nodes_in_group("dungeon_guardians"):
		if enemy.dungeon == instance:
			enemy.receive_damage(100000.0)
			count += 1
	check(instance.guards_remaining == 0, "Floor %d guardians defeated (%d defeated)" % [instance.current_floor, count])

func _run() -> void:
	var test_save: String = "user://outpost_dungeon_expansion_test.json"
	var test_game_save: String = "user://outpost_progress_expansion_test.json"
	for path in [test_save, test_game_save]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var source: PackedScene = load("res://scenes/main.tscn")
	check(source != null, "Outpost dungeon scene loads")
	if source == null:
		quit(1)
		return
	var game = source.instantiate()
	game.save_path = test_game_save
	game.get_node("Dungeons").save_path = test_save
	root.add_child(game)
	await process_frame
	await process_frame
	var manager = game.get_node_or_null("Dungeons")
	check(manager != null, "Existing dungeon manager attached")
	if manager == null:
		quit(1)
		return
	check(manager.entrances.size() == 5, "Five rarity-tier demo entrances appear")
	check(manager.chunks.size() == 5, "Distinct demo chunk registrations remain")
	var qualities: Dictionary = {}
	for portal in manager.entrances.values():
		qualities[int(portal.quality)] = true
		check(portal.label.text.contains("•"), "Portal shows a world-space rarity label")
	check(qualities.size() == 5, "All five rarity tiers represented")
	var rarity = load("res://scripts/dungeons/dungeon_rarity.gd")
	check(rarity.max_entrances(0) == 1 and rarity.max_entrances(4) == 3, "Chunk portal caps are unchanged")
	manager.register_chunk("dynamic", Rect2(Vector2(100, 100), Vector2(50, 50)), 4)
	check(manager.chunks.has("dynamic"), "Dynamic chunk registration works")
	var amount: int = manager.entrances.size()
	manager.register_chunk("dynamic", Rect2(Vector2(100, 100), Vector2(50, 50)), 4)
	check(manager.entrances.size() == amount, "Repeated chunk registration is idempotent")
	manager.unregister_chunk("dynamic")
	check(not manager.chunks.has("dynamic"), "Chunk unload unregisters entrances")
	var portal = manager.entrances["preview_rare:0"]
	var id: String = str(portal.entrance_id)
	game.hero.global_position = portal.global_position + Vector3(6.0, 0.35, 0)
	manager._on_portal_selected(portal)
	check(game.hero.interaction_moving, "Tap-from-range auto-approach remains available")
	game.hero.global_position = portal.global_position + Vector3(1.0, 0.35, 0)
	manager._update_overworld_action()
	check(manager.dimmer.visible, "Entry confirmation shown")
	manager._cancel_dialog()
	check(not manager.dimmer.visible and not game.hero.interaction_locked, "Cancel releases controls")
	manager._on_portal_selected(portal)
	manager._enter_confirmed()
	var instance = manager.active_instance
	check(instance != null, "Instanced dungeon created")
	if instance == null:
		quit(1)
		return
	check(instance.current_floor == 1 and instance.floor_count in [2,3], "Rare entrance spans 2–3 floors")
	check(instance.guards_remaining == 3, "First-floor Rare guardian count retained")
	check(LAYOUT.validate(instance.layout), "Instanced room graph passes reachability checks")
	check(game.hero.global_position.distance_to(instance.hero_spawn_point()) < 0.2, "Player is placed in the generated starting room")
	check(instance.floor_root != null and instance.floor_root.get_child_count() > 30, "KayKit modular dungeon geometry is instantiated")
	var first_pattern: String = str(instance.layout.get("pattern", ""))
	var expected_seed: int = int(instance.layout.get("seed", 0))
	var rebuilt: Dictionary = LAYOUT.generate(id, 2, 0)
	check(int(rebuilt["seed"]) == expected_seed and str(rebuilt["pattern"]) == first_pattern, "Floor layout reconstructs from entrance seed")
	var coins_before: int = int(game.inventory.get("coins", 0))
	var bonus_used: bool = false
	for floor_number in range(1, instance.floor_count + 1):
		check(LAYOUT.validate(instance.layout), "Floor %d graph is reachable" % floor_number)
		if instance.bonus_chests.size() > 0:
			var bonus_id: int = int(instance.bonus_chests.keys()[0])
			game.hero.global_position = instance.to_global(instance.bonus_chests[bonus_id]) + Vector3(0,0.35,1.2)
			var extra: Dictionary = instance.claim_bonus(bonus_id)
			check(not extra.is_empty() and extra.has("materials"), "Optional cache awards materials")
			check(instance.claim_bonus(bonus_id).is_empty(), "Bonus cache cannot be farmed repeatedly")
			manager._apply_reward(extra)
			bonus_used = true
		_defeat_floor(instance)
		game.hero.global_position = instance.chest_world_position() + Vector3(0,0.35,1.5)
		if floor_number < instance.floor_count:
			check(not instance.can_claim_chest() and instance.can_advance_floor(), "Intermediate floor gates stairs, not the final chest")
			manager._claim_chest()
			check(instance.current_floor == floor_number + 1, "Stairs advance to the next floor")
			check(int(manager.floor_checkpoints.get(id, 0)) == instance.current_floor, "Reached floor recorded for retry")
		else:
			check(instance.can_claim_chest(), "Final boss floor unlocks final chest")
			check(instance.claim_chest(), "Final chest can be claimed")
	check(bonus_used, "At least one optional reward cache was discovered")
	check(manager.active_instance == null, "Claiming final chest exits the instance")
	check(manager.completed_ids.has(id), "Completed portal ID is persisted")
	check(not manager.entrances.has(id), "Completed portal disappears")
	check(not manager.floor_checkpoints.has(id), "Clear removes saved checkpoint")
	check(int(game.inventory.get("coins", 0)) > coins_before, "Final chest pays currency")
	check(FileAccess.file_exists(test_save), "Dungeon progression saved in its separate file")
	manager.unregister_chunk("preview_rare")
	manager.register_chunk("preview_rare", Rect2(Vector2(-21,11),Vector2(14,14)),2,[Vector3(-18,0,18)],true)
	check(not manager.entrances.has(id), "Completed entrance remains absent on chunk reload")
	var retry = manager.entrances["preview_uncommon:0"]
	game.hero.global_position = retry.global_position + Vector3(0.5, 0.35, 0)
	manager._on_portal_selected(retry)
	manager._enter_confirmed()
	check(manager.active_instance != null, "Second entrance can be entered")
	manager._leave_pressed()
	check(manager.active_instance == null, "Leaving unloads active instance")
	check(manager.entrances.has("preview_uncommon:0"), "Abandoned entrance stays available")
	check(not manager.completed_ids.has("preview_uncommon:0"), "Abandon does not record completion")
	game.hero.global_position = retry.global_position + Vector3(0.5, 0.35, 0)
	manager._on_portal_selected(retry)
	manager._enter_confirmed()
	check(manager.active_instance != null, "Abandoned entrance can be retried")
	game.hero.health = 1.0
	game.hero.take_hit(200.0)
	manager._physics_process(0.016)
	check(manager.active_instance == null, "Death ends dungeon without clearing entrance")
	check(game.hero.global_position.distance_to(Vector3(0,0.35,0)) < 1.0, "Death respawns at existing overworld location")
	check(manager.entrances.has("preview_uncommon:0"), "Death preserves portal")
	game.queue_free()
	for path in [test_save, test_game_save]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("DUNGEON RESULT: %d failed assertion(s)." % failures)
	quit(0 if failures == 0 else 1)
