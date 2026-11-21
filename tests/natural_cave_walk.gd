extends "res://tests/procedural_cave_walk.gd"
var player_file := "user://natural_%d.json" % OS.get_process_id()
var site_file := "user://natural_sites_%d.json" % OS.get_process_id()

func _initialize() -> void:
	OS.set_environment("OUTPOST_TEST_NATURAL_CAVES","1")
	OS.set_environment("OUTPOST_TEST_PROCEDURAL_CAVE","0")
	OS.set_environment("OUTPOST_TEST_SIDE_CHAMBER","0")
	capture_dir = "res://artifacts/cave_render/natural-network/"
	call_deferred("run")

func run() -> void:
	await setup_walk(player_file,site_file)
	var cave = island.terrain.caves.natural
	check(cave != null and island.mine != null, "Natural cave and separate mine required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	# Set up the player once on the approach. All subsequent travel is physical.
	game.hero.global_position = point(cave.approach)
	island._queue_near(game.hero.position)
	while not island._pending.is_empty():
		island._build_pending()
	await physics_frame
	game.inventory["torch"] = 1
	game.equip_item("torch")
	collect = true
	manual = true
	refresh()
	await capture("01-hillside")
	await visit(cave.chambers[0])
	check(island.section_active, "Hub failed to open")
	await capture("02-junction")
	var clicked := false
	for offset: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var tile: Vector2i = cave.chambers[0]+offset
		var floor_point := point(tile)-Vector3.UP*0.1
		var hit := PICK.resolve(game,game.camera.unproject_position(floor_point))
		if hit.get("target") == null and hit.get("position",Vector3.INF).distance_to(floor_point)<0.08:
			await click_floor(tile)
			clicked = true
			break
	check(clicked,"No pickable floor near junction")
	await visit(cave.guard_cell)
	var pop = island.natural_population
	var guard
	for mob in get_nodes_in_group("enemies"):
		if mob.get("encounter_id") == pop.encounter_id:
			guard = mob
	check(guard != null, "Missing dark chamber encounter")
	if guard != null:
		var hp: float = game.hero.health
		var picked := false
		for i in 200:
			await physics_frame
			refresh()
			if i%40 == 0:
				game.camera_angle_target += PI/2
			picked = picked or PICK.resolve(game,game.camera.unproject_position(guard.position+Vector3.UP*0.65)).get("target") == guard
			if picked and game.hero.health < hp:
				break
		check(picked and game.hero.health < hp,"Goblin picking or attack failed")
		await capture("03-dark-chamber")
		for i in 250:
			await physics_frame
			refresh()
			game.interact_target(guard)
			if not guard.alive:
				break
		check(not guard.alive and game.natural_cave_encounters.get(pop.encounter_id,1) == 0,"Goblin defeat persistence failed")
	await visit(cave.chambers[0])
	await visit(cave.chambers[2])
	var ore
	for obj in get_nodes_in_group("world_interactables"):
		if obj.get("object_id") == pop.ore_id:
			ore = obj
	check(ore != null, "Missing iron")
	if ore != null:
		await visit(cave.ore_cell+Vector2i.LEFT)
		game.interact_target(ore)
		check(ore.remaining().is_empty(),"Ore collection failed")
	await visit(cave.shaft_bottom)
	await capture("04-shaft-bottom")
	await visit(cave.rim)
	await capture("05-sinkhole-rim")
	game.camera_angle_target += PI/2
	await visit(cave.shaft_landing)
	await capture("06-descending")
	check(island.section_active and not island._outline_active, "Occluded player on shaft landing")
	await visit(cave.shaft_bottom)
	await capture("07-descended")
	await visit(cave.chambers[0])
	manual = false
	await visit(cave.approach)
	check(not island.section_active,"Hillside exit still covered")
	var shore: Vector2i = cave.approach - cave.mouth
	game.camera_angle_target = atan2(float(shore.x),float(shore.y))
	game.camera_angle = game.camera_angle_target
	await capture("08-surface")
	for stage in ["navigation plan per command","terrain stream and water"]:
		var times: Array = stage_samples[stage]
		times.sort()
		print("PROFILE ", stage, " n ", times.size()," p50/p95/max us ",times[times.size()/2],"/",times[int(times.size()*0.95)],"/",times.back())
	var id: String = pop.encounter_id
	var loot: String = pop.ore_id
	var peak: int = island.section_peak_bytes
	game.queue_free()
	await process_frame
	await process_frame
	await setup_walk(player_file,site_file,false)
	island._queue_near(point(cave.guard_cell))
	while not island._pending.is_empty():
		island._build_pending()
	check(game.natural_cave_encounters.get(id,1) == 0 and game.opened_world_objects.get(loot,{"iron":3}).is_empty(),"Save reload lost defeat or reward")
	for mob in get_nodes_in_group("enemies"):
		check(mob.get("encounter_id") != id,"Streamed goblin resurrected")
	print("NATURAL WALK ",not failed," peak cache bytes ",peak," cold turn us ",coldest_turn)
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
