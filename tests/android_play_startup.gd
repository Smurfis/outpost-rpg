extends SceneTree
## End-to-end startup regression: title Play -> loading overlay -> complete scene.
## Verify first world frame doesn't synchronously build all 49 Android chunks.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS ANDROID START: " + description)
	else:
		failures += 1
		push_error("FAIL ANDROID START: " + description)

func _run() -> void:
	var title_scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	var loading_scene: PackedScene = load("res://scenes/ui/world_loading.tscn")
	check(title_scene != null and loading_scene != null, "Title and world loader scenes import")
	if title_scene == null or loading_scene == null:
		quit(1)
		return
	var title: Control = title_scene.instantiate() as Control
	root.add_child(title)
	current_scene = title
	await process_frame
	title._launch_game(true)
	await process_frame
	await process_frame
	var loader: Node = current_scene
	check(loader != null and loader.name == "WorldLoading", "Play navigates through the visible loading scene")
	var generation: Node = root.get_node_or_null("Outpost")
	var biome: Node = null
	if generation != null:
		biome = generation.get_node_or_null("VoxelAtmosphere")
		check(biome != null and biome.defer_streaming, "Start-up uses budgeted chunk generation")
		if biome != null:
			check(biome.loaded_chunk_count() < 49, "First Play frame avoids 49 simultaneous terrain colliders")
	var finished: bool = false
	var showed_progress: bool = false
	for frame in range(420):
		await process_frame
		if current_scene != null and current_scene.name == "WorldLoading":
			var display: ProgressBar = current_scene.get("_progress") as ProgressBar
			if display != null and display.value > 10.0 and display.value < 100.0:
				showed_progress = true
		if current_scene != null and current_scene.name == "Outpost":
			finished = true
			break
	check(finished, "World finishes and automatically replaces loading scene")
	if finished:
		var game = current_scene
		var field: Node = game.get_node_or_null("VoxelAtmosphere")
		check(game.hero != null and game.hud != null, "Player and HUD are ready after generation")
		check(field != null and field.initial_generation_complete(), "Initial terrain generation reached completion")
		check(field != null and field.loaded_chunk_count() == 49, "Full 7x7 spawn chunk ring is available before Play hands control back")
		check(not bool(root.get_meta("outpost_defer_world_generation", false)), "Temporary loading generation flag removed")
	check(showed_progress, "Loading screen displays progress during actual chunk building")
	print("ANDROID STARTUP RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
