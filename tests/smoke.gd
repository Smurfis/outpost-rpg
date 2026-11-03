extends SceneTree
## Automated gameplay test for Outpost v0.4.0 (Godot 4.7.2).
var failures: int = 0

func _initialize() -> void:
	call_deferred("_test_game")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _test_game() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene loads")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	check(game.hero != null and game.menu != null and game.hud != null, "Player and visual interface exist")
	check(game.hero.global_position.distance_to(Vector3(0, 0.35, 0)) < 0.7, "Hero remains at starting outpost")
	check(game.recipes.size() == 13, "13 recipes load from JSON")
	check(game.stations.size() == 4, "Four interactive 3D stations exist")
	var types: Dictionary = {}
	for node in get_nodes_in_group("resources"):
		types[node.kind] = true
	check(types.size() == 10, "Ten visually distinct resource types spawn")
	for item in ["iron", "coal", "clay", "herbs", "mushrooms", "reeds"]:
		check(types.has(item), "%s resource spawns" % item)
	game.hero.global_position = Vector3(0, 0.35, 0)
	var before: int = int(game.inventory.get("wood", 0))
	var before_toast: String = game.hud.toast_label.text
	game.gather()
	check(int(game.inventory.get("wood", 0)) == before, "Empty gathering awards no item")
	check(game.hud.toast_label.text == before_toast, "Empty gathering produces no popup spam")
	var target = null
	for resource in get_nodes_in_group("resources"):
		if resource.kind == "wood":
			target = resource
			break
	check(target != null, "A pine tree is available")
	if target != null:
		game.hero.global_position = target.global_position + Vector3(1, 0.35, 0)
		game.gather()
		check(int(game.inventory.get("wood", 0)) == before + 1, "Gathering awards wood")
		check(target.hits_left == 2, "Harvesting reduces node durability")
	game.hero.global_position = game.station_positions["workbench"] + Vector3(0, 0.35, 0)
	game.inventory["wood"] = 7
	game.inventory["stone"] = 5
	check(game.can_craft("spear"), "Spear recipe affordable at workbench")
	check(not game.can_craft("iron_ingot"), "Forge recipe blocked at workbench")
	game.show_crafting()
	check(game.menu.visible and game.menu.current_page == "craft", "Crafting screen opens")
	check(game.menu.selected_station == "workbench", "UI detects current station")
	game.menu._recipe_change("spear")
	game.menu._toggle_ingredient("wood")
	game.menu._toggle_ingredient("stone")
	check(game.menu.loaded.size() == 2, "Material slots load visibly")
	game.menu._start_craft()
	check(not game.crafting.is_empty(), "Loading ingredients starts production")
	check(int(game.inventory.get("spear", 0)) == 0, "Crafting does not instantly deliver item")
	check(int(game.inventory.get("wood", 0)) == 7, "Materials remain reserved until completion")
	game._update_crafting(10.0)
	check(int(game.inventory.get("spear", 0)) == 0, "Timer alone cannot finish without work actions")
	for i in range(3):
		game.craft_work_cooldown = 0.0
		game.work_craft()
	check(game.crafting.is_empty(), "Manual workshop actions finish craft")
	check(int(game.inventory.get("spear", 0)) == 1, "Completed spear enters inventory")
	check(int(game.inventory.get("wood", 0)) == 4 and int(game.inventory.get("stone", 0)) == 3, "Ingredients deducted once on completion")
	check(game.spear_crafted, "Spear equips on completion")
	check(not game.can_craft("spear"), "Unique gear cannot be duplicated")
	game.menu.close_page()
	check(game.begin_craft("axe"), "Can start another recipe")
	game.cancel_craft()
	check(game.crafting.is_empty(), "Work can be cancelled")
	check(int(game.inventory.get("wood", 0)) == 4, "Cancellation never consumes ingredients")
	game.show_inventory()
	check(game.menu.visible and game.menu.current_page == "bag", "Inventory tab opens")
	game.menu.close_page()
	game.inventory["meal"] = 1
	game.hero.health = 20.0
	game.use_meal()
	check(is_equal_approx(game.hero.health, 60.0), "Meal heals 40 HP")
	check(int(game.inventory.get("meal", 0)) == 0, "Consumed food decrements")
	game.hero.global_position = game.station_positions["forge"] + Vector3(0, 0.35, 0)
	game.inventory["iron"] = 3
	game.inventory["coal"] = 1
	check(game.can_craft("iron_ingot"), "Iron ingot can be smelted at forge")
	check(game.begin_craft("iron_ingot"), "Forge crafting starts")
	game._update_crafting(10.0)
	for i in range(4):
		game.craft_work_cooldown = 0.0
		game.work_craft()
	check(int(game.inventory.get("iron_ingot", 0)) == 1, "Forge produces refined ingot")
	check(int(game.inventory.get("iron", 0)) == 0, "Iron ore consumed by recipe")
	game.inventory["iron_ingot"] = 2
	game.inventory["wood"] = 2
	check(game.begin_craft("iron_blade"), "Iron blade can be forged from ingots")
	game._update_crafting(10.0)
	for i in range(5):
		game.craft_work_cooldown = 0.0
		game.work_craft()
	check(int(game.inventory.get("iron_blade", 0)) == 1, "Forged blade awarded")
	var boar = get_first_node_in_group("enemies")
	check(boar != null, "Boar enemy exists")
	if boar != null:
		game.hero.global_position = boar.global_position + Vector3(0.75, 0, 0)
		game.menu.close_page()
		game.attack_delay = 0.0
		game.attack()
		check(is_equal_approx(boar.hp, 8.0), "Iron blade upgrades combat to 24 damage")
		boar.receive_damage(50.0)
		check(int(game.inventory.get("hide", 0)) > 0, "Boar awards hides")
	game.queue_free()
	print("RESULT: %d failed assertion(s)." % failures)
	quit(0 if failures == 0 else 1)
