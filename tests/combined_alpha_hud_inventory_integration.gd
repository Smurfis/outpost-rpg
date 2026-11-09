extends SceneTree
## Combined Android Alpha QA: genuine mana, inventory categories, scrollable
## equipment and chest comparison, single-tap close, 20:9 wide viewport.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS COMBINED ALPHA: " + detail)
	else:
		failures += 1
		push_error("FAIL COMBINED ALPHA: " + detail)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var world: PackedScene = load("res://scenes/main.tscn")
	check(world != null, "World imports with pixel water and PyroLux hooks")
	if world == null:
		quit(1)
		return
	var game = world.instantiate()
	root.add_child(game)
	await process_frame
	check(game.get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Gameplay uses full-width Android content")
	check(game.mana_limit() == 35.0 and game.mana >= 0.0 and game.mana <= game.mana_limit(), "Mana is real character state, not HUD filler")
	var hud = game.hud
	check(hud.mana_bar.visible and hud.mana_numbers.visible, "Blue MP gauge is visible under health")
	check(not hud.mana_numbers.text.contains("—"), "MP gauge contains an actual numeric value")
	check(hud.root.get_node_or_null("SettingsMenuButton") != null, "Menu replaces remote CRAFT with controls settings")
	check(hud.root.get_node_or_null("Action_craft") == null, "General Menu contains no remote Craft shortcut")
	var zone = hud.zone_pill
	check(zone != null and zone.get_global_rect().end.y <= hud.minimap.get_global_rect().position.y, "Area label sits above minimap, not over it")
	check(absf(hud.xp_bar.get_global_rect().end.y - get_viewport().get_visible_rect().size.y) < 1.5, "Character XP remains attached to bottom edge")
	var food: Button = hud.quick_buttons["consumable"] as Button
	var potion: Button = hud.quick_buttons["potion"] as Button
	var torch: Button = hud.torch_button
	check(torch.get_global_rect().get_center().x > food.get_global_rect().get_center().x, "Torch moved to the right of Food")
	check(torch.get_global_rect().get_center().x > potion.get_global_rect().get_center().x, "Torch moved to the right of Potion")
	check(not torch.get_global_rect().intersects(food.get_global_rect()), "Torch and Food have separate hit rectangles")
	check(not torch.get_global_rect().intersects(potion.get_global_rect()), "Torch and Potion have separate hit rectangles")
	check(not hud.smart_button.get_global_rect().intersects(hud.xp_bar.get_global_rect()), "Interact remains above XP bar")
	check(not hud.smart_button.get_global_rect().intersects(torch.get_global_rect()), "Lower Interact does not collide with Torch")

	game.inventory["wood"] = 8
	game.inventory["stone"] = 4
	game.inventory["spear"] = 1
	game.inventory["meal"] = 2
	game.show_inventory()
	await process_frame
	var inv = game.menu.inventory_window
	check(inv.filter_kind == "character" and inv.visible, "Character view is default")
	check(inv.inventory_grid.get_node_or_null("Item_spear") != null, "Character holds weapons")
	check(inv.inventory_grid.get_node_or_null("Item_meal") != null, "Character holds consumables")
	check(inv.inventory_grid.get_node_or_null("Item_wood") == null, "Character does not mix raw resources into gear")
	check(inv.equipment_scroll != null and inv.equipment_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS, "Avatar and gear have an independent visible scrollbar")
	check(inv.scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS, "Item inventory has a visible vertical scrollbar")
	inv._change_filter("resource")
	check(inv.inventory_grid.get_node_or_null("Item_wood") != null and inv.inventory_grid.get_node_or_null("Item_stone") != null, "Resources tab displays actual harvested supplies")
	check(inv.inventory_grid.get_node_or_null("Item_spear") == null, "Resources tab excludes equipment")
	check(not inv.equipment_section.visible, "Resources tab hides avatar and equipment panel")
	var x: Button = inv.inventory_close_button
	var tap := InputEventScreenTouch.new()
	tap.index = 24
	tap.pressed = true
	tap.position = x.get_global_rect().get_center()
	game.menu._input(tap)
	check(not game.menu.visible and not inv.visible, "One touch DOWN closes inventory using its actual top-right X")

	var snapshot: Dictionary = game.inventory.duplicate(true)
	game.menu.open_storage("WOOD CHEST", {"wood": 35, "stone": 7})
	await process_frame
	check(inv.visible and inv.storage_panel.visible and inv.storage_mode, "Chest opens two-panel inventory comparison")
	check(not inv.equipment_section.visible and not inv.equipment_toggle.visible, "Chest hides character gear model")
	check(inv.inventory_grid.get_node_or_null("Item_wood") != null, "Player items stay visible alongside chest")
	check(inv.storage_grid.get_node_or_null("ChestItem_wood") != null, "Storage shows real provided contents")
	check(inv.storage_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS, "Chest inventory has its own scrollbar")
	check(game.inventory == snapshot, "Read-only storage preview never fabricates transfers")
	game.menu._input(tap)
	check(not game.menu.visible, "Same close X exits storage comparison")
	game.queue_free()
	await process_frame
	print("COMBINED ALPHA RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
