extends SceneTree
## Outpost MMORPG reusable loot-icon style and touch tooltip regression.
const VIEW = preload("res://scripts/ui/outpost_item_view.gd")
const HUD_COMPONENTS = preload("res://scripts/ui/hud_v2_components.gd")
var failures: int = 0

func verify(ok: bool, title: String) -> void:
	if ok:
		print("PASS LOOT FEED: " + title)
	else:
		failures += 1
		push_error("FAIL LOOT FEED: " + title)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Game scene and HUD import")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	verify(hud.loot_feed_panel != null and not hud.loot_feed_panel.visible, "Empty feed does not obstruct world or action buttons")
	hud.record_gather("wood", 3)
	hud.record_loot("wood", 3)
	await process_frame
	verify(hud.loot_feed_panel.visible and hud.loot_feed_rows.visible, "Actual grant keeps the compact item feed below Quests")
	verify(hud.loot_feed_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "Loot and combat feed have no opaque rectangle or border")
	verify(not hud.loot_feed_title.visible, "No permanent loot/combat heading clutters the screen")
	verify(not hud.gathered_panel.visible and hud.loot_feed_panel.get_global_rect().position.y >= hud.quest_frame.get_global_rect().end.y, "No persistent Last Gathered card; item feed remains below Quest")
	verify(hud.loot_feed_entries.size() == 1, "One grant creates one bounded receipt")
	verify(hud.loot_icon_controls.size() == 1, "Item receipt has exactly one tappable icon")
	var icon: Button = hud.loot_icon_controls[0] as Button
	verify(icon != null and icon.name == "ItemRarityFrame", "Framed icon is a reusable Godot Button")
	verify(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Custom Android input routing isn't intercepted by nested GUI")
	var badge: Panel = icon.get_node_or_null("ItemQuantityBubble") as Panel
	var count: Label = icon.get_node_or_null("ItemQuantityBubble/ItemQuantityNumber") as Label
	verify(badge != null and count != null and count.text == "3", "Small circular quantity badge shows x3 in bottom-right")
	verify(hud.loot_feed_rows.get_child(0).get_node_or_null("LootReceiptText").text.contains("You received ×3 Wood"), "Feed uses the requested acquisition wording")
	verify(VIEW.rarity_name(-1) == "Rarity not assigned", "Unimplemented quality isn't falsely labelled Common or Rare")
	verify(HUD_COMPONENTS.loot_icon_border(-1).border_color == Color("#83766c"), "Unknown rarity receives neutral border")

	var down := InputEventScreenTouch.new()
	down.index = 4
	down.pressed = true
	down.position = icon.get_global_rect().get_center()
	hud._input(down)
	verify(hud.loot_tooltip_panel.visible and hud.loot_tooltip_name.text == "Wood", "Tap icon opens real item-name tooltip")
	verify(hud.loot_tooltip_rarity.text == "Rarity not assigned", "Tooltip shows unassigned rarity accurately")
	verify(not hud.loot_tooltip_description.text.is_empty(), "Tooltip contains description text or an explicit unassigned description")
	var up := InputEventScreenTouch.new()
	up.index = 4
	up.pressed = false
	up.position = down.position
	hud._input(up)
	hud._input(down)
	verify(not hud.loot_tooltip_panel.visible, "Second tap toggles item tooltip closed")

	hud.record_loot("stone", 2, 3)
	await process_frame
	verify(hud.loot_icon_controls.size() == 2, "New loot receipts are shown without overwriting earlier ones")
	var rare: Button = hud.loot_icon_controls[0]
	verify(rare.get_theme_stylebox("normal").border_color == VIEW.rarity_color(3), "Real item rarity 3 is shown with correct epic border")
	var epic_tap := InputEventScreenTouch.new()
	epic_tap.index = 5
	epic_tap.pressed = true
	epic_tap.position = rare.get_global_rect().get_center()
	hud._input(epic_tap)
	verify(hud.loot_tooltip_name.text == "Stone" and hud.loot_tooltip_rarity.text == "Epic", "Rarity and name update from actual supplied item metadata")
	hud.record_combat_event("Boar defeated")
	verify(hud.loot_feed_entries[0].get("kind", "") == "combat", "Combat events share the same readable feed")
	verify(hud.loot_feed_rows.get_child(0).get_node_or_null("LootReceiptText").text == "Boar defeated", "Combat line renders without pretending it was a loot drop")
	hud.record_loot("iron", 1)
	verify(hud.loot_feed_entries.size() == 3, "Log caps at three receipts for mobile readability")
	hud.record_loot("iron", 4)
	verify(hud.loot_feed_entries.size() == 3 and int(hud.loot_feed_entries[0].get("amount", 0)) == 5,
		"Successive loot grants stack in one iron counter instead of duplicate labels")
	verify(hud.loot_feed_rows.get_child(0).get_node_or_null("LootReceiptText").text.contains("×5 Iron"),
		"Stacked item caption matches actual accumulated quantity")
	hud.record_combat_event("Boar defeated")
	hud.record_combat_event("Boar defeated")
	verify(str(hud.loot_feed_entries[0].get("kind", "")) == "combat"
		and int(hud.loot_feed_entries[0].get("count", 0)) == 3,
		"Repeated identical combat events share one incrementing counter")
	verify(hud.loot_feed_rows.get_child(0).get_node_or_null("LootReceiptText").text.contains("×3"),
		"Repeated combat text displays incremented count")
	hud._advance_loot_feed(2.95)
	verify(hud.loot_feed_entries.size() > 0 and hud.loot_feed_rows.get_child(0).modulate.a > 0.95,
		"Loot/combat text stays fully legible for 3 seconds after last increment")
	hud._advance_loot_feed(0.30)
	verify(hud.loot_feed_rows.get_child(0).modulate.a < 0.85 and hud.loot_feed_rows.get_child(0).modulate.a > 0.0,
		"Old loot and combat notifications fade after 3 seconds of inactivity")
	hud._advance_loot_feed(0.40)
	verify(hud.loot_feed_entries.is_empty() and not hud.loot_feed_rows.visible,
		"Idle notifications clear completely after the short fade")

	var desc: String = VIEW.description("stone", game.recipes)
	verify(not desc.is_empty(), "Item descriptions come from recipes with honest fallback")
	var recipe_found: bool = false
	for entry in game.recipes:
		if not entry is Dictionary:
			continue
		var id: String = str(entry.get("result", ""))
		var description: String = str(entry.get("desc", ""))
		if not id.is_empty() and not description.is_empty():
			recipe_found = true
			verify(VIEW.description(id, game.recipes) == description, "Tooltip reuses genuine craft recipe descriptions")
			break
	verify(recipe_found, "At least one crafted item has a genuine description")
	game.queue_free()
	await process_frame
	print("LOOT FEED RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
