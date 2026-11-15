extends SceneTree
## UI V2 visual-structure smoke test. Runtime status effects are supplied by
## gameplay; this test verifies the reusable view without inventing game buffs.
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS HUD V2: " + label)
	else:
		failures += 1
		push_error("FAIL HUD V2: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Gameplay scene loads")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	check(hud.gathered_panel != null and not hud.gathered_panel.visible, "Last Gathered begins hidden, not decorative dummy data")
	check(hud.status_effect_strip != null and not hud.status_effect_strip.visible, "Status effect row begins empty")
	check(hud.quest_frame.get_theme_stylebox("panel") is StyleBoxEmpty, "Quest background is intentionally invisible")
	check(hud.quest_rule != null and hud.quest_rule.color.a < 0.5, "Quest uses only faint gold underline")
	hud.record_gather("wood", 3)
	check(not hud.gathered_panel.visible and hud.gathered_content.text.contains("Wood ×3"), "Real harvest is tracked without a persistent HUD panel")
	hud.record_gather("stone", 2)
	hud.record_gather("herbs", 1)
	hud.record_gather("fiber", 4)
	check(hud.gathered_entries.size() == 3 and not hud.gathered_content.text.contains("Wood"), "Recent receipts are bounded to three entries")
	hud._toggle_gathered()
	check(not hud.gathered_content.visible and not hud.gathered_panel.visible, "Legacy collapse never resurrects the retired gathered panel")
	hud._toggle_gathered()
	check(not hud.gathered_content.visible and hud.gathered_expanded, "Tracked receipts remain available without on-screen clutter")
	hud.set_status_effects([
			{"id":"poison", "name":"Poison", "kind":"debuff", "remaining":8.5, "stack_count":2, "glyph":"☠"},
			{"id":"haste", "name":"Haste", "kind":"buff", "remaining":12.0, "stack_count":1, "glyph":"✦"}
	])
	check(hud.active_status_effects.size() == 2 and hud.status_effect_strip.visible, "Effect view accepts supplied live model records")
	check(hud.status_effect_strip.get_child(0).name == "StatusEffect_poison", "Debuffs shown before buffs")
	check(not hud.hero_detail.visible, "Effect icons replace weapon HUD text without expanding portrait")
	var many: Array[Dictionary] = []
	for index in range(8):
		many.append({"id":"test_%d" % index, "kind":"buff", "name":"Test", "remaining":2.0, "stack_count":1})
	hud.set_status_effects(many)
	check(hud.status_effect_strip.get_child_count() == 6, "Maximum five effect icons and +N overflow")
	hud.set_status_effects([])
	check(not hud.status_effect_strip.visible and not hud.hero_detail.visible, "Empty effects never bring back the equipped-weapon text")
	check(hud.minimap != null and hud.joystick != null and hud.smart_button != null, "Existing movement and combat controls preserved")
	game.queue_free()
	await process_frame
	print("HUD V2 RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
