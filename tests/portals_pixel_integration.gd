extends SceneTree
## Dungeons restored into voxel/title/pixel-UI build WITHOUT copying old HUD.
var failures: int = 0
const TEST_CLEAR_PATH = "user://portals_pixel_integration_test.json"

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS PORTAL: " + description)
	else:
		failures += 1
		push_error("FAIL PORTAL: " + description)

func _run() -> void:
	if FileAccess.file_exists(TEST_CLEAR_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CLEAR_PATH))
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Combined game scene loads")
	if scene == null:
		quit(1)
		return
	get_tree().root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	var manager = game.get_node("Dungeons")
	manager.save_path = TEST_CLEAR_PATH
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.hud != null and game.menu != null, "PR #9 HUD and crafting menu remain present")
	check(game.hud.root.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Restoration keeps pixel-art PNG HUD")
	check(bool(game.voxel_art_enabled), "Voxel world remains enabled")
	check(manager.entrances.size() == 5, "Five rarity-tier portals returned to overworld")
	check(manager.chunks.size() == 5, "Procedural portal chunk registration restored")
	var portal = manager.entrances.get("preview_rare:0")
	check(portal != null, "Rare dungeon entrance exists")
	if portal == null:
		quit(1)
		return
	game.hero.global_position = portal.global_position + Vector3(6.0, 0.35, 0)
	manager._on_portal_selected(portal)
	check(not game.hero.interaction_locked and not game.hero.interaction_moving, "Distant tap does not hijack joystick")
	game.hero.global_position = portal.global_position + Vector3(1.0, 0.35, 0)
	manager._on_portal_selected(portal)
	check(manager.dimmer.visible and game.hero.interaction_locked, "Near entrance shows confirm and freezes control only for dialog")
	manager._cancel_dialog()
	check(not manager.dimmer.visible and not game.hero.interaction_locked, "Cancel restores movement")
	manager._on_portal_selected(portal)
	manager._enter_confirmed()
	check(manager.active_instance != null, "Dungeon scene is generated on enter")
	check(not game.hero.interaction_locked, "Dungeon entry restores joystick control")
	if manager.active_instance != null:
		var instance = manager.active_instance
		var layout = load("res://scripts/dungeons/dungeon_layout.gd")
		check(layout.validate(instance.layout), "Generated dungeon graph is connected")
		check(instance.floor_root.get_child_count() > 30, "Modular dungeon floor and collision geometry built")
		check(game.hero.global_position.distance_to(instance.hero_spawn_point()) < 0.3, "Player enters in correct dungeon room")
		manager._leave_pressed()
		check(manager.active_instance == null, "Leave returns to overworld")
		check(not game.hero.interaction_locked, "Leaving never traps movement")
		check(manager.entrances.has("preview_rare:0"), "Abandoned dungeon remains retryable")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(TEST_CLEAR_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CLEAR_PATH))
	print("PORTAL INTEGRATION RESULT: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
