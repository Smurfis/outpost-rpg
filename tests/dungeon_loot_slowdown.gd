extends SceneTree
## Regression: dungeon rewards must not leave the player permanently slowed
## by overflowing backpack capacity or incorrectly weighing wallet currency.
const CARRY = preload("res://scripts/inventory/carry_capacity.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS DUNGEON SLOWDOWN: " + description)
	else:
		failures += 1
		push_error("FAIL DUNGEON SLOWDOWN: " + description)

func _run() -> void:
	for currency_id in ["coins", "copper", "silver", "gold", "gems"]:
		check(is_zero_approx(CARRY.weight(currency_id)), "Wallet " + currency_id + " has zero carry weight")
	check(is_zero_approx(CARRY.used({"coins": 2000, "copper": 500, "silver": 50, "gold": 12, "gems": 8})), "An old save with a rich wallet is not overloaded")
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene can load")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	game.save_path = "user://.dungeon-slowdown-test.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.hero.set_physics_process(false)
	var manager = game.get_node_or_null("Dungeons")
	check(manager != null, "Dungeon manager exists")
	if manager == null:
		game.queue_free()
		quit(1)
		return
	game.inventory["stone"] = 54 # 35.1 of the starting 36 carry capacity.
	check(game.bag_load() < game.bag_capacity(), "Player starts below weight capacity")
	manager._apply_reward({
		"coins": 900,
		"currencies": {"copper": 150, "silver": 25, "gold": 5, "gems": 7},
		"materials": {"stone": 20, "gem_fragment": 1},
		"books": ["book_power_strike"],
		"xp": 30
	})
	check(game.bag_load() <= game.bag_capacity() + 0.0001, "Dungeon rewards do not overload backpack")
	check(int(game.inventory.get("copper", 0)) == 150 and int(game.inventory.get("coins", 0)) == 900, "All wallet currency is awarded")
	check(int(game.overflow_loot.get("stone", 0)) == 19, "Excess dungeon stone is stored instead of forcing a permanent slow")
	check(int(game.overflow_loot.get("book_power_strike", 0)) == 1, "Book rewards are retained in overflow when bag is full")
	var before_hit: float = game.bag_load()
	game.hero.take_hit(1.0, game.hero.global_position + Vector3.RIGHT)
	check(is_equal_approx(game.bag_load(), before_hit), "Receiving enemy damage does not change carry weight")
	game.inventory["stone"] = 0
	var recovered: int = game.claim_overflow()
	check(recovered >= 20 and game.overflow_loot.is_empty(), "Player can claim all saved dungeon rewards once bag space is freed")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://.dungeon-slowdown-test.json"))
	print("DUNGEON SLOWDOWN RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
