extends SceneTree
const RESOURCE = preload("res://scripts/resource_node.gd")
const CURRENCY = preload("res://scripts/inventory/currency.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: print("STUMP/WALLET PASS: " + label)
	else:
		failures += 1
		push_error(label)

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "res://.stump-wallet-test.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.hero.set_physics_process(false)
	for count in [1,3]:
		var tree = RESOURCE.new()
		game.add_child(tree)
		tree.position = Vector3(2000,0,2000)
		tree.setup("wood", count)
		await physics_frame
		await physics_frame
		check(tree.resource_body.get_child_count() == count * 2, "Each bundled tree has its own trunk and canopy")
		var canopy: CollisionShape3D = tree.resource_body.get_child(0)
		var trunk: CollisionShape3D = tree.resource_body.get_child(1)
		check(trunk.shape.size.x < canopy.shape.size.x * 0.4, "Trunk is narrower than foliage")
		var start := Transform3D(Basis.IDENTITY, tree.global_position + Vector3(-2.5,0.05,0))
		check(not game.hero.test_move(start, Vector3(1.5,0,0)), "Player can walk beneath the crown toward the stump")
		game.hero.global_position = tree.global_position + Vector3(-1,0.05,0)
		check(game.target_in_range(tree), "Stump is reachable within the existing chopping range")
		check(game.hero.test_move(game.hero.global_transform, Vector3(2,0,0)), "Narrow trunk remains physically solid")
		var high := start.translated(Vector3.UP * tree.tree_canopy_clearance)
		check(game.hero.test_move(high, Vector3(5,0,0)), "Raised canopy still blocks sideways passage at canopy height")
		game.gather_delay = 0
		var wood: int = game.inventory.wood
		game.gather(tree)
		check(game.inventory.wood > wood, "Chopping from beneath the canopy grants wood")
		tree.queue_free()
		await process_frame
	game.inventory.coins = 11
	game.inventory.copper = 3
	game.inventory.silver = 4
	game.inventory.gold = 2
	game.hud._refresh_wallet(game.inventory)
	check(game.hud.wallet_currency_rows.copper.text == "14", "Legacy coins and copper share the copper display")
	check(not game.hud.wallet_coin.visible and not game.hud.wallet_currency_icons.coins.visible, "No separate Coins balance is shown")
	var gold: Control = game.hud.wallet_currency_icons.gold
	var silver: Control = game.hud.wallet_currency_icons.silver
	var copper: Control = game.hud.wallet_currency_icons.copper
	check(gold.global_position.x < silver.global_position.x and silver.global_position.x < copper.global_position.x, "HUD order is Gold, Silver, Copper")
	game.menu.open("bag")
	await process_frame
	var bag = game.menu.inventory_window
	check(bag.currency_labels.copper.text == "14" and bag.currency_labels.gold.text == "2", "Bag uses the same currency balances")
	check(not bag._ordered_items().has("coins") and not bag._ordered_items().has("copper"), "Currency is not duplicated as bag items")
	game._save()
	game.inventory.coins = 0
	game.inventory.copper = 0
	game._load()
	check(CURRENCY.balance(game.inventory, "copper") == 14 and game.inventory.silver == 4 and game.inventory.gold == 2, "Save/load preserves every denomination without double conversion")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.stump-wallet-test.json"))
	print("STUMP/WALLET RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
