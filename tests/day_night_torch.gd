extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS NIGHT: " + label)
	else:
		failures += 1
		push_error("FAIL NIGHT: " + label)
func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "Game scene parses")
	if packed == null:
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	check(game.day_night_enabled, "Clock and sky are enabled")
	check(game.recipes.size() == 14, "Torch recipe extends without removing old crafts")
	check(str(game._recipe_by_id("torch").get("station", "")) == "workbench", "Torch crafted at existing workbench")
	check(absf(game.day_phase() - 0.25) < 0.01, "World starts around midday")
	check(absf(game.sun_light.rotation_degrees.x + 90.0) < 1.0, "Midday sun points down onto terrain")
	var day_energy: float = game.sun_light.light_energy
	var day_ambient: float = game.sky_environment.ambient_light_energy
	game.world_time = game.day_length_seconds * 0.5
	game._update_day_night()
	check(game.is_night(), "Clock reaches night")
	check(game.sun_light.rotation_degrees.x > 80.0, "Night sun travels below horizon")
	check(game.sun_light.light_energy < day_energy * 0.40, "Night reduces directional illumination")
	check(game.sky_environment.ambient_light_energy < day_ambient * 0.5, "Ambient night light drops")
	check(game.sky_material != null, "Pixel sky palette remains controllable")
	check(game.hud.world_clock.text.begins_with("NIGHT"), "Small HUD clock shows nighttime")
	check(game.hero.torch_light != null and not game.hero.torch_pivot.visible, "Torch starts inactive with no light")
	game.inventory["torch"] = 1
	game.inventory["shield"] = 1
	check(game.equip_item("torch"), "Can equip owned torch")
	check(game.is_equipped("torch") and game.hero.torch_pivot.visible and game.hero.torch_light.visible, "Offhand torch emits light")
	check(not game.is_equipped("shield") and not game.hero.shield_mesh.visible, "Torch cannot stack with shield defence")
	check(not game.hero.torch_light.shadow_enabled, "Torch uses mobile-friendly shadowless light")
	check(game.equip_item("shield"), "Shield can replace equipped torch")
	check(game.is_equipped("shield") and not game.hero.torch_pivot.visible and game.hero.shield_mesh.visible, "Offhand choice mutually exclusive")
	check(game.equip_item("shield"), "Second shield tap removes it")
	check(not game.hero.torch_pivot.visible and not game.hero.shield_mesh.visible, "Unequipping restores empty offhand")
	game.world_time = game.day_length_seconds * 0.25
	game._update_day_night()
	check(game.hud.world_clock.text.begins_with("DAY"), "Dawn/day cycle returns")
	game.queue_free()
	await process_frame
	print("DAY NIGHT RESULT: %d failures." % failures)
	quit(0 if failures == 0 else 1)
