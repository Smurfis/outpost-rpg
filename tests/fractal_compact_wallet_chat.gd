extends SceneTree
## Regression for the compact wallet, attached carry readout and PC chat.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS FRACTAL HUD: " + detail)
	else:
		failures += 1
		push_error("FAIL FRACTAL HUD: " + detail)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	root.set_meta("outpost_input_mode", "desktop")
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var chat = game.chat
	check(hud.wallet_frame.visible and hud.wallet_frame.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Wallet is framed, passive and touch-through")
	check(not hud.wallet_collapse.visible and not hud.wallet_open, "Wallet has no dropdown")
	var previous_end: float = 0.0
	for key in ["gold", "silver", "copper", "gems"]:
		var amount: Label = hud.wallet_currency_rows[key] as Label
		var symbol: TextureRect = hud.wallet_currency_icons[key] as TextureRect
		check(amount.visible and symbol.visible and symbol.texture != null, "Visible real currency and icon: " + key)
		check(amount.autowrap_mode == TextServer.AUTOWRAP_OFF and amount.clip_text, "Compact currency does not wrap: " + key)
		check(symbol.get_global_rect().end.x <= amount.get_global_rect().position.x + 2.0, "Icon leads counter: " + key)
		check(amount.get_global_rect().position.x >= previous_end - 1.0, "Currency cells do not overlap: " + key)
		previous_end = amount.get_global_rect().end.x
	check(hud.wallet_frame.get_global_rect().end.x < hud.wallet_bag.get_global_rect().position.x, "Wallet frame ends before BAG")
	hud.render_status(100.0, {"coins": 12, "gold": 3, "silver": 5, "copper": 7, "gems": 2}, 0, 0, "training_blade", "Test quest", "")
	check(hud.bag_weight_label.visible and hud.bag_weight_label.text.begins_with("BAG"), "Carry load stays visible by BAG")
	check(hud.bag_weight_label.get_global_rect().position.y > hud.wallet_bag.get_global_rect().end.y, "Carry label is beneath BAG")
	check(not hud.bag_weight_label.get_global_rect().intersects(hud.quest_frame.get_global_rect()), "Carry label does not cover Quest")
	for screen in [Vector2(1280, 720), Vector2(1600, 720), Vector2(720, 405)]:
		var unit: float = clampf(minf(screen.x / 1280.0, screen.y / 720.0), 0.8, 1.2)
		hud._layout_player_chrome_for_size(screen, unit)
		var wallet_end: float = hud.wallet_frame.anchor_right * screen.x
		var bag_left: float = hud.wallet_bag.anchor_left * screen.x
		var wallet_start: float = hud.wallet_frame.anchor_left * screen.x
		var status_end: float = hud.hero_status_frame.anchor_right * screen.x
		check(wallet_end <= bag_left - 2.0 and wallet_start >= status_end + 2.0, "Wallet fits %d by %d" % [int(screen.x), int(screen.y)])
	hud._layout_player_chrome()
	chat.add_line("GM", "Ready")
	check(chat.frame.anchor_top == 1.0 and chat.frame.anchor_left == 0.0, "Chat anchored bottom-left")
	check(chat.frame.offset_bottom < -20.0 and chat.frame.offset_bottom > -60.0, "Chat just above XP bar")
	check(chat.frame_style.border_width_left == 1 and chat.frame_style.corner_radius_top_left == 0, "Chat border is pixel-crisp")
	chat.open_chat()
	check(chat.chat_open and chat.input.visible and chat.frame_style.bg_color.a > 0.7, "Chat expands for entry")
	check(chat.transcript.get_parsed_text().contains("GM") and chat.transcript.get_parsed_text().contains("Ready"), "Coloured chat preserves history")
	chat.close_chat()
	check(not chat.input.visible and chat.frame.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Closed chat releases gameplay input")
	game.queue_free()
	await process_frame
	print("FRACTAL HUD RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
