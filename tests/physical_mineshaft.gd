extends "res://tests/procedural_cave_walk.gd"
const SEED := 64013
const TREASURE = preload("res://scripts/world/mine_treasure.gd")
var player_save := "user://mine_%d_player.json" % OS.get_process_id()
var dungeon_save := "user://mine_%d_sites.json" % OS.get_process_id()
var site_id: String
var normal_loop := false

func refresh() -> void:
	if normal_loop:
		return
	if island.mine != null:
		island.mine.visit(game.hero.global_position)
	super.refresh()

func _initialize() -> void:
	OS.set_environment("OUTPOST_TEST_SIDE_CHAMBER","0")
	OS.set_environment("OUTPOST_TEST_PROCEDURAL_CAVE","0")
	capture_dir = "res://artifacts/cave_render/physical-mine/"
	call_deferred("run")

func load_world(fresh: bool) -> void:
	await setup_walk(player_save,dungeon_save,fresh)
	island.setup(SEED)
	var at: Vector3 = island.terrain.caves.entrances[0]
	game.hero.global_position = at+Vector3.RIGHT*3
	game.hero.position.y = island.terrain.height_at(floori(game.hero.position.x),floori(game.hero.position.z))+0.1
	island._queue_near(at)
	while not island._pending.is_empty():
		island._build_pending()
	await physics_frame
	check(island.mine!=null,"Mine generation failed")
	site_id = island.mine.site_id
	refresh()

func walk_shore(target_x: float) -> void:
	game.controls.cancel()
	for i in 150:
		var dx: float = target_x-game.hero.position.x
		if absf(dx)<0.25:
			steer(Vector3.ZERO)
			return
		steer(Vector3.RIGHT*signf(dx))
		await physics_frame
		refresh()
	steer(Vector3.ZERO)
	check(false,"Surface approach stalled at "+str(game.hero.position))

func guard_for(id: String) -> Node3D:
	for mob in get_nodes_in_group("enemies"):
		if mob.get_meta("mine_slot","") == id:
			return mob
	return null

func collect_supplies(branch_index := 0) -> void:
	for kind in ["ore","supplies"]:
		var target
		for entity in get_nodes_in_group("world_interactables"):
			if entity.get("object_id")==site_id+"_"+kind+"_"+str(branch_index):
				target=entity
				break
		check(target!=null,"Missing mine "+kind)
		if target==null:
			return
		var approach := Vector2i(floori(target.position.x),floori(target.position.z))
		approach += Vector2i.RIGHT if kind=="ore" else Vector2i.LEFT
		await visit(approach)
		var picked := false
		for i in 4:
			refresh()
			await physics_frame
			await physics_frame
			if PICK.resolve(game,game.camera.unproject_position(target.global_position+Vector3.UP*0.3)).get("target")==target:
				picked=true
				break
			game.camera_angle_target+=PI/2
			game.camera_angle=game.camera_angle_target
		check(picked,"Unselectable "+kind)
		game.interact_target(target)
		check(target.remaining().is_empty(),"Mine supplies failed to transfer")

func fight(id: String) -> void:
	var guard = guard_for(id)
	check(guard!=null,"Missing guard "+id)
	if not guard:
		return
	var hp: float = game.hero.health
	var selected := false
	for i in 210:
		await physics_frame
		refresh()
		var foot := Vector3i((guard.global_position+Vector3.UP*0.2).floor())
		check(not island.terrain.is_solid(foot.x,foot.y,foot.z),"Goblin entered solid rock")
		if i % 40 == 0 and not selected:
			game.camera_angle_target += PI/2
			game.camera_angle = game.camera_angle_target
		var hit := PICK.resolve(game,game.camera.unproject_position(guard.global_position+Vector3.UP*0.65))
		if hit.get("target")==guard:
			selected = true
		if selected and game.hero.health < hp:
			break
	check(selected,"Goblin screen pick "+id)
	check(game.hero.health<hp,"Goblin failed to land an attack "+id)
	await capture("guard-"+id)
	for i in 240:
		await physics_frame
		refresh()
		if game.target_in_range(guard):
			game.interact_target(guard)
		if not guard.alive:
			break
	check(not guard.alive and guard_for(id)==null,"Player combat failed "+id)
	check(island.mine.manager.world_sites.sites[site_id].room_state.has(id),"Defeat not recorded "+id)

func pacing(label: String, live: bool, timers := false) -> void:
	if DisplayServer.get_name()=="headless":
		return
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),timers)
	game.set_process(live)
	island.set_process(live)
	game.terrain_surface.set_process(live)
	var intervals := []
	var gpu := []
	var render_cpu := []
	var previous := 0
	for i in 72:
		await process_frame
		if not live:
			refresh()
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if i>12:
			intervals.append(now-previous)
			if timers:
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		previous = now
	intervals.sort()
	print("PACING ",label," p50/p95/max us ",intervals[intervals.size()/2],"/",intervals[int(intervals.size()*0.95)],"/",intervals.back())
	if timers:
		gpu.sort()
		render_cpu.sort()
		print("VIEWPORT ",label," gpu/CPU p95 ms ",gpu[int(gpu.size()*0.95)],"/",render_cpu[int(render_cpu.size()*0.95)])
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),false)
	game.set_process(false)
	island.set_process(false)
	game.terrain_surface.set_process(false)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	await load_world(true)
	var manager = game.get_node("Dungeons")
	var cave = island.terrain.caves
	var entry := Vector2i(cave.entrances[0].x,cave.entrances[0].z)
	var end := Vector2i(cave.chests[0].x,cave.chests[0].z)
	var branches: Array = cave.branches.duplicate()
	check(not manager.world_site_nodes.has(island.MINE_SITE_ID),"Physical entrance has portal")
	print("MINE world ",SEED," layout ",island.mine.layout_seed," branches ",branches.size()," end ",end)
	if DisplayServer.get_name() != "headless":
		RenderingServer.frame_pre_draw.connect(before_draw)
		RenderingServer.frame_post_draw.connect(after_draw)
	physics_frame.connect(begin_physics)
	process_frame.connect(after_physics)
	collect = true
	await capture("approach")
	await walk_shore(cave.entrances[0].x)
	await capture("entrance")
	for i in branches.size():
		var branch: Dictionary = branches[i]
		print("BRANCH ",i," junction ",branch.junction," center ",branch.center," size ",branch.size)
		await visit(branch.junction)
		await visit(branch.threshold)
		await capture("timber-"+str(i))
		await visit(branch.center)
		if i==0:
			await fight("miner")
		await room_checks("room-"+str(i),branch.center)
		if i==0:
			await collect_supplies()
		await visit(branch.junction)
		if i==0:
			var home: Vector2i = island._cell_at(point(branch.center))
			island._unload(home)
			await process_frame
			island._build_chunk(home)
			await physics_frame
			check(guard_for("miner")==null and guard_for("foreman")!=null,"Partial clear lost at chunk boundary")
	var chest = find_chest()
	await visit(end+Vector2i(0,-1))
	var locked_coins: int = game.inventory.get("coins",0)
	game.interact_target(chest)
	check(int(game.inventory.get("coins",0))==locked_coins and not game.opened_world_objects.has(chest.object_id),"Guarded chest opened early")
	await fight("foreman")
	await room_checks("final",end+Vector2i(0,1))
	var chest_cell := end+Vector2i(-1,-1)
	await visit(chest_cell+Vector2i.RIGHT)
	var picked := false
	for i in 4:
		refresh()
		await physics_frame
		await physics_frame
		if PICK.resolve(game,game.camera.unproject_position(chest.global_position+Vector3.UP*0.45)).get("target")==chest:
			picked = true
			break
		game.camera_angle_target+=PI/2
		game.camera_angle=game.camera_angle_target
	check(picked,"Strongbox mouse pick")
	var coins: int = game.inventory.get("coins",0)
	game.interact_target(chest)
	check(int(game.inventory.get("coins",0))==coins+18,"Treasure payout")
	game.interact_target(chest)
	check(int(game.inventory.get("coins",0))==coins+18,"Duplicate treasure")
	check(manager.world_sites.sites[site_id].reward_claims.has("0:treasure:player"),"Reward receipt")
	await capture("treasure")
	await pacing("fixture steady",false)
	await pacing("live steady",true)
	await pacing("live steady GPU timers",true,true)
	for stage in stage_samples:
		if stage in ["viewport GPU","viewport render CPU"]:
			continue # Timer queries were disabled during the walkthrough.
		var values: Array = stage_samples[stage]
		values.sort()
		print("STAGE ",stage," p95/max us ",values[int(values.size()*0.95)],"/",values.back())
	manual=true
	draw_intervals.clear()
	normal_loop=true
	game.set_process(true)
	island.set_process(true)
	game.terrain_surface.set_process(true)
	game.day_night.set_process(true)
	for i in range(branches.size()-1,-1,-1):
		await visit(branches[i].junction)
		await visit(branches[i].center)
		await visit(branches[i].junction)
	await visit(entry)
	normal_loop=false
	game.set_process(false)
	island.set_process(false)
	game.terrain_surface.set_process(false)
	game.day_night.set_process(false)
	if not draw_intervals.is_empty():
		draw_intervals.sort()
		print("LIVE BACKTRACK p50/p95/max us ",draw_intervals[draw_intervals.size()/2],"/",draw_intervals[int(draw_intervals.size()*0.95)],"/",draw_intervals[-1])
	await walk_shore(cave.entrances[0].x+3)
	await capture("surface")
	check(not island.section_active and manager.active_instance==null,"Walkout restored surface")
	island._clear_stream()
	await process_frame
	island._queue_near(game.hero.global_position)
	while not island._pending.is_empty():
		island._build_pending()
	check(guard_for("foreman")==null and guard_for("miner")==null and find_chest().remaining().is_empty(),"Chunk reload reset mine")
	var peak: int = island.section_peak_bytes
	game.queue_free()
	await process_frame
	await process_frame
	await load_world(false)
	manager = game.get_node("Dungeons")
	check(manager.world_sites.sites[site_id].state=="cleared" and manager.world_sites.sites[site_id].reward_claims.has("0:treasure:player"),"Save reload reset site")
	check(int(game.inventory.get("coins",0))==coins+18 and find_chest().remaining().is_empty() and guard_for("miner")==null and guard_for("foreman")==null,"Save reload reset loot or guards")
	print("MINE RESULT ",not failed," peak bytes ",peak)
	game.queue_free()
	await process_frame
	await process_frame
	if OS.is_debug_build():
		for id in Node.get_orphan_node_ids():
			var node = instance_from_id(id)
			check(node.name!="VoxelSteel Sword","Leaked equipment mesh")
			print("ORPHAN ",node.name," ",node.get_class())
	quit(1 if failed else 0)

func find_chest() -> Node3D:
	for entity in get_nodes_in_group("world_interactables"):
		if entity is TREASURE and not entity.is_queued_for_deletion():
			return entity
	return null
