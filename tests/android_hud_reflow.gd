extends SceneTree
## Real touch-layout collision checks for Outpost's landscape HUD.
## Complements existing tool-slider / orbit / multiplayer gameplay tests.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, detail: String) -> void:
	if ok:
		print("PASS HUD REFLOW: " + detail)
	else:
		failures += 1
		push_error("FAIL HUD REFLOW: " + detail)

func _does_not_overlap(left: Control, right: Control, detail: String) -> void:
	if left != null and right != null:
		verify(not left.get_global_rect().intersects(right.get_global_rect()), detail)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Game scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var controls: Control = hud.root
	hud._layout_touch_hud()
	await process_frame

	var mini: Control = controls.get_node_or_null("LiveWorldMinimap") as Control
	var toggle: Button = controls.get_node_or_null("TopRightMenuButton") as Button
	var menu: Panel = controls.get_node_or_null("FunctionalHotbar") as Panel
	var smart: Button = controls.get_node_or_null("Action_interact") as Button
	verify(mini != null and toggle != null and menu != null and smart != null, "Live minimap, menu and real smart action remain wired")
	if mini != null:
		verify(absf(mini.size.x - mini.size.y) <= 2.0, "Live minimap keeps a 1:1 aspect ratio")
		verify(mini.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Minimap does not intercept camera/touch gestures")
	if smart != null:
		verify(absf(smart.size.x - smart.size.y) <= 2.0 and smart.size.x >= 110.0, "Main tool selector is a real square, finger-sized target")
		verify(smart.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Input remains handled by main smart-tool swipe handler")
		verify(smart.get_node_or_null("ToolSwipeChevron") != null, "Main tool still shows drag affordance")

	var keys: Array[String] = ["skill_1", "skill_2", "skill_3", "consumable", "potion"]
	var right_buttons: Array[Control] = []
	for key in keys:
		var button: Button = controls.get_node_or_null("Action_" + key) as Button
		verify(button != null, "Existing ability/quick selector is retained: " + key)
		if button != null:
			verify(absf(button.size.x - button.size.y) <= 2.0 and button.size.x >= 60.0, "Square touch icon: " + key)
			right_buttons.append(button)
	if hud.torch_button != null:
		verify(absf(hud.torch_button.size.x - hud.torch_button.size.y) <= 2.0, "Offhand torch is square")
		right_buttons.append(hud.torch_button)
	if smart != null:
		right_buttons.append(smart)
	for i in range(right_buttons.size()):
		for j in range(i + 1, right_buttons.size()):
			_does_not_overlap(right_buttons[i], right_buttons[j], "Separate hitboxes: %s / %s" % [right_buttons[i].name, right_buttons[j].name])

	if mini != null and toggle != null:
		_does_not_overlap(mini, toggle, "Minimap is clear of its menu toggle")
	hud._set_top_menu(true)
	verify(hud.top_menu_actions.size() == 6 and menu.visible, "Six-option drop-down opens")
	for option in hud.top_menu_actions:
		verify(option.visible and menu.get_global_rect().encloses(option.get_global_rect()), "Menu option fits panel: " + option.name)
		if mini != null:
			_does_not_overlap(option, mini, "Menu option does not cover minimap")
		if toggle != null:
			_does_not_overlap(option, toggle, "Menu option does not cover toggle")
		for button in right_buttons:
			_does_not_overlap(option, button, "Menu option does not cover playable ability: " + option.name)
	hud._set_top_menu(false)

	# An actual Android tap path rather than direct Button.pressed.emit() only.
	if toggle != null:
		var menu_tap := InputEventScreenTouch.new()
		menu_tap.index = 1
		menu_tap.pressed = true
		menu_tap.position = toggle.get_global_rect().get_center()
		hud._input(menu_tap)
		verify(hud.top_menu_open, "Tapping MENU opens the live six-item flyout")
		var bag_action: Button = controls.get_node_or_null("BagMenuButton") as Button
		if bag_action != null:
			var bag_tap := InputEventScreenTouch.new()
			bag_tap.index = 1
			bag_tap.pressed = true
			bag_tap.position = bag_action.get_global_rect().get_center()
			hud._input(bag_tap)
			verify(game.menu.visible and game.menu.current_page == "bag" and game.menu.inventory_window.visible, "Tapping BAG opens Albion inventory, not an inert overlay")
			var emergency: Button = game.menu.emergency_close
			verify(emergency != null and emergency.visible, "Back to Game stays above the Bag and Craft panels")
			if emergency != null:
				var exit_tap := InputEventScreenTouch.new()
				exit_tap.pressed = true
				exit_tap.position = emergency.get_global_rect().get_center()
				game.menu._input(exit_tap)
				verify(not game.menu.visible, "Tapping Back to Game actually leaves the bag")
		game.show_crafting()
		verify(game.menu.visible and game.menu.current_page == "craft", "Crafting reopens after bag touch")
		game.menu.close_page()

	# Dynamic stick and independent second-finger camera while moving.
	hud._set_floating_mode(true)
	hud._set_sticky_movement(true)
	var screen_size: Vector2 = hud.get_viewport().get_visible_rect().size
	var first := InputEventScreenTouch.new()
	first.index = 0
	first.pressed = true
	first.position = Vector2(screen_size.x * 0.11, screen_size.y * 0.75)
	hud._input(first)
	verify(hud.finger == 0, "Dynamic thumbstick captures an imprecise lower-left touch")
	var walk := InputEventScreenDrag.new()
	walk.index = 0
	walk.position = first.position + Vector2(34, -9)
	hud._input(walk)
	verify(hud.move_vector.length_squared() > 0.001, "Dynamic thumbstick starts movement on drag")
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = Vector2(screen_size.x * 0.53, screen_size.y * 0.56)
	hud._input(second)
	verify(hud.finger == 0 and hud.camera_drag_finger == 1, "Second finger can orbit while first holds movement")
	var release_cam := InputEventScreenTouch.new()
	release_cam.index = 1
	release_cam.pressed = false
	release_cam.position = second.position
	hud._input(release_cam)
	var release_stick := InputEventScreenTouch.new()
	release_stick.index = 0
	release_stick.pressed = false
	release_stick.position = walk.position
	hud._input(release_stick)
	verify(hud.finger == -1 and hud.move_vector.length_squared() > 0.001, "Sticky mode intentionally preserves movement after finger lift")
	verify(hud.stop_sticky_button.visible, "Sticky movement exposes the STOP safety button")
	hud._stop_sticky_movement()
	verify(hud.move_vector == Vector2.ZERO and not hud.stop_sticky_button.visible, "STOP action reliably cancels sticky movement")
	hud._set_sticky_movement(false)
	hud._set_floating_mode(false)

	hud.render_status(81.0, {"wood": 8, "stone": 3, "coins": 12}, 80, 0,
			"training_blade", "Gather wood and stone, then craft a spear", "Explore the fields")
	verify(hud.quest.text == "Gather wood and stone", "Quest ticker shows a concise actionable clause")
	verify(hud.quest_detail.text.contains("then craft a spear"), "Full untruncated objective remains available in journal")
	verify(not hud.hint.visible, "Generic exploration text stays hidden")
	verify(not hud.mana_bar.visible and not hud.mana_numbers.visible, "Nonfunctional MP placeholder does not consume HUD space")
	var status: Panel = controls.get_node_or_null("HeroStatusFrame") as Panel
	var portrait: TextureRect = controls.get_node_or_null("HeroPortrait") as TextureRect
	var wallet: Panel = controls.get_node_or_null("ResourceQuickChips") as Panel
	verify(status != null and portrait != null and wallet != null, "Portrait and compact player resource chrome remain separate editable controls")
	if status != null:
		verify(status.get_global_rect().encloses(hud.hero_detail.get_global_rect()), "Mastery line stays inside status frame")
		var player_style: StyleBoxFlat = status.get_theme_stylebox("panel") as StyleBoxFlat
		verify(player_style != null and player_style.bg_color.a < 0.80 and player_style.border_width_left <= 2, "HP/name backing is translucent with a slim border, not opaque wood")
		verify(absf(status.size.x - 338.0) < 3.0, "Portrait and health frame remains compact on standard Android landscape")
	if wallet != null:
		var wallet_style: StyleBoxFlat = wallet.get_theme_stylebox("panel") as StyleBoxFlat
		verify(wallet_style != null and wallet_style.bg_color.a < 0.65, "Wallet is a lightweight translucent chip")
		verify(absf(wallet.size.x - 312.0) < 3.0, "Wallet does not stretch with screen width")
		verify(wallet.get_global_rect().position.x > status.get_global_rect().end.x, "Wallet does not cover the hero portrait or HP")
	if portrait != null and status != null:
		verify(status.get_global_rect().encloses(portrait.get_global_rect()), "Independent hero portrait stays inside slim status frame")
	# Simulate ultra-wide coordinates without changing gameplay or the viewport.
	# Check the px-layout parameters, not a single fixed percentage at 16:9.
	hud._layout_player_chrome_for_size(Vector2(2400, 1080), 1.2)
	if status != null and wallet != null:
		verify(absf((status.anchor_right - status.anchor_left) * 2400.0 - 405.6) < 2.0, "At 20:9 portrait+HP remain fixed-pixel width (no long opaque banner)")
		verify(absf((wallet.anchor_right - wallet.anchor_left) * 2400.0 - 374.4) < 2.0, "At 20:9 resources stay in a slim independent chip")
		hud._toggle_wallet()
		hud._layout_player_chrome_for_size(Vector2(2400, 1080), 1.2)
		verify(absf((wallet.anchor_right - wallet.anchor_left) * 2400.0 - 121.2) < 2.0, "Collapsed wallet shrinks to a 101px compact chip on ultrawide phones")
		hud._toggle_wallet()
	hud._layout_touch_hud()

	verify(hud.xp_bar.size.y <= 22.0, "Level XP is a slim screen-edge progress meter")
	verify(hud.xp_bar.get_global_rect().position.y > game.hud.get_viewport().get_visible_rect().size.y * 0.94, "XP meter remains below action cluster")

	hud.bag_weight_label.visible = true
	_does_not_overlap(hud.bag_weight_label, hud.quest_frame, "Bag weight alert does not obscure quest")
	hud._toggle_quest()
	verify(hud.quest_detail_back.visible and hud.quest_detail.visible, "Quest panel still expands on tap")

	# Gameplay API remains untouched.
	game.inventory["pickaxe"] = 1
	verify(game.select_quick_tool("pickaxe"), "Original held-tool selection still equips owned pickaxe")
	verify(game.hud.smart_button != null and game.hud.smart_tray != null, "Swipe tray remains available")
	game.queue_free()
	await process_frame
	print("HUD REFLOW RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
