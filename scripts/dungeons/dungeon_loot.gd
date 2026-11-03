extends RefCounted
## Seeded material/book/gem reward tiers. Never drops finished equipment.
const CONFIG = "res://data/progression/loot.json"
const BALANCE = "res://data/progression/balance.json"
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
const SKILLS = preload("res://scripts/progression/skill_service.gd")

static func info() -> Dictionary:
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return cfg if cfg is Dictionary else {}

static func chest(entrance_id: String, rarity: int, floor_index: int, floor_count: int, bonus: bool = false) -> Dictionary:
	var r: int = clampi(rarity, 0, 4)
	var floor_number: int = maxi(1, floor_index + 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT.stable_seed("%s:loot:%d:%d:%s" % [entrance_id, r, floor_index, str(bonus)])
	var cfg: Dictionary = info()
	var tier: int = mini(4, r + int(floor(float(floor_number - 1) / 2.0)))
	var pool: Array = cfg.get("material_tiers", [])[tier]
	var item_id: String = str(pool[rng.randi_range(0, pool.size() - 1)])
	var amount: int = maxi(1, r + 1 + int(floor(float(floor_number) / 2.0)))
	var materials: Dictionary = {item_id: amount}
	if rng.randf() < 0.55:
		var second: String = str(pool[rng.randi_range(0, pool.size() - 1)])
		materials[second] = int(materials.get(second, 0)) + maxi(1, int(floor(float(amount) / 2.0)))
	var book_chances: Array = cfg.get("book_chances", [0.1, 0.18, 0.25, 0.35, 0.5])
	var gems_chances: Array = cfg.get("gem_fragment_chances", [0, 0.04, 0.12, 0.24, 0.39])
	var rare_gem_chances: Array = cfg.get("full_prismatic_gem_chances", [0, 0, 0, 0.005, 0.03])
	var books: Array = []
	if rng.randf() < float(book_chances[r]) * (0.35 if bonus else 1.0):
		var defs: Array = SKILLS.all_skills()
		var entry: Dictionary = defs[rng.randi_range(0, defs.size() - 1)]
		books.append(str(entry.get("book", "")))
	if rng.randf() < float(gems_chances[r]):
		materials["gem_fragment"] = int(materials.get("gem_fragment", 0)) + 1
	if not bonus and rng.randf() < float(rare_gem_chances[r]):
		materials["prismatic_gem"] = int(materials.get("prismatic_gem", 0)) + 1
	var scales: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(BALANCE)) as Dictionary).get("dungeons", {})
	var per_floor: float = float(scales.get("final_chest_floor_multiplier", 1.30))
	var floor_factor: float = pow(per_floor, maxi(0, floor_count - 1))
	var coins: Array = cfg.get("base_coins", [15,28,52,85,135])
	var xp_values: Array = cfg.get("base_experience", [20,38,70,120,210])
	var multiplier: float = 0.20 if bonus else floor_factor
	return {
		"coins": maxi(1, int(round(float(coins[r]) * multiplier))),
		"xp": maxi(1, int(round(float(xp_values[r]) * multiplier))),
		"materials": materials,
		"books": books,
		"floor": floor_number,
		"floors": floor_count,
		"seed": rng.seed,
		"bonus": bonus
	}
