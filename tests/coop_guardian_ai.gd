extends SceneTree
## Pure host combat checks + instantiated game integration, no real phone required.
const ENCOUNTER = preload("res://scripts/network/coop_encounter.gd")
const SAVE: String = "user://outpost_guardian_ai_test.json"
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS AI: " + message)
	else:
		failures += 1
		push_error("FAIL AI: " + message)

func _run() -> void:
	var ledger = ENCOUNTER.new()
	ledger.configure({"id": 91, "floor": 1, "members": [1, 2]}, [
		{"slot": 0, "hp": 24.0, "position": Vector3.ZERO, "damage": 10.0}
	])
	var players: Dictionary = {1: Vector3(6.0, 0, 0), 2: Vector3(9.0, 0, 0)}
	ledger.tick_ai(0.3, players, 1000)
	var moved: Vector3 = ledger.guards[0]["position"]
	check(moved.x > 0.0, "Guardian chases the nearest live party member")
	check(ledger.snapshot().get("positions", {}).has(0), "Snapshot contains host-simulated guardian positions")
	for tick in range(35):
		ledger.tick_ai(0.3, players, 2000 + tick * 300)
	check((ledger.guards[0]["position"] as Vector3).distance_to(Vector3.ZERO) <= ENCOUNTER.MAX_LEASH_DISTANCE + 0.01, "Chase is tethered to original dungeon chamber")
	check(float(ledger.player_health[1]) == 100.0, "Host never damages distant adventurer")
	players[1] = ledger.guards[0]["position"]
	players[2] = Vector3(6.0, 0.0, 0.0)
	ledger.tick_ai(0.12, players, 20000)
	check(float(ledger.player_health[1]) == 90.0, "Host melee applies damage exactly once")
	ledger.tick_ai(0.12, players, 20100)
	check(float(ledger.player_health[1]) == 90.0, "Guardian attack cooldown blocks spam")
	for tick in range(12):
		ledger.tick_ai(0.12, players, 22000 + tick * 1800)
	check(float(ledger.player_health[1]) == 0.0, "Host knocks player out at zero HP")
	check(ledger.strike(1, 91, 1, 0, players[1], 44000).is_empty(), "Knocked-out player cannot strike")
	check(not ledger.revive(1, 1, players), "No self revive")
	check(not ledger.revive(2, 1, players), "Remote ally cannot revive from out of range")
	players[2] = players[1] + Vector3(1.0, 0.0, 0.0)
	check(ledger.revive(2, 1, players), "Nearby living ally can revive the knocked-out peer")
	check(float(ledger.player_health[1]) == ENCOUNTER.REVIVE_HP, "Revive is host-owned and restores fixed HP")
	check(not ledger.revive(2, 1, players), "Repeated revive requests have no effect")
	check(ledger.snapshot().get("player_health", {}).has(2), "Host snapshot contains participant health")
	
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		check(false, "Main Godot scene imports")
		quit(1)
		return
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var game = scene.instantiate()
	game.save_path = SAVE
	root.set_meta("outpost_new_adventure", true)
	root.add_child(game)
	await process_frame
	check(game.coop.host_lan("AI host") == OK, "ENet host starts")
	game.coop.request_preview("ai_smoke", 0)
	await process_frame
	var run_id: int = int(game.coop.preview_descriptor.get("id", 0))
	check(run_id > 0 and game.coop.host_encounters.has(run_id), "Private dungeon has a host AI ledger")
	if run_id > 0 and game.coop.host_encounters.has(run_id):
		var active = game.coop.host_encounters[run_id]["ledger"]
		var target_slot: int = int(active.guards.keys()[0])
		var start_pos: Vector3 = active.guards[target_slot]["position"]
		game.hero.global_position = start_pos + Vector3(0.9, 0.0, 0.0)
		await create_timer(2.3).timeout
		check(float(active.player_health.get(1, 100.0)) < 100.0, "Host guardian actually strikes its player in scene")
		check(game.hero.health < 100.0, "In-scene hero health receives host-authoritative damage")
		check(int(active.revision) > 0, "AI movement and attacks advance state revision")
		game.coop.request_end_preview()
		await process_frame
		check(game.hero.health == 100.0, "Leaving LAN dungeon restores pre-run hero health")
	game.coop.disconnect_session()
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("COOP GUARDIAN AI RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
