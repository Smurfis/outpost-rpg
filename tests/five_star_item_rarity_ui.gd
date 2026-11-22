extends SceneTree
## Five-star ITEM rarity is a presentation of saved equipment quality, not
## the separate 0-3 bag-capacity upgrade or dungeon-entrance challenge tier.
## Run: godot --headless --path . -s res://tests/five_star_item_rarity_ui.gd
const VIEW = preload("res://scripts/ui/outpost_item_view.gd")
const QUALITY = preload("res://scripts/crafting/equipment_quality.gd")
var failures: int = 0

func verify(ok: bool, detail: String) -> void:
	if ok:
		print("PASS FIVE-STAR ITEMS: " + detail)
	else:
		failures += 1
		push_error("FAIL FIVE-STAR ITEMS: " + detail)

func strip_text(strip: HBoxContainer) -> String:
	if strip == null:
		return ""
	var result: String = ""
	for child in strip.get_children():
		if child is Label:
			result += (child as Label).text
	return result

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var expected: Array[String] = ["★☆☆☆☆", "★★☆☆☆", "★★★☆☆", "★★★★☆", "★★★★★"]
	for rank in range(5):
		verify(VIEW.rarity_stars(rank) == expected[rank], "Rank %d renders exactly five slots" % rank)
		verify(VIEW.rarity_color(rank) == QUALITY.rarity_color(rank), "Rank %d uses canonical crafting colour" % rank)
	verify(VIEW.rarity_caption(3) == "★★★★☆  Epic", "Tooltip pairs the rank with readable name")
	verify(VIEW.rarity_stars(-1).is_empty(), "Unassigned rarity never fabricates a star")
	verify(VIEW.item_rarity("spear", {"spear": {"rarity": 4}}) == 4, "Saved legendary roll maps to five stars")
	verify(VIEW.item_rarity("spear", {}) == 0, "Legacy crafted gear defaults to Common")
	verify(VIEW.item_rarity("training_blade", {}) == 0, "Starter sword is Common")
	verify(VIEW.item_rarity("wood", {}) == -1, "Resources without rarity metadata remain ungraded")
	verify(VIEW.item_rarity("backpack_t1", {}) == -1, "Bag-capacity upgrade stars do not become item rarity")

	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Game scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	game.save_path = "user://five_star_item_rarity_ui_smoke.json"
	root.add_child(game)
	await process_frame
	game.inventory["spear"] = 1
	game.inventory["wood"] = 12
	game.best_craft_rolls["spear"] = {
		"rarity": 3, "bonuses": {"damage": 4}, "affix": "", "score": 36.0
	}
	game.show_inventory()
	var panel = game.menu.inventory_window
	var tile: Button = panel.inventory_grid.get_node_or_null("Item_spear") as Button
	verify(tile != null, "Crafted equipment displays as a bag tile")
	if tile != null:
		var star_strip: HBoxContainer = tile.get_node_or_null("ItemRarityStars") as HBoxContainer
		var border: Panel = tile.get_node_or_null("ItemRarityBorder") as Panel
		verify(strip_text(star_strip) == "★★★★☆", "Bag tile uses saved Epic star row")
		var border_style: StyleBoxFlat = null
		if border != null:
			border_style = border.get_theme_stylebox("panel") as StyleBoxFlat
		verify(border_style != null and border_style.border_color == VIEW.rarity_color(3), "Bag tile has Epic border")
		if star_strip != null:
			var unfilled: Label = star_strip.get_node_or_null("RarityStar_4") as Label
			verify(unfilled != null and unfilled.get_theme_color("font_color") == Color("#5b534a"), "Unfilled stars stay dark")
	verify(panel._item_tip("spear").contains("★★★★☆  Epic"), "Desktop tooltip displays item rating")
	verify(not panel._item_tip("wood").contains("★"), "Plain wood has no fabricated rating")
	panel._select_item("spear")
	var label: Label = panel.item_info.find_child("ItemRarityCaption", true, false) as Label
	verify(label != null and label.text == "★★★★☆  EPIC", "Item details display the same saved rating")
	verify(game.equip_item("spear"), "Equipping does not modify the saved rarity")
	panel.refresh()
	var slot: Button = panel.equipment_body.find_child("EquipmentSlot_weapon", true, false) as Button
	var equipped_strip: HBoxContainer = null
	if slot != null:
		equipped_strip = slot.get_node_or_null("ItemRarityStars") as HBoxContainer
	verify(strip_text(equipped_strip) == "★★★★☆", "Equipped weapon shows its quality stars")

	game.hud.record_loot("spear", 1)
	verify(int(game.hud.loot_feed_entries[0].get("rarity", -1)) == 3, "Loot receipt reads saved equipment rarity")
	game.menu.close_page()
	game.last_craft_roll = game.best_craft_rolls["spear"].duplicate(true)
	game.last_craft_improved = true
	game.show_crafting()
	game.menu.on_craft_completed("spear")
	var reveal: HBoxContainer = game.menu.find_child("CraftResultRarityStars", true, false) as HBoxContainer
	verify(strip_text(reveal) == "★★★★☆", "Craft result matches the five-star inventory display")
	game.queue_free()
	await process_frame
	print("FIVE-STAR ITEM RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
