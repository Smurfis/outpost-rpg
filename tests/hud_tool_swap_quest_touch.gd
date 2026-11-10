extends SceneTree
## Regression for Android input: independent tool selection and WoW quest tracker.
var failures: int = 0

func verify(ok: bool, description: String) -> void:
	if ok:
		print("PASS HUD TOOLS: " + description)
	else:
		failures += 1
		push_error("FAIL HUD TOOLS: " + description)

func _tap(hud: Node, button: Control, finger_id: int) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = finger_id
	down.position = point
	down.pressed = true
	hud._input(down)
	var up := InputEventScreenTouch.new()
	up.index = finger_id
	up.position = point
	up.pressed = false
	hud._input(up)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var packed: PackedScene = load("res://scenes/main.tscn")
	verify(packed != null, "Scene imports")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	game.save_path = "user://hud_tools_regression.json"
	root.add_child(game)
	await process_frame
	var hud = game.hud
	verify(hud != null, "Live HUD created")
	if hud == null:
		quit(1)
		return
	var smart: Button = hud.smart_button
	var selector: Button = hud.tool_swap_button
	var menu_button: Button = hud.menu_button
	var bag_button: Button = hud.wallet_bag
	verify(smart != null and selector != null and smart != selector, "TOOLS and INTERACT are separate buttons")
	verify(selector.get_node_or_null("ActionIcon") != null, "Tool selector has matching medallion icon")
	verify(not selector.get_global_rect().intersects(smart.get_global_rect()), "Tool select touch target does not overlap Interact")
	for key in ["skill_1", "skill_2", "skill_3"]:
		verify(not selector.get_global_rect().intersects((hud.quick_buttons[key] as Button).get_global_rect()),
			"Tool selector never overlaps " + key)
	# All three ability medallions must stay separately tappable after
	# tightening the action arc, including above the bottom XP strip.
	var skills: Array[Button] = [
		hud.quick_buttons["skill_1"] as Button,
		hud.quick_buttons["skill_2"] as Button,
		hud.quick_buttons["skill_3"] as Button,
	]
	for i in range(skills.size()):
		var skill_rect: Rect2 = skills[i].get_global_rect()
		verify(not skill_rect.intersects(smart.get_global_rect()), "Skill %d is clear of Interact" % (i + 1))
		verify(not skill_rect.intersects(hud.xp_bar.get_global_rect()), "Skill %d is clear of XP bar" % (i + 1))
		for j in range(i):
			verify(not skill_rect.intersects(skills[j].get_global_rect()), "Skills %d and %d have distinct touch targets" % [i + 1, j + 1])
	var screen: Vector2 = hud.get_viewport().get_visible_rect().size
	var scale: float = clampf(minf(screen.x / 1280.0, screen.y / 720.0), 0.8, 1.2)
	verify(skills[0].get_global_rect().get_center().y >
		smart.get_global_rect().get_center().y - 160.0 * scale,
		"Heroic Strike sits in lower, compact arc above Interact")
	verify(not hud.smart_tray_open and not hud.smart_tray.visible, "Old Training Blade popup is hidden at startup")
	var touch := InputEventScreenTouch.new()
	touch.index = 37
	touch.position = smart.get_global_rect().get_center()
	touch.pressed = true
	hud._input(touch)
	hud._process(1.1)
	verify(not hud.smart_tray_open and not hud.smart_tray.visible, "Long Interact press performs game action without popup")
	touch.pressed = false
	hud._input(touch)
	verify(hud.smart_hold_finger == -1, "Release ends held smart action")
	game.inventory["axe"] = 1
	game.inventory["pickaxe"] = 1
	var before: String = str(game.active_quick_tool)
	_tap(hud, selector, 38)
	var after: String = str(game.active_quick_tool)
	verify(after != before and after in game.available_quick_tools(), "Separate TOOLS tap changes to owned equipment")
	verify(not hud.smart_tray_open and not hud.smart_tray.visible, "Tool cycling never opens a large selector panel")
	verify(menu_button.get_global_rect().size.x == menu_button.get_global_rect().size.y, "MENU medallion is round at actual viewport dimensions")
	verify(bag_button.get_global_rect().size.x == bag_button.get_global_rect().size.y, "BAG medallion is round at actual viewport dimensions")
	var portrait: Rect2 = hud.hero_portrait_frame.get_global_rect()
	var badge: Rect2 = hud.xp_level_badge.get_global_rect()
	verify(portrait.intersects(badge), "Level number overlaps gold portrait rim")
	verify(hud.health_bar.get_global_rect().position.x <= portrait.end.x + 1.0, "Health meter docks to portrait rim")
	verify(hud.mana_bar.get_global_rect().position.x <= portrait.end.x + 1.0, "Mana meter docks to portrait rim")
	verify(hud.quest_frame.get_theme_stylebox("panel") is StyleBoxEmpty, "No opaque black Quest background")
	verify(hud.quest_detail_back.get_theme_stylebox("panel") is StyleBoxEmpty, "Expanded journal has no opaque panel")
	verify(hud.quest_rule != null and hud.quest_rule.color.a < 0.5, "Quest header has one faint gold underline")
	hud._update_quest_tracker("Gather wood and stone")
	var was_open: bool = hud.quest_expanded
	_tap(hud, hud.quest_toggle, 39)
	verify(hud.quest_expanded != was_open and hud.quest_detail.visible, "First QUESTS touch expands WoW-style live objective")
	verify(hud.quest_detail.text.contains("Gather wood and stone"), "Expanded quest shows real objective")
	var echo := InputEventMouseButton.new()
	echo.button_index = MOUSE_BUTTON_LEFT
	echo.position = hud.quest_toggle.get_global_rect().get_center()
	echo.pressed = true
	hud._input(echo)
	echo.pressed = false
	hud._input(echo)
	verify(hud.quest_expanded, "Synthetic Android mouse echo cannot close the Quest dropdown")
	_tap(hud, hud.quest_toggle, 40)
	verify(not hud.quest_expanded and not hud.quest_detail.visible, "Second QUESTS touch collapses objective")
	var map_box: Rect2 = hud.minimap.get_global_rect()
	verify(absf(hud.zone_pill.get_global_rect().end.y - map_box.position.y) < 2.0, "Zone title sits flush above minimap")
	game.queue_free()
	await process_frame
	print("HUD TOOLS RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
