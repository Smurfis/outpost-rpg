extends SceneTree
## Run with: godot --headless --path . --script res://tests/company_splash_3d_smoke.gd
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS FIVE STAR: ", message)
	else:
		failures += 1
		push_error("FAIL FIVE STAR: " + message)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/ui/company_splash.tscn")
	_check(packed != null, "Cinematic studio intro imports")
	if packed == null:
		quit(1)
		return
	var intro: Control = packed.instantiate() as Control
	intro.set("auto_advance", false)
	root.add_child(intro)
	await process_frame
	var world: Node = intro.get_node_or_null("Stage/Viewport/World")
	_check(world != null, "Native 3D world stage exists")
	if world != null:
		_check(int(world.call("get_star_count")) == 5, "Exactly five independent 3D stars")
		_check(world.get_node_or_null("GoldenPortal") != null, "Reusable portal visual exists")
		_check(world.get_node_or_null("IdentCamera") != null, "Perspective camera exists")
		world.call("seek", 6.0)
		_check(float(world.call("get_portal_progress")) >= 0.99, "Portal animation reaches final pose")
		var star: Node3D = world.get_node_or_null("FlyingStar_1") as Node3D
		_check(star != null and star.position.distance_to(Vector3(0.0, -2.4, 0.62)) < 0.4,
			"Top-down ring positioning follows deterministic animation")
	_check((intro.get_node("StudioName") as Label).text == "FIVE STAR", "Studio wordmark remains live text")
	_check((intro.get_node("Hint") as Label).text.contains("skip"), "Intro remains skippable")
	intro.queue_free()
	await process_frame
	print("FIVE STAR IDENT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
