extends RefCounted
## Single item presentation model for HUD, inventory, crafting and bank UIs.
## Five-star rating means ITEM rarity, never portal difficulty or the independent
## 0-3 bag-capacity upgrade stars.
const QUALITY = preload("res://scripts/crafting/equipment_quality.gd")
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS: Array[Color] = [
	Color("#a6adad"),
	Color("#55b777"),
	Color("#568de0"),
	Color("#ae69da"),
	Color("#e4b35b")
]

static func display_name(item_id: String) -> String:
	return item_id.replace("_", " ").capitalize()

static func rarity_name(item_rarity: int) -> String:
	if item_rarity < 0 or item_rarity >= RARITY_NAMES.size():
		return "Rarity not assigned"
	return RARITY_NAMES[item_rarity]

static func rarity_color(item_rarity: int) -> Color:
	if item_rarity < 0 or item_rarity >= RARITY_COLORS.size():
		return Color("#e2d4bd")
	return RARITY_COLORS[item_rarity]

## Existing crafted rarity is authoritative. Legacy/starter gear is Common,
## while ungraded materials and bag-upgrade levels have no implied item rarity.
static func item_rarity(item_id: String, crafted_rolls: Dictionary) -> int:
	if crafted_rolls.has(item_id):
		var raw_roll: Variant = crafted_rolls[item_id]
		if raw_roll is Dictionary and (raw_roll as Dictionary).has("rarity"):
			return clampi(int((raw_roll as Dictionary)["rarity"]), 0, 4)
	if item_id == "training_blade" or QUALITY.is_gear(item_id):
		return 0
	return -1

static func rarity_stars(item_rarity: int) -> String:
	if item_rarity < 0 or item_rarity >= RARITY_NAMES.size():
		return ""
	return "★".repeat(item_rarity + 1) + "☆".repeat(4 - item_rarity)

## One shared star strip gives filled and unfilled stars distinct contrast.
## It is decorative and ignores touch so item tiles remain easy to tap/drag.
static func make_star_strip(item_rarity: int, size_px: int = 11) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.name = "ItemRarityStars"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 0)
	if item_rarity < 0 or item_rarity >= RARITY_NAMES.size():
		return strip
	for index in range(5):
		var star := Label.new()
		star.name = "RarityStar_%d" % index
		star.text = "★" if index <= item_rarity else "☆"
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.add_theme_font_size_override("font_size", size_px)
		star.add_theme_color_override("font_color", rarity_color(item_rarity) if index <= item_rarity else Color("#5b534a"))
		star.add_theme_color_override("font_outline_color", Color("#21160f"))
		star.add_theme_constant_override("outline_size", 1)
		strip.add_child(star)
	return strip

static func rarity_caption(item_rarity: int) -> String:
	if item_rarity < 0 or item_rarity >= RARITY_NAMES.size():
		return ""
	return rarity_stars(item_rarity) + "  " + rarity_name(item_rarity)

static func description(item_id: String, recipes: Array) -> String:
	for recipe in recipes:
		if not recipe is Dictionary:
			continue
		if str(recipe.get("result", "")) == item_id:
			var value: String = str(recipe.get("desc", "")).strip_edges()
			if not value.is_empty():
				return value
	return "No item description is available yet."
