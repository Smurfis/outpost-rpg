extends SceneTree
## Regression for Android screenshot: receipt panels must NEVER cover
## right-side combat actions; compact alerts and torch must remain usable.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, detail: String) -> void:
	if ok:
		print("PASS COMPACT RECEIPTS: " + detail)
	else:
		failures += 1
		push_error("FAIL COMPACT RECEIPTS: " + detail)

func _clear_of(panel: Control, target: Control, label: String) -> void:
	verify(panel != null and target != null and not panel.get_global_rect().intersects(target.get_global_rect()), label)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Outpost world loads")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	hud.record_gather("wood", 1)
	hud.record_loot("wood", 1)
	await process_frame
	var recent: Control = hud.gathered_panel
	var feed: Control = hud.loot_feed_panel
	var quest: Control = hud.quest_frame
	var tooltip: Control = hud.loot_tooltip_panel
	var screen: Vector2 = hud.get_viewport().get_visible_rect().size
	var scale: float = clampf(minf(screen.x / 1280.0, screen.y / 720.0), 0.8, 1.2)
	verify(recent.visible and feed.visible, "Real gathered/loot data reveals both cards")
	verify(recent.get_global_rect().position.x < screen.x * 0.10, "Last Gathered now docks to LEFT beneath Quests")
	verify(feed.get_global_rect().position.x < screen.x * 0.10, "Loot & Combat feed now docks to LEFT")
	verify(recent.size.x <= screen.x * 0.32 and feed.size.x <= screen.x * 0.32, "Neither receipt uses a long opaque banner")
	verify(recent.size.y <= 79.0 * scale and feed.size.y <= 91.0 * scale, "Receipt cards have compact heights")
	verify(recent.get_global_rect().position.y >= quest.get_global_rect().end.y, "Last Gathered starts below the quest")
	verify(feed.get_global_rect().position.y > recent.get_global_rect().end.y, "Loot feed remains below Last Gathered")
	_clear_of(feed, hud.minimap, "Loot feed never obscures the minimap")
	_clear_of(recent, hud.minimap, "Last Gathered never obscures the minimap")
	_clear_of(feed, hud.smart_button, "Loot feed never obscures ATTACK/CRAFT")
	_clear_of(recent, hud.smart_button, "Last Gathered never obscures ATTACK/CRAFT")
	_clear_of(recent, hud.joystick, "Last Gathered is clear of the movement joystick")
	_clear_of(feed, hud.joystick, "Loot feed is clear of the movement joystick")
	for key in ["skill_1", "skill_2", "skill_3", "consumable", "potion"]:
		var action: Button = hud.quick_buttons[key] as Button
		_clear_of(recent, action, "Last Gathered clear of " + key)
		_clear_of(feed, action, "Loot & Combat clear of " + key)
	_clear_of(feed, hud.torch_button, "Loot panel never intercepts TORCH")
	_clear_of(recent, hud.torch_button, "Recent items never intercept TORCH")
	var potion: Button = hud.quick_buttons["potion"] as Button
	verify(hud.torch_button.get_global_rect().get_center().x > potion.get_global_rect().get_center().x + 85.0 * scale, "TORCH has moved further right from the other quick items")
	_clear_of(hud.torch_button, hud.smart_button, "TORCH stays separate from smart attack")
	_clear_of(hud.torch_button, hud.quick_buttons["skill_3"] as Button, "TORCH stays separate from lower special")
	hud._toggle_loot_tooltip("wood", -1)
	await process_frame
	verify(tooltip.visible, "Original rarity/name/description tooltip still opens")
	verify(tooltip.get_global_rect().end.x < screen.x * 0.62, "Tooltip opens toward centre, not the attack controls")
	_clear_of(tooltip, hud.smart_button, "Tooltip clear of ATTACK")
	_clear_of(tooltip, hud.torch_button, "Tooltip clear of TORCH")
	for key in ["skill_1", "skill_2", "skill_3"]:
		_clear_of(tooltip, hud.quick_buttons[key] as Button, "Tooltip clear of skill " + key)
	hud._set_loot_tooltip_visible(false)
	hud._toggle_gathered()
	hud._layout_touch_hud()
	verify(feed.get_global_rect().position.y > recent.get_global_rect().end.y, "Collapsing Last Gathered reflows the loot feed")
	hud._toggle_gathered()
	hud._layout_touch_hud()
	verify(feed.get_global_rect().position.y > recent.get_global_rect().end.y, "Expanding Last Gathered keeps the feed clear")
	var toast: Control = hud.toast_panel
	var prompt: Control = hud.context_prompt_frame
	verify(toast.size.x <= screen.x * 0.31 and prompt.size.x <= screen.x * 0.31, "Context alerts use narrow bars")
	verify(toast.size.y <= 35.0 * scale and prompt.size.y <= 34.0 * scale, "Context alerts no longer occupy giant rows")
	verify(toast.get_global_rect().end.y < prompt.get_global_rect().position.y, "Event toast and context warning do not overlap")
	_clear_of(prompt, hud.minimap, "Context banner leaves minimap clear")
	_clear_of(toast, hud.minimap, "Damage toast leaves minimap clear")
	game.queue_free()
	await process_frame
	print("COMPACT RECEIPTS RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
