extends SceneTree
## Regression suite for the Outpost gameplay loop.
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
	print("DIAG created hero=", game.hero.name, " origin=", game.hero.global_position, " first_boar=", get_first_node_in_group("enemies").global_position)
	check(game.hero.global_position.distance_to(Vector3(0, 0.35, 0)) < 0.1, "Player initializes at outpost")
	await process_frame
	print("DIAG after frame hero=", game.hero.name, " origin=", game.hero.global_position)
	check(game.hero.global_position.distance_to(Vector3(0, 0.35, 0)) < 0.6, "Hero remains at spawn through first physics frame")
	check(game.recipes.size() == 6, "Six JSON recipes load")
	check(game.menu != null and game.hud != null, "HUD and crafting interface initialize")
	check(not game.near_workshop(), "Spawn is not automatically in crafting range")
	var before: int = int(game.inventory.get("wood", 0))
	var message: String = game.hud.toast_label.text
	print("DIAG empty pos=", game.hero.global_position, " nearest=", game._nearest_resource(), " delay=", game.gather_delay, " before toast=", message)
	game.gather()
	print("DIAG empty after toast=", game.hud.toast_label.text, " delay=", game.gather_delay, " inventory=", game.inventory)
	check(int(game.inventory.get("wood", 0)) == before, "Empty gathering awards no item")
	check(game.hud.toast_label.text == message, "Empty gather produces no popup")
	var target = null
	for node in get_nodes_in_group("resources"):
		if node.kind == "wood":
			target = node
			break
	check(target != null, "Wood resource exists")
	if target != null:
		game.hero.global_position = target.global_position + Vector3(1, 0.35, 0)
		print("DIAG near wood pos=", game.hero.global_position, " target=", target.global_position, " nearest=", game._nearest_resource(), " delay=", game.gather_delay)
		game.gather()
		print("DIAG after wood inventory=", game.inventory, " hits=", target.hits_left)
		check(int(game.inventory.get("wood", 0)) == before + 1, "Gathering awards wood")
		check(target.hits_left == 2, "Resource durability decreases")
	game.hero.global_position = game.workshop + Vector3(0, 0.35, 0)
	game.inventory["wood"] = 5
	game.inventory["stone"] = 3
	check(game.can_craft("spear"), "Spear can be crafted at workshop")
	game.craft_item("spear")
	check(int(game.inventory.get("spear", 0)) == 1, "Crafting creates a spear")
	check(int(game.inventory.get("wood", 0)) == 2 and int(game.inventory.get("stone", 0)) == 1, "Crafting deducts ingredients")
	check(game.spear_crafted, "Spear actually equips")
	game.craft_item("spear")
	check(int(game.inventory.get("spear", 0)) == 1, "Unique items cannot duplicate")
	game.show_crafting()
	check(game.menu.visible and game.menu.current_page == "craft", "Craft menu opens")
	game.show_inventory()
	check(game.menu.visible and game.menu.current_page == "bag", "Inventory opens")
	game.menu.close_page()
	game.inventory["meal"] = 1
	game.hero.health = 20.0
	game.use_meal()
	check(is_equal_approx(game.hero.health, 60.0), "Meal restores 40 health")
	check(int(game.inventory.get("meal", 0)) == 0, "Meal is consumed")
	var boar = get_first_node_in_group("enemies")
	check(boar != null, "Boar exists")
	if boar != null:
		game.hero.global_position = boar.global_position + Vector3(0.75, 0.0, 0)
		game.attack_delay = 0.0
		game.attack()
		check(is_equal_approx(boar.hp, 16.0), "Equipped spear boosts damage")
		boar.receive_damage(50.0)
		check(int(game.inventory.get("hide", 0)) > 0, "Boar awards hide")
	game.queue_free()
	print("RESULT: %d failed assertion(s)." % failures)
	quit(0 if failures == 0 else 1)
