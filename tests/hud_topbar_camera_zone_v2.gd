extends SceneTree
## Real touchscreen top chrome, stable isometric camera and non-flickering map.
## All three inputs are press + release: press-and-hold is no longer required.
const ZONES = preload("res://scripts/world/outpost_zone_names.gd")
const MAP = preload("res://scripts/ui/live_world_minimap.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, msg: String) -> void:
	if ok:
		print("PASS TOPBAR CAMERA: " + msg)
	else:
		failures += 1
		push_error("FAIL TOPBAR CAMERA: " + msg)

func _tap(hud: Node, button: Button, index: int) -> void:
	var centre: Vector2 = button.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = index
	down.position = centre
	down.pressed = true
	hud._input(down)
	var up := InputEventScreenTouch.new()
	up.index = index
	up.position = centre
	up.pressed = false
	hud._input(up)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var packed: PackedScene = load("res://scenes/main.tscn")
	verify(packed != null, "Outpost scene loads")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var holder: Control = hud.root
	var menu_button: Button = holder.get_node_or_null("TopRightMenuButton") as Button
	var wallet_button: Button = holder.get_node_or_null("WalletCollapse") as Button
	var bag_button: Button = holder.get_node_or_null("Action_bag") as Button
	verify(menu_button != null and wallet_button != null and bag_button != null, "MENU / WALLET / BAG have actual individual touch surfaces")
	if menu_button == null or wallet_button == null or bag_button == null:
		quit(1)
		return

	var y0: Vector2 = menu_button.get_global_rect().get_center()
	var hold_down := InputEventScreenTouch.new()
	hold_down.index = 16
	hold_down.position = y0
	hold_down.pressed = true
	hud._input(hold_down)
	hud._process(0.42)
	verify(hud.top_menu_open, "MENU opens immediately on the FIRST finger down, without needing a hold")
	var hold_up := InputEventScreenTouch.new()
	hold_up.index = 16
	hold_up.position = y0
	hold_up.pressed = false
	hud._input(hold_up)
	verify(hud.top_menu_open, "Finger-up does not dismiss the menu opened by the first tap")
	var echo := InputEventMouseButton.new()
	echo.button_index = MOUSE_BUTTON_LEFT
	echo.position = y0
	echo.pressed = true
	hud._input(echo)
	echo.pressed = false
	hud._input(echo)
	verify(hud.top_menu_open, "Synthetic Android mouse echo press+release cannot close the freshly opened modal")
	hud._set_top_menu(false)
	_tap(hud, wallet_button, 17)
	verify(hud.wallet_open and hud.wallet_frame.visible, "One WALLET tap expands currency panel")
	_tap(hud, wallet_button, 18)
	verify(not hud.wallet_open and not hud.wallet_frame.visible, "Second WALLET tap collapses once, not twice")

	_tap(hud, bag_button, 19)
	verify(game.menu.visible and game.menu.current_page == "bag", "One BAG tap opens real inventory")
	if game.menu.visible:
		game.menu.close_page()

	# Rapid swerves should change yaw only. Pitch and roll must never drift.
	var expected_pitch: float = atan2(20.0, 26.25)
	for i in range(16):
		var yaw_before: float = game.camera_angle_target
		game.drag_camera(15000.0 if i % 2 == 0 else -15000.0)
		verify(absf(game.camera_angle_target - yaw_before) <= 90.0 * game.CAMERA_DRAG_RADIANS_PER_PIXEL + 0.001, "Extreme Android drag is capped safely")
		game._camera(1.0 / 60.0)
		var target: Vector3 = game.camera_focus_smooth + Vector3.UP * game.camera_occlusion_rise
		var orbit: Vector3 = game.camera.global_position - target
		var pitch: float = atan2(orbit.y, Vector2(orbit.x, orbit.z).length())
		verify(absf(pitch - expected_pitch) < 0.004, "Camera pitch stays constant on each fast reversal")
		verify(absf(game.camera.global_transform.basis.y.dot(game.camera.global_transform.basis.x)) < 0.001, "Camera basis remains orthogonal, no roll creep")

	var minimap: Control = holder.get_node_or_null("LiveWorldMinimap") as Control
	verify(minimap != null and minimap.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Minimap is filtered smoothly")
	verify(MAP.terrain_colour("inland") == Color("719a51"), "Inland grass is one deterministic colour")
	verify(MAP.terrain_colour("water") != MAP.terrain_colour("dry_sand"), "Distinct biomes remain distinguishable")
	if minimap != null:
		minimap._process(0.5)
		var map_image: Image = minimap.get("_image") as Image
		verify(map_image != null and map_image.get_pixel(31, 31) == map_image.get_pixel(32, 31), "Adjacent grass cells do not alternate shades")
		var previous: Color = map_image.get_pixel(31, 31)
		game.hero.global_position += Vector3(5.0, 0.0, 0.0)
		minimap._process(0.5)
		verify(map_image.get_pixel(31, 31) == previous, "Walking through the same biome does not recolour map pixels")
		verify(int(minimap.get("_relief_samples")) == 0, "Map does not add unstable per-voxel elevation tints")
	verify(ZONES.resolve(Vector3.ZERO, game.get_node_or_null("VoxelAtmosphere")) == "OUTPOST CLEARING", "Real starter clearing is the initial named zone")
	verify(ZONES.resolve(Vector3(120.0, 0.0, 0.0), game.get_node_or_null("VoxelAtmosphere")) == "OPEN WATER", "Beyond island uses real coastal-water zone")
	hud._show_zone_name("OUTPOST CLEARING")
	verify(not hud.zone_banner.visible, "Initial zone displays silently in minimap pill")
	hud._show_zone_name("THE FIELDS")
	verify(hud.zone_banner.visible and hud.zone_banner.text.contains("THE FIELDS"), "Transition shows an unobtrusive zone-entry announcement")
	hud._show_zone_name("THE FIELDS")
	verify(hud.zone_banner_seconds > 0.0, "Repeated identical zone does not dismiss banner")
	game.queue_free()
	await process_frame
	print("TOPBAR CAMERA RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
