extends "res://tests/side_chamber_walk.gd"

var stage_samples := {}
var physics_started := 0
var submit_started := 0
var physics_fixture_us := 0

var collect := false
var visited := {}
var last_room := -1
var coldest_turn := 0


func _initialize() -> void:
	OS.set_environment("OUTPOST_TEST_SIDE_CHAMBER","0")
	OS.set_environment("OUTPOST_TEST_PROCEDURAL_CAVE","1")
	capture_dir = "res://artifacts/cave_render/procedural-trial/"
	call_deferred("run")

func sample(stage: String, usec: float) -> void:
	if not collect:
		return
	if not stage_samples.has(stage):
		stage_samples[stage] = []
	stage_samples[stage].append(usec)

func begin_physics() -> void:
	physics_started = Time.get_ticks_usec()
	physics_fixture_us = 0

func after_physics() -> void:
	if physics_started and measuring_walk:
		sample("physics phase outside fixture",maxi(0,Time.get_ticks_usec()-physics_started-physics_fixture_us))
	physics_started = 0

func before_draw() -> void:
	submit_started = Time.get_ticks_usec()

func after_draw() -> void:
	if measuring_walk and submit_started:
		sample("render submission wall",Time.get_ticks_usec()-submit_started)
		var rid := root.get_viewport_rid()
		sample("viewport GPU",1000.0*RenderingServer.viewport_get_measured_render_time_gpu(rid))
		sample("viewport render CPU",1000.0*RenderingServer.viewport_get_measured_render_time_cpu(rid))

func refresh() -> void:
	var started := Time.get_ticks_usec()
	# Drive the same live terrain and gameplay updates at the fixture's fixed physics tick.
	game.terrain_surface._process(1.0/60)
	island._queue_near(game.hero.global_position)
	island._build_pending()
	var streamed := Time.get_ticks_usec()
	game._process(1.0/60)
	var played := Time.get_ticks_usec()
	var old_sector: int = island._sector
	var old_builds: int = island.section_builds
	var masks: int = island.mask_usec
	var faces: int = island.faces_usec
	var uploads: int = island.publish_usec
	super.refresh()
	var finished := Time.get_ticks_usec()
	if physics_started:
		physics_fixture_us += finished-started
	if measuring_walk:
		sample("terrain stream and water",streamed-started)
		sample("game manager",played-streamed)
		sample("visibility mask",island.mask_usec-masks)
		sample("section faces",island.faces_usec-faces)
		sample("section publication",island.publish_usec-uploads)
	if island.section_active:
		if island._region != last_room:
			print("ENTRY region ",island._region," first ",not visited.has(island._region)," update us ",finished-played," builds ",island.section_builds-old_builds)
		visited[island._region] = true
		if old_sector >= 0 and old_sector != island._sector and island.section_builds != old_builds:
			if finished-played > coldest_turn:
				coldest_turn = finished-played
				print("COLD peak us ",coldest_turn," mask/face/publish ",island.mask_usec-masks,"/",island.faces_usec-faces,"/",island.publish_usec-uploads)
	last_room = island._region if island.section_active else -1

func visit(cell: Vector2i) -> void:
	var start := Time.get_ticks_usec()
	var path := PATH.plan_world(game,game.hero.global_position,point(cell))
	var elapsed := Time.get_ticks_usec()-start
	sample("navigation plan per command",elapsed)
	check(not path.is_empty(),"No traversable route to "+str(cell))
	await walk(cell)
	check(Vector2(game.hero.position.x,game.hero.position.z).distance_to(Vector2(cell)+Vector2(0.5,0.5))<0.45,"Did not arrive at "+str(cell))

func room_checks(label: String, cell: Vector2i) -> void:
	check(island.section_active and island._region == island._owners[cell], "Wrong rendered room "+label)
	await orbit_room(label)
	verify_floor_samples(cell)
	# Require a real mouse command to a visible, unoccupied floor tile.
	for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var dest: Vector2i = cell+offset
		var goal := point(dest)-Vector3.UP*0.1
		var hit := PICK.resolve(game,game.camera.unproject_position(goal))
		if hit.get("target") == null and hit.get("position",Vector3.INF).distance_to(goal)<0.05:
			await click_floor(dest)
			return
	check(false,"No selectable visible floor in "+label)

func run() -> void:
	await setup_walk()
	physics_frame.connect(begin_physics)
	process_frame.connect(after_physics)
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		RenderingServer.frame_pre_draw.connect(before_draw)
		RenderingServer.frame_post_draw.connect(after_draw)
	var cave = island.terrain.caves
	var entry := Vector2i(cave.entrances[0].x,cave.entrances[0].z)
	var end := Vector2i(cave.chests[0].x,cave.chests[0].z)
	check(cave.branches.size() >= 2,"Missing procedural branches")
	game.hero.global_position = point(entry)
	island._queue_near(game.hero.global_position)
	while not island._pending.is_empty():
		island._build_pending()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	for i in 500:
		refresh()
		if island._prewarm_complete:
			break
		await process_frame
	await capture("entrance")
	collect = true
	var branches: Array = cave.branches.duplicate()
	branches.sort_custom(func(a,b):return a.junction.x > b.junction.x)
	for i in branches.size():
		var branch: Dictionary = branches[i]
		print("ROOM ",i," center ",branch.center," size ",branch.size," junction ",branch.junction)
		await visit(branch.junction)
		await capture("junction-"+str(i))
		await visit(branch.threshold)
		await capture("passage-"+str(i))
		await visit(branch.center)
		await room_checks("chamber-"+str(i),branch.center)
		await visit(branch.junction)
	await visit(end+Vector2i.LEFT)
	await room_checks("end",end+Vector2i.LEFT)
	var chest = island.get_node("IslandCaveChest_0")
	check(PICK.resolve(game,game.camera.unproject_position(chest.position+Vector3.UP*0.5)).get("target")==chest,"Chest selection")
	var enemy := get_first_node_in_group("enemies") as Node3D
	check(enemy!=null,"Live enemy missing")
	if enemy:
		var previous := enemy.global_position
		enemy.set_physics_process(false)
		game.camera_angle_target = 0
		game.camera_angle = 0
		refresh()
		enemy.global_position = chest.global_position+Vector3(-1,0,1)
		await physics_frame
		await physics_frame
		var picked := PICK.resolve(game,game.camera.unproject_position(enemy.global_position+Vector3.UP*0.5))
		check(picked.get("target")==enemy,"Enemy selection at %s hit %s" % [enemy.global_position,picked])
		enemy.global_position = previous
		enemy.set_physics_process(true)
	manual = true
	branches.reverse()
	for branch in branches:
		await visit(branch.junction)
		await visit(branch.center)
		await visit(branch.junction)
	await visit(entry)
	await capture("surface")
	check(not island.section_active and not island._outline_active,"Surface restoration")
	check(island._variants.size()<=island.MAX_VARIANTS and island.section_evictions>0,"Cache eviction")
	collect = false
	stage_samples["walking cutaway"] = Array(walking_times)
	if not draw_intervals.is_empty():
		stage_samples["walking draw interval"] = Array(draw_intervals)
	for stage in stage_samples:
		var values: Array = stage_samples[stage]
		values.sort()
		print("PROFILE ",stage," n ",values.size()," p50/p95/max us ",values[values.size()/2],"/",values[int(values.size()*0.95)],"/",values.back())
	print("TOTAL seed ",island.terrain.seed," rooms ",branches.size()+1," peak bytes ",island.section_peak_bytes," evictions ",island.section_evictions," patch builds/reuses ",island.section_builds,"/",island.section_reuses," cold us ",coldest_turn," passed ",not failed)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
