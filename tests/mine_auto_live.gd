extends "res://tests/physical_mineshaft.gd"
## Real _process, physics, movement and elapsed gameplay time. No direct
## scheduler calls, velocity resets or mine development commands.
const GM = preload("res://scripts/debug/gm_commands.gd")

func _initialize() -> void:
	OS.set_environment("OUTPOST_TEST_SIDE_CHAMBER", "0")
	OS.set_environment("OUTPOST_TEST_PROCEDURAL_CAVE", "0")
	OS.set_environment("OUTPOST_TEST_MINE_RENEWAL_SECONDS", "3")
	call_deferred("run")

func capture(_label: String) -> void:
	await process_frame

func _live() -> void:
	normal_loop = true
	game.set_process(true)
	game.terrain_surface.set_process(true)
	game.day_night.set_process(true)
	island.set_process(true)

func _image(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("user://mine-auto-%s.png" % label) == OK, "Could not capture " + label)

func run() -> void:
	await load_world(true)
	_live()
	game.inventory["backpack_t2"] = 1
	game.equipment["bag"] = "backpack_t2"
	game.bag_quality["backpack_t2"] = 3
	game._save()
	var mine = island.mine
	var entry: Vector3 = mine.entrance
	var original_seed: int = mine.layout_seed
	await walk_shore(entry.x)
	await visit(island.terrain.caves.branches[0].center)
	await fight("miner")
	var end: Vector3 = island.terrain.caves.chests[0]
	await visit(Vector2i(end.x, end.z) + Vector2i(0, -1))
	await fight("foreman")
	var site: Dictionary = mine.manager.world_sites.sites[site_id]
	check(site.state == "cleared", "Required goblins did not clear mine")
	check(not mine._supplies_claimed(game.opened_world_objects), "Optional loot was already claimed")
	var chest := find_chest()
	check(chest != null, "Strongbox missing")
	if chest != null:
		await visit(Vector2i(end.x, end.z) + Vector2i(0, -1))
		var selected := false
		for angle in 4:
			await physics_frame
			var screen: Vector2 = game.camera.unproject_position(chest.global_position + Vector3.UP * 0.45)
			if PICK.resolve(game, screen).get("target") == chest:
				selected = game.controls.primary_at(screen, false)
				break
			game.camera_angle_target += PI / 2
			game.camera_angle = game.camera_angle_target
		check(selected, "Strongbox could not be clicked")
		for frame in 180:
			await physics_frame
			if site.reward_claims.has("0:treasure:player"):
				break
		check(site.reward_claims.has("0:treasure:player"), "Strongbox click did not claim reward")
	await _image("cleared")
	await visit(Vector2i(entry.x, entry.z))
	await walk_shore(entry.x + 3)
	await walk_shore(entry.x + 10)
	await walk_shore(entry.x + 12)
	var before_status: Dictionary = site.duplicate(true)
	var reason: String = GM.execute(game, ".mine status")
	check(site == before_status and reason.contains("scheduler") and reason.contains("cycle 0"), "Read-only .mine status changed progression")
	print("AUTO LIVE after exit: ", reason, " velocity=", game.hero.velocity)
	var left_at := Time.get_ticks_msec()
	for sample in 80:
		await create_timer(0.2).timeout
		if site.state == "sealed":
			break
	check(site.state == "sealed", "Mine did not seal: " + island.mine_auto.status(island, game))
	check(mine.access.closed, "Sealed mine has no physical bulkhead")
	await _image("sealed")
	var saved_timer: int = int(site.get("auto_renew_remaining_ms", -1))
	check(saved_timer > 0, "Sealed countdown missing")
	game._save()
	game.queue_free()
	await process_frame
	await process_frame
	await load_world(false)
	_live()
	mine = island.mine
	site = mine.manager.world_sites.sites[site_id]
	check(site.state == "sealed" and mine.access.closed and int(site.get("auto_renew_remaining_ms", -1)) > 0, "Countdown did not survive reload")
	await walk_shore(entry.x + 10)
	await walk_shore(entry.x + 12)
	for sample in 140:
		await create_timer(0.2).timeout
		if site.get("reopened", false) and site.state == "active":
			break
		site = island.mine.manager.world_sites.sites[site_id]
	check(site.state == "active" and int(site.cycle) == 1 and site.get("reopened", false), "Automatic renewal did not open: " + island.mine_auto.status(island, game))
	check(site.reward_claims.has("0:treasure:player") and not game.opened_world_objects.has(site_id + "_ore_0"), "Historical reward or optional-loot forfeit failed")
	check(island.mine.layout_seed != original_seed and not island.mine.access.closed, "Renewed geometry or entrance not published")
	check(Time.get_ticks_msec() - left_at >= 2500, "Renewal skipped gameplay cooldown")
	await walk_shore(entry.x)
	await visit(island.terrain.caves.branches[0].center)
	check(guard_for("miner") != null, "Fresh cycle goblin missing")
	await _image("renewed")
	await visit(Vector2i(entry.x, entry.z))
	await walk_shore(entry.x + 3)
	print("AUTO LIVE RESULT: ", not failed, " status ", island.mine_auto.status(island, game))
	game.queue_free()
	await process_frame
	quit(int(failed))
