extends RefCounted
## Persistent RPG character level and independent weapon familiarity.
## Legacy saves already contain absolute experience; no migration/reset.
const MASTERY_UNLOCK_RANKS: Array[int] = [1, 3, 5]
const WEAPON_SKILLS: Array[String] = ["power_strike", "cleave", "sundering_blow"]

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

static func skill_for_slot(slot: int) -> String:
	if slot < 0 or slot >= WEAPON_SKILLS.size():
		return ""
	return WEAPON_SKILLS[slot]

static func cooldown_for_skill(skill_id: String) -> float:
	match skill_id:
		"power_strike": return 7.0
		"cleave": return 10.0
		"sundering_blow": return 11.0
	return 0.0

static func multiplier_for_skill(skill_id: String) -> float:
	match skill_id:
		"power_strike": return 1.55
		"cleave": return 1.10
		"sundering_blow": return 1.35
	return 1.0
