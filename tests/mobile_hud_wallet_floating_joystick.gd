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
	verify(hud.wallet_collapse != null and not hud.wallet_collapse.visible, "Old dropdown Wallet button is hidden")
	var bag: Button = hud_root.get_node_or_null("Action_bag") as Button
	verify(bag != null, "Live bag action attached to wallet")
	verify(hud_root.get_node_or_null("CharacterLevelBadge") != null, "Level badge is left of screen-wide XP meter")
	var badge: Label = hud_root.get_node_or_null("CharacterLevelBadge") as Label
	verify(badge != null and badge.visible and hud.hero_portrait_frame.get_global_rect().grow(12.0).intersects(badge.get_global_rect()) and not hud.xp_bar.get_global_rect().intersects(badge.get_global_rect()), "Character level badge sits beside portrait, not inside bottom XP")
	verify(hud_root.get_node_or_null("LastTrackedResourceCount") != null, "One tracked resource instead of four permanent materials")
	hud.render_status(83.0, {"wood": 8, "stone": 5, "coins": 147}, 40, 0, "training_blade", "Find iron", "")
	verify(hud.wallet_coin.text.contains("147"), "Wallet shows the actual currency owned")
	hud.render_status(83.0, {"wood": 9, "stone": 5, "coins": 147}, 40, 0, "training_blade", "Find iron", "")
	verify(hud.wallet_resource_id == "wood" and hud.wallet_resource_count.text.contains("9"), "Recent gather changes the tracked material")
	verify(not hud.wallet_open and not hud.wallet_frame.visible, "Wallet is a permanent transparent strip, not a flyout")
	verify(hud.wallet_coin.visible and hud.wallet_coin.text.contains("147"), "Coins appear immediately in horizontal wallet")
	verify(not hud.wallet_resource_count.visible, "Last tracked resource no longer masquerades as currency")
	for key in ["coins", "copper", "silver", "gold", "gems"]:
		verify(game.inventory.has(key) and int(game.inventory[key]) >= 0,
			"Real persistable player currency account exists: " + key)
		var icon: TextureRect = hud.wallet_currency_icons.get(key) as TextureRect
		verify(icon != null and icon.texture != null and icon.visible,
			"Original transparent pixel currency icon loads and shows horizontally: " + key)
		if icon != null:
			verify(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Currency art never blocks touch: " + key)
	verify(hud.wallet_currency_rows.has("silver") and (hud.wallet_currency_rows["silver"] as Label).visible and (hud.wallet_currency_rows["silver"] as Label).text.contains("—"), "Unavailable silver shows a dash, not fictitious zero")
	var bounds: Array[Rect2] = []
	bounds.append(hud.wallet_coin.get_global_rect())
	for key in ["copper", "silver", "gold", "gems"]:
		var cell: Label = hud.wallet_currency_rows[key] as Label
		verify(cell.visible, "Currency appears without a dropdown: " + key)
		bounds.append(cell.get_global_rect())
	for i in range(5):
		var currency: String = ["coins", "copper", "silver", "gold", "gems"][i]
		var symbol: TextureRect = hud.wallet_currency_icons[currency] as TextureRect
		verify(symbol.get_global_rect().end.x <= bounds[i].position.x + 1.0,
			"Wallet pixel-art symbol stays to the left of its amount: " + currency)
	for i in range(1, bounds.size()):
		verify(absf(bounds[i].position.y - bounds[0].position.y) < 2.0 and bounds[i].position.x >= bounds[i - 1].end.x - 1.5,
			"Currency counters are laid out horizontally without overlapping")
	# Regression from real Android: the fifth currency used to sit underneath
	# BAG because the wallet row extended into its button rectangle.
	verify(bounds[4].end.x <= bag.get_global_rect().position.x - 3.0,
		"Last currency ends before the BAG button; no top-row overlap")
	verify(bounds[0].position.x >= hud.hero_status_frame.get_global_rect().end.x + 3.0,
		"Wallet starts after the portrait and HP/MP instead of covering them")
	for key in ["copper", "silver", "gold", "gems"]:
		var label: Label = hud.wallet_currency_rows[key] as Label
		verify(label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.clip_text,
			"Wallet amount never wraps into a second line: " + key)
	verify(hud.wallet_coin.autowrap_mode == TextServer.AUTOWRAP_OFF,
		"Coins also remain a single horizontal counter")
	# Check logical layout for 16:9 and 20:9 independent of headless window
	# dimensions; these anchors are consumed by the actual Godot renderer.
	for virtual_size in [Vector2(1280, 720), Vector2(1600, 720)]:
		hud._layout_player_chrome_for_size(virtual_size, 1.0)
		var bag_left: float = bag.anchor_left * virtual_size.x
		var last_currency: Label = hud.wallet_currency_rows["gems"] as Label
		var gems_end: float = last_currency.anchor_right * virtual_size.x
		var coins_left: float = hud.wallet_coin.anchor_left * virtual_size.x
		var portrait_end: float = hud.hero_status_frame.anchor_right * virtual_size.x
		verify(gems_end <= bag_left - 4.0 and coins_left >= portrait_end + 3.0,
			"Wallet never overlaps Bag or portrait at %d×%d" % [int(virtual_size.x), int(virtual_size.y)])
	hud._layout_player_chrome()
	hud._refresh_wallet({"coins": 1234567, "copper": 23456, "silver": 0, "gold": 2, "gems": 9})
	verify(hud.wallet_coin.text.contains("1.2M") and hud.wallet_coin.tooltip_text.contains("1234567"),
		"Large coin balances shorten in the strip but preserve exact total")
	verify((hud.wallet_currency_rows["copper"] as Label).text.contains("23.5K")
		and (hud.wallet_currency_rows["copper"] as Label).tooltip_text.contains("23456"),
		"Large copper balances stay one-line with exact-count tooltip")
	hud._refresh_wallet({"wood": 9, "stone": 5, "coins": 147})
	var old_bag_x: float = bag.anchor_left
	hud._toggle_wallet()
	verify(hud.wallet_coin.visible and not hud.wallet_frame.visible, "Deprecated wallet toggle never opens an opaque panel")
	verify(absf(bag.anchor_left - old_bag_x) < 0.001, "Passive wallet never shifts the Bag button")
	hud._set_top_menu(true)
	verify(hud.wallet_coin.visible, "Menu does not hide the horizontal currency display")
	hud._set_top_menu(false)
	var top_menu: Button = hud_root.get_node_or_null("TopRightMenuButton") as Button
	verify(top_menu != null, "One top-right menu replaces button row")
	var clock: Label = hud_root.get_node_or_null("MinimapFooterClock") as Label
	verify(clock != null and hud.clock_footer != null, "Calendar/day-time has a dedicated attached minimap footer")
	if clock != null and top_menu != null:
		var mini_bounds: Rect2 = hud.minimap.get_global_rect()
		var footer_bounds: Rect2 = hud.clock_footer.get_global_rect()
		verify(absf(footer_bounds.position.y - (mini_bounds.end.y - 7.0)) < 2.0, "Minimap calendar footer visually attaches to map")
		verify(top_menu.get_global_rect().end.x < mini_bounds.position.x, "Wooden MENU is left of minimap, never obscuring it")
		verify(top_menu.get_global_rect().position.y < mini_bounds.position.y, "Single-tap MENU aligns to zone pill above the minimap")
		verify(hud.zone_pill != null and hud.zone_pill.get_global_rect().end.y <= mini_bounds.position.y, "WoW-inspired zone pill is ABOVE the circular map")
	verify(not game.menu.visible, "Bag and Gear modal panels stay hidden while playing")
	var screen_mid: Vector2 = hud.get_viewport().get_visible_rect().size * 0.5
	verify(hud.top_menu_panel.get_global_rect().get_center().distance_to(screen_mid) < 2.0, "Game MENU is now a centered modal, not a tiny map dropdown")
	verify(hud.top_menu_shade != null and not hud.top_menu_shade.visible, "Modal shade is hidden during gameplay")
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
	var tap_down := InputEventScreenTouch.new()
	tap_down.index = 13
	tap_down.position = top_menu.get_global_rect().get_center()
	tap_down.pressed = true
	hud._input(tap_down)
	hud._process(0.38)
	verify(hud.top_menu_open, "MENU opens immediately on the first touch-down")
	var tap_up := InputEventScreenTouch.new()
	tap_up.index = 13
	tap_up.position = tap_down.position
	tap_up.pressed = false
	hud._input(tap_up)
	verify(hud.top_menu_open and hud.top_menu_panel.visible and hud.top_menu_shade.visible, "Release preserves the centered Game Menu without double activation")
	verify(hud.top_menu_actions.size() == 6, "Menu has six functional destinations")
	for option in hud.top_menu_actions:
		verify(option.visible, "Expanded option is visible: " + option.name)
	hud._set_top_menu(false)
	verify(not hud.top_menu_panel.visible and not hud.top_menu_shade.visible, "Game MENU closes cleanly without changing gameplay")
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
