extends "res://tests/mine_cycle_loading.gd"

func run() -> void:
	OS.set_environment("OUTPOST_TEST_MINE_LIFECYCLE","1")
	var mode := OS.get_cmdline_user_args()[0]
	player_save = "user://renew_player.json"
	dungeon_save = "user://renew_registry.json"
	if mode == "prepare":
		var player := FileAccess.open(player_save, FileAccess.WRITE)
		player.store_string(JSON.stringify({"version":5, "placed_blocks":[]}))
		player.close()
	await setup_walk(player_save, dungeon_save, false)
	var manager = game.get_node("Dungeons")
	var mine = island.mine
	if mine == null:
		check(false, "Mine startup failed")
		quit(1)
		return
	var id: String = mine.site_id
	await process_frame
	game.hero.velocity = Vector3.ZERO
	if mode == "prepare":
		mine._register(game)
		var initial: Dictionary = manager.world_sites.sites[id]
		initial.state = "ready_for_renewal"
		initial.boss_defeated = true
		initial.room_state = {"miner":true,"foreman":true}
		initial.reward_claims = {"0:treasure:player":true}
		initial.world_event = {"id":"goblin_reoccupation","site_id":id,"phase":"ready_for_renewal","seed":REGISTRY.cycle_seed(TEST_SEED,id,1,"goblin_reoccupation"),"objective":"Investigate the disturbance at the Goblin Mine.","completed":false}
		mine.access.closed = true
		check(island.advance_mine_renewal_for_test() == "outstanding_rewards", "Missing player receipts accepted")
		for slots: Array in mine.slots.values():
			for slot in slots:
				if slot.kind in ["ore","crate","treasure"]:
					game.opened_world_objects[id + "_" + slot.id] = {}
		game._save()
		check(manager._save_clears(), "Seed fixture")
	var site: Dictionary = manager.world_sites.sites[id]
	var committed: bool = mode in ["reopen","reload","walk"]
	check(site.cycle == int(committed) and mine.layout_seed == REGISTRY.cycle_seed(TEST_SEED,id,int(committed),"initial"), "Wrong recovery generation")
	if mode != "prepare":
		var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://renew_baseline.json"))
		check(snapshot.inventory == JSON.parse_string(JSON.stringify(game.inventory)) and snapshot.rewards == site.reward_claims and snapshot.defeats == site.room_state,"Inventory or receipts changed across checkpoints")
	if committed:
		var coords := []
		var keys: Array = island.terrain.caves.floors.keys()
		keys.sort()
		for c: Vector2i in keys:
			coords.append([c.x,c.y,island.terrain.caves.floors[c]])
		check(JSON.stringify(coords).sha256_text()=="1837af8d15b1678eea5d74b266a72bb818e821bf26d343f05545e0593bb6c666","Restart changed cycle-one geometry")
	var phase: String = site.get("renewal",{}).get("phase","")
	match mode:
		"prepare":
			var snapshot := FileAccess.open("user://renew_baseline.json",FileAccess.WRITE)
			snapshot.store_string(JSON.stringify({"inventory":game.inventory,"rewards":site.reward_claims,"defeats":site.room_state}))
			snapshot.close()
			var block := Vector3i(mine.entrance.floor())
			game.building.blocks[block] = true
			check(island.advance_mine_renewal_for_test() == "protected", "Construction bypass")
			game.building.blocks.erase(block)
			var original: Vector3 = game.hero.position
			game.hero.position = mine.entrance
			check(island.advance_mine_renewal_for_test() == "occupied", "Presence bypass")
			game.hero.position = original
			var hovered := Node3D.new()
			game.add_child(hovered)
			game.controls.inspected = hovered
			check(island.advance_mine_renewal_for_test() == "prepared", "Hover blocked staging")
			hovered.queue_free()
			game.controls.inspected = null
		"publish":
			check(phase == "prepared", "Prepared checkpoint missing")
			for field in ["from_cycle","generator_version","phase","seed","digest"]:
				var corrupted: Dictionary = manager.world_sites.export_state()
				corrupted.sites[id].renewal[field] = "bad"
				check(not REGISTRY.new().import_state(corrupted),"Malformed journal accepted: "+field)
			var original_digest: String = site.renewal.digest
			site.renewal.digest = "0".repeat(64)
			check(island.advance_mine_renewal_for_test()=="layout_changed","Stale candidate accepted")
			site.renewal.digest = original_digest
			island._build_chunk(island._cell_at(mine.entrance))
			check(island.advance_mine_renewal_for_test() == "publishing", "Could not journal publication")
		"staged_fail":
			check(phase == "publishing","Missing publishing checkpoint")
			var before := FileAccess.get_file_as_string(dungeon_save)
			island._build_chunk(island._cell_at(mine.entrance))
			var path := ProjectSettings.globalize_path(dungeon_save+".tmp")
			check(DirAccess.make_dir_absolute(path)==OK,"Fixture could not block save")
			check(island.advance_mine_renewal_for_test()=="save_failed","Failed save replaced resident terrain")
			check(DirAccess.remove_absolute(path)==OK,"Fixture could not unblock save")
			check(island.mine == mine and site.cycle==0 and mine.access.closed and before==FileAccess.get_file_as_string(dungeon_save),"Uncommitted generation leaked")
		"commit","live":
			check(phase == "publishing", "Publish checkpoint missing")
			island._queue_near(mine.entrance)
			while not island._pending.is_empty():
				island._build_pending()
			var key: Vector2i = island._cell_at(mine.entrance)
			var old: Array = island._loaded[key].duplicate()
			var original: Dictionary = island.terrain.caves.floors.duplicate()
			check(island.advance_mine_renewal_for_test() == "committed", "Live commit failed")
			check(original != island.terrain.caves.floors, "No physical change")
			for node in old:
				check(not node.is_inside_tree(),"Stale generation remained resident")
			check(island.mine.access.closed,"Commit reopened before collider install")
			if mode == "live":
				await physics_frame
				await process_frame
				game.hero.velocity = Vector3.ZERO
				check(island.advance_mine_renewal_for_test()=="open","Resident reopen")
				await walkthrough()
		"reopen":
			check(mine.access.closed,"Missing committed barricade")
			island._queue_near(mine.entrance)
			while not island._pending.is_empty():
				island._build_pending()
			check(island.advance_mine_renewal_for_test() == "open","Reopen failed")
		"reload","walk":
			check(not mine.access.closed and island.advance_mine_renewal_for_test() == "open","Open state lost")
			check(site.reward_claims == {"0:treasure:player":true} and site.room_state.size()==2,"Historical progress lost")
			if mode == "walk":
				await walkthrough()
	print("RENEWAL ",mode," ",not failed)
	if not failed and OS.get_cmdline_user_args().has("interrupt"):
		var marker := FileAccess.open("user://" + mode + ".checkpoint",FileAccess.WRITE)
		marker.store_string(str(OS.get_process_id()))
		marker.close()
		# The harness terminates this process after observing the durable marker.
		await create_timer(45.0).timeout
		check(false, "Expected external interruption")
	game.queue_free()
	await process_frame
	await process_frame
	quit(int(failed))

func walkthrough() -> void:
	var mine = island.mine
	var entry: Vector3 = mine.entrance
	# Position the fixture on the surface. All subsequent movement uses controls.
	game.hero.position = entry + Vector3.RIGHT*3
	game.hero.position.y = island.terrain.height_at(floori(game.hero.position.x),floori(game.hero.position.z))+0.08
	island._queue_near(entry)
	while not island._pending.is_empty():
		island._build_pending()
	await physics_frame
	refresh()
	await snapshot("open-entrance")
	var old = DATA.new(TEST_SEED)
	old.caves.carve_mine(old,REGISTRY.cycle_seed(TEST_SEED,mine.site_id,0,"initial"))
	var branch: Dictionary = {}
	for candidate in island.terrain.caves.branches:
		if not old.caves.floors.has(candidate.center):
			branch = candidate
			break
	check(not branch.is_empty(),"Missing changed room")
	if branch.is_empty():
		return
	manual = false
	await walk_shore(entry.x)
	await visit(branch.junction)
	await visit(branch.center)
	check(island.section_active and not island._outline_active,"Renewed chamber hidden")
	await snapshot("open-chamber")
	game.camera_angle_target += PI/2
	game.camera_angle = game.camera_angle_target
	refresh()
	await snapshot("open-rotated")
	var sampled := false
	for delta: Vector2i in [Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP]:
		var target: Vector2i = branch.center + delta
		var at := point(target)-Vector3.UP*0.1
		var hit := PICK.resolve(game,game.camera.unproject_position(at))
		if hit.get("position",Vector3.INF).distance_to(at)<0.1:
			await click_floor(target)
			sampled = true
			break
	check(sampled,"No visible selectable floor")
	manual = true
	await visit(branch.junction)
	await visit(Vector2i(floori(entry.x),floori(entry.z)))
	await walk_shore(entry.x+3)
	check(not island.section_active,"Surface not restored")
	island._clear_stream()
	await process_frame
	island._queue_near(entry)
	while not island._pending.is_empty():
		island._build_pending()
	for node in island.get_children():
		check(not node.has_meta("mine_bulkhead"),"Re-streamed stale bulkhead")
	check(guard_for("miner")==null and guard_for("foreman")==null,"Old occupants resurrected")

func snapshot(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("user://"+label+".png")==OK,"Capture "+label)
