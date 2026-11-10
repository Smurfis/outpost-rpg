extends SceneTree
## Verify the Alpha loading layout is a transparent overlay, with live controls.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS TRANSPARENT LOADING: " + message)
	else:
		failures += 1
		push_error("FAIL TRANSPARENT LOADING: " + message)

func _run() -> void:
	var loader_scene: PackedScene = load("res://scenes/ui/world_loading.tscn")
	_check(loader_scene != null, "World loading scene imports")
	if loader_scene == null:
		quit(1)
		return
	var loader: CanvasLayer = loader_scene.instantiate() as CanvasLayer
	root.add_child(loader)
	var page: Control = loader.get_node_or_null("LoadingArtboard") as Control
	_check(page != null, "Loading canvas is present")
	_check(loader.get_node_or_null("LoadingArtboard/DuskVeil") == null, "No full-screen opaque dusk veil")
	_check(loader.get_node_or_null("LoadingArtboard/LoadingCenter/WorldLoadingFrame") == null, "No opaque modal frame")
	var column: VBoxContainer = loader.get_node_or_null("LoadingArtboard/LoadingCenter/LoadingStack") as VBoxContainer
	_check(column != null, "Freestanding centered loading stack")
	var crest: TextureRect = loader.get_node_or_null("LoadingArtboard/LoadingCenter/LoadingStack/OutpostLoadingCrest") as TextureRect
	_check(crest != null and crest.texture != null, "Separate transparent Outpost logo loads")
	if crest != null and crest.texture != null:
		var image: Image = crest.texture.get_image()
		_check(image != null and image.get_pixel(0, 0).a < 0.05, "Logo corners are alpha transparent")
	var progress: ProgressBar = loader.get_node_or_null("LoadingArtboard/LoadingCenter/LoadingStack/WorldGenerationProgress") as ProgressBar
	_check(progress != null and progress.max_value == 100.0 and not progress.show_percentage, "Live progress bar is preserved")
	var stage: Label = loader.get_node_or_null("LoadingArtboard/LoadingCenter/LoadingStack/WorldGenerationStage") as Label
	var detail: Label = loader.get_node_or_null("LoadingArtboard/LoadingCenter/LoadingStack/ProgressDetail") as Label
	_check(stage != null and detail != null, "Live loading stage and percentage labels remain")
	var cancel: Button = loader.get_node_or_null("LoadingArtboard/LoadingCenter/LoadingStack/CancelLoading") as Button
	_check(cancel != null and cancel.flat and cancel.pressed.is_connected(loader._cancel_to_title), "Accessible, unboxed return-to-title action remains wired")
	print("TRANSPARENT LOADING RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
