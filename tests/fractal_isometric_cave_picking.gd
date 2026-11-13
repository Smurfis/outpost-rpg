extends SceneTree
## Live isometric camera + click ray + AStar3D cave-floor regression. Unlike
## shader-only smoke tests, this invokes the same picker and path planner as PC.
const PICKER = preload("res://scripts/interaction/world_picker.gd")
const PATH = preload("res://scripts/navigation/crafting_station_path.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ISO PICK: " + message)
	else:
		failures += 1
		push_error("FAIL ISO PICK: " + message)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	root.set_meta("outpost_input_mode", "desktop")
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	await physics_frame
	var streamer = game.terrain_surface.archipelago
	var routes: Array = streamer.terrain.caves.routes
	check(routes.size() == 3, "Isometric test uses the three real island cave routes")
	for index in range(routes.size()):
		var route: Array = routes[index]
		var first: Vector3i = route[mini(13, route.size() - 1)]
		var destination: Vector3i = route[mini(16, route.size() - 1)]
		var start := Vector3(float(first.x) + 0.5, float(first.y) + 0.08, float(first.z) + 0.5)
		var goal := Vector3(float(destination.x) + 0.5, float(destination.y) + 0.08, float(destination.z) + 0.5)
		game.hero.stop_interaction_move()
		game.hero.global_position = start
		game.hero.velocity = Vector3.ZERO
		streamer._queue_near(start)
		for i in range(58):
			streamer._build_pending()
		game.camera_focus_smooth = Vector3.ZERO
		game._camera(0.3)
		streamer._update_cutaway(game, start)
		check(streamer._cutaway_material.get_shader_parameter("island_cutaway_enabled") == true,
			"Island %d uses cutaway only inside a real cave" % [index + 1])
		var near_floor: Vector3 = goal + Vector3(0.0, 1.35, 0.0)
		var ray = PhysicsRayQueryParameters3D.create(
			near_floor, goal + Vector3(0.0, -1.6, 0.0), 1, [game.hero.get_rid()])
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and (hit.get("normal", Vector3.ZERO) as Vector3).y > 0.7
			and absf((hit.get("position", Vector3.INF) as Vector3).y - float(destination.y)) < 0.5,
			"Island %d true cave floor is intact in physics" % [index + 1])
		var path: PackedVector3Array = PATH.plan_world(game, start, goal)
		check(not path.is_empty(),
			"Island %d planner uses walkable cave floor, not overhead mountain roof" % [index + 1])
		var screen: Vector2 = game.camera.unproject_position(goal)
		var click: Dictionary = PICKER.resolve(game, screen)
		print("ISO PICK TRACE: island=%d screen=%s hit=%s hero=%s cave_floor=%d" % [
			index + 1, str(screen), str(click), str(start), destination.y])
		check(not click.is_empty() and (click.get("target") != null or
			((click.get("normal", Vector3.ZERO) as Vector3).y > 0.7 and
			absf((click.get("position", Vector3.INF) as Vector3).y - float(destination.y)) < 1.1)),
			"Island %d screen-space click resolves cave level instead of an occluding wall/roof" % [index + 1])
	game.queue_free()
	await process_frame
	print("ISOMETRIC PICK RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
