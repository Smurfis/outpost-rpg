extends SceneTree
## Real alpha regression: floor cone/line geometry is also the exact damage
## region, and moving clear during a guardian's wind-up avoids the heavy hit.
const MARKER = preload("res://scripts/vfx/attack_telegraph.gd")
const GUARDIAN = preload("res://scripts/dungeons/dungeon_guardian.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ALPHA TELEGRAPHS: " + message)
	else:
		failures += 1
		push_error("FAIL ALPHA TELEGRAPHS: " + message)

func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var cone = MARKER.new()
	host.add_child(cone)
	cone.global_position = Vector3(0.0, 0.06, 0.0)
	cone.configure("cone", Vector3.FORWARD, 4.0, 0.95)
	check(cone.contains_position(Vector3(0, 0, -3)), "Cone hits directly ahead")
	check(not cone.contains_position(Vector3(3, 0, -1)), "Cone leaves safe ground on the side")
	check(not cone.contains_position(Vector3(0, 0, -5)), "Cone has a finite radius")
	check(cone.mesh != null and cone.mesh.get_surface_count() == 1, "Cone renders a red floor mesh")
	var line = MARKER.new()
	host.add_child(line)
	line.global_position = Vector3(0, 0.06, 0)
	line.configure("line", Vector3.FORWARD, 5.0, 1.1)
	check(line.contains_position(Vector3(0.4, 0, -4)), "Line hits along its narrow centre")
	check(not line.contains_position(Vector3(1.5, 0, -4)), "Line can be sidestepped")
	check(not line.contains_position(Vector3(0, 0, -5.5)), "Line has a finite length")
	line.queue_free()
	cone.queue_free()
	host.queue_free()
	await process_frame

	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Live Outpost scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	game.save_path = "user://alpha_telegraph_test.json"
	root.add_child(game)
	await process_frame
	var dungeon := Node3D.new()
	game.add_child(dungeon)
	game.hero.global_position = Vector3(55.0, 0.22, 55.0)
	var goblin = GUARDIAN.new()
	dungeon.add_child(goblin)
	goblin.setup(game.hero, dungeon, 0, game.hero.global_position + Vector3(0, 0, -2.8), "goblin")
	goblin._begin_heavy_attack(game.hero.global_position - goblin.global_position)
	check(goblin.heavy_shape == "cone" and goblin.heavy_charge_left > 0.0, "Goblin commits a charged cone")
	check(is_instance_valid(goblin.heavy_telegraph), "Warning mesh is shown before damage")
	var hp_before: float = game.hero.health
	game.hero.global_position = goblin.global_position + Vector3(4.0, 0.0, 0.0)
	goblin._finish_heavy_attack()
	check(is_equal_approx(game.hero.health, hp_before), "Dodging outside the red cone prevents damage")
	game.hero.global_position = goblin.global_position + Vector3(0, 0, 2.0)
	goblin._begin_heavy_attack(game.hero.global_position - goblin.global_position)
	goblin._finish_heavy_attack()
	check(game.hero.health < hp_before, "Standing in the marked cone takes the heavy hit")
	goblin.queue_free()
	var skeleton = GUARDIAN.new()
	dungeon.add_child(skeleton)
	skeleton.setup(game.hero, dungeon, 0, game.hero.global_position + Vector3(0, 0, -2.8), "skeleton")
	skeleton._begin_heavy_attack(game.hero.global_position - skeleton.global_position)
	check(skeleton.heavy_shape == "line", "Skeleton uses a red line thrust instead of a cone")
	skeleton._cancel_heavy_attack()
	skeleton.queue_free()
	dungeon.queue_free()
	game.queue_free()
	await process_frame
	print("ALPHA TELEGRAPHS RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
