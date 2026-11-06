extends SceneTree
## Direct Continue, clean responsive loading screen and cancellable world startup.
var failures: int = 0
const SAVE_PATH := "user://outpost_progress_v02.json"

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS TITLE LOAD: " + description)
	else:
		failures += 1
		push_error("FAIL TITLE LOAD: " + description)

func _run() -> void:
	var had_save: bool = FileAccess.file_exists(SAVE_PATH)
	var backup: String = FileAccess.get_file_as_string(SAVE_PATH) if had_save else ""
	var fixture: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	_check(fixture != null, "Temporary save fixture is writable")
	if fixture == null:
		quit(1)
		return
	fixture.store_string('{"version":5,"inventory":{"wood":1}}')
	fixture.close()
	var title_scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_check(title_scene != null, "Approved title scene loads")
	if title_scene == null:
		_restore_save(had_save, backup)
		quit(1)
		return
	var title: Control = title_scene.instantiate() as Control
	root.add_child(title)
	current_scene = title
	await process_frame
	var continue_button: Button = title.get_node_or_null("Artboard/ContinueButton") as Button
	_check(continue_button != null and not continue_button.disabled, "Saved adventure enables Continue")
	var splash: Label = title.get_node_or_null("Artboard/UpdateSplash") as Label
	_check(splash != null and not splash.clip_text, "Rotating text does not hard-clip long messages")
	if splash != null:
		splash.call("set_message", "Craft your own legend!")
		_check(splash.text.contains("\n"), "Long slogan is laid out on two readable lines")
	var crest: Control = title.get_node_or_null("Artboard/OutpostLogo") as Control
	_check(crest != null and crest.material is ShaderMaterial, "Bright crest retains edge-alpha shader")
	if crest != null:
		var shader_source: String = (crest.material as ShaderMaterial).shader.code
		_check(shader_source.contains("COLOR.a") and not shader_source.contains("texture(TEXTURE"), "Crest edge shader does not double-darken source colours")
	title.call("_begin_continue")
	await process_frame
	await process_frame
	var loading: Node = current_scene
	_check(loading != null and loading.name == "WorldLoading", "Continue directly opens loading screen, no second adventure menu")
	if loading != null and loading.name == "WorldLoading":
		var page: Control = loading.get_node_or_null("LoadingArtboard") as Control
		_check(page != null and page.find_child("OutpostLoadingCrest", true, false) != null, "Loading artwork contains the genuine Outpost crest")
		_check(page != null and page.find_child("Landscape", true, false) != null, "Full-screen backdrop uses approved landscape")
		_check(page != null and page.find_child("LoadingStack", true, false) != null, "Single centered stack replaces grey loading box")
		var bar: ProgressBar = loading.get("_progress") as ProgressBar
		_check(bar != null and bar.max_value == 100.0, "Real world-generation progress bar is visible")
		var cancel: Button = loading.get("_cancel_button") as Button
		_check(cancel != null and cancel.text.contains("CANCEL") and not cancel.disabled, "Cancel button is touch-accessible during loading")
		loading.call("_cancel_to_title")
		await process_frame
		await process_frame
		_check(current_scene != null and current_scene.name == "TitleScreen", "Cancel returns to title without entering the game")
		_check(root.get_node_or_null("Outpost") == null, "Cancel removes any partially built world")
		_check(not root.has_meta("outpost_new_adventure"), "Cancel clears launch-only metadata")
	_restore_save(had_save, backup)
	print("TITLE LOAD RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _restore_save(had_save: bool, backup: String) -> void:
	if had_save:
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(backup)
			file.close()
	else:
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
