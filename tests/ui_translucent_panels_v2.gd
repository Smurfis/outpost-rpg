extends SceneTree
## Visual regression: remaining world HUD/crafting/inventory panels must use
## flat, genuinely alpha-blended styles rather than legacy nine-slice images.
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS TRANSLUCENT UI: " + label)
	else:
		failures += 1
		push_error("FAIL TRANSLUCENT UI: " + label)

func surface(control: Control, label: String, light: bool = false) -> void:
	check(control != null, label + " exists")
	if control == null:
		return
	var style: StyleBox = control.get_theme_stylebox("panel")
	check(style is StyleBoxFlat and not style is StyleBoxTexture, label + " has a flat, texture-free surface")
	if style is StyleBoxFlat:
		var flat: StyleBoxFlat = style as StyleBoxFlat
		check(flat.bg_color.a > 0.50 and flat.bg_color.a < 0.98, label + " is translucent but legible")
		if light:
			check(flat.bg_color.r > 0.75, label + " keeps light surface for dark ink text")

func _run() -> void:
	var parchment: StyleBoxFlat = SKIN.translucent_surface(true)
	var wood: StyleBoxFlat = SKIN.translucent_surface()
	var selected: StyleBoxFlat = SKIN.translucent_surface(false, true, true)
	check(parchment.bg_color.a < 1.0 and parchment.bg_color.a > 0.75, "Light parchment is alpha blended without pixel holes")
	check(wood.bg_color.a < 0.90 and selected.border_color.a > wood.border_color.a, "Dark panel and active selection remain visually distinguishable")
	var button := Button.new()
	SKIN.apply_translucent_button(button, "wood_selected")
	check(button.get_theme_stylebox("normal") is StyleBoxFlat and button.get_theme_stylebox("pressed") is StyleBoxFlat, "New button treatment contains no nine-slice texture")
	button.free()

	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Real game loads with translucent styles")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	surface(hud.quest_detail_back, "Expanded quest journal", true)
	surface(hud.toast_panel, "Context toast", true)
	surface(hud.quick_tray, "Consumable quick tray")
	surface(hud.smart_tray, "Tool-selection tray")
	var menu_button: Button = hud.root.get_node_or_null("TopRightMenuButton") as Button
	check(menu_button != null and menu_button.get_theme_stylebox("normal") is StyleBoxFlat, "Top-right MENU button now has flat chrome")
	hud._toggle_quest()
	check(hud.quest_detail_back.visible, "Quest journal remains tappable and expandable")
	hud._toggle_quest()
	hud.toast("UI visual regression")
	check(hud.toast_panel.visible and hud.toast_label.text.contains("regression"), "Toast retains real message text")
	hud.toast_panel.visible = false
	hud.toast_label.visible = false

	game.inventory["wood"] = 12
	game.show_inventory()
	await process_frame
	var inventory = game.menu.inventory_window
	var equipment: PanelContainer = inventory.window.find_child("CharacterEquipmentSection", true, false) as PanelContainer
	var carried: PanelContainer = inventory.window.find_child("CarriedItems", true, false) as PanelContainer
	surface(equipment, "Equipment section", true)
	surface(carried, "Carried-item grid", true)
	var item: Button = inventory.inventory_grid.get_node_or_null("Item_wood") as Button
	check(item != null and item.get_theme_stylebox("normal") is StyleBoxFlat, "Real inventory item retains tap action with flat frame")
	var empty: Panel = inventory.inventory_grid.find_child("EmptyInventorySlot", true, false) as Panel
	surface(empty, "Empty inventory slots")
	inventory._select_item("wood")
	check(inventory.item_card.visible and inventory.selected_id == "wood", "Inventory item tooltip and selection stay functional")
	game.menu.close_page()

	game.hero.global_position = game.station_positions["workbench"] + Vector3(0, 0.35, 0)
	game.show_crafting()
	await process_frame
	check(game.menu.shell.visible and game.menu.current_page == "craft", "Station opens unchanged crafting flow")
	var recipe: Button = game.menu.recipes_list.get_node_or_null("Recipe_spear") as Button
	check(recipe != null, "Actual spear recipe still exists")
	if recipe != null:
		check(recipe.get_theme_stylebox("normal") is StyleBoxFlat, "Recipe selection has flat parchment card")
		check(game.menu.selected_id != "" and game.menu.left_scroll.visible, "Recipe list scrolls as before")
	var crafting_surface: PanelContainer = game.menu.popup_frame.find_child("PanelContainer", true, false) as PanelContainer
	if crafting_surface == null:
		# The surface can be referenced by its first PanelContainer descendant
		# without relying on anonymous node names from earlier versions.
		for c in game.menu.popup_frame.get_children():
			if c is VBoxContainer:
				for node in c.get_children():
					if node is PanelContainer:
						crafting_surface = node
						break
	surface(crafting_surface, "Crafting two-column surface", true)
	game.menu.close_page()
	game.queue_free()
	await process_frame
	print("TRANSLUCENT UI RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
