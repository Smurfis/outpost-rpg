extends SceneTree
## Developer-only GL capture, with test saves isolated in user://.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://ocean_capture_player.json"
	game.get_node("Dungeons").save_path = "user://ocean_capture_dungeons.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.terrain_surface.set_process(false)
	game.hero.set_physics_process(false)
	game.hud.visible = false
	var island = game.terrain_surface.archipelago
	island.set_process(false)
	var folder := "res://artifacts/cave_render/ocean-stage"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for index in range(island.terrain.islands.size()):
		var info: Dictionary = island.terrain.islands[index]
		var center: Vector2i = info.center
		var shore_x: int = center.x + roundi(float(info.radius) * 0.85)
		var point := Vector3(float(shore_x) + 0.5, float(island.terrain.height_at(shore_x, center.y)) + 0.2, float(center.y) + 0.5)
		game.hero.global_position = point
		island._queue_near(point)
		while not island._pending.is_empty():
			island._build_pending()
		game.terrain_surface._update_water_horizon(point)
		game.camera_angle = 0.5
		game.camera_angle_target = 0.5
		game.camera_focus_smooth = Vector3.ZERO
		game._camera(1.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/island_%d_shore.png" % [folder, index + 1])
		game.camera.global_position += Vector3.UP * 18.0
		game.camera.look_at(point, Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/island_%d_elevated.png" % [folder, index + 1])
		print("CAPTURE ISLAND ", index + 1, " ", point)
	game.queue_free()
	await process_frame
	quit()
