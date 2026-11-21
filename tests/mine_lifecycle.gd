extends "res://tests/physical_mineshaft.gd"
## Live-site lifecycle acceptance. Uses the parent fixture's isolated player
## and dungeon files, real combat/picking, and ordinary save/load paths.
func capture(_label: String) -> void:
	await process_frame

func state() -> Dictionary:
	return island.mine.manager.world_sites.sites[site_id]

func reload_state(expected: String) -> void:
	var previous: Variant = JSON.parse_string(JSON.stringify(state()))
	game.queue_free()
	await process_frame
	await process_frame
	await load_world(false)
	check(JSON.parse_string(JSON.stringify(state())) == previous and state().state == expected, "Reload changed " + expected)
	check(island.mine.access.closed == (expected in ["sealed", "ready_for_renewal"]), "Reloaded access " + expected)

func layout_digest() -> String:
	var cave = island.terrain.caves
	return var_to_bytes([cave.routes, cave.floors, cave.branches, island.mine.layout_seed]).hex_encode().sha256_text()

func verify_gate_pick(cell: Vector2i, step: Vector2i, body: StaticBody3D) -> bool:
	var outward := Vector3(step.x, 0, step.y)
	var base := point(cell)
	var probe: Transform3D = game.hero.global_transform
	probe.origin = base + outward
	probe.origin.y = maxf(base.y, point(cell + step).y) + 0.05
	var contact := KinematicCollision3D.new()
	if not game.hero.test_move(probe, -outward, contact) or contact.get_collider() != body:
		return false
	game.camera_angle_target = atan2(outward.x, outward.z)
	game.camera_angle = game.camera_angle_target
	game.camera.size = 12
	refresh()
	for elevation in [1.5, 2.25, 0.75]:
		var face := base + outward * 0.5 + Vector3.UP * float(elevation)
		var screen: Vector2 = game.camera.unproject_position(face)
		if not root.get_visible_rect().has_point(screen):
			continue
		var hit := PICK.resolve(game, screen)
		if hit.get("collider") != body or hit.position.distance_to(face) > 0.05:
			continue
		check(not game.controls.primary_at(screen, false), "Click accepted the upright sealed face as a floor")
		print("BULKHEAD capsule and picker ", cell, " face ", face, " screen ", screen)
		return true
	return false

func verify_seal() -> void:
	await physics_frame
	var access = island.mine.access
	var trunk: Array = island.terrain.caves.routes[0]
	var found := false
	for i in range(1, trunk.size()):
		var p: Vector3i = trunk[i]
		var cell := Vector2i(p.x, p.z)
		var key: Vector2i = island._cell_at(point(cell))
		if cell not in access.seal_chunks.get(key, []):
			continue
		# Probe from the open side horizontally into the same visible timber.
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var outside := cell + step
			if not access.footprint.has(outside) or access.roofed.has(outside):
				continue
			var target := point(cell) + Vector3.UP * 1.5
			var origin := target + Vector3(step.x, 0, step.y)
			var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider is StaticBody3D:
				var art = hit.collider.get_node_or_null("Sealed mine timbers")
				found = art is MeshInstance3D and art.is_visible_in_tree() and verify_gate_pick(cell, step, hit.collider)
			if found:
				break
		if found:
			break
	check(found, "Entrance timber did not agree with capsule collision and gameplay picking")
	if found and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("user://mine-" + str(state().state) + ".png") == OK, "Capture failed")
	var end: Vector3i = trunk.back()
	check(PATH.plan_world(game, game.hero.position, point(Vector2i(end.x, end.z))).is_empty(), "Planner crossed sealed entrance")
	check(guard_for("miner") == null and guard_for("foreman") == null and find_chest().remaining().is_empty(), "Closed site restored occupants or treasure")

func reload_chunks() -> void:
	island._clear_stream()
	await process_frame
	island._queue_near(game.hero.position)
	while not island._pending.is_empty():
		island._build_pending()
	await verify_seal()

func run() -> void:
	OS.set_environment("OUTPOST_TEST_MINE_LIFECYCLE", "1")
	var args := OS.get_cmdline_user_args()
	var seal_and_quit := args.has("--seal-and-quit")
	if args.has("--load-sealed") or args.has("--load-ready"):
		var snapshot: Variant = null
		if FileAccess.file_exists("user://lifecycle_expected.json"):
			snapshot = JSON.parse_string(FileAccess.get_file_as_string("user://lifecycle_expected.json"))
		if not snapshot is Dictionary or not snapshot.has("player_save") or not snapshot.has("dungeon_save"):
			push_error("Run --seal-and-quit first to create the lifecycle checkpoint")
			quit(1)
			return
		player_save = snapshot.player_save
		dungeon_save = snapshot.dungeon_save
		await load_world(false)
		var expected: Dictionary = snapshot.site
		expected.state = "sealed" if args.has("--load-sealed") else "ready_for_renewal"
		check(expected == JSON.parse_string(JSON.stringify(state())), "Fresh process changed persisted site")
		check(layout_digest() == snapshot.layout, "Fresh process changed cave layout")
		check(JSON.parse_string(JSON.stringify(game.inventory)) == snapshot.inventory, "Fresh process changed inventory")
		await walk_shore(island.mine.entrance.x)
		await verify_seal()
		if args.has("--load-sealed"):
			await reload_chunks()
		await walk_shore(island.mine.entrance.x + 3)
		if args.has("--load-sealed"):
			check(island.mine.advance_for_test("ready_for_renewal"), "Renewal eligibility rejected after restart")
		await finish()
		return
	await load_world(true)
	var original_layout := layout_digest()
	var entry: Vector3 = island.mine.entrance
	var entry_cell := Vector2i(entry.x, entry.z)
	var miner: Vector2i = island.terrain.caves.branches[0].center
	var junction: Vector2i = island.terrain.caves.branches[0].junction
	var end: Vector3 = island.terrain.caves.chests[0]
	var final_cell := Vector2i(end.x, end.z)
	manual = true
	await walk_shore(entry.x)
	await visit(junction)
	check(state().state == "active" and not island.mine.advance_for_test("sealed"), "Premature seal")
	await visit(miner)
	await fight("miner")
	await reload_state("active")
	check(guard_for("miner") == null and guard_for("foreman") != null, "Reload lost partial encounter progress")
	await walk_shore(entry.x)
	await visit(final_cell + Vector2i(0, -1))
	await fight("foreman")
	check(state().state == "cleared", "Missing clear after both defeats")
	await visit(entry_cell)
	await walk_shore(entry.x + 3)
	check(not island.mine.advance_for_test("sealed"), "Unclaimed treasure was sealed")
	await reload_state("cleared")
	await walk_shore(entry.x)
	await visit(final_cell + Vector2i(0, -1))
	var chest = find_chest()
	var coins: int = game.inventory.get("coins", 0)
	game.interact_target(chest)
	game.interact_target(chest)
	check(int(game.inventory.get("coins", 0)) == coins + 18 and chest.remaining().is_empty(), "Treasure was duplicated or lost")
	check(not island.mine.advance_for_test("sealed"), "Player sealed inside the mine")
	await visit(entry_cell)
	await walk_shore(entry.x + 3)
	check(state().state == "cleared", "Leaving sealed the mine automatically")
	check(not island.mine.advance_for_test("sealed"), "Mine sealed with branch supplies outstanding")
	await walk_shore(entry.x)
	for i in island.terrain.caves.branches.size():
		await visit(island.terrain.caves.branches[i].junction)
		await collect_supplies(i)
	check(not island.mine.advance_for_test("sealed"), "Occupied site sealed after all rewards were collected")
	await visit(entry_cell)
	await walk_shore(entry.x + 3)
	OS.set_environment("OUTPOST_TEST_MINE_LIFECYCLE", "0")
	check(not island.mine.advance_for_test("sealed"), "Development flag was bypassed")
	OS.set_environment("OUTPOST_TEST_MINE_LIFECYCLE", "1")
	check(not island.mine.advance_for_test("ready_for_renewal"), "Skipped sealing")
	game.hero.move_along_station_path(PackedVector3Array([point(entry_cell)]))
	check(game.hero.interaction_moving and not island.mine.advance_for_test("sealed"), "Sealed during player navigation")
	game.controls.cancel()
	check(island.mine.advance_for_test("sealed"), "Vacant cleared mine refused sealing")
	await verify_seal()
	check(original_layout == layout_digest(), "Sealing changed cave occupancy or topology")
	if seal_and_quit:
		var file := FileAccess.open("user://lifecycle_expected.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"site": state(), "layout": original_layout, "inventory": game.inventory,
			"player_save": player_save, "dungeon_save": dungeon_save}))
		file.close()
		await finish()
		return
	await reload_state("sealed")
	await verify_seal()
	await reload_chunks()
	check(island.mine.advance_for_test("ready_for_renewal"), "Sealed mine refused eligibility")
	await reload_state("ready_for_renewal")
	await verify_seal()
	check(not island.mine.advance_for_test("active") and int(state().cycle) == 0, "Eligibility reset the cycle")
	check(int(game.inventory.get("coins", 0)) == coins + 18, "Reload changed treasure payout")
	check(original_layout == layout_digest(), "Reload changed cave occupancy or topology")
	await finish()

func finish() -> void:
	game.queue_free()
	await process_frame
	await process_frame
	print("MINE LIFECYCLE ", not failed)
	quit(1 if failed else 0)
