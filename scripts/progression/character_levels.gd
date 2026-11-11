extends RefCounted
## Persistent RPG character level and independent weapon familiarity.
## Legacy saves already contain absolute experience; no migration/reset.
const MASTERY_UNLOCK_RANKS: Array[int] = [1, 3, 5]
# The three visible slots are always Heroic Strike, Armour Break, Whirlwind.
# Existing saves store mastery XP only, so changing runtime skill IDs is safe.
const WEAPON_SKILLS: Array[String] = ["power_strike", "armor_break", "whirlwind"]
const WEAPON_SKILL_NAMES: Array[String] = ["HEROIC STRIKE", "ARMOUR BREAK", "WHIRLWIND"]
const ARMOR_BREAK_SECONDS: float = 6.0
const ARMOR_BREAK_BONUS: float = 0.25
const WHIRLWIND_RADIUS: float = 3.2
const WHIRLWIND_DURATION: float = 0.90

static func total_xp_for(level: int) -> int:
	var n: int = maxi(0, level - 1)
	return 100 * n + 25 * n * maxi(0, n - 1)

static func level_for(xp: int) -> int:
	var level: int = 1
	while level < 100 and xp >= total_xp_for(level + 1):
		level += 1
	return level

static func level_state(xp: int) -> Dictionary:
	var level: int = level_for(xp)
	var current: int = total_xp_for(level)
	var next: int = total_xp_for(level + 1)
	return {"level": level, "current": maxi(0, xp - current), "required": maxi(1, next - current), "total": xp}

static func spend_level(xp: int, levels: int = 1) -> int:
	var current_level: int = level_for(xp)
	if current_level <= levels:
		return xp
	var delta: int = total_xp_for(current_level) - total_xp_for(current_level - levels)
	return maxi(0, xp - delta)

static func mastery_rank(xp: int) -> int:
	return mini(10, 1 + maxi(0, xp) / 60)

static func available_skill_slots(mastery_xp: int) -> int:
	var rank: int = mastery_rank(mastery_xp)
	var slots: int = 0
	for required in MASTERY_UNLOCK_RANKS:
		if rank >= required:
			slots += 1
	return slots

static func unlock_level_for_slot(slot: int) -> int:
	if slot < 0 or slot >= MASTERY_UNLOCK_RANKS.size():
		return -1
	return MASTERY_UNLOCK_RANKS[slot]

static func skill_name_for_slot(slot: int) -> String:
	if slot < 0 or slot >= WEAPON_SKILL_NAMES.size():
		return ""
	return WEAPON_SKILL_NAMES[slot]

static func next_skill_unlock_level(mastery_xp: int) -> int:
	var slots: int = available_skill_slots(mastery_xp)
	return unlock_level_for_slot(slots) if slots < WEAPON_SKILLS.size() else -1

static func skill_for_slot(slot: int) -> String:
	if slot < 0 or slot >= WEAPON_SKILLS.size():
		return ""
	return WEAPON_SKILLS[slot]

static func cooldown_for_skill(skill_id: String) -> float:
	match skill_id:
		"power_strike": return 7.0
		"armor_break": return 10.0
		"whirlwind": return 13.0
	return 0.0

static func multiplier_for_skill(skill_id: String) -> float:
	match skill_id:
		"power_strike": return 1.55
		"armor_break": return 1.15
		"whirlwind": return 0.92
	return 1.0
