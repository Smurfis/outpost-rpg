extends SceneTree
## godot --headless --path . -s res://tests/fractal_inventory_tombstones.gd
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL GRAVES: " + description)
	else:
		print("PASS GRAVES: " + description)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		check(false, "World loads")
		quit(1)
		return
	var game = scene.instantiate()
	var save: String = "user://fractal_inventory_graves_regression.json"
	game.save_path = save
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.hero.set_physics_process(false)
	game.inventory["wood"] = 10
	game.inventory["stone"] = 4
	game.show_inventory()
	var panel = game.menu.inventory_window
	panel._change_filter("resource")
	var wood_tile: Button = panel.inventory_grid.get_node_or_null("Item_wood") as Button
	check(wood_tile != null and bool(wood_tile.allow_inventory_discard), "Resources can start drag outside bag")
	check(game.can_discard_item("wood"), "Raw resource is discardable")
	panel._request_discard("wood")
	check(int(game.inventory["wood"]) == 10 and panel.pending_discard_id == "wood", "Discard waits for confirmation")
	panel.discard_dialog.hide() # Cancel means no server-side inventory mutation.
	check(int(game.inventory["wood"]) == 10, "No leaves inventory intact")
	panel._request_discard("wood")
	panel._confirm_discard()
	check(int(game.inventory["wood"]) == 0, "Yes permanently destroys confirmed stack")
	game.menu.close_page()
	game.inventory["wood"] = 8
	game.inventory["spear"] = 1
	game.equipment["weapon"] = "spear"
	game.best_craft_rolls["spear"] = {"rarity": 2}
	game.on_player_defeated(game.hero.global_position)
	check(int(game.inventory["wood"]) == 0 and int(game.inventory["spear"]) == 0, "Death removes items and equipment from player")
	check(game.equipment["weapon"] == "training_blade" and game.death_tombstones.size() == 1, "Death makes one recoverable tombstone")
	var grave_id: String = str(game.death_tombstones.keys()[0])
	check(int(game.tombstone_contents(grave_id).get("wood", 0)) == 8, "Tombstone contains lost resources")
	game.open_tombstone(grave_id)
	check(game.menu.current_page == "storage" and game.menu.inventory_window.storage_tombstone_id == grave_id, "Grave opens in live storage inventory")
	check(game.take_tombstone_item(grave_id, "wood") == 8, "Resources are recoverable")
	check(game.take_tombstone_item(grave_id, "spear") == 1, "Weapon is recoverable")
	check(not game.death_tombstones.has(grave_id), "Empty tombstone is removed")
	game.menu.close_page()
	game.inventory["stone"] = 5
	game.on_player_defeated(Vector3(5, 1, 3))
	check(game.death_tombstones.size() == 1, "A later death creates another grave")
	var saved_grave: String = str(game.death_tombstones.keys()[0])
	game._save()
	game.queue_free()
	await process_frame
	var reload = scene.instantiate()
	reload.save_path = save
	root.add_child(reload)
	await process_frame
	check(reload.death_tombstones.has(saved_grave), "Unclaimed grave survives Continue save/load")
	check(int(reload.tombstone_contents(saved_grave).get("stone", 0)) == 5, "Saved grave contents survive restart")
	check(int(reload.inventory.get("spear", 0)) == 0, "Past spear quest never duplicates a lost weapon")
	reload.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	print("GRAVE INVENTORY RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
