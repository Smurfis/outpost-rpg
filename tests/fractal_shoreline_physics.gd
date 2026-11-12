extends SceneTree
## Real CharacterBody3D swimming / collision transition, not height-only checks.
var failures: int = 0
func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS SHORE WALK: " + detail)
	else:
		failures += 1
		push_error("FAIL SHORE WALK: " + detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	var streamer = game.terrain_surface.archipelago
	check(streamer != null and streamer.terrain.islands.size() == 3, "Live island terrain is active")
	if streamer == null:
		quit(1)
		return
	# The first island was inaccessible from the sea; a real avatar must
	# traverse its generated physics collision rather than a fake sampler.
	var centre: Vector2i = streamer.terrain.islands[0]["center"]
	var outer: float = float(centre.x) + float(streamer.terrain.islands[0]["radius"]) + 9.0
	var start: Vector3 = Vector3(outer, game.hero.WATER_SURFACE_Y - 0.78, float(centre.y) + 0.5)
	var goal: Vector3 = Vector3(float(centre.x) + 13.0, 0.0, float(centre.y) + 0.5)
	game.hero.global_position = start
	game.hero.velocity = Vector3.ZERO
	# Prime collision before movement so a streaming delay is not mistaken
	# for a swim-to-terrain physics bug.
	streamer._queue_near(start)
	for _i in range(50):
		streamer._build_pending()
	game.hero.move_to_interaction(goal)
	var first_swim: bool = game.hero._detect_surface_swimming()
	var highest_y: float = start.y
	var closest_x: float = start.x
	var grounded: bool = false
	var ever_stuck: bool = false
	var last_x: float = start.x
	var stationary_frames: int = 0
	for frame in range(630):
		await physics_frame
		var at: Vector3 = game.hero.global_position
		closest_x = minf(closest_x, at.x)
		highest_y = maxf(highest_y, at.y)
		grounded = grounded or game.hero.is_on_floor()
		if at.x < last_x - 0.005:
			stationary_frames = 0
		elif at.x < float(centre.x) + 25:
			stationary_frames += 1
		if stationary_frames > 85:
			ever_stuck = true
			print("SHORE DEBUG: stalled pos=%s swim=%s grounded=%s wall=%s next_tile=%d" % [
				str(at), str(game.hero.swimming), str(game.hero.is_on_floor()),
				str(game.hero.is_on_wall()), streamer.terrain.height_at(floori(at.x - 1), floori(at.z))])
			break
		last_x = at.x
		if frame % 90 == 0:
			print("SHORE TRACE: frame=%d pos=%s swim=%s floor=%s" % [frame, str(at), str(game.hero.swimming), str(game.hero.is_on_floor())])
		if at.x <= goal.x + 2.7:
			break
	check(first_swim, "Character begins genuinely swimming")
	check(not ever_stuck, "Character does not freeze against voxel shoreline")
	check(closest_x < float(centre.x) + 23.0,
		"Character crosses actual shoreline and approaches inland island")
	check(highest_y > -2.5 and grounded,
		"Character climbs out of water and reaches island walking level")
	print("SHORE WALK SUMMARY: x=%.2f highest_y=%.2f grounded=%s" % [closest_x, highest_y, str(grounded)])
	game.queue_free()
	await process_frame
	print("SHORE WALK RESULT: %d failures." % failures)
	quit(0 if failures == 0 else 1)
