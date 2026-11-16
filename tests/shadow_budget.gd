extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, detail: String) -> void:
	if value:
		print("PASS SHADOW BUDGET: " + detail)
	else:
		failures += 1
		push_error("FAIL SHADOW BUDGET: " + detail)

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.equipment["offhand"] = "torch"
	game.shadow_light_budget = 0
	game._update_shadow_budget()
	check(not game.day_night.sunlight.shadow_enabled and not game.hero.torch_light.shadow_enabled, "Zero budget disables both shadows")
	game.shadow_light_budget = 1
	game.day_night.interior_blend = 1.0
	game._update_shadow_budget()
	check(not game.day_night.sunlight.shadow_enabled and game.hero.torch_light.shadow_enabled, "One indoor shadow favours the torch")
	game.day_night.interior_blend = 0.0
	game._update_shadow_budget()
	check(game.day_night.sunlight.shadow_enabled and not game.hero.torch_light.shadow_enabled, "One outdoor shadow favours sunlight")
	game.shadow_light_budget = 2
	game._update_shadow_budget()
	check(game.day_night.sunlight.shadow_enabled and game.hero.torch_light.shadow_enabled, "Two-light budget enables both")
	game.hud._cycle_shadow_budget()
	check(game.shadow_light_budget == 0 and "0" in game.hud.shadow_budget_button.text, "Settings button cycles budget")
	game.queue_free()
	await process_frame
	print("SHADOW BUDGET RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
