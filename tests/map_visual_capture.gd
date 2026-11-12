extends SceneTree
## Desktop visual QA only; generated images use a fully explored test fixture.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "res://.map-visual-save.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.get_node("Dungeons").set_process(false)
	game.hero.set_physics_process(false)
	game.map_service.set_process(false)
	var service = game.map_service
	for x in range(-84, 85, 24):
		for z in range(-84, 85, 24):
			game.hero.global_position = Vector3(x, 0, z)
			service.biome.update_streaming_for(game.hero.global_position)
			for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
			service.observe_player()
			service.refresh_entities()
			await process_frame
	game.hero.global_position = Vector3(0,0.35,0)
	service.biome.update_streaming_for(game.hero.global_position)
	game.hero.update_combat(7)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var opened: bool = game.world_map.open_map()
	print("CAPTURE opened=", opened, " screen=", game.world_map.screen.size, " combat=", game.hero.in_combat, " overworld=", service.in_overworld())
	game.world_map.relief.schedule(Vector3.ZERO)
	for i in range(1200): game.world_map.relief.tick()
	game.world_map.dirty = true
	await process_frame
	await RenderingServer.frame_post_draw
	print("CAPTURE visible=", game.world_map.is_open(), " screen=", game.world_map.screen.size, " art=", game.world_map.map_art.size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/map"))
	root.get_texture().get_image().save_png("res://artifacts/map/overview.png")
	game.world_map.centre_player()
	for i in range(30):
		game.world_map._process(0.05)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/map/close.png")
	game.world_map.close_map()
	game._camera(1)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/map/minimap.png")
	game.queue_free()
	await process_frame
	quit()
