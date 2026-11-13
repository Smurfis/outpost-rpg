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
	# The GM overlay is opt-in; rings should never create discovered terrain
	# or persist in a save. The existing uncharted silhouettes are separate.
	var world_map = game.world_map
	check(not world_map.show_island_circles, "Island location rings start disabled")
	var discovered_before: int = game.map_service.discovered.size()
	var revision_before: int = game.map_service.revision
	check(GM.execute(game, ".map islands true") == "Island map circles enabled.",
		"GM can enable island circles on the world map")
	check(world_map.show_island_circles and world_map.has_remote_islands,
		"Enabled map toggle targets the three real fractal islands")
	check(GM.execute(game, ".map islands false") == "Island map circles hidden.",
		"GM can hide island circles again")
	check(not world_map.show_island_circles, "Off means rings no longer render")
	check(GM.execute(game, ".map islands invalid").begins_with("Usage:"),
		"GM rejects invalid map flag values")
	check(not world_map.show_island_circles, "Malformed map command cannot change visibility")
	check(game.map_service.discovered.size() == discovered_before and game.map_service.revision == revision_before,
		"GM island circles do not reveal land or mutate exploration data")
	check(world_map.mini_camera.cull_mask == 1,
		"GM island circles never change the minimap")
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
	check(get_nodes_in_group("gm_overlords").is_empty(), "Overlord boss never spawns without a GM command")
	check(GM.execute(game, ".spawn dragon").begins_with("Usage:"), "Unknown spawn types cannot be invoked")
	var spawn_result: String = GM.execute(game, ".spawn overlord")
	check(spawn_result.begins_with("Spawned Abyssal Overlord"), "GM spawn creates the Overlord test boss")
	var bosses: Array[Node] = get_nodes_in_group("gm_overlords")
	check(bosses.size() == 1, "Overlord spawn is limited to one active boss")
	check(GM.execute(game, ".spawn overlord").contains("already spawned"), "Repeated command cannot spam bosses")
	if not bosses.is_empty():
		var boss = bosses[0]
		check(boss.avatar != null and boss.avatar.animator != null, "Overlord uses the animated CC0 Demon asset")
		check(boss.max_hp >= 400.0 and boss.melee_damage >= 20.0, "Overlord is a combat boss, not scenery")
		var boss_data: Dictionary = game.target_frame_data(boss)
		check(boss_data.get("rank") == "BOSS" and boss_data.get("name") == "Abyssal Overlord",
			"Boss rarity name and HP are exposed to the transparent target HUD")
	check(GM.execute(game, ".despawn overlord").begins_with("Despawned 1"), "GM despawn clears the test boss")
	check(get_nodes_in_group("gm_overlords").is_empty(), "Overlord leaves no automatic spawns")
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
