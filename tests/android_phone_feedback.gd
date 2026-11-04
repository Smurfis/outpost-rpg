extends SceneTree
## Regression of real Android feedback: terrain, swing, labels and touch crafting.
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS PHONE UX: " + label)
	else:
		failed += 1
		push_error("FAIL PHONE UX: " + label)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "World scene is available")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var terrain = game.get_node("VoxelAtmosphere")
	check(terrain.stream_enabled, "Terrain streaming is enabled")
	check(terrain.get_node_or_null("SteppedDistanceCliffs") == null, "Mobile map no longer has giant-block perimeter")
	check(terrain.get_node_or_null("DistantWaterHorizon") != null, "Water horizon masks the unfinished map edge")
	var camp_height: float = terrain.surface_y_at(0.5, 0.5)
	check(is_equal_approx(camp_height, -0.055), "Original camp elevation is preserved")
	var terrain_outside: Array = [terrain.surface_y_at(38.0, 30.0), terrain.surface_y_at(55.0, 12.0), terrain.surface_y_at(70.0, 66.0)]
	check(terrain_outside.all(func(y: float) -> bool: return y <= camp_height + 0.001), "Fields descend rather than making player climb when leaving camp")
	check(terrain_outside.any(func(y: float) -> bool: return y < camp_height - 0.49), "Fields have recognisable rolling downhill levels")
	var workbench = game.stations["workbench"]
	var forge = game.stations["forge"]
	game.hero.global_position = Vector3(0, 0.35, 0)
	await process_frame
	check(workbench.station_label != null and workbench.station_label.visible, "Nearby crafting bench shows its label")
	check(forge.station_label != null and not forge.station_label.visible, "Distant crafting bench hides its label")
	check(workbench.station_label.no_depth_test == false, "Crafting label respects model occlusion")
	var portal = game.get_node("Dungeons").entrances["preview_common:0"]
	check(portal.label != null and not portal.label.visible, "Distant dungeon title hidden")
	game.hero.global_position = portal.global_position + Vector3(2, 0, 0)
	await process_frame
	check(portal.label.visible, "Dungeon title appears when player approaches")
	check(not portal.label.no_depth_test, "Dungeon title respects avatar depth")
	game.hero.global_position = Vector3(0, 0.35, 0)
	game.hero.swing()
	await physics_frame
	check(game.hero.right_arm.rotation.x > 0.0, "Attack arm swings toward player's local forward, not backward")
	game.hero.global_position = game.station_positions["workbench"] + Vector3(0, 0.35, 0)
	game.show_crafting()
	await process_frame
	check(game.menu.left_scroll.visible and not game.menu.right_scroll.visible, "Crafting opens with one full-width recipe page")
	check(game.menu.left_scroll.get_script() != null, "Recipe list uses touchscreen swipe control")
	game.menu._recipe_change("spear")
	await process_frame
	check(not game.menu.left_scroll.visible and game.menu.right_scroll.visible, "Tapping recipe opens a separate details page")
	game.menu._begin_prepare()
	check(game.menu.craft_step == "prepare", "Details moves to preparation flow")
	game.menu._back_to_browse()
	check(game.menu.left_scroll.visible, "Back returns to full recipe list")
	game.queue_free()
	await process_frame
	print("PHONE UX RESULT: %d failures" % failed)
	quit(0 if failed == 0 else 1)
