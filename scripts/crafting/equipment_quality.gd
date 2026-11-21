extends RefCounted
## Equipment crafting quality rolls. Everything here is pure game logic so
## station UI, save migration and combat can share the same roll definitions.
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const CHANCES: Array[float] = [0.60, 0.27, 0.10, 0.025, 0.005]
const STAT_KEYS: Array[String] = ["damage", "attack_speed", "crit_chance", "ability_power"]
const CRAFTABLE_GEAR: Array[String] = ["spear", "iron_blade", "axe", "pickaxe", "shield", "torch", "satchel", "cloak", "shrimp_net"]
const AFFIX_KEYS: Array[String] = ["Brutal", "Swift", "Vampiric", "Titanic"]
const AFFIX_CHANCES: Array[float] = [0.0, 0.02, 0.09, 0.25, 0.55]

static func is_gear(item_id: String) -> bool:
	return item_id in CRAFTABLE_GEAR

static func rarity_name(rank: int) -> String:
	return RARITY_NAMES[clampi(rank, 0, 4)]

static func rarity_color(rank: int) -> Color:
	match clampi(rank, 0, 4):
		0: return Color("#a6adad")
		1: return Color("#55b777")
		2: return Color("#568de0")
		3: return Color("#ae69da")
		_: return Color("#e4b35b")

static func stat_label(key: String) -> String:
	match key:
		"damage": return "Damage"
		"attack_speed": return "Attack Speed"
		"crit_chance": return "Critical Chance"
		"ability_power": return "Ability Power"
		_: return key.replace("_", " ").capitalize()

static func format_stat(key: String, amount: float) -> String:
	var suffix: String = "%" if key in ["attack_speed", "crit_chance"] else ""
	return "+%d%s" % [roundi(amount), suffix]

static func affix_description(affix: String) -> String:
	match affix:
		"Brutal": return "8% more physical damage"
		"Swift": return "6% faster attacks"
		"Vampiric": return "Restore 2 health on hit"
		"Titanic": return "12% more damage, 8% slower attacks"
		_: return ""

static func _score(rarity: int, bonuses: Dictionary, affix: String) -> float:
	var total: float = float(rarity) * 8.0
	for key in bonuses:
		total += float(bonuses[key]) * (2.0 if str(key) == "damage" else 1.0)
	if affix != "":
		total += 7.0
	return total

static func roll_item(item_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if not is_gear(item_id):
		return {}
	var random: RandomNumberGenerator = rng
	if random == null:
		random = RandomNumberGenerator.new()
		random.randomize()
	var chance: float = random.randf()
	var rarity: int = 0
	var threshold: float = 0.0
	for rank in range(CHANCES.size()):
		threshold += CHANCES[rank]
		if chance < threshold:
			rarity = rank
			break
	var bonus_count: int = rarity
	# Even Common equipment can occasionally roll a useful strong stat.
	if rarity == 0 and random.randf() < 0.16:
		bonus_count = 1
	var bonuses: Dictionary = {}
	for _i in range(bonus_count):
		var stat: String = STAT_KEYS[random.randi_range(0, STAT_KEYS.size() - 1)]
		var value: int = random.randi_range(1, 3 + rarity * 2)
		bonuses[stat] = int(bonuses.get(stat, 0)) + value
	var affix: String = ""
	if random.randf() < AFFIX_CHANCES[rarity]:
		affix = AFFIX_KEYS[random.randi_range(0, AFFIX_KEYS.size() - 1)]
	return {"rarity": rarity, "bonuses": bonuses, "affix": affix,
		"score": _score(rarity, bonuses, affix)}

static func sanitise_roll(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var rolled: Dictionary = raw as Dictionary
	var rarity: int = clampi(int(rolled.get("rarity", 0)), 0, 4)
	var bonuses: Dictionary = {}
	if rolled.get("bonuses", {}) is Dictionary:
		for key in STAT_KEYS:
			var amount: int = clampi(int(rolled["bonuses"].get(key, 0)), 0, 48)
			if amount > 0:
				bonuses[key] = amount
	var affix: String = str(rolled.get("affix", ""))
	if affix not in AFFIX_KEYS:
		affix = ""
	return {"rarity": rarity, "bonuses": bonuses, "affix": affix,
		"score": _score(rarity, bonuses, affix)}

static func is_upgrade(candidate: Dictionary, previous: Dictionary) -> bool:
	if previous.is_empty():
		return true
	return float(candidate.get("score", 0.0)) > float(previous.get("score", 0.0))
