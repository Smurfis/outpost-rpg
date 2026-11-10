extends SceneTree
## Android regression: portrait/labels, Settings touch + persistence, swimming,
## crest matte and updater controls. Deliberately no APK/saves are modified.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, label: String) -> void:
	if ok:
		print("PASS ALPHA UI SWIM: " + label)
	else:
		failures += 1
		push_error("FAIL ALPHA UI SWIM: " + label)

func tap(hud: Node, point: Vector2, touch_id: int) -> void:
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.index = touch_id
	down.position = point
	hud._input(down)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.index = touch_id
	up.position = point
	hud._input(up)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var source: PackedScene = load("res://scenes/main.tscn")
	verify(source != null, "Main game imports")
	if source == null:
		quit(1)
		return
	var game = source.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var portrait: TextureRect = hud.hero_portrait_art
	verify(portrait != null and portrait.material is ShaderMaterial, "Hero has a genuine circular artwork mask")
	if portrait != null and portrait.material is ShaderMaterial:
		verify((portrait.material as ShaderMaterial).shader.code.contains("circular_alpha"), "Portrait square backing is clipped to circular art")
	var gold_ring: StyleBoxFlat = hud.hero_portrait_frame.get_theme_stylebox("panel") as StyleBoxFlat
	verify(gold_ring != null and gold_ring.get_corner_radius(CORNER_TOP_LEFT) > 50, "Portrait has visible gold circular frame")
	verify(hud.root.get_node_or_null("CharacterLevelBadgeFrame") != null, "Level badge has real panel artwork")
	var level_rect: Rect2 = hud.xp_level_badge.get_global_rect()
	var portrait_rect: Rect2 = hud.hero_portrait_frame.get_global_rect()
	verify(level_rect.get_center().x > portrait_rect.get_center().x, "Level medallion sits on RIGHT edge of the portrait")
	verify(absf(level_rect.size.x - level_rect.size.y) < 1.0, "Level medallion is circular, not 39-by-27 rectangle")
	var badge_frame: Panel = hud.root.get_node_or_null("CharacterLevelBadgeFrame") as Panel
	if badge_frame != null:
		var badge_style: StyleBoxFlat = badge_frame.get_theme_stylebox("panel") as StyleBoxFlat
		verify(badge_style != null and badge_style.get_corner_radius(CORNER_TOP_LEFT) >= 30, "Level badge uses true round border")
	verify(hud.health_bar.get_global_rect().position.x - hud.hero_portrait_frame.get_global_rect().end.x <= 11.0, "HP remains close to portrait")

	hud._layout_touch_hud()
	var smart: Button = hud.smart_button
	var action: Button = hud.quick_buttons["skill_1"] as Button
	verify(smart.size.x >= 122.0 and smart.size.y >= 122.0, "Interact is five percent larger")
	verify(action.size.x >= 75.0, "Combat ability grows three percent without shifting position")
	verify(smart.get_global_rect().end.y < hud.xp_bar.get_global_rect().position.y, "Raised Interact remains clear of bottom XP")

	hud._show_control_settings()
	await process_frame
	verify(hud.control_settings_panel.visible, "Settings opens from game")
	verify(hud.control_settings_panel.get_node_or_null("ControlSettingsScroll") != null, "Controls settings content scrolls on small phones")
	verify(hud.floating_mode_toggle.text.contains("Dynamic movement stick"), "Dynamic movement mode is explicit in Controls")
	verify(hud.movement_stick_slider != null and hud.movement_stick_slider.min_value == 80.0 and hud.movement_stick_slider.max_value == 150.0, "Stick size slider ranges 80% through 150%")
	var slider_rect: Rect2 = hud.movement_stick_slider.get_global_rect()
	var slider_at: Vector2 = slider_rect.position + Vector2(slider_rect.size.x * 0.75, slider_rect.size.y * 0.5)
	tap(hud, slider_at, 58)
	verify(hud.movement_stick_scale >= 1.25 and hud.movement_stick_scale <= 1.40, "Android slider touch resizes joystick")
	verify(is_equal_approx(hud.joystick.size.x, 148.0 * hud.movement_stick_scale), "Slider resizes visual movement ring")
	verify(is_equal_approx(hud.knob.size.x, 55.0 * hud.movement_stick_scale), "Slider resizes thumb as well")
	var saved_slider := ConfigFile.new()
	verify(saved_slider.load(hud.CONTROL_PREFS) == OK and is_equal_approx(float(saved_slider.get_value("controls", "movement_stick_scale", 0.0)), hud.movement_stick_scale), "Stick scale persists in controls config")
	hud._set_movement_stick_size(100.0)
	hud.movement_stick_slider.set_value_no_signal(100.0)
	var close: Button = hud.control_settings_close_button
	verify(close != null and close.is_visible_in_tree(), "Permanent red X stays visible in Settings")
	if close != null:
		tap(hud, close.get_global_rect().get_center(), 52)
		verify(not hud.control_settings_panel.visible, "One Android finger tap closes Settings")
	hud._show_control_settings()
	await process_frame
	var old_floating: bool = hud.floating_joystick_enabled
	tap(hud, hud.floating_mode_toggle.get_global_rect().get_center(), 53)
	verify(hud.floating_joystick_enabled != old_floating, "Dynamic joystick CheckButton accepts actual touch")
	# Actual movement touches are tested once Controls is dismissed below.
	# A hidden gameplay joystick is expected WHILE Settings is open.
	hud._set_floating_mode(old_floating)
	hud.floating_mode_toggle.set_pressed_no_signal(old_floating)

	hud._set_status_text_mode("health", "percent")
	hud._set_status_text_mode("mana", "off")
	hud._set_status_text_mode("xp", "percent")
	hud.render_status(50.0, game.inventory, 0, 0, "training_blade", "", "")
	verify(hud.health_numbers.text == "50%" and hud.health_numbers.visible, "Health percentage shows real HP")
	verify(not hud.mana_numbers.visible and hud.mana_bar.visible, "Mana OFF hides text without hiding bar")
	verify(hud.xp_level_label.text.contains("%") and hud.xp_bar.visible, "XP percentage works without hiding bottom strip")
	verify(hud.status_mode_buttons.has("health:text") and hud.status_mode_buttons.has("health:percent") and hud.status_mode_buttons.has("health:off"), "Every stat has Numbers, Percent and Off choices")
	hud._save_control_prefs()
	var config := ConfigFile.new()
	verify(config.load(hud.CONTROL_PREFS) == OK and str(config.get_value("status_text", "health", "")) == "percent", "Text-mode selection persists to preferences")
	for stat in ["health", "mana", "xp"]:
		hud._set_status_text_mode(stat, "text")
	hud._preview_swimming_fx()
	verify(game.hero.swim_preview_seconds > 0.0, "Controls can trigger real swim stroke preview")
	verify(get_nodes_in_group("outpost_swim_particles").size() > 0, "Preview emits batched splash particles")
	verify(not hud.control_settings_panel.visible, "Preview closes Controls for unobstructed view")
	hud._set_floating_mode(true)
	var moving_touch := InputEventScreenTouch.new()
	moving_touch.index = 91
	moving_touch.pressed = true
	moving_touch.position = Vector2(210, 520)
	hud._input(moving_touch)
	verify(hud.finger == 91 and hud.joystick.visible, "Dynamic movement appears on first movement-area touch during gameplay")
	verify(hud.joystick.position.distance_to(moving_touch.position - hud.joystick.size * 0.5) < 2.0,
		"Dynamic movement ring is centered on that touch in the lower-left movement zone")
	moving_touch.pressed = false
	hud._input(moving_touch)
	hud._set_floating_mode(old_floating)
	game.hero.global_position = Vector3(95.0, -3.15, 0.0)
	verify(game.hero._detect_surface_swimming(), "Coastline ocean is identified as swimmable water")
	verify(not game.get_node("VoxelAtmosphere").is_land_at(95.0, 0.0), "Swimming only activates outside true land")
	var fire_stations: Array[String] = ["campfire", "forge"]
	for station_key in fire_stations:
		var station: Node3D = game.stations.get(station_key) as Node3D
		verify(station != null, "Existing %s station is present" % station_key)
		if station == null:
			continue
		var legacy_parts: Array = station.get("legacy_fire_parts")
		verify(legacy_parts.size() > 0, "Legacy %s fire effects are explicitly tracked" % station_key)
		station.call("_disable_legacy_fire_vfx")
		var all_hidden: bool = true
		for legacy in legacy_parts:
			all_hidden = all_hidden and not (legacy as MeshInstance3D).visible
		verify(all_hidden, "%s legacy flame and smoke/shapes disappear behind PyroLux" % station_key)
	# This is the actual Android smart Interact touch route, not a direct
	# call to menu.open(). A harvestable next to the loom previously stole
	# the context and made CRAFT appear completely unresponsive.
	game.hero.global_position = game.station_positions["loom"] + Vector3(0.0, 0.35, 0.0)
	verify(game._nearest_resource() != null, "Loom regression location has a nearby gatherable")
	verify(str(game.smart_context().get("kind", "")) == "craft", "Station CRAFT outranks harvestables in interaction radius")
	var interact_point: Vector2 = hud.smart_button.get_global_rect().get_center()
	tap(hud, interact_point, 73)
	verify(game.menu.visible and game.menu.current_page == "craft" and game.menu.selected_station == "loom",
		"Single Android Interact tap opens the correct loom crafting recipes")
	game.menu.close_page()
	for station_id in ["workbench", "forge", "campfire"]:
		game.hero.global_position = game.station_positions[station_id] + Vector3(0.0, 0.35, 0.0)
		verify(str(game.smart_context().get("kind", "")) == "craft", "Interact identifies " + station_id + " at station")
		tap(hud, interact_point, 74)
		verify(game.menu.visible and game.menu.current_page == "craft" and game.menu.selected_station == station_id,
			"Interact touch opens " + station_id + " instead of another station or an inert button")
		game.menu.close_page()
	game.queue_free()
	await process_frame

	var title_scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	verify(title_scene != null, "Title screen imports with improved crest matte")
	if title_scene != null:
		var title = title_scene.instantiate()
		root.add_child(title)
		await process_frame
		var crest: Control = title.get_node_or_null("Artboard/OutpostLogo") as Control
		verify(crest != null and crest.material is ShaderMaterial, "Original Outpost crest keeps its shader")
		if crest != null and crest.material is ShaderMaterial:
			verify((crest.material as ShaderMaterial).shader.code.contains("blue_sky"), "Title crest removes painted side-sky opacity")
		var check_button: Button = title.get("_update_button") as Button
		verify(check_button != null and check_button.get_theme_stylebox("normal") is StyleBoxFlat, "Update actions use gold-translucent controls")
		var stable_button: Button = title.get("_channel_stable_button") as Button
		verify(stable_button != null and stable_button.text.contains("STABLE"), "Stable/Alpha update selector exists")
		title.queue_free()
		await process_frame
	print("ALPHA UI SWIM RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
