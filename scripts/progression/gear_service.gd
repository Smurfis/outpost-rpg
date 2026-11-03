extends RefCounted
## Equipment instances are rolled ONCE on craft, stored as plain saveable dictionaries.
const DEFINITIONS = "res://data/progression/gear.json"
const BALANCE = "res://data/progression/balance.json"
const TIERS = "res://data/progression/metal_tiers.json"
const SLOTS: Array[String] = ["weapon", "head", "body", "feet"]

static func config() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE))
	return value if value is Dictionary else {}

static func definitions() -> Array:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFINITIONS))
	return value if value is Array else []

static func template(id: String) -> Dictionary:
	for value in definitions():
		if value is Dictionary and str(value.get("id", "")) == id:
			return value
	return {}

static func rarity_name(rarity: int) -> String:
	return ["Common", "Uncommon", "Rare", "Epic", "Legendary"][clampi(rarity, 0, 4)]

static func tier_for_level(item_level: int) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIERS))
	if not (value is Array):
		return {}
	var level: int = clampi(item_level, 1, 50)
	for entry in value:
		if entry is Dictionary and level >= int(entry.get("min_level", 1)) and level <= int(entry.get("max_level", 50)):
			return entry
	return {}

static func recipe_cost(id: String, item_level: int, rarity: int) -> Dictionary:
	var definition: Dictionary = template(id)
	if definition.is_empty():
		return {}
	var tier: Dictionary = tier_for_level(item_level)
	if tier.is_empty():
		return {}
	var level: int = clampi(item_level, 1, 50)
	var lower: int = int(tier.get("min_level", 1))
	var multiplier: int = 1 + mini(2, int(floor(float(level - lower) / 5.0)))
	var refined: String = str(tier.get("refined", "iron_ingot"))
	var fabric: String = str(tier.get("cloth", "linen"))
	var result: Dictionary = {}
	var base: Dictionary = definition.get("base_cost", {})
	# Upgrade the *same* gear template through successive material tiers.
	# Material substitution is paid once; no transmutes of old inventory are needed.
	for key in base:
		var material: String = str(key)
		if material == "iron_ingot":
			material = refined
		elif material == "linen":
			material = fabric
		result[material] = int(result.get(material, 0)) + int(base[key]) * multiplier
	if not result.has(refined):
		result[refined] = 1 + maxi(0, multiplier - 1)
	var catalyst: String = str(tier.get("catalyst", ""))
	if catalyst != "":
		result[catalyst] = int(result.get(catalyst, 0)) + 1
	var rarity_index: int = clampi(rarity, 0, 4)
	var rarity_materials: Array[String] = ["", "copper", "quartz", "ether_dust", "legendary_core"]
	var rare_key: String = rarity_materials[rarity_index]
	if rare_key != "":
		result[rare_key] = int(result.get(rare_key, 0)) + maxi(1, rarity_index - 1)
	return result

static func can_pay(materials: Dictionary, costs: Dictionary) -> bool:
	if costs.is_empty():
		return false
	for key in costs:
		if int(materials.get(str(key), 0)) < int(costs[key]):
			return false
	return true

static func roll(id: String, item_level: int, rarity: int, roll_seed: int, serial: int, spent: Dictionary = {}) -> Dictionary:
	var definition: Dictionary = template(id)
	if definition.is_empty():
		return {}
	var balance: Dictionary = config().get("gear", {})
	var r: int = clampi(rarity, 0, 4)
	var level: int = clampi(item_level, 1, int(balance.get("gear_level_cap", 50)))
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, roll_seed)
	var ranges: Array = balance.get("socket_count_by_rarity", [[1,1],[1,2],[1,2],[2,3],[3,3]])
	var socket_range: Array = ranges[r]
	var count: int = rng.randi_range(int(socket_range[0]), int(socket_range[1]))
	var colors: Array = balance.get("socket_colors", ["red","yellow","blue"])
	var weights: Array = balance.get("socket_color_weights", [38, 30, 32])
	var sockets: Array = []
	for i in range(count):
		var roll_value: int = rng.randi_range(1, 100)
		var color_name: String = str(colors[0])
		for j in range(colors.size()):
			roll_value -= int(weights[j])
			if roll_value <= 0:
				color_name = str(colors[j])
				break
		sockets.append({"color": color_name, "skill": ""})
	var legendary: bool = r == 4 and level >= int(balance.get("legendary_prismatic_min_level", 15)) and rng.randf() < float(balance.get("legendary_prismatic_chance", 0.35))
	if legendary:
		sockets.append({"color": "prismatic", "skill": ""})
	return {
		"uid": "%s-%d-%d" % [id, serial, maxi(1, roll_seed)],
		"template": id,
		"name": str(definition.get("name", id)),
		"slot": str(definition.get("slot", "")),
		"rarity": r,
		"item_level": level,
		"craft_tier": int(tier_for_level(level).get("tier", 1)),
		"seed": maxi(1, roll_seed),
		"sockets": sockets,
		"spent": spent.duplicate(true),
		"locked": false,
		"favourite": false
	}

static func item_stats(item: Dictionary) -> Dictionary:
	var definition: Dictionary = template(str(item.get("template", "")))
	var balance: Dictionary = config().get("gear", {})
	var role: String = str(definition.get("role", "physical"))
	var level: float = float(item.get("item_level", 1))
	var output: Dictionary = {"damage": 0.0, "attack_speed": 0.0, "crit": 0.0, "ability_power": 0.0}
	if role == "physical":
		output["damage"] = level * float(balance.get("level_damage", 0.58))
	elif role == "precision":
		output["attack_speed"] = level * float(balance.get("level_attack_speed", 0.006)) * 2.0
		output["crit"] = level * float(balance.get("level_crit", 0.002))
	elif role == "arcane":
		output["ability_power"] = level * float(balance.get("level_ability_power", 0.39))
	return output

static func aggregate(items: Array, loadout: Dictionary) -> Dictionary:
	var all_config: Dictionary = config()
	var base: Dictionary = all_config.get("base_stats", {"damage": 8.0, "attack_speed": 1.0, "crit": 0.05, "ability_power": 0.0})
	var output: Dictionary = base.duplicate()
	var armour: float = 0.0
	var gear_balance: Dictionary = all_config.get("gear", {})
	for item in items:
		if not (item is Dictionary):
			continue
		var slot: String = str(item.get("slot", ""))
		if str(loadout.get(slot, "")) != str(item.get("uid", "")):
			continue
		var bonuses: Dictionary = item_stats(item)
		for stat in ["damage", "attack_speed", "crit", "ability_power"]:
			output[stat] = float(output.get(stat, 0.0)) + float(bonuses.get(stat, 0.0))
		if slot in ["head", "body", "feet"]:
			armour += float(item.get("item_level", 1)) * float(gear_balance.get("level_armour_mitigation", 0.006))
	var limits: Dictionary = all_config.get("limits", {})
	output["attack_speed"] = clampf(float(output["attack_speed"]), 0.5, float(limits.get("attack_speed", 3.5)))
	output["crit"] = clampf(float(output["crit"]), 0.0, float(limits.get("crit", 0.75)))
	output["mitigation"] = clampf(armour, 0.0, float(limits.get("damage_mitigation", 0.7)))
	return output

static func get_equipped(items: Array, loadout: Dictionary, slot: String) -> Dictionary:
	var uid: String = str(loadout.get(slot, ""))
	for item in items:
		if item is Dictionary and str(item.get("uid", "")) == uid:
			return item
	return {}
