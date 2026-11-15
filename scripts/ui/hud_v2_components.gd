extends RefCounted
## Transparent utility surfaces shared by Quest, Last Gathered, and future
## Settings/Changelog section cards. These are intentionally NOT modal frames.
## Illustrative wood/bronze artwork remains a separate, reviewable art pass.
static func utility_card() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.08, 0.54)
	style.border_color = Color(0.79, 0.57, 0.33, 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5)
	style.anti_aliasing = false
	return style

static func effect_icon(is_debuff: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#39202c") if is_debuff else Color("#233b2f")
	style.border_color = Color("#d4677c") if is_debuff else Color("#a4bf69")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(2)
	style.anti_aliasing = false
	return style

## Future-ready rarity frame for actual item-quality data.
## -1 denotes unknown/untracked item quality, never assume it is Rare.
static func loot_icon_border(item_rarity: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var colors: Array[Color] = [
		Color("#b5ada2"), # Common
		Color("#70b75e"), # Uncommon
		Color("#548fce"), # Rare
		Color("#b77ce0"), # Epic
		Color("#e3a353")  # Legendary
	]
	style.bg_color = Color("#261c1c")
	style.border_color = Color("#83766c") if item_rarity < 0 else colors[clampi(item_rarity, 0, 4)]
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(2)
	style.anti_aliasing = false
	return style

## Quantity medallion intentionally lives inside a single icon button.
## Copied conceptually from Roblox MMORPG_Framework's framed-icon pattern.
static func loot_quantity_badge() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#242026")
	style.border_color = Color("#ccac71")
	style.set_border_width_all(1)
	style.set_corner_radius_all(99)
	style.set_content_margin_all(0)
	style.anti_aliasing = true
	return style
