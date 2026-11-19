extends SceneTree
## Developer-only graphical capture; launch without --headless.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.set_meta("outpost_new_adventure", true)
	root.set_meta("outpost_input_mode", "desktop")
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://render_capture_player.json"
	game.get_node("Dungeons").save_path = "user://render_capture_dungeon.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.terrain_surface.set_process(false)
	game.day_night.set_process(false)
	game.hero.set_physics_process(false)
	game.hud.visible = false
	var island = game.terrain_surface.archipelago
	island.set_process(false)
	var route: Array = island.terrain.caves.routes[0]
	var end: Vector3i = route.back()
	var outside := Vector3(200.5,island.terrain.height_at(200,62)+0.15,62.5)
	var inside := Vector3(end.x-0.5,end.y+0.15,end.z+0.5)
	var folder := "res://artifacts/cave_render/real-section-optimized/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var failed := false
	var cold := OS.get_environment("OUTPOST_COLD_SECTION") == "1"
	for index in range(9):
		var pos := outside if index in [0,6,8] else inside
		game.hero.global_position = pos
		island._queue_near(pos)
		while not island._pending.is_empty():
			island._build_pending()
		game.terrain_surface._update_water_horizon(pos)
		game.day_night.interior_blend = 1.0 if pos == inside else 0.0
		game.day_night._apply_light()
		game.camera_angle = (0 if index == 7 else max(0,index-1))*PI/2
		game.camera_angle_target = game.camera_angle
		game.camera_focus_smooth = Vector3.ZERO
		game._camera(1.0)
		if index == 0 and not cold:
			var samples := PackedInt64Array()
			for frame in range(200):
				var t := Time.get_ticks_usec()
				island._update_cutaway(game,pos,1)
				samples.append(Time.get_ticks_usec()-t)
				await process_frame
			samples.sort()
			print("approach warmup p95/max us ",samples[189],"/",samples[-1]," builds ",island.section_builds," payload bytes ",island.section_cache_bytes)
		var start := Time.get_ticks_usec()
		var previous: int = island.section_builds
		island._update_cutaway(game,pos,1)
		print("section ",index," builds ",island.section_builds-previous," usec ",Time.get_ticks_usec()-start)
		if index in [1,5,7] and not cold and island.section_builds != previous:
			failed = true
		island._update_hero_visibility(game,game.hero)
		await physics_frame
		await physics_frame
		if pos == inside:
			var goal := Vector3(end.x-1.5,end.y,end.z+1.5)
			if index == 4:
				# At 270 degrees the preserved one-block sill occludes this edge.
				var blocked = preload("res://scripts/interaction/world_picker.gd").resolve(game,game.camera.unproject_position(goal))
				failed = failed or not blocked.is_empty()
				goal.x += 1.0
			var pick = preload("res://scripts/interaction/world_picker.gd").resolve(game,game.camera.unproject_position(goal))
			var chest = island.get_node("IslandCaveChest_0")
			var object = preload("res://scripts/interaction/world_picker.gd").resolve(game,game.camera.unproject_position(chest.global_position+Vector3.UP*0.5))
			var path = preload("res://scripts/navigation/crafting_station_path.gd").plan_world(game,pos,goal)
			print("floor ",pick.get("position")," expected ",goal," chest ",object.get("target")==chest," path ",path.size())
			failed = failed or not island.section_active or pick.get("position",Vector3.INF).distance_to(goal)>0.1 or object.get("target")!=chest or path.is_empty()
		if cold or DisplayServer.get_name() == "headless":
			continue
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+str(index)+".png")
	island.invalidate_section_geometry()
	failed = failed or island.section_cache_bytes != 0 or not island._variants.is_empty() or not island._shared_chunks.is_empty() or island.packet_cache_bytes != 0
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
