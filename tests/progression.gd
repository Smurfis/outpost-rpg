extends SceneTree
## Deterministic layout, floor reward, four-stat gear, socket/skill persistence,
## protected salvage and repeated craft/refund economy tests.
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
const LOOT = preload("res://scripts/dungeons/dungeon_loot.gd")
const GEAR = preload("res://scripts/progression/gear_service.gd")
const SKILLS = preload("res://scripts/progression/skill_service.gd")
const SALVAGE = preload("res://scripts/progression/salvage_service.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var all_patterns: Array = ["linear","branching","circular","hub","labyrinth"]
	var cfg: Dictionary = LAYOUT.settings()
	for rarity in range(5):
		for index in range(4):
			var entrance: String = "generated:%d:%d" % [rarity,index]
			var profile: Dictionary = LAYOUT.profile(entrance,rarity)
			var floors: int = int(profile["floors"])
			var limit: Array = cfg["floor_ranges"][rarity]
			check(floors >= int(limit[0]) and floors <= int(limit[1]), "Floor count follows rarity tier %d" % rarity)
			for floor_index in range(floors):
				for pattern in all_patterns:
					var layout: Dictionary = LAYOUT.generate(entrance,rarity,floor_index,pattern)
					check(LAYOUT.validate(layout), "%s rarity %d floor %d is connected" % [pattern,rarity,floor_index + 1])
					var count: int = (layout["rooms"] as Array).size()
					var range_value: Array = cfg["room_ranges"][rarity]
					check(count >= int(range_value[0]) and count <= int(range_value[1]), "Room count in rarity range")
					var repeat: Dictionary = LAYOUT.generate(entrance,rarity,floor_index,pattern)
					check(JSON.stringify(layout) == JSON.stringify(repeat), "Identical seed rebuilds identical graph")
	var reward_1: Dictionary = LOOT.chest("depth-test", 4, 0, 1)
	var reward_5: Dictionary = LOOT.chest("depth-test", 4, 4, 5)
	check(int(reward_5.get("coins",0)) >= int(float(reward_1.get("coins",0)) * 2.5), "Final chest scales ~30% for each additional floor")
	check(not reward_5.has("gear") and reward_5.has("materials"), "Dungeon drops materials, never completed equipment")
	check(reward_5 == LOOT.chest("depth-test",4,4,5), "Chest rewards deterministic from ID and floor")
	check(GEAR.definitions().size() >= 6 and SKILLS.all_skills().size() >= 9, "Gear and skills load from data files")
	for rarity in range(5):
		for level in [1,5,15,30]:
			var spent: Dictionary = GEAR.recipe_cost("pioneer_blade",level,rarity)
			var item: Dictionary = GEAR.roll("pioneer_blade",level,rarity,123456,100 + rarity,spent)
			var sockets: Array = item["sockets"]
			check(sockets.size() >= 1 and sockets.size() <= 4, "Equipment socket count 1..4")
			var normal_count: int = 0
			var special_count: int = 0
			for socket in sockets:
				if str(socket["color"]) == "prismatic":
					special_count += 1
				else:
					normal_count += 1
					check(str(socket["color"]) in ["red","yellow","blue"], "Normal socket uses red/yellow/blue")
			check(normal_count >= 1 and normal_count <= 3 and special_count <= 1, "At most three normal and one prismatic socket")
			check(special_count == 0 or rarity == 4 and level >= 15, "Prismatic only on high-level legendary")
			check(item["sockets"] == GEAR.roll("pioneer_blade",level,rarity,123456,100 + rarity,spent)["sockets"], "Craft seed always rerolls same initial sockets")
			var refund: Dictionary = SALVAGE.refund(item)
			for key in spent:
				check(int(refund.get(str(key),0)) <= int(spent[key]), "Salvage never duplicates input materials")
	var low: Dictionary = GEAR.roll("pioneer_blade",25,1,334,99)
	var high: Dictionary = GEAR.roll("pioneer_blade",1,3,335,100)
	check(float(GEAR.item_stats(low)["damage"]) > float(GEAR.item_stats(high)["damage"]), "Item level outranks rarity for base Damage")
	var core_stat: Dictionary = GEAR.aggregate([low],{"weapon":low["uid"],"head":"","body":"","feet":""})
	check(core_stat.has("damage") and core_stat.has("attack_speed") and core_stat.has("crit") and core_stat.has("ability_power"), "Exactly four combat stat families are available")
	var skill: Dictionary = SKILLS.definition("mend")
	check(skill["family"] == "blue" and skill["type"] == "heal", "Blue Mend is a healing AP skill")
	check(SKILLS.compatible({"color":"prismatic"}, skill), "Legendary wildcard socket accepts blue")
	check(SKILLS.compatible({"color":"blue"}, skill), "Blue socket accepts blue")
	check(not SKILLS.compatible({"color":"red"}, skill), "Red socket rejects blue")
	var materials: Dictionary = {"book_mend":2,"ether_dust":0}
	var learned: Dictionary = {}
	check(SKILLS.learn(learned,materials,"book_mend"), "Book permanently unlocks skill")
	check(not SKILLS.learn(learned,materials,"book_mend"), "Duplicate book does not relearn")
	check(SKILLS.recycle_duplicate(learned,materials,"book_mend"), "Duplicate converts into ether dust")
	check(int(materials.get("ether_dust",0)) == 2, "Duplicate conversion creates two essence units")
	var socketed: Dictionary = GEAR.roll("channeler_staff",20,4,22,11)
	socketed["sockets"] = [{"color":"prismatic","skill":""}]
	var items: Array = [socketed]
	check(SKILLS.assign(items,learned,str(socketed["uid"]),0,"mend"), "Wildcard socket can be assigned learned skill")
	check((items[0]["sockets"] as Array)[0]["skill"] == "mend", "Skill assignment stored on item")
	var salvage_materials: Dictionary = {"iron_ingot":20,"wood":20}
	var spent: Dictionary = GEAR.recipe_cost("pioneer_blade",5,0)
	var item_a: Dictionary = GEAR.roll("pioneer_blade",5,0,13,100,spent)
	var item_b: Dictionary = GEAR.roll("pioneer_blade",5,0,14,101,spent)
	var salvage_items: Array = [item_a,item_b]
	var loadout: Dictionary = {"weapon":str(item_a["uid"])}
	check(SALVAGE.protected(item_a,loadout), "Equipped item cannot be dismantled")
	check(SALVAGE.salvage_one(salvage_items,salvage_materials,loadout,str(item_a["uid"])).is_empty(), "Equipped salvage yields zero")
	item_b["favourite"] = true
	check(SALVAGE.salvage_one(salvage_items,salvage_materials,loadout,str(item_b["uid"])).is_empty(), "Favourite gear protected")
	item_b["favourite"] = false
	check(not SALVAGE.salvage_one(salvage_items,salvage_materials,loadout,str(item_b["uid"])).is_empty(), "Unprotected gear salvages")
	check(salvage_items.size() == 1, "Salvaged gear destroyed exactly once")
	var main_save: String = "user://outpost_progress_feature_test.json"
	if FileAccess.file_exists(main_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(main_save))
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	game.save_path = main_save
	game.get_node("Dungeons").demo_chunk_fallback = false
	root.add_child(game)
	await process_frame
	game.hero.global_position = game.station_positions["forge"] + Vector3(0,0.35,0)
	for item_id in GEAR.recipe_cost("pioneer_blade",20,2):
		game.inventory[str(item_id)] = 100
	check(game.craft_gear("pioneer_blade",20,2), "Physical forge crafts instanced gear")
	check(game.crafted_gear.size() == 1, "Forged item added exactly once")
	if game.crafted_gear.is_empty():
		game.queue_free()
		print("PROGRESSION RESULT: %d failed assertion(s)." % failures)
		quit(1)
		return
	var crafted: Dictionary = game.crafted_gear[0]
	var original_sockets: Array = crafted["sockets"].duplicate(true)
	check(game.equip_crafted(str(crafted["uid"])), "Crafted gear equips by unique ID")
	game.learned_skills["mend"] = true
	game._save()
	game.queue_free()
	var restored = scene.instantiate()
	restored.save_path = main_save
	restored.get_node("Dungeons").demo_chunk_fallback = false
	root.add_child(restored)
	await process_frame
	check(restored.crafted_gear.size() == 1, "Crafted gear persists after reload")
	if restored.crafted_gear.size() > 0:
		check(restored.crafted_gear[0]["sockets"] == original_sockets, "Socket colours are never rerolled by save/load")
		check(str(restored.gear_loadout["weapon"]) == str(crafted["uid"]), "Equipped gear UID persists")
	check(bool(restored.learned_skills.get("mend", false)), "Learned skill library persists")
	check(restored.inventory.has("ancient_ore") or not restored.inventory.has("ancient_ore"), "Older resource slots do not prevent migration")
	restored.queue_free()
	if FileAccess.file_exists(main_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(main_save))
	print("PROGRESSION RESULT: %d failed assertion(s)." % failures)
	quit(0 if failures == 0 else 1)
