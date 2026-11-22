extends "res://tests/physical_mineshaft.gd"

func capture(_label: String) -> void:
	await process_frame

func run() -> void:
	OS.set_environment("OUTPOST_TEST_MINE_LIFECYCLE", "0")
	await load_world(true)
	game.inventory["backpack_t2"] = 1
	game.equipment["bag"] = "backpack_t2"
	game.bag_quality["backpack_t2"] = 3
	game._save()
	for cycle in 3:
		var mine = island.mine
		var site: Dictionary = mine.manager.world_sites.sites[site_id]
		check(int(site.cycle) == cycle, "wrong cycle on entry")
		var entry: Vector3 = mine.entrance
		await walk_shore(entry.x)
		await visit(island.terrain.caves.branches[0].center)
		await fight("miner")
		if cycle == 1:
			var seed: int = mine.layout_seed
			game._save()
			game.queue_free()
			await process_frame
			await process_frame
			await load_world(false)
			mine = island.mine
			site = mine.manager.world_sites.sites[site_id]
			check(mine.layout_seed == seed and site.room_state.get("miner") == true and not site.room_state.has("foreman"), "partial encounter did not persist")
			await walk_shore(entry.x)
			await visit(island.terrain.caves.branches[0].center)
			check(guard_for("miner") == null and guard_for("foreman") != null, "defeated guard returned after reload")
		var end: Vector3 = island.terrain.caves.chests[0]
		await visit(Vector2i(end.x,end.z) + Vector2i(0,-1))
		await fight("foreman")
		check(site.state == "cleared", "defeats failed to clear cycle " + str(cycle))
		check(not mine.manager.world_sites.advance_mine(site_id, "sealed", true), "unclaimed strongbox did not block sealing")
		check(not mine._supplies_claimed(game.opened_world_objects), "unclaimed supplies were treated as collected")
		if DisplayServer.get_name() != "headless":
			refresh()
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("user://repeat-cycle-%d.png" % cycle) == OK, "capture failed")
		var chest: Node3D
		for entity in get_nodes_in_group("world_interactables"):
			if entity.get("object_id") == mine.REGISTRY.mine_object_id(site, "treasure"):
				chest = entity
				break
		check(chest != null, "missing strongbox")
		if chest != null:
			var coins: int = game.inventory.get("coins",0)
			game.interact_target(chest)
			game.interact_target(chest)
			check(chest.remaining().is_empty() and int(game.inventory.get("coins",0)) == coins+18, "reward missing or duplicated")
		for i in island.terrain.caves.branches.size():
			await visit(island.terrain.caves.branches[i].junction)
			await collect_cycle_supplies(i)
		await visit(Vector2i(entry.x,entry.z))
		await walk_shore(entry.x+3)
		check(site.reward_claims.has("%d:treasure:player" % cycle), "missing cycle reward receipt")
		if cycle == 1:
			check(site.world_event.completed and site.world_event.phase == "completed", "investigation not completed")
		if cycle == 2:
			game._save()
			game.queue_free()
			await process_frame
			await process_frame
			await load_world(false)
			var loaded: Dictionary = island.mine.manager.world_sites.sites[site_id]
			check(loaded.cycle == 2 and loaded.state == "cleared", "cycle two did not persist")
			check(loaded.room_state.size() == 2 and loaded.cycle_history.size() == 2, "encounter history lost")
			for prior in 3:
				check(loaded.reward_claims.has("%d:treasure:player" % prior), "historical receipt lost")
			check(loaded.world_event.completed, "completed event reset")
			var invalid: Dictionary = island.mine.manager.world_sites.export_state()
			invalid.sites[site_id].cycle_history.erase("0")
			check(not mine.REGISTRY.new().import_state(invalid), "missing historical defeat accepted")
			invalid = island.mine.manager.world_sites.export_state()
			invalid.sites[site_id].reward_claims.erase("1:treasure:player")
			check(not mine.REGISTRY.new().import_state(invalid), "missing historical reward accepted")
			mine = island.mine
			site = loaded
			entry = mine.entrance
			await walk_shore(entry.x+3)
		check(mine.trigger_reoccupation_for_test(), "could not seal")
		check(mine.advance_for_test("ready_for_renewal"), "could not prepare renewal")
		for expected in ["prepared", "publishing", "committed", "open"]:
			await process_frame
			game.hero.velocity = Vector3.ZERO
			var result: String = island.advance_mine_renewal_for_test()
			check(result == expected, "renewal expected %s got %s" % [expected,result])
			if failed:
				break
		if failed:
			break
		game._save()
		game.queue_free()
		await process_frame
		await process_frame
		await load_world(false)
		check(island.mine.manager.world_sites.sites[site_id].cycle == cycle+1, "reload lost cycle")
		check(island.mine.manager.world_sites.sites[site_id].reward_claims.has("%d:treasure:player" % cycle), "reload lost historical receipt")
		check(island.mine.manager.world_sites.sites[site_id].cycle_history.has(str(cycle)), "reload lost historical defeats")
	print("REPEAT MINE ", not failed)
	game.queue_free()
	await process_frame
	quit(int(failed))

func collect_cycle_supplies(index: int) -> void:
	var site: Dictionary = island.mine.manager.world_sites.sites[site_id]
	for kind in ["ore", "supplies"]:
		var id: String = island.mine.REGISTRY.mine_object_id(site, kind + "_" + str(index))
		var target: Node3D
		for entity in get_nodes_in_group("world_interactables"):
			if entity.get("object_id") == id:
				target = entity
				break
		check(target != null, "missing supply " + id)
		if target == null:
			return
		var approach := Vector2i(floori(target.position.x),floori(target.position.z))
		approach += Vector2i.RIGHT if kind == "ore" else Vector2i.LEFT
		await visit(approach)
		game.interact_target(target)
		check(target.remaining().is_empty(), "unclaimed supply " + id)
		var inventory: Dictionary = game.inventory.duplicate(true)
		game.interact_target(target)
		check(game.inventory == inventory, "supply paid twice " + id)
