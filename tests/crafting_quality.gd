extends SceneTree
## Seeded, deterministic quality and affix tests. Run with:
## godot --headless --path . -s res://tests/crafting_quality.gd
const QUALITY = preload("res://scripts/crafting/equipment_quality.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_test")

func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS CRAFT: " + detail)
	else:
		failures += 1
		push_error("FAIL CRAFT: " + detail)

func _test() -> void:
	check(QUALITY.is_gear("spear") and QUALITY.is_gear("pickaxe"), "Weapons and tools roll quality")
	check(not QUALITY.is_gear("iron_ingot"), "Materials do not get equipment rarity")
	check(QUALITY.RARITY_NAMES.size() == 5, "Five rarity stages exist")
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 774411
	rng_b.seed = 774411
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var matched: bool = true
	var nonempty_boosts: bool = false
	for index in range(10000):
		var roll_a: Dictionary = QUALITY.roll_item("spear", rng_a)
		var roll_b: Dictionary = QUALITY.roll_item("spear", rng_b)
		if roll_a != roll_b:
			matched = false
		var rank: int = int(roll_a.get("rarity", -1))
		if rank < 0 or rank > 4:
			check(false, "Every roll must have a valid rarity")
			break
		counts[rank] += 1
		nonempty_boosts = nonempty_boosts or not roll_a.get("bonuses", {}).is_empty()
		check_roll_shape(roll_a)
	check(matched, "Identical seeds produce identical rarity and stat rolls")
	check(nonempty_boosts, "Stat boosts actually appear")
	check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > counts[4] and counts[4] > 0, "Probability tiers become progressively rarer")
	check(QUALITY.roll_item("iron_ingot", rng_a).is_empty(), "Resource crafting stays deterministic")
	var baseline: Dictionary = {"rarity": 2, "bonuses": {"damage": 5}, "affix": "", "score": 26.0}
	var worse: Dictionary = {"rarity": 0, "bonuses": {}, "affix": "", "score": 0.0}
	check(not QUALITY.is_upgrade(worse, baseline), "Lower score cannot replace a better weapon")
	check(QUALITY.is_upgrade(baseline, worse), "Better roll can replace an existing item")
	var cleaned: Dictionary = QUALITY.sanitise_roll({"rarity": 400, "bonuses": {"damage": 2000, "unknown": 50}, "affix": "invalid"})
	check(int(cleaned["rarity"]) == 4 and int(cleaned["bonuses"]["damage"]) == 48 and not cleaned["bonuses"].has("unknown") and cleaned["affix"] == "", "Saved roll data is bounded")
	print("CRAFT QUALITY RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func check_roll_shape(roll: Dictionary) -> void:
	var boosts: Dictionary = roll.get("bonuses", {})
	for stat in boosts:
		if stat not in QUALITY.STAT_KEYS or int(boosts[stat]) < 1:
			check(false, "Generated stat entries must be supported and positive")
