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
	root.set_meta("outpost_input_mode", "touch")
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
	# Actual projected station-tap path: it must not be confused with
	# camera rotation or walking-joystick input.
	game.hero.global_position = Vector3(-8.0, 0.35, 3.0)
	game._camera(0.5)
	var campfire_click: Vector2 = game.camera.unproject_position(game.stations["campfire"].global_position + Vector3.UP * 0.9)
	check(game.station_at_screen(campfire_click) == "campfire", "Tapped physical campfire selects its Crafting Station identity")
	var first_touch := InputEventScreenTouch.new()
	first_touch.index = 22
	first_touch.pressed = true
	first_touch.position = campfire_click
	game.hud._input(first_touch)
	print("PHONE PRESS DEBUG: finger=", game.hud.camera_drag_finger, " joystick_finger=", game.hud.finger, " desktop=", game.hud.desktop_mode)
	var release := InputEventScreenTouch.new()
	release.index = 22
	release.pressed = false
	release.position = campfire_click
	game.hud._input(release)
	var raw_pick: Dictionary = preload("res://scripts/interaction/world_picker.gd").resolve(game, campfire_click)
	print("PHONE ROUTE DEBUG: mobile=", not game.controls.desktop, " free_touch=", game.hud._can_start_camera_drag(campfire_click), " ui_block=", game.controls.point_over_ui(campfire_click), " target=", raw_pick.get("target", null), " navigate=", game.controls.navigating)
	check(game.controls.navigating and game.controls.target == game.stations["campfire"], "Station tap starts shared, range-checked A-star walking instead of camera orbit")
	if not game.controls.navigating:
		var direct: bool = game.controls.primary_at(campfire_click, false)
		print("PHONE DIRECT DEBUG: accepted=", direct, " target=", game.controls.target, " moving=", game.hero.interaction_moving, " toast=", game.hud.toast_label.text)
	check(game.hero.station_waypoints.size() > 0, "Shared route uses actual waypoints rather than teleporting")
	for waypoint in game.hero.station_waypoints:
		var separation: float = Vector2(waypoint.x - game.station_positions["campfire"].x, waypoint.z - game.station_positions["campfire"].z).length()
		check(separation >= 1.5, "A-star route never cuts straight through the station's solid centre")
	game.hero.global_position = game.station_positions["campfire"] + Vector3(2.5, 0.35, 0)
	game.controls._physics_process(0.016)
	check(game.menu.visible and game.menu.selected_station == "campfire", "Shared arrival opens only the tapped station's recipes")
	game.hero.take_hit(4.0)
	check(not game.menu.visible and game.station_walk_target.is_empty(), "Enemy damage closes station modal and cancels navigation")
	game.hero.global_position = game.station_positions["workbench"] + Vector3(0, 0.35, 0)
	game.show_crafting()
	await process_frame
	check(game.menu.left_scroll.visible and game.menu.right_scroll.visible, "Crafting opens with Albion recipe list and details together")
	check(game.menu.left_scroll.get_script() != null, "Recipe list uses touchscreen swipe control")
	check(game.menu.title.text.contains("WOODWORK") and game.menu.station_badge.visible, "Actual interacted station determines window title and icon")
	check(game.menu.station_tabs.get_child_count() == 0 and not game.menu.craft_stage_strip.visible, "No five-station tabs or redundant stage cards")
	game.menu._recipe_change("spear")
	await process_frame
	check(game.menu.left_scroll.visible and game.menu.right_scroll.visible, "Tapping a recipe updates tooltip without losing list")
	check(game.menu.details.find_child("StationCraftAction", true, false) != null, "Selected recipe offers a direct Craft action")
	game.menu._back_to_browse()
	check(game.menu.left_scroll.visible and game.menu.right_scroll.visible, "Browsing remains accessible without navigation screens")
	game.queue_free()
	await process_frame
	print("PHONE UX RESULT: %d failures" % failed)
	quit(0 if failed == 0 else 1)
