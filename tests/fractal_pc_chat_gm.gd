extends SceneTree
## Offline Alpha chat is keyboard-first and its testing GM commands are open
## to every player, without network authentication or console privileges.
const GM = preload("res://scripts/debug/gm_commands.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS PC CHAT: " + detail)
	else:
		failures += 1
		push_error("FAIL PC CHAT: " + detail)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var source: PackedScene = load("res://scenes/main.tscn")
	check(source != null, "Game loads")
	if source == null:
		quit(1)
		return
	var game = source.instantiate()
	root.add_child(game)
	await process_frame
	var chat = game.chat
	check(chat != null and chat.frame != null and chat.input != null, "Bottom-left chat UI is mounted")
	check(chat.frame.anchor_top == 1.0 and chat.frame.offset_left < 32, "Chat is anchored to the bottom left")
	check(not chat.chat_open, "Chat starts closed")
	var open_key := InputEventKey.new()
	open_key.keycode = KEY_ENTER
	open_key.pressed = true
	chat._input(open_key)
	check(chat.chat_open and chat.input.visible and chat.input.has_focus(), "Enter focuses the chat field")
	check(game.controls.modal_open(), "Typing blocks gameplay movement and abilities")
	chat._submit("Hello Outpost")
	check(not chat.chat_open and chat.lines.back().contains("Hello Outpost"), "Normal message is shown and Enter closes input")
	check(GM.execute(game, ".help").contains(".tp"), "Everyone can list GM commands")
	var initial: int = int(game.inventory.get("wood", 0))
	var given: String = GM.execute(game, ".give wood 2")
	check(given.begins_with("Granted ") and int(game.inventory.get("wood", 0)) >= initial,
		"GM give command uses real inventory state")
	check(GM.execute(game, ".give fake_item 2").begins_with("Unknown item"), "Unknown items cannot be invented")
	check(GM.execute(game, ".give wood -500").contains("between 1 and 99"),
		"GM input rejects negative grant counts")
	check(GM.execute(game, ".speed 2").contains("2.0x") and is_equal_approx(game.hero.gm_speed_multiplier, 2.0),
		"GM speed changes runtime walking multiplier")
	check(GM.execute(game, ".speed 1").contains("1.0x"), "GM speed can reset")
	check(GM.execute(game, ".time night").contains("night") and game.day_night.is_night(),
		"GM time invokes existing day/night cycle")
	game.hero.health = 20
	game.mana = 1
	GM.execute(game, ".heal")
	check(game.hero.health >= 100 and game.mana > 30, "GM heal restores health and mana")
	check(GM.execute(game, ".tp 0 0").begins_with("Teleported") and absf(game.hero.global_position.x) < 1.0,
		"GM teleport uses world terrain sample")
	var island_result: String = GM.execute(game, ".island 1")
	check(island_result.contains("Island 1") and absf(game.hero.global_position.x - 172.0) < 1.0,
		"GM island command takes a playtester to generated island one")
	check(game.terrain_surface.archipelago.loaded_chunk_count() > 0,
		"GM teleport preloads the immediate island collision chunk")
	# A sea-level character must remain buoyant when entering the first
	# shallow beach voxel; the old version dropped swimming immediately.
	var remote = game.terrain_surface.archipelago.terrain
	var centre: Vector2i = remote.islands[0]["center"]
	var beach_x: int = -9999
	for x in range(centre.x + 50, centre.x + 12, -1):
		if remote.is_land_at(float(x) + 0.5, float(centre.y) + 0.5) and remote.height_at(x, centre.y) == -3:
			beach_x = x
			break
	check(beach_x != -9999, "Island has a submerged landing step")
	if beach_x != -9999:
		game.hero.global_position = Vector3(float(beach_x) + 0.5, -3.60, float(centre.y) + 0.5)
		check(game.hero._detect_surface_swimming(), "Swim buoyancy remains active on the first island landing step")
	GM.execute(game, ".home")
	check(game.hero.global_position.distance_to(Vector3(0, 0.35, 0)) < 0.01,
		"GM home returns to original spawn")
	chat.open_chat()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	game.controls._input(esc)
	check(not chat.chat_open, "Escape closes chat before another modal")
	chat.open_chat()
	chat._submit(".clear")
	check(chat.lines.is_empty(), "Clear wipes transcript")
	game.queue_free()
	await process_frame
	print("PC CHAT RESULT: %d failures." % failures)
	quit(0 if failures == 0 else 1)
