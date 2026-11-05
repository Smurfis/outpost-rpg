extends SceneTree
## End-to-end checks for real weight caps, craftable tiered bags, quality stars
## and non-destructive overflow. Uses a fresh test character.
const CARRY = preload("res://scripts/inventory/carry_capacity.gd")
var failures: int = 0

func verify(ok: bool, message: String) -> void:
	if ok:
		print("PASS CARRY CAMERA: " + message)
	else:
		failures += 1
		push_error("FAIL CARRY CAMERA: " + message)

func _run() -> void:
	pass

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	verify(is_equal_approx(CARRY.capacity(""), 36.0), "No bag starts with limited carry weight")
	verify(CARRY.capacity("backpack_t2", 2) > CARRY.capacity("backpack_t1", 2), "Tier 2 backpack carries more")
	verify(CARRY.weight("wood", "wood_satchel_t1", 1) < CARRY.weight("wood", "ore_satchel_t1", 1), "Wood satchel saves wood weight only")
	verify(CARRY.weight("iron", "ore_satchel_t2", 2) < CARRY.weight("iron", "wood_satchel_t2", 2), "Ore satchel saves ore weight")
	verify(CARRY.weight("coins") == 0.0, "Silver/coins do not block resource harvesting")
	var preview: Dictionary = {"wood": 100, "iron": 20}
	verify(CARRY.used(preview, "wood_satchel_t1", 1) < CARRY.used(preview), "Specialist bags reduce effective load")
	verify(CARRY.max_fit({"wood": 80}, "stone", 3) == 0, "Cannot collect additional heavy items at capacity")
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Playable world loads with new bag scripts")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	verify(game.equipment.has("bag"), "Dedicated bag slot is available")
	verify(game.inventory.has("backpack_t1") and game.inventory.has("ore_satchel_t2"), "New bag items initialize in inventory")
	verify(game.menu.item_ids.has("wood_satchel_t1"), "Bag inventory UI knows specialist bags")
	verify(game.hud.root.get_node_or_null("CarryWeightLabel") != null, "HUD displays true bag load")
	verify(game._recipe_by_id("backpack_t1").get("station", "") == "loom", "Backpack is craftable at the loom")
	verify(game._recipe_by_id("ore_satchel_t1").get("station", "") == "forge", "Mining satchel has a forge recipe")

	game.inventory["fiber"] = 7
	game.inventory["hide"] = 3
	game.hero.global_position = game.station_positions["loom"] + Vector3(0.0, 0.35, 0.0)
	verify(game.can_craft("backpack_t1"), "Materials and weight permit actual bag crafting")
	verify(game.begin_craft("backpack_t1"), "Bag starts existing staged manual crafting")
	game._update_crafting(3.0)
	for i in range(4):
		game.craft_work_cooldown = 0.0
		game.work_craft()
	verify(game.crafting.is_empty(), "Bag completion uses actual stroke and time requirements")
	verify(game.inventory["backpack_t1"] == 1, "Bag crafted exactly once")
	verify(game.bag_quality.get("backpack_t1", 0) == 1, "First crafted bag earns one star")
	verify(game.equipped_bag_id() == "backpack_t1", "New bag auto-equips")
	var first_capacity: float = game.bag_capacity()
	game.inventory["fiber"] = 7
	game.inventory["hide"] = 3
	verify(game.can_craft("backpack_t1"), "Same recipe upgrades an existing bag")
	verify(game.begin_craft("backpack_t1"), "Bag star upgrade is a real crafting action")
	game._update_crafting(3.0)
	for i in range(4):
		game.craft_work_cooldown = 0.0
		game.work_craft()
	verify(game.inventory["backpack_t1"] == 1 and game.bag_quality.get("backpack_t1", 0) == 2, "Recraft adds one star but never duplicates bag stock")
	verify(game.bag_capacity() > first_capacity, "Star upgrade improves carry capacity")
	game.bag_quality["backpack_t1"] = 3
	verify(not game.can_craft("backpack_t1"), "No infinite recraft beyond three stars")
	game.inventory["wood"] = 0
	game.inventory["stone"] = 0
	game.inventory["hide"] = 0
	game.inventory["fiber"] = 0
	game.equipment["bag"] = ""
	game.inventory["backpack_t1"] = 0
	var fitting: int = game.grant_item("wood", 1000, true)
	verify(fitting > 0 and fitting < 1000, "Pickup respects maximum carry")
	verify(game.overflow_loot.get("wood", 0) == 1000 - fitting, "Excess rewards stored and never destroyed")
	game.inventory["backpack_t1"] = 1
	game.bag_quality["backpack_t1"] = 3
	verify(game.equip_item("backpack_t1"), "Owned backpack equips through existing API")
	var before: int = int(game.inventory["wood"])
	var claimed: int = game.claim_overflow()
	verify(claimed > 0 and int(game.inventory["wood"]) > before, "Larger bag lets player recover stored loot")
	verify(game.overflow_loot.has("wood"), "Unclaimed loot remains recoverable")
	verify(game.bag_load() <= game.bag_capacity() + 0.0001, "Load never exceeds equipped bag allowance from pickup")
	game.hero.global_position = Vector3(0.0, 0.35, 0.0)
	game._camera(0.25)
	var smooth_before: float = game.camera_focus_smooth.y
	game.hero.global_position.y += 2.0
	game._camera(0.016)
	verify(game.camera_focus_smooth.y > smooth_before and game.camera_focus_smooth.y < game.hero.global_position.y + 0.95, "Beach/step elevation moves camera focus smoothly")
	var current_yaw: float = game.camera_angle_target
	game.drag_camera(80.0)
	verify(absf(game.camera_angle_target - current_yaw) > 0.25, "Dragging camera steers continuous isometric orbit")
	game.show_inventory()
	verify(game.menu.recipes_list.get_node_or_null("BagItemGrid") != null, "Bag screen preserves the functional item grid")
	verify(game.menu.station_tabs.get_node_or_null("RecoverStoredLoot") != null, "Full-bag loot recovery appears in inventory")
	game.menu.close_page()
	game.queue_free()
	await process_frame
	print("CARRY CAMERA RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
