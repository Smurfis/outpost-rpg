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
	var portrait: TextureRect = hud.get_node_or_null("HeroPortrait") as TextureRect
	verify(portrait != null and portrait.texture != null, "New original adventurer portrait is visible inside compact player card")
	verify(hud.get_node_or_null("HeroPortraitFrame") != null, "Portrait has its own illustrated frame")
	if status_box != null:
		var screen: Vector2 = game.hud.get_viewport().get_visible_rect().size
		verify(status_box.size.y <= screen.y * 0.15, "Top-left portrait and HP use at most 15% of screen height")
		verify(status_box.size.x <= screen.x * 0.285, "Status card remains below 28.5% of viewport width")
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
	for key in ["bag", "gear"]:
		verify(hud.get_node_or_null("Action_" + key) != null, "Hotbar real button " + key)
	verify(hud.get_node_or_null("Action_craft") == null and hud.get_node_or_null("SettingsMenuButton") != null, "No remote Craft; real settings replaces menu shortcut")
	verify(hud.get_node_or_null("TorchQuickSlot") != null, "Offhand torch remains accessible")
	for key in ["skill_1", "skill_2", "skill_3", "potion", "consumable", "interact"]:
		var action: Button = hud.get_node_or_null("Action_" + key) as Button
		verify(action != null, "New radial action " + key)
		if action != null:
			var shape: StyleBox = action.get_theme_stylebox("normal")
			# Image-backed circular medallions replaced the old flat rounded panels.
			# Verify actual active and disabled artwork instead of checking corner radii.
			var inactive: StyleBox = action.get_theme_stylebox("disabled")
			verify(shape is StyleBoxTexture and (shape as StyleBoxTexture).texture != null
				and inactive is StyleBoxTexture and (inactive as StyleBoxTexture).texture != null,
				"Round framed " + key)
	verify(hud.get_node_or_null("Action_attack") == null and hud.get_node_or_null("Action_gather") == null, "No redundant attack or gather tiles")
	var main_action: Button = hud.get_node_or_null("Action_interact") as Button
	verify(main_action != null and main_action.get_node_or_null("ToolSwipeChevron") != null, "Hold-to-select gesture keeps a small always-visible arrow")
	game.hud._process(8.5)
	var tool_hint: Label = hud.get_node_or_null("QuickToolGestureHint") as Label
	var camera_hint: Label = hud.get_node_or_null("CameraDragHint") as Label
	verify(tool_hint != null and not tool_hint.visible, "Temporary tool help no longer blocks the world")
	verify(camera_hint != null and not camera_hint.visible, "Temporary camera help no longer blocks the world")
	verify(hud.get_node_or_null("CharacterLevelXP") != null and hud.get_node_or_null("CharacterLevelLabel") != null, "Character XP remains in its bottom bar")
	var radial: Control = hud.get_node_or_null("RadialLevelFrame") as Control
	verify(radial != null and radial.get_node_or_null("LevelNumber") != null, "Reusable radial art remains available for future skill-level popups")
	verify(radial != null and not radial.visible, "Oversized character-level radial does not cover gameplay")
	verify(game.hud.xp_level_badge.visible, "Compact numeric character level belongs beside portrait, not inside XP")
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
	var inv = game.menu.inventory_window
	verify(inv != null and inv.visible and not game.menu.shell.visible, "Separate right-side inventory opens instead of old crafting panel")
	var character_tab: Button = inv.get_node_or_null("InventoryWindow/InventoryLayout/BagFilters/BagFilter_character") as Button
	var resources_tab: Button = inv.get_node_or_null("InventoryWindow/InventoryLayout/BagFilters/BagFilter_resource") as Button
	verify(character_tab != null and resources_tab != null, "Inventory has distinct Character and Resources tabs")
	inv._change_filter("resource")
	verify(inv.filter_kind == "resource" and inv.inventory_grid.get_node_or_null("Item_wood") != null, "Resources tab displays actual carried materials")
	inv._change_filter("character")
	verify(inv.bag_meter != null and inv.bag_meter.get_theme_stylebox("fill") is StyleBoxFlat, "Real bag load meter remains visible")
	var grid: GridContainer = inv.inventory_grid
	verify(grid != null and grid.columns >= 4 and grid.columns <= 6, "Inventory grid adapts to landscape phone widths")
	if grid != null:
		verify(grid.get_node_or_null("Item_wood") == null, "Character tab does not mix raw wood with equipment")
		inv._change_filter("resource")
		verify(grid.get_node_or_null("Item_wood") != null, "Resources tab exposes real materials")
		inv._select_item("wood")
		verify(inv.selected_id == "wood" and inv.item_card.visible, "Item selection opens functional detail pane")
		verify(inv.get_node_or_null("InventoryWindow/InventoryLayout/CharacterEquipmentSection") != null, "Inventory displays collapsible equipment silhouette")
	game.hero.global_position = game.station_positions["workbench"] + Vector3(0.0, 0.35, 0.0)
	game.menu.close_page()
	game.show_crafting()
	await process_frame
	var crafting: Control = game.menu.shell.get_child(1) as Control
	verify(crafting != null, "Craft modal exists")
	if crafting != null:
		print("UI POPUP ACTUAL: %s screen=%s" % [crafting.size, game.menu.get_viewport().get_visible_rect().size])
	if crafting != null:
		verify(crafting.size.x <= 880.0 and crafting.size.y <= 600.0, "Craft modal pixel dimensions capped on wide phones")
		verify(crafting.size.x < game.menu.shell.size.x * 0.75, "Craft leaves landscape visible on Android")
	verify(game.menu.craft_step == "browse", "Station begins with browse/selected recipe")
	verify(not game.menu.craft_stage_strip.visible and game.menu.craft_stage_strip.get_child_count() == 0, "No extra four-step breadcrumb controls")
	verify(not game.menu.station_tabs.visible and game.menu.station_tabs.get_child_count() == 0, "Interacting with one object never displays five station tabs")
	verify(game.menu.selected_station == "workbench" and game.menu.title.text.contains("WOODWORK"), "Actual nearby workbench determines the crafting header")
	verify(game.menu.station_badge.visible and game.menu.station_badge.texture != null, "Independent woodwork icon represents the interacted station")
	verify(game.menu.left_scroll.visible and game.menu.right_scroll.visible, "Recipes on the left; item details remain on the right")
	var spear: Button = game.menu.recipes_list.get_node_or_null("Recipe_spear") as Button
	verify(spear != null, "Forest Spear is a tappable recipe row")
	if spear != null:
		var name_text: Label = spear.get_child(1) as Label
		verify(name_text != null and name_text.get_theme_color("font_color") == Color("#342416"), "Item names remain legible on light parchment")
		spear.pressed.emit()
	verify(game.menu.selected_id == "spear" and game.menu.left_scroll.visible, "Tapping a recipe shows details without leaving the list")
	var craft_action: Button = game.menu.details.find_child("StationCraftAction", true, false) as Button
	verify(craft_action != null and craft_action.text.contains("CRAFT"), "Station detail has one clear craft action instead of Prepare and Load tabs")
	var close_crafting: Button = game.menu.dismiss_button
	verify(close_crafting != null and not close_crafting.disabled and close_crafting.pressed.is_connected(game.menu.close_page), "Craft X is always reachable")
	if close_crafting != null:
		var red_circle: StyleBoxFlat = close_crafting.get_theme_stylebox("normal") as StyleBoxFlat
		verify(red_circle != null and red_circle.corner_radius_top_left >= 50 and close_crafting.custom_minimum_size.x >= 54, "Close X is a large, red circular button")
	game.menu.close_page()
	verify(not game.menu.visible, "Close returns to gameplay without modifying inventory")
	game.hero.global_position = game.station_positions["campfire"] + Vector3(0.0, 0.35, 0.0)
	game.show_crafting()
	verify(game.menu.selected_station == "campfire" and game.menu.title.text.contains("CAMPFIRE"), "Campfire interaction immediately switches correct station context")
	verify(game.menu.station_badge.texture.resource_path.ends_with("/station_campfire.svg"), "Campfire gets its own visual icon")
	verify(game.menu.recipes_list.get_node_or_null("Recipe_spear") == null, "Campfire shows food/tonic recipes, never unrelated workbench weapons")
	var outside_tap := InputEventScreenTouch.new()
	outside_tap.pressed = true
	game.menu._dismiss_from_shade(outside_tap)
	verify(not game.menu.visible, "Tapping outside campfire safely dismisses modal")
	game.show_crafting()
	var android_back := InputEventAction.new()
	android_back.action = "ui_cancel"
	android_back.pressed = true
	game.menu._input(android_back)
	verify(not game.menu.visible, "Android Back/Escape always closes station crafting")
	game.queue_free()
	await process_frame
	print("APPROVED UI RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
