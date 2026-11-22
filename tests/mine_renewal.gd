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
	var committed: bool = mode == "reload"
	check(site.cycle == int(committed) and mine.layout_seed == REGISTRY.cycle_seed(TEST_SEED,id,int(committed),"initial"), "Wrong recovery generation")
	var phase: String = site.get("renewal",{}).get("phase","")
	match mode:
		"prepare":
			var block := Vector3i(mine.entrance.floor())
			game.building.blocks[block] = true
			check(island.advance_mine_renewal_for_test() == "protected", "Construction bypass")
			game.building.blocks.erase(block)
			var original: Vector3 = game.hero.position
			game.hero.position = mine.entrance
			check(island.advance_mine_renewal_for_test() == "occupied", "Presence bypass")
			game.hero.position = original
			check(island.advance_mine_renewal_for_test() == "prepared", "Could not stage")
		"publish":
			check(phase == "prepared", "Prepared checkpoint missing")
			island._build_chunk(island._cell_at(mine.entrance))
			check(island.advance_mine_renewal_for_test() == "awaiting_unload", "Loaded collider replaced")
			island._clear_stream()
			await process_frame
			await physics_frame
			game.hero.velocity = Vector3.ZERO
			check(island.advance_mine_renewal_for_test() == "publishing", "Could not journal publication")
		"commit":
			check(phase == "publishing", "Publish checkpoint missing")
			var original: Dictionary = island.terrain.caves.floors.duplicate()
			check(island.advance_mine_renewal_for_test() == "committed", "Live commit failed")
			check(original != island.terrain.caves.floors, "No physical change")
	if mode in ["commit","reload"]:
		check(island.advance_mine_renewal_for_test() == "committed", "Retry advanced cycle")
		check(island.mine.access.closed and manager.world_sites.sites[id].reward_claims == {"0:treasure:player":true}, "Seal or receipt changed")
		var cell: Vector2i = island.terrain.caves.branches[0].center
		var at := point(cell)
		game.hero.position = at
		island._queue_near(at)
		while not island._pending.is_empty():
			island._build_pending()
		await physics_frame
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP,1,[game.hero.get_rid()])
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y-at.y)<0.15,"Missing renewed floor")
		refresh()
		check(not island.section_active,"Closed mine revealed through barricade")
		# Inspect rebuilt interior geometry directly, behind the retained seal.
		check(island._section_update(at,game.camera.global_basis.z),"Renewed section unavailable")
		island._update_hero_visibility(game,game.hero)
		game.day_night.interior_blend = 1.0
		game.day_night._apply_light()
		await physics_frame
		var floor_position := Vector3(at.x, at.y-0.1, at.z)
		var picked := PICK.resolve(game,game.camera.unproject_position(floor_position))
		check(not picked.is_empty() and picked.position.distance_to(floor_position)<0.12,"Renewed floor picking")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("user://renewed-chamber.png")==OK,"Screenshot")
			game.camera_angle_target += PI/2
			game.camera_angle = game.camera_angle_target
			game._camera(1.0)
			check(island._section_update(at,game.camera.global_basis.z),"Rotated section unavailable")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("user://renewed-rotated.png")==OK,"Rotated screenshot")
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
