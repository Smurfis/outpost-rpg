extends SceneTree
const PICK = preload("res://scripts/interaction/world_picker.gd")
const PATH = preload("res://scripts/navigation/crafting_station_path.gd")
const OUT := "res://artifacts/cave_render/streamed-section/"
var capture_dir := OUT
var game
var island
var failed := false
var worst := 0
var walking_worst := 0
var walking_times := PackedInt64Array()
var measuring_walk := false
var draw_intervals := PackedInt64Array()
var previous_walk_draw := 0
var captures := 0
var manual := false

func _initialize() -> void:
	OS.set_environment("OUTPOST_TEST_SIDE_CHAMBER","1")
	call_deferred("run")

func check(ok: bool, msg: String) -> void:
	if not ok:
		failed = true
		push_error(msg)

func point(c: Vector2i) -> Vector3:
	return Vector3(c.x+0.5,island.terrain.caves.floor_at(c.x,c.y)+0.1,c.y+0.5)

func refresh() -> void:
	game._camera(1.0)
	var old: int = island._region
	var was_active: bool = island.section_active
	var t := Time.get_ticks_usec()
	island._update_cutaway(game,game.hero.global_position,1)
	var elapsed := Time.get_ticks_usec()-t
	worst = maxi(worst,elapsed)
	if measuring_walk:
		walking_worst = maxi(walking_worst,elapsed)
		walking_times.append(elapsed)
	if island.section_active and (old != island._region or not was_active):
		print("activate region ",island._region," us ",elapsed)
	island._update_hero_visibility(game,game.hero)
	game.day_night.interior_blend = 1.0 if island.section_active else 0.0
	game.day_night._apply_light()

func record_draw() -> void:
	var now := Time.get_ticks_usec()
	if measuring_walk and previous_walk_draw != 0:
		draw_intervals.append(now - previous_walk_draw)
	previous_walk_draw = now if measuring_walk else 0

func walk(c: Vector2i) -> void:
	previous_walk_draw = 0
	measuring_walk = true
	var goal := point(c)
	var path: PackedVector3Array = PATH.plan_world(game,game.hero.global_position,goal)
	check(not path.is_empty(),"No navigation path to "+str(c))
	if manual:
		game.controls.cancel()
	else:
		check(game.controls.move_to(goal),"Move command rejected "+str(goal))
	var next := 0
	for i in range(900):
		if manual:
			while next < path.size()-1 and Vector2(game.hero.position.x-path[next].x,game.hero.position.z-path[next].z).length() < 0.19:
				next += 1
			var delta: Vector3 = path[next]-game.hero.position
			delta.y = 0
			steer(delta.normalized())
		if i % 24 == 0:
			game.camera_angle_target += 0.15
		await physics_frame
		refresh()
		if game.hero.global_position.distance_to(goal)<0.45:
			game.controls.cancel()
			steer(Vector3.ZERO)
			measuring_walk = false
			return
	print("STALL velocity=",game.hero.velocity," moving=",game.hero.interaction_moving," waypoint=",game.hero.interaction_target," remaining=",game.hero.station_waypoints," original path=",path)
	for j in game.hero.get_slide_collision_count():
		var contact = game.hero.get_slide_collision(j)
		print("CONTACT ",contact.get_collider().name," shape ",contact.get_collider_shape_index()," normal ",contact.get_normal()," at ",contact.get_position())
	check(false,"Walk stalled at "+str(game.hero.global_position)+" going to "+str(goal))

func capture(label: String) -> void:
	# Measure the four reproducible camera poses after orbiting on the walk.
	game.camera_angle_target = roundf(game.camera_angle_target/(PI/2))*(PI/2)
	game.camera_angle = game.camera_angle_target
	var t := Time.get_ticks_usec()
	refresh()
	print("pose update us ",Time.get_ticks_usec()-t)
	await physics_frame
	if island.section_active:
		check(not island._outline_active,"Unexpected outline")
		if label in ["02-side","03-side-rotated","05-end","06-end-rotated"]:
			var anchor: Vector2i = island.side_chamber.center if island._region == 1 else Vector2i(island.terrain.caves.routes[0].back().x,island.terrain.caves.routes[0].back().z)
			var goal := point(anchor+Vector2i(1,-1))-Vector3.UP*0.1
			var hit := PICK.resolve(game,game.camera.unproject_position(goal))
			check(hit.get("position",Vector3.INF).distance_to(goal)<0.1,"Visible floor pick failed: "+label)
			verify_floor_samples(anchor)
	print(label," at ",game.hero.global_position," region ",island._region," builds ",island.section_builds," bytes ",island.section_cache_bytes)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_dir+label+".png")==OK,"Capture failed")
	captures += 1

func setup_walk(player_save := "user://connected_capture.json", dungeon_save := "user://connected_dungeon.json", fresh := true) -> void:
	if DisplayServer.get_name() != "headless" and not RenderingServer.frame_post_draw.is_connected(record_draw):
		RenderingServer.frame_post_draw.connect(record_draw)
	# Only this capture drives the player. Desktop key and mouse events can
	# otherwise replace a waypoint while the offscreen window is running.
	root.unfocusable = true
	root.size = Vector2i(1280,720)
	root.set_meta("outpost_new_adventure",fresh)
	root.set_meta("outpost_input_mode","desktop")
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = player_save
	game.get_node("Dungeons").save_path = dungeon_save
	root.add_child(game)
	game.set_process_unhandled_input(false)
	game.controls.set_process_unhandled_input(false)
	game.controls.set_process_input(false)
	game.hud.set_process_input(false)
	for action in [&"outpost_left", &"outpost_right", &"outpost_up", &"outpost_down"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	await physics_frame
	game.set_process(false)
	game.terrain_surface.set_process(false)
	game.day_night.set_process(false)
	game.controls.set_physics_process(true)
	game.hud.hide()
	island = game.terrain_surface.archipelago
	island.set_process(false)

func run() -> void:
	await setup_walk()
	check(island.side_chamber != null,"Test chamber missing")
	if failed:
		quit(1)
		return
	var side = island.side_chamber
	var route: Array = island.terrain.caves.routes[0]
	var entrance := Vector2i(route[0].x,route[0].z)
	var end := Vector2i(route.back().x,route.back().z)
	game.hero.global_position = point(entrance)
	island._queue_near(game.hero.global_position)
	while not island._pending.is_empty():
		island._build_pending()
	game.terrain_surface._update_water_horizon(game.hero.global_position)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var t := Time.get_ticks_usec()
	for frame in range(1800):
		refresh()
		if island._prewarm_complete:
			print("warmup frames ",frame+1," total elapsed ms ",(Time.get_ticks_usec()-t)/1000," peak section us ",worst)
			break
		await process_frame
	check(island._prewarm_complete,"Warmup never finished")
	var warm_count: int = island.section_builds
	check(game.hero.global_position.distance_to(point(entrance))<0.45,"Player moved during stationary entrance prewarm")
	worst = 0
	await capture("00-entrance")
	var turn: Vector2i = side.junction
	var sign_z: int = signi(side.center.y-turn.y)
	var connector := turn + Vector2i(0,2*sign_z)
	await walk(turn)
	await capture("01-tunnel")
	await walk(connector)
	await walk(side.center)
	await capture("02-side")
	await orbit_room("side")
	await click_floor(side.center+Vector2i(1,0))
	game.camera_angle_target += PI/2
	game.camera_angle = game.camera_angle_target
	await capture("03-side-rotated")
	check(island._region==1 and island.section_active,"Side chamber inactive")
	await walk(connector)
	await capture("04-return-tunnel")
	await walk(turn)
	await walk(end+Vector2i(-1,0))
	await capture("05-end")
	await orbit_room("end")
	game.camera_angle_target += PI/2
	game.camera_angle = game.camera_angle_target
	await capture("06-end-rotated")
	check(island._region==0 and island.section_active,"End chamber inactive")
	var chest = island.get_node("IslandCaveChest_0")
	check(PICK.resolve(game,game.camera.unproject_position(chest.global_position+Vector3.UP*0.5)).get("target")==chest,"Chest pick failed")
	await click_floor(end+Vector2i(-1,-1))
	await wall_probe(end)
	await walk(turn)
	await walk(side.center)
	await capture("07-side-reentry")
	await walk(turn)
	await walk(entrance)
	await capture("08-surface")
	manual = true
	for dest in [turn,end+Vector2i(-1,0),turn,connector,side.center,connector,turn,entrance]:
		await walk(dest)
	print("reverse route by direct movement complete at ",game.hero.position)
	check(not island.section_active,"Surface did not restore")
	check(island.section_evictions>0 and island._variants.size()<=island.MAX_VARIANTS,"Cache bounds were not exercised")
	if not draw_intervals.is_empty():
		draw_intervals.sort()
		print("walking draw interval p95/max us ",draw_intervals[int(draw_intervals.size()*0.95)],"/",draw_intervals[-1])
	walking_times.sort()
	print("movement p95/max us ",walking_times[int(walking_times.size()*0.95)],"/",walking_worst)
	print("column packet hits ",island.section_packet_hits," packet bytes ",island.packet_cache_bytes)
	print("entrance builds ",warm_count," total builds ",island.section_builds," shared hits ",island.section_reuses," evictions ",island.section_evictions," peak payload ",island.section_peak_bytes)
	print("mask/face/publish us ",island.mask_usec,"/",island.faces_usec,"/",island.publish_usec)
	check(island._face_pages.size()<=island.MAX_FACE_PAGES and island._recent_masks.size()<=island.MAX_RECENT_MASKS,"Auxiliary caches exceeded bounds")
	var entries: int = island._variants.size()
	island.invalidate_section_geometry()
	check(island.section_cache_bytes==0 and island.packet_cache_bytes==0 and island._shared_chunks.is_empty() and island._recent_masks.is_empty() and island._face_pages.is_empty(),"Section payload retained after invalidation")
	print("walk peak section us ",worst," cache entries ",entries," passed ",not failed)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)

func steer(direction: Vector3) -> void:
	var right: Vector3 = game.camera.global_basis.x
	var forward: Vector3 = game.camera.global_basis.z
	game.hud.move_vector = Vector2(direction.dot(right),direction.dot(Vector3(forward.x,0,forward.z).normalized()))

func wall_probe(end: Vector2i) -> void:
	var edge := end+Vector2i(-2,2)
	await walk(edge)
	game.camera_angle_target = 0
	game.camera_angle = 0
	refresh()
	var wall := edge + Vector2i.DOWN
	var goal := Vector3(wall.x+0.5,point(edge).y-0.1,wall.y+0.5)
	await physics_frame
	var hit := PICK.resolve(game,game.camera.unproject_position(goal))
	check(hit.is_empty() or hit.get("normal",Vector3.UP).y < 0.7,"Cross section was accepted as a ground target")
	print("WALL PROBE destination ",goal," pick ",hit.get("position")," normal ",hit.get("normal")," planned path ",PATH.plan_world(game,game.hero.global_position,goal))
	steer(Vector3.BACK)
	for i in range(25):
		await physics_frame
	for i in game.hero.get_slide_collision_count():
		var contact = game.hero.get_slide_collision(i)
		print("WALL CONTACT ",contact.get_collider().name," shape ",contact.get_collider_shape_index()," normal ",contact.get_normal()," at ",contact.get_position()," player ",game.hero.global_position," velocity ",game.hero.velocity)
	print("occupancy foot/head ",island.terrain.is_solid(wall.x,0,wall.y),"/",island.terrain.is_solid(wall.x,1,wall.y)," standing cell ",Vector2i(floori(game.hero.position.x),floori(game.hero.position.z)))
	steer(Vector3.ZERO)

func verify_floor_samples(anchor: Vector2i) -> void:
	var verified := 0
	for dx in range(-3,4):
		for dz in range(-3,4):
			var cell := anchor + Vector2i(dx,dz)
			var at := Vector3(cell.x+0.5,point(anchor).y-0.1,cell.y+0.5)
			var hit := PICK.resolve(game,game.camera.unproject_position(at))
			if hit.is_empty() or hit.get("target") != null or hit.normal.y < 0.7:
				continue
			var air := Vector3i((Vector3(hit.position)+Vector3.UP*0.01).floor())
			var floor_y: int = island.terrain.caves.floor_at(air.x,air.z)
			check(not island.terrain.is_solid(air.x,air.y,air.z),"Solid voxel %s reported as floor: %s" % [air,hit])
			if floor_y != air.y:
				continue
			check(island.terrain.is_solid(air.x,air.y-1,air.z) and not island.terrain.is_solid(air.x,air.y+1,air.z),"Walkable sample missing footing or headroom")
			verified += 1
	check(verified > 0,"No visible physical floor samples")

func click_floor(cell: Vector2i) -> void:
	var goal := point(cell)-Vector3.UP*0.1
	var click: Vector2 = game.camera.unproject_position(goal)
	check(game.controls.primary_at(click,false),"Click rejected at "+str(cell))
	for i in range(180):
		await physics_frame
		refresh()
		if game.hero.global_position.distance_to(goal)<0.45:
			game.controls.cancel()
			return
	check(false,"Click failed to move capsule to "+str(goal))

func orbit_room(label: String) -> void:
	var angle: float = game.camera_angle_target
	for degrees in [0,90,180,270]:
		game.camera_angle_target = deg_to_rad(degrees)
		game.camera_angle = game.camera_angle_target
		await capture("%s-%03d" % [label,degrees])
	for degrees in range(0,360,10):
		game.camera_angle_target = deg_to_rad(degrees)
		game.camera_angle = game.camera_angle_target
		refresh()
		await physics_frame
		await physics_frame
		var torso: Vector3 = game.hero.global_position + Vector3.UP*1.2
		var ray := PhysicsRayQueryParameters3D.create(game.camera.project_ray_origin(game.camera.unproject_position(torso)),torso,island.SECTION_PICK)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
		check(hit.is_empty(),"Hidden torso at %s %d" % [label,degrees])
	game.camera_angle_target = angle
	game.camera_angle = angle
	refresh()


