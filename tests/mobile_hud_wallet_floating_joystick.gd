extends SceneTree
## Genuine Android HUD regression: wallet, one long-press menu, three skills,
## fixed/floating joystick modes and local display name preferences.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, name: String) -> void:
	if ok:
		print("PASS MOBILE HUD: " + name)
	else:
		failures += 1
		push_error("FAIL MOBILE HUD: " + name)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game_scene: PackedScene = load("res://scenes/main.tscn")
	verify(game_scene != null, "Game scene imported")
	if game_scene == null:
		quit(1)
		return
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var hud_root: Control = hud.root
	verify(hud_root.get_node_or_null("WalletCollapse") != null, "Wallet starts with a collapse control")
	var bag: Button = hud_root.get_node_or_null("Action_bag") as Button
	verify(bag != null, "Live bag action attached to wallet")
	verify(hud_root.get_node_or_null("CharacterLevelBadge") != null, "Level badge is left of screen-wide XP meter")
	var badge: Label = hud_root.get_node_or_null("CharacterLevelBadge") as Label
	verify(badge != null and badge.visible and hud.xp_bar.get_global_rect().encloses(badge.get_global_rect()), "Compact level number is overlaid inside the full-width XP strip")
	verify(hud_root.get_node_or_null("LastTrackedResourceCount") != null, "One tracked resource instead of four permanent materials")
	hud.render_status(83.0, {"wood": 8, "stone": 5, "coins": 147}, 40, 0, "training_blade", "Find iron", "")
	verify(hud.wallet_coin.text.contains("147"), "Wallet shows the actual currency owned")
	hud.render_status(83.0, {"wood": 9, "stone": 5, "coins": 147}, 40, 0, "training_blade", "Find iron", "")
	verify(hud.wallet_resource_id == "wood" and hud.wallet_resource_count.text.contains("9"), "Recent gather changes the tracked material")
	var old_bag_x: float = bag.anchor_left
	hud._toggle_wallet()
	verify(not hud.wallet_open and not hud.wallet_resource_count.visible, "Collapsed wallet hides material counters")
	verify(bag.anchor_left < old_bag_x, "Bag icon remains attached next to collapse control")
	hud._toggle_wallet()
	verify(hud.wallet_open and hud.wallet_resource_count.visible, "Wallet restores the contents")
	var top_menu: Button = hud_root.get_node_or_null("TopRightMenuButton") as Button
	verify(top_menu != null, "One top-right menu replaces button row")
	var clock: Label = hud_root.get_node_or_null("MinimapFooterClock") as Label
	verify(clock != null, "Day/night display has a dedicated location beneath future minimap")
	if clock != null and top_menu != null:
		verify(clock.anchor_top >= 0.32, "Clock remains below the map")
		verify(top_menu.anchor_top < 0.14 and top_menu.anchor_bottom < 0.17, "Menu is now near the top right beside the minimap")
		verify(top_menu.get_global_rect().end.x < hud.minimap.get_global_rect().position.x, "Menu is left of minimap, never obscuring it")
	verify(not game.menu.visible, "Bag and Gear modal panels stay hidden while playing")
	verify(hud.top_menu_panel.anchor_top < 0.22 and hud.top_menu_panel.anchor_bottom < 0.35, "Expanded menu is a compact top-right flyout, not next to combat buttons")
	for slot in ["skill_1", "skill_2", "skill_3"]:
		var skill_button: Button = hud.quick_buttons[slot] as Button
		verify(hud.top_menu_panel.anchor_bottom < skill_button.anchor_top, "Expanded menu never obscures radial " + slot)
	var stick_before: Vector2 = hud.joystick.position
	var skill_before: Vector2 = (hud.quick_buttons["skill_1"] as Button).position
	hud._bag()
	verify(game.menu.visible and game.menu.current_page == "bag", "Bag opens only on demand as an independent modal")
	game.menu.close_page()
	hud._gear()
	verify(game.menu.visible and game.menu.current_page == "equipment", "Gear opens only on demand as an independent modal")
	game.menu.close_page()
	verify(hud.joystick.position == stick_before and (hud.quick_buttons["skill_1"] as Button).position == skill_before, "Opening Bag and Gear never nudges movement or skills")

	verify(not hud.top_menu_open, "Extra options are collapsed by default")
	hud._menu_button_down()
	hud._process(0.38)
	verify(hud.top_menu_open and hud.top_menu_panel.visible, "Hold opens the options dropdown")
	hud._menu_button_up()
	hud._menu_button_pressed()
	verify(hud.top_menu_open, "Releasing long press does not immediately close dropdown")
	verify(hud.top_menu_actions.size() == 6, "Menu has six functional destinations")
	for option in hud.top_menu_actions:
		verify(option.visible, "Expanded option is visible: " + option.name)
	hud._set_top_menu(false)
	verify(not hud.top_menu_panel.visible, "Dropdown can be hidden without closing gameplay")
	for key in ["skill_1", "skill_2", "skill_3"]:
		verify(hud_root.get_node_or_null("Action_" + key) != null, "Exactly three existing skill radials: " + key)
	verify(hud_root.get_node_or_null("Action_skill_4") == null and hud_root.get_node_or_null("Action_skill_5") == null, "No invented fourth or fifth skill")
	hud._show_skill_details()
	verify(hud.skill_detail_panel.visible and hud.skill_detail_text.text.contains("3"), "Menu shows actual mastery information")
	hud.skill_detail_panel.visible = false
	hud._show_control_settings()
	verify(hud.control_settings_panel.visible, "In-game control settings are functional")
	verify(hud.floating_mode_toggle != null and hud.name_edit != null, "Control settings have mode and display name fields")
	hud.name_edit.text = "Explorer"
	hud._save_character_name()
	verify(hud.player_display_name == "Explorer" and hud.status.text == "Explorer", "Name preference replaces OUTPOST in the HUD")
	hud.control_settings_panel.visible = false
	hud._set_floating_mode(true)
	verify(hud.floating_joystick_enabled, "Floating movement mode is available")
	var finger_down := InputEventScreenTouch.new()
	finger_down.index = 31
	finger_down.pressed = true
	finger_down.position = Vector2(210, 520)
	hud._input(finger_down)
	verify(hud.finger == 31 and hud.joystick.visible, "Touching free lower-left playfield spawns joystick")
	var origin: Vector2 = hud.joystick.position
	var finger_drag := InputEventScreenDrag.new()
	finger_drag.index = 31
	finger_drag.position = Vector2(330, 534)
	hud._input(finger_drag)
	verify(hud.move_vector.length() > 0.6, "Finger drag drives actual player movement")
	verify(hud.joystick.position.x > origin.x, "Floating movement ring follows out-of-radius thumb")
	var finger_up := InputEventScreenTouch.new()
	finger_up.index = 31
	finger_up.position = finger_drag.position
	finger_up.pressed = false
	hud._input(finger_up)
	verify(hud.finger == -1 and hud.move_vector == Vector2.ZERO and not hud.joystick.visible, "Release resets finger and hides floating ring")
	var saved := ConfigFile.new()
	verify(saved.load("user://outpost_controls.cfg") == OK and saved.get_value("controls", "floating_joystick", false), "Joystick preference persists outside gameplay save")
	hud._set_floating_mode(false)
	verify(hud.joystick.visible, "Fixed joystick mode restores existing controls")
	hud.name_edit.text = "Adventurer"
	hud._save_character_name()
	game.queue_free()
	await process_frame
	print("MOBILE HUD RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
