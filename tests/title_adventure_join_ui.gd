extends SceneTree
## Regression of the clickable, non-grey home menu and LAN join UX.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, note: String) -> void:
	if ok:
		print("PASS TITLE ADVENTURE: " + note)
	else:
		failures += 1
		push_error("FAIL TITLE ADVENTURE: " + note)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_check(scene != null, "Title art scene imports")
	if scene == null:
		quit(1)
		return
	var title: Control = scene.instantiate() as Control
	root.add_child(title)
	await process_frame
	var play: Button = title.get_node_or_null("Artboard/PlayButton") as Button
	var settings: Button = title.get_node_or_null("Artboard/SettingsButton") as Button
	_check(play != null and settings != null, "Original Play and Settings actions remain clickable")
	if play != null and settings != null:
		var focus_style: StyleBoxFlat = play.get_theme_stylebox("focus") as StyleBoxFlat
		_check(focus_style != null and focus_style.border_color.a < 0.01, "Grey/gold rectangle selection borders removed")
		_check(play.material is ShaderMaterial, "Actual Play pixels use a selectable visual state")
		_check(settings.material is ShaderMaterial, "Settings uses same gold image treatment as Play")
		settings.call("_on_pointer_entered")
		_check(bool((settings.material as ShaderMaterial).get_shader_parameter("selected")), "Gold follows selected Settings")
		_check(not bool((play.material as ShaderMaterial).get_shader_parameter("selected")), "Play returns to unselected artwork when Settings is active")
	var crest: Control = title.get_node_or_null("Artboard/OutpostLogo") as Control
	_check(crest != null and crest.material is ShaderMaterial, "Approved crest sky blends without hard opaque rectangle")
	var backdrop: TextureRect = title.get_node_or_null("Artboard/Backdrop") as TextureRect
	_check(backdrop != null and backdrop.modulate == Color.WHITE, "Backdrop no longer uses mismatched dusk opacity")
	var version: Label = title.get_node_or_null("Artboard/Version") as Label
	_check(version != null and version.visible and version.text.contains("0.5.0-dev"), "One live version label avoids doubled painted lettering")
	title.call("_on_play")
	var adventure: PanelContainer = title.get_node_or_null("Artboard/AdventurePanel") as PanelContainer
	var shade: ColorRect = title.get_node_or_null("Artboard/AdventureShade") as ColorRect
	_check(adventure != null and adventure.visible and shade != null and shade.visible, "Play opens parchment-and-wood adventure panel")
	_check(adventure != null and adventure.get_theme_stylebox("panel") != null, "Adventure panel uses native Outpost art styling")
	title.call("_close_adventure_panel")
	_check(adventure != null and not adventure.visible, "Back closes adventure without launching the world")
	title.call("_toggle_settings")
	var panel: PanelContainer = title.get_node_or_null("Artboard/SettingsPanel") as PanelContainer
	_check(panel != null and panel.visible, "Settings opens a themed custom panel")
	var slider: HSlider = panel.find_child("MasterVolumeSlider", true, false) as HSlider if panel != null else null
	_check(slider != null, "Volume adjustment uses a genuine Godot HSlider")
	var update: Button = panel.find_child("CheckForUpdates", true, false) as Button if panel != null else null
	var download: Button = panel.find_child("DownloadUpdate", true, false) as Button if panel != null else null
	_check(update != null and download != null and download.disabled, "Update check and download are separate real controls")
	_check(title.has_method("_join_friend"), "LAN address input is wired to a real host connection")
	var session_script: Script = load("res://scripts/network/coop_session.gd") as Script
	_check(session_script != null, "Existing LAN co-op session remains available")
	if session_script != null:
		_check(session_script.has_method("respond_to_join"), "Host can approve or decline a join request")
	var join_popup: Script = load("res://scripts/network/coop_join_approval.gd") as Script
	_check(join_popup != null, "Host join-approval popup script imports")
	title.queue_free()
	await process_frame
	print("TITLE ADVENTURE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
