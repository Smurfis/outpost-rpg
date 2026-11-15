extends RefCounted
## Single item presentation model for HUD, inventory, crafting and bank UIs.
## Do not equate dungeon portal quality or bag-star quality with item rarity.
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS: Array[Color] = [
	Color("#b5ada2"),
	Color("#70b75e"),
	Color("#548fce"),
	Color("#b77ce0"),
	Color("#e3a353")
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

static func description(item_id: String, recipes: Array) -> String:
	for recipe in recipes:
		if not recipe is Dictionary:
			continue
		if str(recipe.get("result", "")) == item_id:
			var value: String = str(recipe.get("desc", "")).strip_edges()
			if not value.is_empty():
				return value
	return "No item description is available yet."
