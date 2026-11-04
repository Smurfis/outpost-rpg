extends SceneTree
## Host-owned combat damage, cooldown, distance and final-loot regression.
const ENCOUNTER = preload("res://scripts/network/coop_encounter.gd")
const SAVE: String = "user://outpost_coop_encounter_test.json"
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS HOST COMBAT: " + message)
	else:
		failures += 1
		push_error("FAIL HOST COMBAT: " + message)

func _run() -> void:
	var ledger = ENCOUNTER.new()
	var descriptor: Dictionary = {"id": 42, "floor": 2}
	ledger.configure(descriptor, [
		{"slot": 0, "hp": 16.0, "position": Vector3.ZERO},
		{"slot": 1, "hp": 8.0, "position": Vector3(7, 0, 0)}
	])
	check(ledger.remaining() == 2, "Two guardians are alive at start")
	check(ledger.strike(1, 41, 2, 0, Vector3.ZERO, 1000).is_empty(), "Wrong run is rejected")
	check(ledger.strike(1, 42, 1, 0, Vector3.ZERO, 1000).is_empty(), "Wrong floor is rejected")
	check(ledger.strike(1, 42, 2, 99, Vector3.ZERO, 1000).is_empty(), "Unknown guardian is rejected")
	check(ledger.strike(1, 42, 2, 0, Vector3(20, 0, 0), 1000).is_empty(), "Out-of-range melee is rejected")
	check(not ledger.strike(1, 42, 2, 0, Vector3(1, 0, 0), 1000).is_empty(), "Valid host strike deals damage")
	check(is_equal_approx(float(ledger.guards[0]["hp"]), 8.0), "Host computes fixed damage")
	check(ledger.strike(1, 42, 2, 0, Vector3.ZERO, 1100).is_empty(), "Rapid replay does not damage again")
	check(not ledger.strike(2, 42, 2, 0, Vector3.ZERO, 1100).is_empty(), "Independent party member can hit")
	check(ledger.remaining() == 1, "Exactly one guardian removed")
	check(ledger.strike(2, 42, 2, 0, Vector3.ZERO, 1800).is_empty(), "Dead guardian cannot be farmed")
	check(not ledger.strike(1, 42, 2, 1, Vector3(7, 0, 0), 1800).is_empty(), "Last guardian can be defeated")
	check(ledger.cleared() and ledger.remaining() == 0, "Exit unlocks only on actual clear")
	check(ledger.snapshot().get("revision", 0) == 3, "Only accepted hits advance replication revision")

	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		check(false, "Outpost scene imports")
		quit(1)
		return
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var game = scene.instantiate()
	game.save_path = SAVE
	root.set_meta("outpost_new_adventure", true)
	root.add_child(game)
	await process_frame
	check(game.coop.host_lan("Host Test") == OK, "Host starts actual ENet service")
	game.coop.request_preview("host_combat_test", 0)
	await process_frame
	var run_id: int = int(game.coop.preview_descriptor.get("id", 0))
	check(run_id != 0 and game.coop.host_encounters.has(run_id), "Active private run owns one combat ledger")
	if run_id != 0 and game.coop.host_encounters.has(run_id):
		var live = game.coop.host_encounters[run_id]["ledger"]
		check(not game.coop.can_advance_preview(), "Fresh floor is locked")
		var first = null
		for guard in get_nodes_in_group("dungeon_guardians"):
			if game.coop.run_preview.is_ancestor_of(guard):
				first = guard
				break
		if first != null:
			var hp_before: float = float(first.hp)
			game.hero.global_position = first.global_position + Vector3(0.0, 0.0, 1.0)
			game.attack()
			check(float(first.hp) < hp_before, "Gameplay attack routes through host and updates guardian")
			check(float(live.guards[int(first.get_meta("encounter_slot"))]["hp"]) < hp_before, "Host records damage rather than trusting client HP")
		else:
			check(false, "Seeded dungeon spawned guardian")
		var at_ms: int = Time.get_ticks_msec() + 1000
		for slot in live.guards.keys():
			var target: Dictionary = live.guards[slot]
			game.hero.global_position = target["position"] + Vector3(0, 0, 1.0)
			while float(live.guards[slot]["hp"]) > 0.0:
				var result: Dictionary = live.strike(1, run_id, live.floor_number, int(slot), game.hero.global_position, at_ms)
				check(not result.is_empty(), "Host accepts a spaced strike on a live guardian")
				at_ms += 600
		game.coop._broadcast_encounter_state(run_id)
		check(game.coop.can_advance_preview(), "Synchronized clear unlocks the final chest")
		var old_coins: int = int(game.inventory.get("coins", 0))
		game.coop._complete_run(1, run_id)
		check(game.coop.preview_descriptor.is_empty(), "Successful completion exits the dungeon")
		check(game.coop_reward_receipts.size() == 1, "Final reward has exactly one persistent receipt")
		check(int(game.inventory.get("coins", 0)) > old_coins, "Host awards real coins from final chest")
		var coins_after: int = int(game.inventory.get("coins", 0))
		game.coop._complete_run(1, run_id)
		check(int(game.inventory.get("coins", 0)) == coins_after, "Duplicate complete-run request cannot farm loot")
		var receipt: String = str(game.coop_reward_receipts.keys()[0])
		check(not game.receive_coop_reward(receipt, {"coins": 99999, "xp": 99999}), "Replayed reward receipt cannot pay twice")
	game.coop.disconnect_session()
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("COOP HOST COMBAT RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
