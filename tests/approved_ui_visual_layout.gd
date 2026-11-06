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
	var status_box: Panel = hud.get_node_or_null("HeroStatusFrame") as Panel
	verify(status_box != null, "Compact player card")
	var crest: TextureRect = hud.get_node_or_null("OutpostSigil") as TextureRect
	verify(crest != null and crest.texture != null, "Original small crest replaces blocky fixed face")
	verify(hud.get_node_or_null("HeroPortrait") == null, "Generic hero portrait removed from gameplay HUD")
	if status_box != null:
		var screen: Vector2 = game.hud.get_viewport().get_visible_rect().size
		verify(status_box.size.y <= screen.y * 0.135, "Top-left identity uses at most 13.5% of screen height")
		verify(status_box.size.x <= screen.x * 0.26, "Status card leaves space for real world view")
	verify(hud.get_node_or_null("ResourceQuickChips") != null, "Actual inventory resource chips")
	verify(hud.get_node_or_null("QuestBanner") != null, "One slim quest banner")
	var toggle: Button = hud.get_node_or_null("QuestToggle") as Button
	verify(toggle != null, "Quest banner has functional tap-to-expand")
	if toggle != null:
		toggle.pressed.emit()
	verify(game.hud.quest_detail.visible and game.hud.quest_detail_back.visible, "Quest expands without changing game state")
	verify(game.hud.quest.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "Single-line quest truncates safely instead of overflowing")
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
	game.hud._toggle_quest()
	game.hud.render_status(67.0, {"wood": 8}, 52, 0, "spear", "Starter quest finished: craft new gear, explore and survive", "Explore: iron, coal and clay")
	verify(not game.hud.quest_frame.visible and not game.hud.quest.visible, "Completed starter objective no longer wastes top screen space")
	verify(game.hud.quest_toggle.visible, "Compact journal button remains after completion")
	verify(not game.hud.hint.visible, "Generic explore message does not occupy bottom center")
	game.hud.update_context(true, false, false)
	game.hud.render_status(67.0, {"wood": 8}, 52, 0, "spear", "Gather 5 wood", "Nearby: Tree, 2 hits")
	verify(game.hud.quest_frame.visible and game.hud.hint.visible, "Real objective and nearby action remain visible")
	game.hud.update_context(false, false, false)
	verify(not game.hud.hint.visible, "Context label disappears out of range")

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
	verify(crafting != null, "Craft modal exists")
	if crafting != null:
		verify(crafting.size.x <= 880.0 and crafting.size.y <= 600.0, "Craft modal pixel dimensions capped on wide phones")
		verify(crafting.size.x < game.menu.shell.size.x * 0.75, "Craft leaves landscape visible on Android")
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
