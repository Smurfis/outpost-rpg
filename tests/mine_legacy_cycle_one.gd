extends "res://tests/physical_mineshaft.gd"

const REGISTRY = preload("res://scripts/dungeons/world_site_registry.gd")

func run() -> void:
	var id := "fractal_physical_goblin_mine_1_64012"
	var registry = REGISTRY.new()
	check(registry.register_site(id,64012,Vector3i(192,3,62),["island_192_60"],REGISTRY.MINE),"register fixture")
	var site: Dictionary = registry.sites[id]
	site.cycle = 1
	site.layout_seed = REGISTRY.cycle_seed(64012,id,1,"initial")
	site.state = "ready_for_renewal"
	site.reopened = true
	site.room_state = {"miner":true,"foreman":true}
	site.boss_defeated = true
	site.reward_claims = {"0:treasure:player":true}
	site.world_event = {"id":"goblin_reoccupation", "site_id":id, "phase":"ready_for_renewal", "seed":REGISTRY.cycle_seed(64012,id,1,"goblin_reoccupation"), "objective":"Investigate the disturbance at the Goblin Mine.", "completed":false}
	var player := FileAccess.open("user://legacy-cycle-player.json",FileAccess.WRITE)
	player.store_string(JSON.stringify({"version":5,"placed_blocks":[],"inventory":{"coins":23}}))
	player.close()
	var save := FileAccess.open("user://legacy-cycle-sites.json",FileAccess.WRITE)
	save.store_string(JSON.stringify({"version":4,"world_sites":registry.export_state()}))
	save.close()
	await setup_walk("user://legacy-cycle-player.json","user://legacy-cycle-sites.json",false)
	var mine = island.mine
	check(mine != null,"legacy mine failed to load")
	if mine == null:
		quit(1)
		return
	var loaded: Dictionary = mine.manager.world_sites.sites[id]
	check(loaded.cycle == 1 and loaded.state == "active" and loaded.room_state.is_empty(),"legacy cycle not activated")
	check(loaded.cycle_history["0"].size() == 2 and loaded.reward_claims == {"0:treasure:player":true},"historical progress lost")
	check(int(game.inventory.get("coins",0)) == 23,"inventory changed during migration")
	var branch: Vector2i = island.terrain.caves.branches[0].center
	island._queue_near(point(branch))
	while not island._pending.is_empty():
		island._build_pending()
	await physics_frame
	check(guard_for("miner") != null,"new miner missing")
	print("LEGACY CYCLE ONE ",not failed)
	game.queue_free()
	await process_frame
	quit(int(failed))
