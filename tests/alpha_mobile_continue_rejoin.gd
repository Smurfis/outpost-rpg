extends SceneTree
## Regression: desktop controls must not replace the Android HUD, and a
## save/Continue cycle must not leave an uncontrollable second player.
const MAIN = preload("res://scenes/main.tscn")
const PLAYER = preload("res://scripts/player.gd")
const SAVE_PATH = "user://alpha-mobile-continue-regression.json"
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, description: String) -> void:
	if ok:
		print("PASS MOBILE REJOIN: " + description)
	else:
		failures += 1
		push_error("FAIL MOBILE REJOIN: " + description)

func _check_characters(game: Node, phase: String) -> void:
	var playable_count: int = 0
	for child in game.get_children():
		if child.get_script() == PLAYER:
			playable_count += 1
	verify(playable_count == 1 and game.hero != null, phase + ": exactly one real player")
	verify(not game.coop.online() and game.coop.remote_avatars.is_empty(), phase + ": no stale multiplayer avatars")
	var guide: Node3D = game.get_node_or_null("CampGuideNPC") as Node3D
	verify(guide != null and guide != game.hero, phase + ": the guide is a separate NPC")
	if guide != null:
		verify(guide.get_node_or_null("GuideOutfit/GuideWideBrimHat") != null
			and guide.get_node_or_null("GuideOutfit/NPCNameplate") != null,
			phase + ": stationary guide has a recognizable hat and NPC nameplate")

func _check_touch_hud(game: Node, phase: String) -> void:
	game.hud.floating_joystick_enabled = false
	game.hud._position_stick()
	verify(not game.controls.desktop and game.hud.joystick.visible, phase + ": touch joystick shown")
	var interact: Rect2 = game.hud.smart_button.get_global_rect()
	var first: Rect2 = game.hud.quick_buttons.skill_1.get_global_rect()
	var third: Rect2 = game.hud.quick_buttons.skill_3.get_global_rect()
	verify(interact.size.x >= 110.0 and first.get_center().y < third.get_center().y,
		phase + ": original large Interact and curved ability positions")
	verify(game.hud.focus_button == null or not game.hud.focus_button.visible,
		phase + ": PC target button hidden")

func _run() -> void:
	root.set_meta("outpost_input_mode", "touch")
	root.set_meta("outpost_new_adventure", true)
	var first = MAIN.instantiate()
	first.save_path = SAVE_PATH
	root.add_child(first)
	await process_frame
	_check_characters(first, "First game")
	_check_touch_hud(first, "First game")
	first.inventory["wood"] = 13
	first._save() # Same save action used by Save & Return to Title.
	first.queue_free()
	await process_frame
	await process_frame
	verify(FileAccess.file_exists(SAVE_PATH), "Leave writes a valid save file")
	var continued = MAIN.instantiate()
	continued.save_path = SAVE_PATH
	root.add_child(continued) # No fresh-start flag: _ready follows Continue's _load path.
	await process_frame
	verify(int(continued.inventory.get("wood", 0)) == 13, "Continue restores stored progress")
	_check_characters(continued, "Continued game")
	_check_touch_hud(continued, "Continued game")
	continued.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("MOBILE REJOIN RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
