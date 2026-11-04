extends SceneTree
## Regression: independent parties, deterministic dungeon runs, host LAN preview,
## unchanged solo save behaviour, and no unwanted main-game dungeon changes.
const REGISTRY = preload("res://scripts/network/party_registry.gd")
const SAVE = "user://outpost_coop_preview_test.json"
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func test(ok: bool, message: String) -> void:
	if ok:
		print("PASS COOP: " + message)
	else:
		failures += 1
		push_error("FAIL COOP: " + message)

func _run() -> void:
	var reg = REGISTRY.new()
	var a: int = reg.create_party(1)
	test(a == 1, "Host starts party 1")
	for peer_id in [2, 3, 4]:
		test(reg.join_party(peer_id, a), "Can join up to four player party")
	test(not reg.join_party(5, a), "Full party rejects fifth member")
	test(reg.members_of(a).size() == 4, "Four player membership bound")
	var b: int = reg.create_party(5)
	test(b == 2, "Second party is independent")
	test(not reg.start_run(2, "crypts", 2).has("id"), "Only leader can create a private run")
	var first: Dictionary = reg.start_run(1, "crypts", 2)
	var second: Dictionary = reg.start_run(5, "crypts", 2)
	test(int(first.get("party_id", -1)) != int(second.get("party_id", -1)), "Same dungeon entrance supports separate party instances")
	test(int(first.get("id", 0)) != int(second.get("id", 0)), "Separate parties own different run IDs")
	test(int(first.get("seed", -1)) == int(second.get("seed", -2)), "Same entrance reconstructs same deterministic layout seed")
	test(not reg.join_party(2, b), "Cannot switch parties during a live run")
	test(reg.active_run(a).get("members", []).size() == 4, "Party run freezes participant roster")
	test(reg.start_run(1, "duplicate", 4).is_empty(), "Party cannot start overlapping dungeons")
	test(reg.advance_floor(2, int(first.get("id", 0))).is_empty(), "Ordinary member cannot skip floors")
	var floors: int = int(first.get("floors", 0))
	for floor_number in range(2, floors + 1):
		var progressed: Dictionary = reg.advance_floor(1, int(first["id"]))
		test(int(progressed.get("floor", 0)) == floor_number, "Leader can advance floor within this party")
	test(reg.advance_floor(1, int(first["id"])).is_empty(), "Cannot advance beyond final floor")
	test(not reg.end_run(5, int(first["id"])), "Other party leader cannot end this party's run")
	test(reg.end_run(1, int(first["id"])), "Leader can end own run")
	test(reg.active_run(a).is_empty() and not reg.active_run(b).is_empty(), "Ending party A does not affect party B")
	reg.remove_peer(1)
	test(reg.leader_of(a) == 2, "Leader reassigned when host peer departs")
	test(reg.party_of(1) == 0, "Disconnected leader membership cleared")
	test(reg.snapshot().get("parties", []).size() == 2, "Snapshot includes independent parties")
	var scene: PackedScene = load("res://scenes/main.tscn")
	test(scene != null, "Legacy Outpost scene is still loadable")
	if scene == null:
		quit(1)
		return
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var game = scene.instantiate()
	root.set_meta("outpost_new_adventure", true)
	root.add_child(game)
	await process_frame
	test(game.coop != null and game.coop.mode == "solo", "Outpost boots offline with optional co-op")
	test(not game.coop.ui.visible, "Co-op interface is closed at boot")
	test(game.hero != null and not game.hero.interaction_locked, "Solo player controller stays unlocked")
	var error: int = game.coop.host_lan("Explorer")
	test(error == OK, "ENet UDP localhost host initializes")
	if error == OK:
		test(game.coop.party_id() == 1, "Host automatically joins party 1")
		test(game.coop.is_party_leader(), "Host can create a private run")
		game.coop.request_preview("coop_integration", 0)
		await process_frame
		test(game.coop.run_preview != null, "Host creates private deterministic dungeon preview")
		test(game.coop.preview_descriptor.get("floor", 0) == 1, "Preview starts at first floor")
		test(not game.hero.interaction_locked, "Entering a party preview leaves player movement enabled")
		game.coop.request_end_preview()
		await process_frame
		test(game.coop.run_preview == null and not game.coop.has_return_point, "Ending preview returns player home")
		game.coop.disconnect_session()
		test(game.coop.mode == "solo", "Disconnect restores offline solo")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("COOP RESULT: %d failed assertion(s)." % failures)
	quit(0 if failures == 0 else 1)
