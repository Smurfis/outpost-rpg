extends "res://tests/procedural_cave_walk.gd"

# Reproduce the 4B reference pose and identify which visual owns its bright pixel.
func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("HILLSIDE requires a graphical viewport")
		quit()
		return
	await setup_walk()
	game.hero.position = Vector3(183.5,0.99584,54.90813)
	island._queue_near(game.hero.position)
	while not island._pending.is_empty():
		island._build_pending()
	game.camera_angle_target = 0
	game.camera_angle = 0
	game.camera_focus_smooth = Vector3.ZERO
	refresh()
	await physics_frame
	await RenderingServer.frame_post_draw
	var pixel := Vector2i(980,472)
	var before := root.get_texture().get_image().get_pixelv(pixel)
	var start: Vector3 = game.camera.project_ray_origin(pixel)
	var end: Vector3 = start+game.camera.project_ray_normal(pixel)*game.camera.far
	var candidates := RenderingServer.instances_cull_ray(start,end,game.get_world_3d().scenario)
	print("HILLSIDE baseline ",before," candidates ",candidates.size())
	for id in candidates:
		var candidate = instance_from_id(id)
		if not candidate is GeometryInstance3D or not candidate.is_visible_in_tree():
			continue
		candidate.hide()
		await RenderingServer.frame_post_draw
		var after := root.get_texture().get_image().get_pixelv(pixel)
		candidate.show()
		if before != after:
			print("HILLSIDE contributing visual ",candidate.get_path()," pixel without ",after)
	var portal = game.get_node("Dungeons").world_site_nodes[island.MINE_SITE_ID]
	portal.hide()
	await RenderingServer.frame_post_draw
	var bare := root.get_texture().get_image().get_pixelv(pixel)
	print("HILLSIDE without portal ",bare)
	check(before.get_luminance()>bare.get_luminance()+0.25,"Portal does not explain bright square")
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
