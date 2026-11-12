extends RefCounted
## Centralized, deterministic carry-weight rules. No inventory mutation here.
## This is intentionally not a fixed slot-count: varied resources weigh
## differently and specialist bags help specific gatherings.
const BASE_CAPACITY: float = 36.0
const BAG_DEFINITIONS: Dictionary = {
	"backpack_t1": {"tier":1, "bonus":26.0, "specialty":""},
	"backpack_t2": {"tier":2, "bonus":52.0, "specialty":""},
	"wood_satchel_t1": {"tier":1, "bonus":15.0, "specialty":"wood"},
	"wood_satchel_t2": {"tier":2, "bonus":27.0, "specialty":"wood"},
	"ore_satchel_t1": {"tier":1, "bonus":15.0, "specialty":"ore"},
	"ore_satchel_t2": {"tier":2, "bonus":27.0, "specialty":"ore"}
}
const WEIGHTS: Dictionary = {
	"wood":0.45, "stone":0.65, "fiber":0.22, "berries":0.12,
	"iron":1.15, "coal":0.95, "clay":0.72, "herbs":0.18,
	"mushrooms":0.22, "reeds":0.22, "hide":0.70, "coins":0.0,
	# Wallet balances never consume backpack capacity, even after a dungeon.
	"copper":0.0, "silver":0.0, "gold":0.0, "gems":0.0,
	"iron_ingot":1.6, "linen":0.50, "bricks":1.4,
	"shrimp":0.15, "cooked_shrimp":0.20, "shrimp_net":0.8,
	"meal":0.65, "tonic":0.40, "stew":0.65,
	"spear":2.5, "axe":2.2, "pickaxe":2.5, "shield":3.0,
	"torch":1.0, "satchel":1.0, "iron_blade":3.0, "cloak":1.0,
	"backpack_t1":1.5, "backpack_t2":2.0,
	"wood_satchel_t1":1.5, "wood_satchel_t2":2.0,
	"ore_satchel_t1":1.5, "ore_satchel_t2":2.0
}

static func is_bag(item_id: String) -> bool:
	return BAG_DEFINITIONS.has(item_id)

static func tier(item_id: String) -> int:
	return int(BAG_DEFINITIONS.get(item_id, {}).get("tier", 0))

static func specialty(item_id: String) -> String:
	return str(BAG_DEFINITIONS.get(item_id, {}).get("specialty", ""))

static func capacity(item_id: String, stars: int = 0) -> float:
	var details: Dictionary = BAG_DEFINITIONS.get(item_id, {})
	if details.is_empty():
		return BASE_CAPACITY
	return BASE_CAPACITY + float(details["bonus"]) + float(clampi(stars, 0, 3)) * 5.0

static func weight(item_id: String, equipped_bag: String = "", stars: int = 0) -> float:
	var base: float = float(WEIGHTS.get(item_id, 0.5))
	var matching: bool = (specialty(equipped_bag) == "wood" and item_id == "wood") or (specialty(equipped_bag) == "ore" and item_id in ["stone", "iron", "coal", "iron_ingot"])
	if matching:
		var reduction: float = 0.38 if tier(equipped_bag) == 1 else 0.50
		reduction += 0.03 * float(clampi(stars, 0, 3))
		return base * maxf(0.35, 1.0 - reduction)
	return base

static func used(inventory: Dictionary, equipped_bag: String = "", stars: int = 0) -> float:
	var result: float = 0.0
	for key in inventory:
		var count: int = maxi(0, int(inventory[key]))
		if count > 0:
			result += float(count) * weight(str(key), equipped_bag, stars)
	return result

static func remaining(inventory: Dictionary, equipped_bag: String = "", stars: int = 0) -> float:
	return capacity(equipped_bag, stars) - used(inventory, equipped_bag, stars)

static func can_fit(inventory: Dictionary, item_id: String, count: int, equipped_bag: String = "", stars: int = 0) -> bool:
	if count <= 0:
		return true
	return remaining(inventory, equipped_bag, stars) + 0.0001 >= weight(item_id, equipped_bag, stars) * float(count)

static func max_fit(inventory: Dictionary, item_id: String, requested: int, equipped_bag: String = "", stars: int = 0) -> int:
	if requested <= 0:
		return 0
	var per_item: float = weight(item_id, equipped_bag, stars)
	if per_item <= 0.0:
		return requested
	return clampi(int(floorf((remaining(inventory, equipped_bag, stars) + 0.0001) / per_item)), 0, requested)
