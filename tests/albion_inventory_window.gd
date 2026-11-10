extends SceneTree
## Regression: Albion-inspired bag with real inventory and equipment actions.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, message: String) -> void:
	if ok:
		print("PASS INVENTORY: " + message)
	else:
		failures += 1
		push_error("FAIL INVENTORY: " + message)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Gameplay scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	game.save_path = "user://inventory_window_smoke.json"
	root.add_child(game)
	await process_frame
	game.inventory["wood"] = 12
	game.inventory["stone"] = 8
	game.inventory["spear"] = 1
	game.show_inventory()
	var panel = game.menu.inventory_window
	verify(game.menu.visible and panel.visible, "Bag opens a live separate inventory")
	verify(not game.menu.shell.visible, "Old crafting modal does not cover inventory")
	verify(panel.window.position.x > game.get_viewport().get_visible_rect().size.x * 0.45, "Inventory docks to right of the world")
	verify(panel.inventory_grid.columns >= 4 and panel.inventory_grid.columns <= 6, "Mobile grid uses 4-6 columns")
	verify(panel.inventory_grid.get_node_or_null("Item_wood") == null, "Character tab keeps materials out of equipment")
	verify(panel.inventory_grid.get_node_or_null("Item_spear") != null, "Real gear tile appears in Character")
	var spear_tile: Button = panel.inventory_grid.get_node_or_null("Item_spear") as Button
	verify(spear_tile != null and spear_tile.tooltip_text.contains("Weight") and spear_tile.tooltip_text.contains("Tap to inspect"), "Weapons expose concise tooltip on mouse hover; touch still opens details")
	await process_frame
	verify(not game.menu.emergency_close.visible, "Stray left-side emergency X is hidden while Inventory owns its own close")
	var inventory_x: Button = panel.find_child("InventoryCloseButton", true, false) as Button
	verify(inventory_x != null and inventory_x.get_theme_stylebox("normal") is StyleBoxFlat and (inventory_x.get_theme_stylebox("normal") as StyleBoxFlat).corner_radius_top_left >= 50, "Inventory has matching large red circular close button")
	verify(inventory_x != null and inventory_x.get_global_rect().get_center().x >= panel.window.get_global_rect().get_center().x, "Inventory X is attached to top-right of real inventory window")
	verify(panel.bag_meter.value > 0.0 and panel.bag_meter.max_value == game.bag_capacity(), "Capacity meter displays existing carry system")
	verify(panel.equipment_body.find_child("EquipmentSlot_weapon", true, false) != null, "Character equipment slots are actionable")
	verify(panel.window.get_global_rect().end.y <= game.get_viewport().get_visible_rect().size.y - 14.0,
		"Compact inventory fits inside the Android landscape viewport")
	verify(panel.inventory_grid.get_child_count() <= 18, "Short Character inventory has at most three rows, not 24 placeholder boxes")
	for equip_id in ["weapon", "offhand", "back", "bag", "tool_wood", "tool_mining", "tool_forage"]:
		var equip_slot: Button = panel.equipment_body.find_child("EquipmentSlot_" + equip_id, true, false) as Button
		verify(equip_slot != null and equip_slot.is_visible_in_tree(), "Every character equipment slot is visible: " + equip_id)
		if equip_slot != null:
			verify(equip_slot.get_global_rect().end.y <= panel.equipment_scroll.get_global_rect().end.y + 2.0,
				"Gear icon does not clip under avatar scroll area: " + equip_id)
	var starter_slot: Button = panel.equipment_body.find_child("EquipmentSlot_weapon", true, false) as Button
	verify(starter_slot != null and starter_slot.get_node_or_null("GearIcon") != null, "Equipped starter sword uses actual sword art instead of flag placeholder")
	if starter_slot != null:
		starter_slot.pressed.emit()
		verify(panel.item_card.visible and panel.selected_id == "training_blade", "Tapping equipped training sword identifies it as the starter weapon")
	panel._change_filter("character")
	game.inventory["axe"] = 1
	game.inventory["pickaxe"] = 1
	panel.refresh()
	var axe_slot: Button = panel.equipment_body.find_child("EquipmentSlot_tool_wood", true, false) as Button
	var pick_slot: Button = panel.equipment_body.find_child("EquipmentSlot_tool_mining", true, false) as Button
	verify(axe_slot != null and pick_slot != null, "Separate woodcutting and mining gear icons exist")
	if axe_slot != null:
		verify(axe_slot._can_drop_data(Vector2.ZERO, {"source":"outpost_character_inventory", "item_id":"axe"}), "Woodcutting slot accepts dragged crafted axe")
		verify(not axe_slot._can_drop_data(Vector2.ZERO, {"source":"outpost_character_inventory", "item_id":"pickaxe"}), "Woodcutting slot rejects incompatible pickaxe")
		axe_slot._drop_data(Vector2.ZERO, {"source":"outpost_character_inventory", "item_id":"axe"})
		verify(game.equipment["tool_wood"] == "axe", "Dropping axe equips the real item")
	if pick_slot != null:
		pick_slot._drop_data(Vector2.ZERO, {"source":"outpost_character_inventory", "item_id":"pickaxe"})
		verify(game.equipment["tool_mining"] == "pickaxe", "Dropping pickaxe equips the real item")
	panel.refresh()
	panel._change_filter("resource")
	verify(panel.inventory_grid.get_node_or_null("Item_wood") != null and panel.inventory_grid.get_node_or_null("Item_spear") == null, "Resources tab contains wood but not weapons")
	panel._change_filter("character")
	panel._select_item("spear")
	verify(panel.item_card.visible, "Tapping item shows detail pane")
	panel._equip_selected()
	verify(game.is_equipped("spear"), "Equip action uses existing gameplay equipment")
	verify(panel.inventory_grid.get_node_or_null("Item_spear/EquippedMarker") != null, "Equipped items have visible markers")
	panel._toggle_equipment()
	verify(not panel.equipment_section.visible, "Character silhouette collapses for additional bag room")
	panel._toggle_equipment()
	verify(panel.equipment_section.visible, "Equipment section expands again")
	panel._cycle_sort()
	verify(panel.sort_kind == "count", "Sort mode changes without modifying inventory data")
	verify(int(game.inventory["wood"]) == 12 and int(game.inventory["spear"]) == 1, "Sorting never mutates item quantities")
	game.show_equipment()
	verify(game.menu.current_page == "equipment" and panel.visible and panel.equipment_expanded, "Gear entry shares the same inventory window")
	game.menu.close_page()
	verify(not game.menu.visible and not panel.visible, "Closing returns to gameplay")
	game.show_crafting()
	verify(game.menu.visible and game.menu.shell.visible and not panel.visible, "Crafting remains a separate functioning page")
	game.menu.close_page()
	game.queue_free()
	await process_frame
	print("INVENTORY RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
