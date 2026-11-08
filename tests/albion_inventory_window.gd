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
	verify(panel.inventory_grid.get_node_or_null("Item_wood") != null, "Real material tile appears")
	verify(panel.inventory_grid.get_node_or_null("Item_spear") != null, "Real gear tile appears")
	var spear_tile: Button = panel.inventory_grid.get_node_or_null("Item_spear") as Button
	verify(spear_tile != null and spear_tile.tooltip_text.contains("Weight") and spear_tile.tooltip_text.contains("Tap to inspect"), "Weapons expose concise tooltip on mouse hover; touch still opens details")
	await process_frame
	verify(not game.menu.emergency_close.visible, "Stray left-side emergency X is hidden while Inventory owns its own close")
	var inventory_x: Button = panel.window.find_child("InventoryCloseButton", true, false) as Button
	verify(inventory_x != null and inventory_x.get_theme_stylebox("normal") is StyleBoxFlat and (inventory_x.get_theme_stylebox("normal") as StyleBoxFlat).corner_radius_top_left >= 50, "Inventory has matching large red circular close button")
	verify(inventory_x != null and inventory_x.get_global_rect().get_center().x >= panel.window.get_global_rect().get_center().x, "Inventory X is attached to top-right of real inventory window")
	verify(panel.bag_meter.value > 0.0 and panel.bag_meter.max_value == game.bag_capacity(), "Capacity meter displays existing carry system")
	verify(panel.equipment_body.find_child("EquipmentSlot_weapon", true, false) != null, "Character equipment slots are actionable")
	panel._change_filter("consumable")
	verify(panel.inventory_grid.get_node_or_null("Item_wood") == null, "Category filtering removes unrelated items")
	panel._change_filter("all")
	panel._select_item("spear")
	verify(panel.item_card.visible, "Tapping item shows detail pane")
	panel._equip_selected()
	verify(game.is_equipped("spear"), "Equip action uses existing gameplay equipment")
	verify(panel.inventory_grid.get_node_or_null("Item_spear/EquippedMarker") != null, "Equipped items have visible markers")
	panel._toggle_equipment()
	verify(not panel.equipment_body.get_parent().visible, "Character silhouette collapses for additional bag room")
	panel._toggle_equipment()
	verify(panel.equipment_body.get_parent().visible, "Equipment section expands again")
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
