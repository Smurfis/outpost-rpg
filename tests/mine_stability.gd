extends "res://tests/physical_mineshaft.gd"
## One live main loop. No screenshots or image readbacks inside measured intervals.
var phase := ""
var samples := {}
var last_draw := 0
var draw_start := 0
var idle_start := 0
var physics_start := 0
var physics_us := 0
var script_us := 0
var counters := PackedInt64Array()
var actors: Array = []
var gpu_queries := false


func _initialize() -> void:
	OS.set_environment("OUTPOST_PROFILE_MINE","1")
	super._initialize()
	capture_dir = "res://artifacts/stability-data/frames/"

func tick_physics() -> void:
	var now := Time.get_ticks_usec()
	if physics_start:
		physics_us += now-physics_start
	physics_start = now

func tick_idle() -> void:
	idle_start = Time.get_ticks_usec()
	if physics_start:
		physics_us += idle_start-physics_start
	physics_start = 0

func tick_submit() -> void:
	draw_start = Time.get_ticks_usec()
	script_us = draw_start-idle_start

func read_counts() -> PackedInt64Array:
	var ai := 0
	for actor in actors:
		if is_instance_valid(actor):
			ai += int(actor.ai_usec)
	return PackedInt64Array([island.stream_usec,island.mask_usec,island.faces_usec,island.publish_usec,game.controls.path_usec,ai])

func tick_draw() -> void:
	var now := Time.get_ticks_usec()
	var current := read_counts()
	if phase!="" and last_draw and not counters.is_empty():
		var row := [now-last_draw,now-draw_start,script_us,physics_us]
		for i in current.size():
			row.append(maxi(0,current[i]-counters[i]))
		row.append(1000.0*RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()) if gpu_queries else 0.0)
		if not samples.has(phase):
			samples[phase] = []
		samples[phase].append(row)
	counters = current
	last_draw = now
	physics_us = 0

func capture(_label: String) -> void:
	# Base combat checks also run in this fixture; exclude PNG readback.
	await process_frame

func measure(label: String, frames := 36) -> void:
	phase = ""
	for i in 8:
		await process_frame
	phase = label
	for i in frames:
		await process_frame
	phase = ""

func travel(cell: Vector2i, label: String, inject_focus := false) -> void:
	var goal := point(cell)
	check(game.controls.move_to(goal),"Rejected route "+label)
	phase = label
	for i in 1250:
		await physics_frame
		if i==5 and inject_focus:
			var pending: PackedVector3Array = game.hero.station_waypoints.duplicate()
			game.controls.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			check(game.controls.navigating and game.hero.station_waypoints==pending,"Focus cleared or replaced the path")
		if game.hero.global_position.distance_to(goal)<0.42:
			phase = ""
			game.controls.cancel()
			return
		if not game.hero.interaction_moving and not game.controls.navigating:
			break
	phase = ""
	check(false,"Route interrupted "+label+" at "+str(game.hero.position))

func ablate(label: String) -> void:
	var sea: MeshInstance3D = game.terrain_surface._distant_ocean
	var sea_layers := sea.layers
	sea.layers = 0
	await measure(label+" ocean off")
	sea.layers = sea_layers
	var layers := {}
	for node in island.find_children("*","MeshInstance3D",true,false):
		if node.is_visible_in_tree() and (node.name.begins_with("IslandRock_") or node.name.begins_with("CaveCutaway_") or node.name.begins_with("IslandShadow_") or node.name.begins_with("CaveShadow_") or (node.get_parent()==island and node.get_child_count()>0 and node.get_child(0) is StaticBody3D)):
			layers[node] = node.layers
			node.layers = 0
	await measure(label+" terrain off")
	for node in layers:
		if is_instance_valid(node):
			node.layers = layers[node]
	root.disable_3d = true
	await measure(label+" empty viewport")
	root.disable_3d = false

func report() -> void:
	for label in samples:
		var rows: Array = samples[label]
		var stats := []
		for column in rows[0].size():
			var values := []
			for row in rows:
				values.append(row[column])
			values.sort()
			stats.append([values[values.size()/2],values[int(values.size()*0.95)],values[-1]])
		print("FRAME ",label," n=",rows.size()," ",JSON.stringify(stats))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	await load_world(true)
	var graphics := DisplayServer.get_name()!="headless"
	actors = [guard_for("miner"), guard_for("foreman")]
	normal_loop = true
	game.set_process(true)
	island.set_process(true)
	game.day_night.set_process(true)
	game.terrain_surface.set_process(true)
	var entry: Vector3 = island.terrain.caves.entrances[0]
	# Sample idle away from the miner's eight-metre aggro radius.
	var trunk: Vector3i = island.terrain.caves.routes[0][13]
	var junction := Vector2i(trunk.x,trunk.z)
	var end := Vector2i(island.terrain.caves.chests[0].x,island.terrain.caves.chests[0].z)
	game.hud.show()
	var vsync := DisplayServer.window_get_vsync_mode()
	if graphics:
		physics_frame.connect(tick_physics)
		process_frame.connect(tick_idle)
		RenderingServer.frame_pre_draw.connect(tick_submit)
		RenderingServer.frame_post_draw.connect(tick_draw)
		print("DISPLAY vsync ",DisplayServer.window_get_vsync_mode()," max fps ",Engine.max_fps," low processor ",OS.low_processor_usage_mode," refresh ",DisplayServer.screen_get_refresh_rate())
		await measure("outdoor idle")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		await measure("outdoor vsync off")
		await ablate("outdoor uncapped")
		gpu_queries = true
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		await measure("outdoor uncapped gpu")
		gpu_queries = false
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),false)
		DisplayServer.window_set_vsync_mode(vsync)
	phase = "outdoor movement"
	await walk_shore(entry.x)
	phase = ""
	await travel(junction,"underground movement",true)
	if graphics:
		await measure("underground idle")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		await measure("underground vsync off")
		await ablate("underground uncapped")
		gpu_queries = true
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		await measure("underground uncapped gpu")
		gpu_queries = false
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),false)
		DisplayServer.window_set_vsync_mode(vsync)
	# Walk a real visible floor click, then deliver focus loss while the mouse
	# is held. Picking has finished and subsequent yaw changes cannot retarget it.
	var clicked := false
	for offset in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
		var c: Vector2i = junction+offset
		if not island.terrain.caves.has_cave(c.x,c.y):
			continue
		var g := point(c)-Vector3.UP*0.1
		var s: Vector2 = game.camera.unproject_position(g)
		var hit := PICK.resolve(game,s)
		if hit.get("position",Vector3.INF).distance_to(g)>0.05 or hit.get("target")!=null:
			continue
		if not game.controls.primary_at(s,true):
			continue
		clicked=true
		var path: PackedVector3Array = game.hero.station_waypoints.duplicate()
		game.controls.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(game.controls.navigating and not game.controls.hold_ground and path==game.hero.station_waypoints,"Focus loss during click")
		for i in 90:
			await physics_frame
			if game.hero.global_position.distance_to(g)<0.42:
				break
		check(game.hero.global_position.distance_to(g)<0.42,"Visible click to %s stopped at %s; goal %s" % [g,game.hero.position,game.controls.destination])
		break
	check(clicked,"No valid floor click")
	# Encounter approach may legitimately be interrupted by a blow, so use
	# directional movement during combat, as in a manual melee encounter.
	manual = true
	await visit(island.terrain.caves.branches[0].junction)
	phase = "combat"
	await visit(island.terrain.caves.branches[0].center)
	await fight("miner")
	phase = ""
	game.camera_angle_target += PI/2
	await visit(end+Vector2i(0,1))
	await fight("foreman")
	manual=false
	for i in 3:
		game.camera_angle_target += PI/2
		await travel(Vector2i(entry.x,entry.z),"return to entrance",true)
		phase = "surface exit and approach"
		await walk_shore(entry.x+3)
		await process_frame
		await physics_frame
		check(not island.section_active,"Surface exit left the cutaway active")
		await walk_shore(entry.x)
		phase = ""
		await travel(end+Vector2i.RIGHT,"repeat mine entry",true)
	await travel(Vector2i(entry.x,entry.z),"return to entrance")
	check(game.controls.move_to(point(junction)),"Pause control route")
	game.controls.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(not game.controls.navigating and not game.hero.interaction_moving,"Pause failed to cancel")
	if graphics:
		RenderingServer.frame_post_draw.disconnect(tick_draw)
		report()
	print("STABILITY ",not failed)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
