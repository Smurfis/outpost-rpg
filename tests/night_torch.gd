extends SceneTree
## Day/night transitions, first-night message, persistent offhand crafting,
## shadowless mobile light and save migration in the actual combined game.
const SAVE_TEST = "user://outpost_night_torch_test.json"
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, info: String) -> void:
	if ok:
		print("PASS NIGHT: " + info)
	else:
		failed += 1
		push_error("FAIL NIGHT: " + info)

func _run() -> void:
	if FileAccess.file_exists(SAVE_TEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEST))
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Godot game scene loads")
	if scene == null:
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	game.save_path = SAVE_TEST
	root.add_child(game)
	await process_frame
	var cycle = game.day_night
	check(cycle != null and cycle.is_night() == false, "New adventurer starts in daylight")
	check(cycle.clock_text().length() == 5, "Game uses a 24-hour clock")
	check(game.hud.clock_label != null, "HUD includes day/night clock")
	check(game.recipes.size() == 14, "All old recipes plus new torch are available")
	check(game.equipment_slot("torch") == "offhand", "Torch occupies offhand equipment slot")
	check(not game.hero.torch_light.visible, "Unequipped torch does not emit light")
	var daylight: float = cycle.environment.ambient_light_energy
	cycle.set_phase(0.86)
	check(cycle.is_night(), "Time transition produces night")
	check(cycle.environment.ambient_light_energy < daylight, "Night darkens the world")
	check(game.night_quote_seen, "First nighttime shows the game's light message exactly once")
	check(game.hud.toast_label.text.contains("You are its light"), "Nightfall quote appears in HUD toast")
	cycle.set_phase(0.50)
	check(not cycle.is_night(), "Daylight returns after sunrise")
	check(cycle.environment.ambient_light_energy > 0.7, "Sunrise restores outdoor visibility")
	game.inventory["wood"] = 3
	game.inventory["fiber"] = 2
	game.hero.global_position = game.station_positions["workbench"] + Vector3(0.0, 0.35, 0)
	check(game.begin_craft("torch"), "Existing workbench crafting starts torch recipe")
	game._update_crafting(10.0)
	for i in range(3):
		game.craft_work_cooldown = 0.0
		game.work_craft()
	check(int(game.inventory.get("torch", 0)) == 1, "Torch is crafted exactly once")
	check(game.is_equipped("torch"), "Crafted torch automatically uses offhand")
	check(game.hero.torch_mesh.visible and game.hero.torch_light.visible, "Torch mesh and real light appear in hand")
	check(not game.hero.torch_light.shadow_enabled, "Dynamic torch shadows disabled for Android")
	check(game.hero.torch_light.omni_range >= 7.0, "Torch illuminates walking distance")
	check(int(game.inventory.get("wood", 0)) == 1 and int(game.inventory.get("fiber", 0)) == 1, "Ingredients spent once after successful crafting")
	game.inventory["shield"] = 1
	check(game.equip_item("shield"), "Old shield can replace torch")
	check(not game.hero.torch_mesh.visible, "Equipped shield puts torch away")
	check(game.equip_item("torch"), "Owned torch can replace shield")
	check(not game.hero.shield_mesh.visible, "Offhand exclusivity prevents shield and torch together")
	game.toggle_torch()
	check(not game.hero.torch_light.visible and game.equipment["offhand"] == "", "Quick slot extinguishes/unequips torch")
	game.toggle_torch()
	check(game.hero.torch_light.visible and game.is_equipped("torch"), "Quick slot re-equips lit torch")
	game._save()
	game.queue_free()
	await process_frame
	var reload = scene.instantiate()
	reload.save_path = SAVE_TEST
	root.add_child(reload)
	await process_frame
	check(reload.night_quote_seen, "First-night message flag survives save/reload")
	check(int(reload.inventory.get("torch", 0)) == 1, "Crafted torch persists in existing save format")
	check(reload.is_equipped("torch") and reload.hero.torch_light.visible, "Torch equipment and light restore after restart")
	check(reload.recipes.size() == 14, "Unrelated recipes retained")
	reload.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE_TEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEST))
	print("NIGHT TORCH RESULT: %d failures." % failed)
	quit(0 if failed == 0 else 1)
