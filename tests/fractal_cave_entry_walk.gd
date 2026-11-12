extends SceneTree
## Godot physics integration: real avatar enters each cave from the hillside.
## This catches entrances that look open but are blocked by collision or steps.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS CAVE ENTRY: " + detail)
	else:
		failures += 1
		push_error("FAIL CAVE ENTRY: " + detail)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	var streamer = game.terrain_surface.archipelago
	var world = streamer.terrain
	check(world.caves.routes.size() == 3, "Each remote island has a cave")
	for index in range(world.caves.routes.size()):
		var route: Array = world.caves.routes[index]
		var entrance: Vector3i = route[0]
		var inside: Vector3i = route[mini(12, route.size() - 1)]
		var x: float = float(entrance.x) + 4.5
		var z: float = float(entrance.z) + 0.5
		var outside_floor: float = float(world.height_at(floori(x), floori(z)))
		var start := Vector3(x, outside_floor + 0.05, z)
		var goal := Vector3(float(inside.x) + 0.5, float(inside.y), float(inside.z) + 0.5)
		game.controls.cancel()
		game.hero.stop_interaction_move()
		game.hero.global_position = start
		game.hero.velocity = Vector3.ZERO
		game.hero.knockback_velocity = Vector3.ZERO
		streamer._queue_near(start)
		for _i in range(65):
			streamer._build_pending()
		game.hero.move_to_interaction(goal)
		var entered: bool = false
		var frozen: bool = false
		var last_x: float = start.x
		var no_progress: int = 0
		for frame in range(520):
			await physics_frame
			var at: Vector3 = game.hero.global_position
			if at.x <= float(entrance.x) - 7.0 and world.caves.has_cave(floori(at.x), floori(at.z)):
				entered = true
				break
			if at.x < last_x - 0.004:
				no_progress = 0
			else:
				no_progress += 1
			last_x = at.x
			if no_progress > 95:
				frozen = true
				print("CAVE ENTRY STALL: island=%d frame=%d position=%s target=%s floor=%s wall=%s velocity=%s" % [
					index + 1, frame, str(at), str(goal), str(game.hero.is_on_floor()), str(game.hero.is_on_wall()), str(game.hero.velocity)])
				for ox in range(-4, 5):
					var xx: int = floori(at.x) + ox
					print("CAVE APPROACH: x=%d terrain=%d carve_floor=%d roof=%d" % [
						xx, world.height_at(xx, floori(at.z)), world.caves.floor_at(xx, floori(at.z)),
						world.caves.cover_height_at(xx, floori(at.z))])
				break
		check(not frozen, "Island %d cave has no impassable collision snag" % (index + 1))
		check(entered, "Island %d avatar walks in from the hillside and reaches tunnel depth" % (index + 1))
	game.queue_free()
	await process_frame
	print("CAVE ENTRY RESULT: %d failures." % failures)
	quit(0 if failures == 0 else 1)
