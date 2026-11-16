extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS BUILDING: " + message)
	else:
		failures += 1
		push_error("FAIL BUILDING: " + message)

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://building_test.json"
	root.add_child(game)
	await physics_frame
	game.inventory.wood = 3
	game.experimental_building_enabled = true
	game.building.set_enabled(true)
	var target: Vector3 = game.hero.global_position + Vector3(2.0, -0.35, -2.0)
	game.building.update_preview(game.camera.unproject_position(target))
	check(game.building.preview.visible, "Cursor hit displays a placement preview")
	check(game.building.preview_valid, "Free reachable terrain face accepts placement")
	var cell: Vector3i = game.building.preview_cell
	check(game.building.place_preview(), "Placement consumes the valid preview")
	check(game.inventory.wood == 2, "Placement costs one wood")
	check(game.building.blocks.has(cell), "Placed block has a persistent collision body")
	await physics_frame
	var first_body: StaticBody3D = game.building.blocks[cell]
	var side: Vector3 = first_body.global_position + Vector3(0.5, 0, 0)
	game.building.update_preview(game.camera.unproject_position(side))
	check(game.building.preview.visible and game.building.preview_valid, "Aiming at a block side previews a supported bridge extension")
	var next_cell: Vector3i = game.building.preview_cell
	check(next_cell == cell + Vector3i.RIGHT, "Side preview snaps to the adjacent voxel")
	check(game.building.place_preview(), "A second block extends from the first")
	check(game.inventory.wood == 1 and game.building.blocks.has(next_cell), "Bridge consumes wood and creates solid block")
	check(not game.building.can_place(cell), "Existing blocks cannot be overwritten")
	check(not game.building.can_place(Vector3i(100, 0, 100)), "Out-of-range placement is rejected")
	var records: Array = game.building.serialize()
	check(records.size() == 2, "Save data contains both placed blocks")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.save_path)) if FileAccess.file_exists(game.save_path) else {}
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	check(saved.get("placed_blocks", []).size() == 2, "Progress save persists both placements")
	game.queue_free()
	await process_frame
	var again = load("res://scenes/main.tscn").instantiate()
	again.save_path = "user://building_test.json"
	root.add_child(again)
	await physics_frame
	check(again.building.blocks.has(cell) and again.building.blocks.has(next_cell), "Reload restores both collision blocks")
	again.queue_free()
	await process_frame
	print("BUILDING RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
