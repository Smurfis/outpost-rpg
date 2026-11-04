extends SceneTree
## Two separate Godot processes: real loopback ENet connection + party preview.
const SAVE: String = "user://coop_pair_"
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS PAIR: " + msg)
	else:
		failures += 1
		push_error("FAIL PAIR: " + msg)

func frames(amount: int) -> void:
	for i in range(amount):
		await process_frame

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var is_host: bool = "--host" in args
	var role: String = "host" if is_host else "client"
	var save_path: String = SAVE + role + ".json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		check(false, "Scene loads")
		quit(1)
		return
	var game = scene.instantiate()
	root.set_meta("outpost_new_adventure", true)
	root.add_child(game)
	await frames(3)
	if is_host:
		check(game.coop.host_lan("LAN Host") == OK, "Host listens on UDP 30115")
	else:
		check(game.coop.join_lan("127.0.0.1", "LAN Guest") == OK, "Client attempts localhost UDP")
	var joined: bool = false
	for i in range(260):
		await create_timer(0.05).timeout
		if game.coop.roster.size() >= 2 and game.coop.party_id() == 1:
			joined = true
			break
	check(joined, "%s sees two players in party 1" % role)
	if not joined:
		game.coop.disconnect_session()
		game.queue_free()
		quit(1)
		return
	check(game.coop.remote_avatars.size() == 1, "%s displays one remote avatar" % role)
	var got_run: bool = false
	var got_exit: bool = false
	if is_host:
		game.coop.request_preview("lan_pair_caverns", 0)
		await frames(24)
		got_run = game.coop.run_preview != null and int(game.coop.preview_descriptor.get("floor", 0)) == 1
		check(got_run, "Host creates one dungeon preview for the party")
		await create_timer(2.8).timeout
		var run_id: int = int(game.coop.preview_descriptor.get("id", 0))
		var authority = game.coop.host_encounters.get(run_id, {}).get("ledger", null)
		check(authority != null and int(authority.revision) > 0, "Host received and validated real client ATTACK RPC")
		game.coop.request_end_preview()
		await frames(30)
		got_exit = game.coop.run_preview == null
		check(got_exit, "Host ends preview for party")
	else:
		for i in range(240):
			await create_timer(0.05).timeout
			if game.coop.run_preview != null and str(game.coop.preview_descriptor.get("entrance_id", "")) == "lan_pair_caverns":
				got_run = true
				break
		check(got_run, "Client receives and builds identical seeded dungeon preview")
		if got_run:
			var instance: Node3D = game.coop.run_preview
			check(instance != null and instance.get_child_count() > 0, "Client's generated dungeon has geometry")
			check(game.hero.global_position.distance_to(instance.hero_spawn_point()) < 2.0, "Client teleports inside private preview")
			var guardian = null
			for candidate in get_nodes_in_group("dungeon_guardians"):
				if instance.is_ancestor_of(candidate):
					guardian = candidate
					break
			if guardian != null:
				var original_hp: float = float(guardian.hp)
				game.hero.global_position = guardian.global_position + Vector3(0.0, 0.0, 1.0)
				await create_timer(0.75).timeout # Allow peer-position packet to reach host.
				game.attack() # Goes over the real ENet RPC, not a direct local health edit.
				var synchronized_hit: bool = false
				for i in range(24):
					await create_timer(0.05).timeout
					if float(guardian.hp) < original_hp:
						synchronized_hit = true
						break
				check(synchronized_hit, "Client ATTACK is confirmed by replicated host guardian HP")
			else:
				check(false, "Client sees a targetable seeded guardian")
			for i in range(420):
				await process_frame
				if game.coop.run_preview == null:
					got_exit = true
					break
			check(got_exit, "Client returns to overworld when host ends party preview")
	check(not game.hero.interaction_locked, "Movement remains unlocked after LAN session actions")
	game.coop.disconnect_session()
	game.queue_free()
	await frames(3)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("LAN PAIR RESULT: %s %d failed assertion(s)" % [role, failures])
	quit(0 if failures == 0 else 1)
