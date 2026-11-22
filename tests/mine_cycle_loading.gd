extends "res://tests/physical_mineshaft.gd"
const REGISTRY = preload("res://scripts/dungeons/world_site_registry.gd")
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const TEST_SEED := 64012

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := "user://cycle_fixture_sites.json"
	var player := "user://cycle_fixture_player.json"
	var id := "fractal_physical_goblin_mine_1_64012"
	if args.has("create"):
		var player_file := FileAccess.open(player, FileAccess.WRITE)
		player_file.store_string(JSON.stringify({"version":5,"placed_blocks":[]}))
		player_file.close()
		var registry = REGISTRY.new()
		check(registry.register_site(id,TEST_SEED,Vector3i(192,3,62),["island_192_60"],REGISTRY.MINE),"register")
		var site: Dictionary = registry.sites[id]
		site.state = "ready_for_renewal"
		site.cycle = 1
		site.layout_seed = REGISTRY.cycle_seed(TEST_SEED,id,1,"initial")
		site.room_state = {"miner":true,"foreman":true}
		site.boss_defeated = true
		site.reward_claims = {"0:treasure:player":true}
		site.world_event = {"id":"goblin_reoccupation","site_id":id,"phase":"ready_for_renewal","seed":REGISTRY.cycle_seed(TEST_SEED,id,1,"goblin_reoccupation"),"objective":"Investigate the disturbance at the Goblin Mine.","completed":false}
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify({"version":4,"world_sites":registry.export_state()}))
		file.close()
	var raw := FileAccess.get_file_as_string(path)
	var source: Dictionary = JSON.parse_string(raw).world_sites
	var baseline: Dictionary = source.sites[id]
	for corruption in ["wrong_id","negative","fractional","future","seed","schema"]:
		var bad: Dictionary = source.duplicate(true)
		match corruption:
			"wrong_id": bad.sites[id].site_id = "another_mine"
			"negative": bad.sites[id].cycle = -1
			"fractional": bad.sites[id].cycle = 0.5
			"future": bad.sites[id].cycle = 2
			"seed": bad.sites[id].layout_seed = 1
			"schema": bad.schema = 999
		var verifier = REGISTRY.new()
		check(not verifier.import_state(bad),"accepted invalid "+corruption)
	check(baseline.cycle == 1 and raw == FileAccess.get_file_as_string(path),"invalid checks touched file")
	player_save = player
	dungeon_save = path
	await setup_walk(player_save,dungeon_save,false)
	island._queue_near(island.mine.entrance)
	while not island._pending.is_empty():
		island._build_pending()
	await physics_frame
	game.hero.global_position = island.mine.entrance + Vector3.RIGHT*3
	game.hero.position.y = island.terrain.height_at(floori(game.hero.position.x),floori(game.hero.position.z))+0.1
	var manager = game.get_node("Dungeons")
	var record: Dictionary = manager.world_sites.sites[id]
	check(manager.world_site_save_valid and record.cycle == 1,"cycle one rejected")
	check(island.mine.layout_seed == record.layout_seed and island.mine.access.closed,"seed or seal")
	check(record.room_state.size()==2 and record.reward_claims.has("0:treasure:player"),"progress lost")
	check(guard_for("miner")==null and guard_for("foreman")==null, "cleared goblin resurrected")
	check(record.world_event.phase == "ready_for_renewal", "event changed")
	if DisplayServer.get_name() != "headless":
		game.camera_angle = PI/2
		game.camera_angle_target = PI/2
		game._camera(1.0)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("user://cycle-one.png") == OK, "capture failed")
	var keys: Array = island.terrain.caves.floors.keys()
	keys.sort()
	var columns := []
	for c: Vector2i in keys:
		columns.append([c.x,c.y,island.terrain.caves.floors[c]])
	var signature := JSON.stringify(columns).sha256_text()
	var checked_floors := 0
	for branch in island.terrain.caves.branches:
		var cell: Vector2i = branch.center
		var at := Vector3(cell.x+0.5,island.terrain.caves.floor_at(cell.x,cell.y),cell.y+0.5)
		var key: Vector2i = island._cell_at(at)
		if not island._loaded.has(key):
			island._build_chunk(key)
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.5,at-Vector3.UP,1,[game.hero.get_rid()])
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y-at.y)<0.05,"renewed floor collision")
		checked_floors += 1
	check(checked_floors >= 2,"renewed chambers missing")
	var base = DATA.new(TEST_SEED)
	base.caves.carve_mine(base,REGISTRY.cycle_seed(TEST_SEED,id,0,"initial"))
	check(base.caves.floors != island.terrain.caves.floors,"cycle one geometry did not change")
	check(raw == FileAccess.get_file_as_string(path),"load changed save")
	print("CYCLE SIGNATURE ",signature," seed ",island.mine.layout_seed)
	print("CYCLE LOAD ",not failed)
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
