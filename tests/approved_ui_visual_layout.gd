extends SceneTree
## Integration acceptance: reusable mobile HUD and compact touch crafting.
## No claim of pixel-perfect similarity until a physical Android screenshot.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, text_value: String) -> void:
	if ok:
		print("PASS APPROVED UI: " + text_value)
	else:
		failures += 1
		push_error("FAIL APPROVED UI: " + text_value)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Original gameplay still imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame

	var hud: Control = game.hud.root
	verify(hud != null, "HUD is live and attached to gameplay")
	verify(hud.get_node_or_null("HeroStatusFrame") != null, "Compact player card")
	verify(hud.get_node_or_null("PortraitMedallion") != null, "Hero portrait frame")
	var portrait: TextureRect = hud.get_node_or_null("HeroPortrait") as TextureRect
	verify(portrait != null and portrait.texture != null, "Independent imported adventurer portrait art")
	verify(hud.get_node_or_null("ResourceQuickChips") != null, "Actual inventory resource chips")
	verify(hud.get_node_or_null("QuestBanner") != null, "One slim quest banner")
	var toggle: Button = hud.get_node_or_null("QuestToggle") as Button
	verify(toggle != null, "Quest banner has functional tap-to-expand")
	if toggle != null:
		toggle.pressed.emit()
	verify(game.hud.quest_detail.visible and game.hud.quest_detail_back.visible, "Quest expands without changing game state")
	var hotbar: Panel = hud.get_node_or_null("FunctionalHotbar") as Panel
	verify(hotbar != null, "Dedicated framed hotbar")
	for key in ["bag", "craft", "gear"]:
		verify(hud.get_node_or_null("Action_" + key) != null, "Hotbar real button " + key)
	verify(hud.get_node_or_null("TorchQuickSlot") != null, "Offhand torch remains accessible")
	for key in ["skill_1", "skill_2", "skill_3", "potion", "consumable", "interact"]:
		var action: Button = hud.get_node_or_null("Action_" + key) as Button
		verify(action != null, "New radial action " + key)
		if action != null:
			var shape: StyleBox = action.get_theme_stylebox("normal")
			verify(shape is StyleBoxFlat and (shape as StyleBoxFlat).corner_radius_top_left >= 60, "Round framed " + key)
	verify(hud.get_node_or_null("Action_attack") == null and hud.get_node_or_null("Action_gather") == null, "No redundant attack or gather tiles")
	verify(hud.get_node_or_null("CharacterLevelXP") != null and hud.get_node_or_null("CharacterLevelLabel") != null, "Character level XP bar spans lower screen")
	var coop: Button = hud.get_node_or_null("CoopEntryButton") as Button
	verify(coop != null and coop.pressed.is_connected(game.hud._open_coop), "Co-op remains usable")
	game.hud.render_status(67.0, {"wood": 8, "stone": 5, "hide": 3, "coins": 12}, 52, 0, "spear", "Gather more wood", "Nearby: a tree")
	verify(game.hud.health_numbers.text.contains("67"), "Health is a true live value")
	verify(game.hud.items["wood"].text == "8", "Resource chip reflects inventory")

	game.inventory["wood"] = 8
	game.inventory["stone"] = 5
	game.show_inventory()
	verify(game.menu.current_page == "bag", "Bag opens from old gameplay API")
	var grid: GridContainer = game.menu.recipes_list.get_node_or_null("BagItemGrid") as GridContainer
	verify(grid != null and grid.columns == 4, "Bag uses compact 4-column sprite inventory")
	if grid != null:
		verify(grid.get_node_or_null("Item_wood") != null, "Item tiles are real interactive buttons")
		game.menu._bag_select("wood")
		verify(game.menu.selected_bag_id == "wood", "Item selection opens details")

	game.hero.global_position = game.station_positions["workbench"] + Vector3(0.0, 0.35, 0.0)
	game.menu.close_page()
	game.show_crafting()
	var crafting: Control = game.menu.shell.get_child(1) as Control
	verify(crafting != null and crafting.anchor_right - crafting.anchor_left < 0.68, "Craft modal leaves landscape visible")
	verify(game.menu.craft_step == "browse", "Craft stage begins on full-width recipe cards")
	verify(game.menu.left_scroll.visible and not game.menu.right_scroll.visible, "Single pane recipe browse")
	var spear: Button = game.menu.recipes_list.get_node_or_null("Recipe_spear") as Button
	verify(spear != null, "Forest Spear is a real item card")
	if spear != null:
		spear.pressed.emit()
	verify(game.menu.craft_step == "detail" and not game.menu.left_scroll.visible, "Tap a card to inspect item")
	game.menu._begin_prepare()
	verify(game.menu.craft_step == "prepare", "Prepare step preserves real crafting state")
	game.menu.close_page()
	verify(not game.menu.visible, "Close returns to gameplay without modifying inventory")
	game.queue_free()
	await process_frame
	print("APPROVED UI RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
