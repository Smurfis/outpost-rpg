extends SceneTree
## Regression: each generated doorway link has a walkable floor across the
## between-room seam and both side parapets, not just a visually placed tile.
const INSTANCE = preload("res://scripts/dungeons/dungeon_instance.gd")
var failures: int = 0
var sampled_passages: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS SEAMS: " + message)
	else:
		failures += 1
		push_error("FAIL SEAMS: " + message)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		check(false, "Main scene can be loaded")
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var manager = game.get_node("Dungeons")
	check(manager.entrances.size() == 5, "Portal system stays online")
	var tiers: Array[int] = [0, 2, 4]
	var seam_samples: int = 0
	var barrier_samples: int = 0
	for tier in tiers:
		var dungeon = INSTANCE.new()
		game.add_child(dungeon)
		dungeon.position = Vector3(2000.0 + float(tier) * 400.0, 0.0, 2500.0)
		dungeon.setup("collision_sample_%d" % tier, tier, game.hero, 1)
		await physics_frame
		await physics_frame
		var rooms: Array = dungeon.layout["rooms"]
		var edges: Array = dungeon.layout["edges"]
		check(not edges.is_empty(), "Tier %d has connected passages" % tier)
		for edge in edges:
			var first: Vector2i = rooms[edge.x]["grid"]
			var second: Vector2i = rooms[edge.y]["grid"]
			var center: Vector3 = dungeon.global_position + Vector3(float(first.x + second.x) * INSTANCE.STEP * 0.5, 0, float(first.y + second.y) * INSTANCE.STEP * 0.5)
			var along_x: bool = first.x != second.x
			var cross: Vector3 = Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
			var tangent: Vector3 = Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
			# Test inside the gap between doorway wall planes, where the bug
			# was observed. Sample left/centre/right and both doorway lips.
			for step_offset in [-0.30, 0.0, 0.30]:
				for cross_offset in [-2.2, -1.4, -0.8, 0.0, 0.8, 1.4, 2.2]:
					var point: Vector3 = center + tangent * float(step_offset) + cross * float(cross_offset)
					var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.42, point + Vector3.DOWN * 1.9, 1)
					var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
					if hit.is_empty() or not dungeon.floor_root.is_ancestor_of(hit["collider"]):
						check(false, "No safe connector floor tier %d position %.2f / %.2f" % [tier, float(step_offset), float(cross_offset)])
					else:
						var at: Vector3 = hit["position"]
						if absf(at.y - (dungeon.global_position.y - 0.06)) > 0.3:
							check(false, "Uneven/obstructed floor tier %d at %.2f / %.2f" % [tier, float(step_offset), float(cross_offset)])
					seam_samples += 1
			# The side wall should physically stop diagonal movement even
			# between the two doorframes.
			for sign_value in [-1.0, 1.0]:
				var start: Vector3 = center + cross * sign_value * 1.4 + Vector3.UP * 0.8
				var end: Vector3 = center + cross * sign_value * 4.0 + Vector3.UP * 0.8
				var wall_ray := PhysicsRayQueryParameters3D.create(start, end, 1)
				var barrier: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(wall_ray)
				if barrier.is_empty() or not dungeon.floor_root.is_ancestor_of(barrier["collider"]):
					check(false, "Missing side barrier tier %d side %d" % [tier, int(sign_value)])
				barrier_samples += 1
			sampled_passages += 1
		dungeon.queue_free()
		await process_frame
	check(seam_samples > 100, "Measured %d actual floor collision points across %d passages" % [seam_samples, sampled_passages])
	check(barrier_samples >= 6, "Checked %d parapet collision rays" % barrier_samples)
	game.queue_free()
	await process_frame
	print("DUNGEON SEAMS RESULT: %d failures, %d floor samples, %d barrier samples." % [failures, seam_samples, barrier_samples])
	quit(0 if failures == 0 else 1)
