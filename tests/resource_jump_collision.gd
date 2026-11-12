extends SceneTree

const RESOURCE = preload("res://scripts/resource_node.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("RESOURCE COLLISION FAIL: " + label)
	else:
		print("RESOURCE COLLISION PASS: " + label)

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var hero = game.hero
	hero.set_physics_process(false)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(30, 1, 30)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	game.add_child(floor_body)
	floor_body.position = Vector3(2000, -0.5, 2000)
	for kind in ["iron", "clay", "wood"]:
		var resource = RESOURCE.new()
		game.add_child(resource)
		resource.position = Vector3(2000, 0, 2000)
		resource.setup(kind, 3)
		var collider: CollisionShape3D = resource.resource_body.get_child(0)
		var top: float = collider.global_position.y + collider.shape.size.y * 0.5
		var width: float = collider.shape.size.x
		await physics_frame
		await physics_frame
		var start := Transform3D(Basis.IDENTITY, Vector3(collider.global_position.x - width * 0.5 - 1.0, 0.1, collider.global_position.z))
		check(hero.test_move(start, Vector3(width + 2.0, 0, 0)), kind + " blocks walking through its sides")
		check(not hero.test_move(start.translated(Vector3.UP * (top + 0.2)), Vector3(width + 2.0, 0, 0)), kind + " permits crossing when feet clear its top")
		hero.global_transform = start
		hero.velocity = Vector3.ZERO
		game._camera(1.0)
		var right: Vector3 = game.camera.global_transform.basis.x
		var forward: Vector3 = -game.camera.global_transform.basis.z
		right.y = 0
		forward.y = 0
		var walk := Vector2(Vector3.RIGHT.dot(right.normalized()), -Vector3.RIGHT.dot(forward.normalized()))
		var highest: float = hero.position.y
		for frame in range(100):
			await physics_frame
			game.hud.move_vector = walk
			hero._physics_process(1.0 / 60.0)
			highest = maxf(highest, hero.position.y)
		game.hud.move_vector = Vector2.ZERO
		if kind == "wood":
			check(highest < 0.2 and hero.position.x < collider.global_position.x, "Walking cannot auto-hop a full-height tree")
		else:
			check(highest >= top - 0.1 and hero.position.x > collider.global_position.x + width * 0.5, "Walking automatically hops onto and across " + kind)
		hero.position = Vector3(collider.global_position.x, top + 0.5, collider.global_position.z)
		for frame in range(40):
			await physics_frame
			hero.velocity = Vector3(0, -3, 0)
			hero.move_and_slide()
		check(hero.is_on_floor() and absf(hero.position.y - top) < 0.1, kind + " supports the actual player capsule on top")
		var fixed_transform: Transform3D = collider.global_transform
		resource.harvest()
		await process_frame
		check(collider.global_transform.is_equal_approx(fixed_transform), "Harvest feedback does not move " + kind + " collision")
		while resource.active:
			resource.harvest()
		await physics_frame
		await physics_frame
		check(resource.resource_body.collision_layer == 0, "Depleted " + kind + " leaves no invisible obstacle")
		resource._process(resource.recovery + 1.0)
		await physics_frame
		await physics_frame
		check(resource.resource_body.collision_layer == 1, "Respawn restores " + kind + " collision")
		resource.queue_free()
		await process_frame
	var custom = RESOURCE.new()
	custom.collision_height = 2.5
	custom.collision_width = 1.25
	game.add_child(custom)
	custom.position = Vector3(2000, 0, 2000)
	custom.setup("iron")
	check(custom.resource_body.get_child(0).shape.size.is_equal_approx(Vector3(1.25, 2.5, 1.25)), "Explicit width and height override model defaults")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
