extends SceneTree
## Android UI regression: authentic action context, wood/bronze medallions,
## touch controls preserved, and radial timers tied to actual game state.
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ACTION MEDALLIONS: " + message)
	else:
		failures += 1
		push_error("FAIL ACTION MEDALLIONS: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main game scene loads")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	game.save_path = "user://action_medallions_test.json"
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var smart: Button = hud.smart_button
	check(smart != null, "Existing smart interact button remains")
	check(smart.get_theme_stylebox("normal") is StyleBoxTexture, "Wooden gold normal medallion is an independent image")
	check(smart.get_theme_stylebox("disabled") is StyleBoxTexture, "Muted grey inactive medallion exists")
	check(smart.get_node_or_null("CooldownRing") != null, "Interactive radial timer is present")
	check(not smart.disabled, "Hold-to-select-tools stays accessible, even at idle")
	var icon: TextureRect = smart.get_node("ActionIcon") as TextureRect
	game.hero.global_position = Vector3(90.0, 4.0, 90.0)
	check(str(game.smart_context().get("icon")) == "hand", "Idle uses only a glove, never the sword")
	var wood_found: bool = false
	var stone_found: bool = false
	for resource in get_nodes_in_group("resources"):
		if not resource.active:
			continue
		var desired: String = "axe" if str(resource.kind) == "wood" else "pickaxe" if str(resource.kind) in ["stone", "iron", "coal"] else ""
		if desired == "":
			continue
		game.hero.global_position = resource.global_position + Vector3(0.0, 0.35, 0.0)
		var active: Dictionary = game.smart_context()
		if str(active.get("icon")) == desired:
			wood_found = wood_found or desired == "axe"
			stone_found = stone_found or desired == "pickaxe"
			hud._refresh_smart_button()
			check(icon.texture != null and icon.texture.resource_path.ends_with(desired + ".svg"), desired + " HUD art matches actual nearby resource")
		if wood_found and stone_found:
			break
	check(wood_found, "Wood shows axe rather than generic gather icon")
	check(stone_found, "Ore and rocks show pickaxe rather than generic gather icon")
	var combat_found: bool = false
	for enemy in get_nodes_in_group("enemies"):
		if not enemy.alive:
			continue
		game.hero.global_position = enemy.global_position + Vector3(0.0, 0.35, 0.0)
		game.active_quick_tool = "training_blade"
		if str(game.smart_context().get("kind")) == "attack":
			combat_found = str(game.smart_context().get("icon")) == "sword"
			break
	check(combat_found, "Nearby enemy shows sword")
	if wood_found or stone_found:
		game.gather_delay = 0.25
		hud._refresh_smart_button()
		var ring: Control = smart.get_node("CooldownRing") as Control
		check(float(ring.get("fraction")) > 0.0, "Smart action radial uses current gathering recovery")
	var potion: Button = hud.quick_buttons["potion"] as Button
	check(potion.get_theme_stylebox("normal") is StyleBoxTexture, "Potion uses the same golden wood rim")
	game.inventory["tonic"] = 2
	game.quick_slots["potion"] = "tonic"
	game.hero.health = 30.0
	check(game.use_quick_consumable("potion"), "Tonic heals and starts a real use cooldown")
	check(not game.use_quick_consumable("potion"), "Cooldown prevents repeated potion consumption")
	hud._refresh_quick_radials()
	var potion_ring: Control = potion.get_node("CooldownRing") as Control
	check(potion.disabled and float(potion_ring.get("fraction")) > 0.0, "Potion displays grey inactive state and radial timer")
	for key in ["skill_1", "skill_2", "skill_3", "consumable"]:
		var holder: Button = hud.quick_buttons[key] as Button
		check(holder.get_node_or_null("CooldownRing") != null, key + " uses the shared radial system")
	game.queue_free()
	await process_frame
	print("ACTION MEDALLIONS RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
