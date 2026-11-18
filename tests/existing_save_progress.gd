extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL EXISTING SAVE: " + message)
	else:
		print("PASS EXISTING SAVE: " + message)

func run() -> void:
	var id := "%d_%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
	var path := "user://existing_save_test_%s.json" % id
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create isolated save fixture")
		quit(1)
		return
	file.store_string(JSON.stringify({"version": 4, "inventory": {"spear": 1, "wood": 17},
		"equipment": {"weapon": "spear"}, "experience": 321, "kills": 12,
		"weapon_mastery_xp": {"spear": 45}, "spear": true}))
	file.close()
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = path
	game.get_node("Dungeons").save_path = "user://existing_dungeon_test_%s.json" % id
	root.add_child(game)
	await process_frame
	check(game.inventory.get("wood") == 17 and game.inventory.get("spear") == 1, "Legacy inventory is retained")
	check(game.equipment.get("weapon") == "spear", "Equipped weapon is retained")
	check(game.experience == 321 and game.kills == 12 and game.weapon_mastery_xp.get("spear") == 45, "Progression is retained")
	game._save()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved is Dictionary and saved.get("version") == 5 and saved.inventory.get("wood") == 17 and saved.equipment.get("weapon") == "spear", "Upgraded save retains inventory and equipment")
	game.queue_free()
	print("EXISTING SAVE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
