extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS BUILDING ROOM: " + detail)
	else:
		failures += 1
		push_error("FAIL BUILDING ROOM: " + detail)

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var building = game.building
	var base := Vector3i(10, 1, 10)
	for x in range(-1, 2):
		for z in range(-1, 2):
			if absi(x) == 1 or absi(z) == 1:
				building._spawn(base + Vector3i(x, 0, z))
	building._spawn(base + Vector3i.UP)
	game.hero.global_position = Vector3(10.5, 0.1, 10.5)
	game.camera.global_position = game.hero.global_position + Vector3(20, 20, 0)
	building._update_interior_cutaway()
	var roof: StaticBody3D = building.blocks[base + Vector3i.UP]
	var foreground: StaticBody3D = building.blocks[base + Vector3i.RIGHT]
	var background: StaticBody3D = building.blocks[base + Vector3i.LEFT]
	check(not roof.get_node("VisibleBlock").visible, "Occupied enclosed room opens its roof")
	check(not foreground.get_node("VisibleBlock").visible and background.get_node("VisibleBlock").visible, "Only camera-facing room wall opens")
	check(foreground.collision_layer == 1 and roof.collision_layer == 1, "Hidden blocks retain physical collision")
	check(roof.get_node("BlockShadow").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "Hidden roof retains its shadow proxy")
	game.camera.global_position = game.hero.global_position + Vector3(-20, 20, 0)
	building._update_interior_cutaway()
	check(foreground.get_node("VisibleBlock").visible and not background.get_node("VisibleBlock").visible, "Camera rotation switches the foreground wall")
	game.hero.global_position = Vector3(20.5, 0.1, 20.5)
	building._update_interior_cutaway()
	check(roof.get_node("VisibleBlock").visible, "Leaving restores the roof")
	game.queue_free()
	await process_frame
	print("BUILDING ROOM RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
