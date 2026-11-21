extends SceneTree
## The remote islands have different radii and mountain profiles. Actually
## simulate swim-to-walk transitions on each one; static sampler tests alone
## allowed a blocking cave entrance and concave-mesh collider to slip through.
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS ALL SHORE: " + detail)
	else:
		failures += 1
		push_error("FAIL ALL SHORE: " + detail)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	var streamer = game.terrain_surface.archipelago
	check(streamer != null, "Real archipelago streaming is enabled")
	if streamer == null:
		game.queue_free()
		quit(1)
		return
	for number in range(streamer.terrain.islands.size()):
		var island: Dictionary = streamer.terrain.islands[number]
		var centre: Vector2i = island["center"]
		var outer: float = float(centre.x) + float(island["radius"]) + 9.0
		var start: Vector3 = Vector3(outer, game.hero.WATER_SURFACE_Y - 0.78, float(centre.y) + 0.5)
		var goal: Vector3 = Vector3(float(centre.x) + 13.0, 0, float(centre.y) + 0.5)
		game.hero.stop_interaction_move()
		game.controls.cancel()
		game.hero.global_position = start
		game.hero.velocity = Vector3.ZERO
		game.hero.knockback_velocity = Vector3.ZERO
		streamer._queue_near(start)
		for _preload in range(75):
			streamer._build_pending()
		game.hero.move_to_interaction(goal)
		var initial_swim: bool = game.hero._detect_surface_swimming()
		var closest_x: float = outer
		var highest_y: float = start.y
		var grounded: bool = false
		var last_x: float = outer
		var no_progress: int = 0
		var stuck: bool = false
		for frame in range(660):
			await physics_frame
			var at: Vector3 = game.hero.global_position
			closest_x = minf(closest_x, at.x)
			highest_y = maxf(highest_y, at.y)
			grounded = grounded or game.hero.is_on_floor()
			if at.x < last_x - 0.005:
				no_progress = 0
			elif at.x < outer - 3.0:
				no_progress += 1
			if no_progress > 85:
				stuck = true
				print("ALL SHORE STALL island=%d frame=%d at=%s swimming=%s grounded=%s" % [
					number + 1, frame, str(at), str(game.hero.swimming), str(game.hero.is_on_floor())])
				break
			last_x = at.x
			if at.x <= goal.x + 2.7:
				break
		check(initial_swim, "Island %d starts in real swimmable ocean" % (number + 1))
		check(not stuck, "Island %d no permanent beach or cliff sticking" % (number + 1))
		check(closest_x <= goal.x + 3.0,
			"Island %d traverses coast and reaches inland exploration zone (x=%.2f)" % [number + 1, closest_x])
		check(grounded and highest_y >= -1.0,
			"Island %d transitions to on-foot exploration (highest Y=%.2f)" % [number + 1, highest_y])
	game.queue_free()
	await process_frame
	print("ALL SHORE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
