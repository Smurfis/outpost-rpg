extends "res://tests/physical_mineshaft.gd"

func run() -> void:
	await setup_walk()
	var cave = island.terrain.caves
	var cache: Vector3 = cave.chests[1]
	var route: Array = cave.routes[1]
	print("From -201,-25: island 2 entrance ",cave.entrances[1]," cache ",cache)
	for index in [route.size()/2,route.size()-3]:
		var voxel: Vector3i = route[index]
		game.hero.global_position = point(Vector2i(voxel.x,voxel.z))
		island._queue_near(game.hero.position)
		while not island._pending.is_empty():
			island._build_pending()
		await physics_frame
		refresh()
		check(island.section_active and not island._outline_active,"Island 2 should use reconstructed sections")
	for degrees in [0,90,180,270]:
		game.camera_angle = deg_to_rad(degrees)
		game.camera_angle_target = game.camera_angle
		refresh()
		await physics_frame
		var chest = island.get_node("IslandCaveChest_1")
		var hit := PICK.resolve(game, game.camera.unproject_position(chest.global_position+Vector3.UP*0.4))
		check(hit.get("target")==chest,"Chest could not be picked at heading "+str(degrees))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://island2-"+str(degrees)+".png")
	game.queue_free()
	await process_frame
	await process_frame
	print("CACHE CAVE ",not failed)
	quit(int(failed))
