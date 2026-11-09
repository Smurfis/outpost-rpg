extends SceneTree
## The new MMORPG item tile must be one reusable touch target in inventory
## and crafting, with a neutral rarity border and circular quantity badge.
const TILES = preload("res://scripts/ui/mmorpg_item_tile.gd")
const HUD_V2 = preload("res://scripts/ui/hud_v2_components.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ITEM TILE: " + message)
	else:
		failures += 1
		push_error("FAIL ITEM TILE: " + message)

func _run() -> void:
	var probe := Button.new()
	TILES.apply_item_frame(probe, -1, false)
	var normal: StyleBox = probe.get_theme_stylebox("normal")
	check(normal is StyleBoxFlat, "Base item icon uses translucent flat style, not nine-slice texture")
	if normal is StyleBoxFlat:
		check((normal as StyleBoxFlat).border_color == HUD_V2.loot_icon_border(-1).border_color, "Unknown item quality is a neutral border")
	var badge: Panel = TILES.add_quantity_badge(probe, 17)
	check(badge != null and badge.name == "ItemQuantityBubble", "Circular quantity medallion belongs to one icon")
	check(badge.get_theme_stylebox("panel") is StyleBoxFlat, "Quantity medallion uses a pixel-hole-free style")
	var count: Label = probe.get_node_or_null("ItemQuantityBubble/ItemCount") as Label
	check(count != null and count.text == "17", "Quantity value matches accepted inventory count")
	check(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Quantity bubble never swallows item taps")
	probe.free()

	root.set_meta("outpost_new_adventure", true)
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "Outpost gameplay imports with new tile helper")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.inventory["wood"] = 12
	game.inventory["stone"] = 8
	game.show_inventory()
	await process_frame
	var inv = game.menu.inventory_window
	check(inv.visible and game.menu.current_page == "bag", "Current Albion inventory opens")
	var tile: Button = inv.inventory_grid.get_node_or_null("Item_wood") as Button
	check(tile != null, "Wood icon is a single tappable Button")
	if tile != null:
		var quantity: Label = tile.get_node_or_null("ItemQuantityBubble/ItemCount") as Label
		check(quantity != null and quantity.text == "12", "Inventory Wood has bottom-right ×12 count bubble")
		check(tile.get_theme_stylebox("normal") is StyleBoxFlat, "Inventory tile shares flat rarity-border style")
		check(tile.pressed.is_connected(inv._select_item.bind("wood")), "Existing tap-to-inspect binding preserved")
		tile.pressed.emit()
		check(inv.selected_id == "wood" and inv.item_card.visible, "Item tooltip still opens on tap")
		check(int(game.inventory["wood"]) == 12, "Visual feedback never alters inventory")
	game.menu.close_page()

	game.hero.global_position = game.station_positions["workbench"] + Vector3(0, 0.35, 0)
	game.show_crafting()
	await process_frame
	var spear: Button = game.menu.recipes_list.get_node_or_null("Recipe_spear") as Button
	check(spear != null, "Spear recipe remains actionable in woodwork station")
	if spear != null:
		var frame: Panel = spear.get_node_or_null("RecipeItemRarityFrame") as Panel
		check(frame != null and frame.get_theme_stylebox("panel") is StyleBoxFlat, "Recipe item art has the same rarity frame")
		if frame != null:
			check((frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color == HUD_V2.loot_icon_border(-1).border_color, "Crafting does not invent rarity")
		var recipe_name: Label = spear.get_child(1) as Label
		check(recipe_name != null and recipe_name.text.contains("Spear"), "Crafting description text position unchanged")
		spear.pressed.emit()
		check(game.menu.selected_id == "spear", "Recipe selection still works")
	game.menu.close_page()
	game.queue_free()
	await process_frame
	print("ITEM TILE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
