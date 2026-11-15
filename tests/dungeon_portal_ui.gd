extends SceneTree
## Screenshot-driven Android dungeon entry UI: centred CTA, readable summary,
## yes/no decisions and the existing movement-lock lifecycle.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, note: String) -> void:
	if ok:
		print("PASS DUNGEON PORTAL UI: " + note)
	else:
		failures += 1
		push_error("FAIL DUNGEON PORTAL UI: " + note)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	root.set_meta("outpost_input_mode", "touch")
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Main scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	game.save_path = "user://dungeon_portal_ui_test.json"
	root.add_child(game)
	await process_frame
	var manager = game.get_node_or_null("Dungeons")
	verify(manager != null, "Dungeon manager is present")
	if manager == null:
		quit(1)
		return
	var enter: Button = manager.action_button as Button
	var screen: Vector2 = root.get_visible_rect().size
	verify(enter != null, "Dungeon has a real Enter touch button")
	if enter != null:
		verify(absf(enter.get_global_rect().get_center().x - screen.x * 0.5) < 2.0, "Enter dungeon is horizontally centred on the viewport")
		verify(enter.anchor_left < 0.5 and enter.anchor_right > 0.5, "Enter button stays centred at different resolutions")
	var panel: PanelContainer = manager.dimmer.find_child("DungeonConfirmPanel", true, false) as PanelContainer
	var actions: HBoxContainer = panel.find_child("DungeonDecisionButtons", true, false) as HBoxContainer if panel != null else null
	verify(panel != null and actions != null, "Confirmation is a styled centred modal with a decision row")
	verify(manager.confirm_button != null and manager.decline_button != null, "YES ENTER and NO STAY are separate real buttons")
	verify(manager.confirm_button.text.contains("YES") and manager.decline_button.text.contains("NO"), "Decision buttons use clear, short captions")
	verify(manager.confirm_button.pressed.is_connected(manager._enter_confirmed), "YES enters the selected dungeon")
	verify(manager.decline_button.pressed.is_connected(manager._cancel_dialog), "NO dismisses without entering")
	verify(manager.dialog_stats != null and manager.dialog_stats.get_parent().name == "DungeonSummary", "Dungeon stats have an inset summary panel")
	verify(manager.dialog_badge != null and manager.dialog_badge.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Portal rarity is independently styled")
	verify(manager.entrances.size() > 0, "Test scene includes dungeon entrances")
	if manager.entrances.size() > 0:
		var portal: Area3D = manager.entrances.values()[0] as Area3D
		game.hero.global_position = portal.global_position + Vector3(1.0, 0.0, 1.0)
		manager._prompt_to_enter(portal)
		verify(manager.dimmer.visible and manager.chosen_portal == portal, "Approaching a portal opens the confirmation")
		verify(manager.dialog_title.text.length() > 3 and manager.dialog_stats.text.contains("TREASURE BONUS"), "Selected dungeon populates readable name, floors and reward info")
		verify(game.hero.interaction_locked, "Confirmation suspends movement until a decision")
		manager.decline_button.pressed.emit()
		verify(not manager.dimmer.visible and manager.chosen_portal == null, "NO STAY closes the modal and preserves the entrance")
		verify(not game.hero.interaction_locked, "Declining unlocks the player controls")
		verify(manager.active_instance == null, "Declining does not generate a dungeon")
	game.queue_free()
	await process_frame
	print("DUNGEON PORTAL UI RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
