extends RefCounted
## Presentation data shared by desktop hover and touch inspection.
const ITEMS = preload("res://scripts/ui/outpost_item_view.gd")
const LEVELS = preload("res://scripts/progression/character_levels.gd")

static func item(game: Node, id: String) -> String:
	if id.is_empty():
		return "Empty slot\nAssign an owned item from Inventory."
	return "%s ×%d%s\n%s" % [ITEMS.display_name(id), int(game.inventory.get(id, 0)),
		" · Equipped" if game.is_equipped(id) else "", ITEMS.description(id, game.recipes)]

static func skill(game: Node, slot: int) -> String:
	var id: String = LEVELS.skill_for_slot(slot)
	if id == "":
		return "Unknown ability"
	var description: String = ""
	match id:
		"power_strike":
			description = "A powerful single-target sword strike."
		"armor_break":
			description = "Deals damage and weakens the target for 6s.\nYour physical attacks deal +25% damage."
		"whirlwind":
			description = "Spin twice with a golden sword trail.\nHit every nearby foe once in a %.1fm circle." % LEVELS.WHIRLWIND_RADIUS
	var rank: int = game.mastery_rank(game.current_weapon_id())
	var required: int = LEVELS.unlock_level_for_slot(slot)
	var lock: String = "\nUNLOCK AT WEAPON LEVEL %d (CURRENT: %d)" % [required, rank] if slot >= game.unlocked_skill_slots() else ""
	return "%s  •  WEAPON LV %d\n%s\n%.0f%% weapon damage · %d MP\nCooldown %.0fs · %.1fs remaining%s" % [
		LEVELS.skill_name_for_slot(slot), required, description,
		LEVELS.multiplier_for_skill(id) * 100.0, 6 + slot * 3,
		LEVELS.cooldown_for_skill(id), float(game.skill_cooldowns.get(id, 0.0)), lock]

static func world(game: Node, target: Node3D) -> String:
	if not is_instance_valid(target):
		return ""
	if target.is_in_group("enemies"):
		return "%s · %.0f HP\nAttack" % [game.enemy_display_name(target), float(target.hp)]
	if target.is_in_group("resources"):
		var action: String = "Chop" if target.kind == "wood" else "Mine" if target.kind in ["stone", "iron", "coal"] else "Net shrimp" if target.kind == "shrimp" else "Gather"
		return "%s%s\n%s · %d actions left%s" % ["Shrimp pool" if target.kind == "shrimp" else ITEMS.display_name(target.kind),
			" · Bundle ×%d" % target.bundle_count if target.bundle_count > 1 else "", action, target.hits_left,
			"\nRequires equipped Shrimp net (6 fibre at Workbench)." if target.kind == "shrimp" else ""]
	if target.is_in_group("stations"):
		return "%s\nOpen crafting" % str(target.station_id).capitalize()
	if target.has_method("inspection_text"):
		return str(target.inspection_text())
	return "%s\n%s" % [str(target.get_meta("display_name", target.name)).replace("_", " "),
		str(target.get_meta("world_action", "Interact"))]
