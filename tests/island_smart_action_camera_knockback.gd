extends SceneTree
## Mobile integration: tool swipe selector, 45 degree camera orbit, safe
## impulses, deterministic irregular island, coastline foam and water shader.
var failed: int = 0
func _initialize() -> void:
	call_deferred("_run")
func verify(ok: bool, message: String) -> void:
	if ok:
		print("PASS ISLAND UX: " + message)
	else:
		failed += 1
		push_error("FAIL ISLAND UX: " + message)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var source: PackedScene = load("res://scenes/main.tscn")
	verify(source != null, "Outpost scene still imports")
	if source == null:
		quit(1)
		return
	var game = source.instantiate()
	root.add_child(game)
	await process_frame
	var terrain: Node = game.get_node_or_null("VoxelAtmosphere")
	verify(terrain != null, "Fields chunk streaming available")
	if terrain == null:
		quit(1)
		return
	verify(terrain.is_land_at(0.0, 0.0), "Camp is always dry, walkable land")
	verify(not terrain.is_land_at(94.0, 94.0), "Diagonal world corners are ocean rather than square land")
	verify(not terrain.is_land_at(95.0, 0.0), "Beyond the coastal headlands is ocean")
	verify(not terrain.is_land_at(0.0, 95.0), "Coastline never reaches the straight outer Z border")
	var water: MeshInstance3D = terrain.get_node_or_null("DistantWaterHorizon") as MeshInstance3D
	verify(water != null and water.material_override is ShaderMaterial, "Ocean is rendered with animated water shader")
	if water != null and water.material_override is ShaderMaterial:
		var shader: Shader = (water.material_override as ShaderMaterial).shader
		verify(shader != null and shader.code.contains("TIME") and shader.code.contains("ripples"), "Water texture ripples animate over time")
	var mixed: bool = false
	var coast_changes: int = 0
	for a in range(64, 96, 2):
		if terrain.is_land_at(float(a), 0.0) != terrain.is_land_at(float(a), 68.0):
			mixed = true
		if a < 94 and terrain.is_land_at(float(a), 30.0) != terrain.is_land_at(float(a + 2), 30.0):
			coast_changes += 1
	verify(mixed or coast_changes > 0, "Ocean border follows local coastline rather than uniform square cutoff")
	terrain.update_streaming_for(Vector3(79, 0.0, 68))
	var has_foam: bool = false
	for node in terrain.get_children():
		if str(node.name).begins_with("ShoreFoam_"):
			has_foam = true
			break
	verify(has_foam, "Water-facing coastal chunks stream batched beach foam")
	var old_camera_yaw: float = float(game.camera_angle_target)
	game.rotate_camera(1)
	verify(game.camera_angle_target > old_camera_yaw, "Players can manually rotate the isometric camera")
	game._camera(0.5)
	verify(not is_equal_approx(game.camera_angle, old_camera_yaw), "Camera orbit actually updates")
	game.rotate_camera(-1)
	verify(is_equal_approx(game.camera_angle_target, old_camera_yaw), "Camera rotates in both directions")
	var camera_hint: Label = game.hud.root.get_node_or_null("CameraDragHint") as Label
	verify(camera_hint != null, "Camera rotation is guided by a nonblocking drag hint")
	verify(game.hud.root.get_node_or_null("RotateCameraLeft") == null and game.hud.root.get_node_or_null("RotateCameraRight") == null, "Discrete camera buttons do not block the world")
	var drag_start: Vector2 = game.hud.get_viewport().get_visible_rect().size * Vector2(0.50, 0.42)
	var press := InputEventScreenTouch.new()
	press.index = 12
	press.pressed = true
	press.position = drag_start
	game.hud._input(press)
	verify(game.hud.camera_drag_finger == 12, "Touching open world captures a camera drag finger")
	var angle_before: float = game.camera_angle_target
	var orbit_drag := InputEventScreenDrag.new()
	orbit_drag.index = 12
	orbit_drag.position = drag_start + Vector2(10.0, 0.0)
	orbit_drag.relative = Vector2(10.0, 0.0)
	orbit_drag.screen_relative = Vector2(10.0, 0.0)
	game.hud._input(orbit_drag)
	verify(is_equal_approx(game.camera_angle_target, angle_before), "Tiny pre-hold finger wobble does not rotate camera")
	game.hud._process(0.88)
	verify(game.hud.camera_hold_ready, "Holding the world for 0.82 seconds enables camera orbit")
	orbit_drag.position = drag_start + Vector2(75.0, 0.0)
	orbit_drag.relative = Vector2(65.0, 0.0)
	orbit_drag.screen_relative = Vector2(65.0, 0.0)
	game.hud._input(orbit_drag)
	verify(absf(game.camera_angle_target - angle_before) > 0.2, "Android long-hold then drag rotates camera continuously")
	var release := InputEventScreenTouch.new()
	release.index = 12
	release.pressed = false
	release.position = orbit_drag.position
	game.hud._input(release)
	verify(game.hud.camera_drag_finger == -1, "Camera drag finger releases cleanly")
	# Short, deliberate swipes must orbit without waiting for the long-hold.
	var fast_press := InputEventScreenTouch.new()
	fast_press.index = 17
	fast_press.pressed = true
	fast_press.position = drag_start
	game.hud._input(fast_press)
	var yaw_before_swipe: float = game.camera_angle_target
	var early_swipe := InputEventScreenDrag.new()
	early_swipe.index = 17
	early_swipe.position = drag_start + Vector2(48.0, 0.0)
	early_swipe.relative = Vector2(48.0, 0.0)
	early_swipe.screen_relative = Vector2(48.0, 0.0)
	game.hud._input(early_swipe)
	verify(game.hud.camera_drag_finger == 17 and game.hud.camera_hold_ready, "Deliberate drag activates orbit without hold")
	verify(absf(game.camera_angle_target - yaw_before_swipe) > 0.1, "Early world drag rotates camera instead of cancelling")
	var fast_release := InputEventScreenTouch.new()
	fast_release.index = 17
	fast_release.pressed = false
	fast_release.position = early_swipe.position
	game.hud._input(fast_release)
	verify(game.hud.camera_drag_finger == -1, "Fast orbit finger also releases cleanly")
	var main_action: Button = game.hud.root.get_node_or_null("Action_interact") as Button
	verify(main_action != null, "Primary interaction has a dedicated large touch target")
	verify(game.hud.tool_swap_button != null, "TOOLS is an independent medallion beside Interact")
	game.inventory["axe"] = 1
	game.inventory["pickaxe"] = 1
	verify(game.select_quick_tool("training_blade"), "Fallback blade is available to start cycling")
	# Android hold of INTERACT must never open the former Training Blade list.
	if main_action != null:
		var start: Vector2 = main_action.get_global_rect().get_center()
		var down := InputEventScreenTouch.new()
		down.index = 14
		down.pressed = true
		down.position = start
		game.hud._input(down)
		game.hud._process(0.55)
		verify(not game.hud.smart_tray_open and not game.hud.smart_tray.visible, "Long Interact hold never launches a tool selector")
		var lift := InputEventScreenTouch.new()
		lift.index = 14
		lift.pressed = false
		lift.position = start
		game.hud._input(lift)
		verify(game.active_quick_tool == "training_blade", "Interact long hold does not switch equipped tools")
	var swap_button: Button = game.hud.tool_swap_button
	if swap_button != null:
		var point: Vector2 = swap_button.get_global_rect().get_center()
		for requested in ["axe", "pickaxe"]:
			var tool_press := InputEventScreenTouch.new()
			tool_press.index = 15
			tool_press.position = point
			tool_press.pressed = true
			game.hud._input(tool_press)
			var tool_release := InputEventScreenTouch.new()
			tool_release.index = 15
			tool_release.position = point
			tool_release.pressed = false
			game.hud._input(tool_release)
			verify(game.active_quick_tool == requested and game.is_equipped(requested), "TOOLS tap equips owned " + requested)
		verify(not game.hud.smart_tray_open and not game.hud.smart_tray.visible, "Separate tool swapping never opens the old panel")
	verify(not game.select_quick_tool("iron_blade"), "Cannot quick-equip unowned weapon")
	verify(game.available_quick_tools().has("training_blade"), "Default blade remains available as fallback")

	var boar = get_first_node_in_group("enemies")
	verify(boar != null, "Hostile creature exists")
	if boar != null:
		boar.global_position = game.hero.global_position + Vector3(2.0, 0.0, 0.0)
		boar.receive_damage(8.0)
		verify(boar.knockback_velocity.length() > 4.0, "Damage pushes live boar away from attacker")
		game.hero.take_hit(5.0, boar.global_position)
		verify(game.hero.knockback_velocity.length() > 4.0, "Enemy strike pushes player back")
	game.queue_free()
	await process_frame
	print("ISLAND UX RESULT: %d failures" % failed)
	quit(0 if failed == 0 else 1)
