extends SceneTree

const STREAMER = preload("res://scripts/world/island_archipelago.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, detail: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL INTERIOR: " + detail)
	else:
		print("PASS INTERIOR: " + detail)

func _run() -> void:
	var island = STREAMER.new()
	root.add_child(island)
	island.setup(64012)
	var cave = island.terrain.caves
	# A small connected chamber, an inaccessible neighbour, and a steep
	# one-block-separated wall exercise connectivity without terrain changes.
	cave.floors.clear()
	for x in range(5):
		for z in range(5):
			cave.floors[Vector2i(x, z)] = 2
	cave.floors[Vector2i(6, 2)] = 2
	cave.floors[Vector2i(5, 1)] = 7
	island._update_reveal_mask(Vector2i(2, 2))
	check(island._reveal_cells.size() == 25, "Entire connected room is revealed")
	check(not island._reveal_cells.has(Vector2i(6, 2)), "Disconnected neighbouring space remains concealed")
	check(not island._reveal_cells.has(Vector2i(5, 1)), "Unreachable height does not leak the reveal")
	check(island._reveal_texture != null, "Room mask is supplied to the cave shader")
	island._cutaway_focus = Vector3(2.5, 3, 2.5)
	check(island._is_cut_overhead_block(Vector3(4.5, 6, 4.5), Vector3.UP), "Picking ignores revealed roof away from the player")
	check(not island._is_cut_overhead_block(Vector3(6.5, 6, 2.5), Vector3.UP), "Picking retains disconnected roof")
	check(not island._is_cut_overhead_block(Vector3(4.5, 6, 4.5), Vector3.RIGHT), "Walls remain collidable for picking")
	var body := StaticBody3D.new()
	body.set_meta("island_roof_shape_index", 1)
	island._cutaway_material.set_shader_parameter("island_cutaway_enabled", true)
	island._cutaway_eye = island._cutaway_focus + Vector3(10, 10, 0)
	var wall := {"collider": body, "shape": 0, "position": Vector3(3.9, 5, 2.5), "normal": Vector3.RIGHT}
	check(island.cutaway_hides_hit(wall), "Camera-facing wall at the revealed room is pick-through")
	island._cutaway_eye = island._cutaway_focus + Vector3(-10, 10, 0)
	check(not island.cutaway_hides_hit(wall), "Rotating the camera restores the far-side wall")
	body.free()
	island.queue_free()
	await process_frame
	print("INTERIOR REVEAL RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
