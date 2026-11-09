extends RefCounted
## Shared framed inventory/item tile. No fake item rarity, no imported
## nine-slice textures. Used by Albion bag and crafting bag listings.
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
const HUD_V2 = preload("res://scripts/ui/hud_v2_components.gd")

static func icon_frame(item_rarity: int = -1) -> StyleBoxFlat:
	return HUD_V2.loot_icon_border(item_rarity)

static func apply_item_frame(button: Button, item_rarity: int = -1, selected: bool = false, light: bool = false) -> void:
	var true_rarity_border: Color = icon_frame(item_rarity).border_color
	for state in ["normal", "hover", "pressed", "disabled"]:
		var current: bool = selected or state in ["hover", "pressed"]
		var box: StyleBoxFlat = SKIN.translucent_surface(light, current, true)
		box.border_color = true_rarity_border
		# Selection is NOT a rarity. A heavier border/background indicates
		# the selected tile without inventing a quality attribute.
		box.set_border_width_all(3 if selected else 2)
		if selected and item_rarity < 0:
			box.border_color = Color("#d7b879")
		if state == "disabled":
			box.bg_color.a *= 0.55
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", SKIN.flat("transparent"))

static func add_quantity_badge(button: Button, quantity: int, id: String = "ItemCount") -> Panel:
	var bubble := Panel.new()
	bubble.name = "ItemQuantityBubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_stylebox_override("panel", HUD_V2.loot_quantity_badge())
	bubble.anchor_left = 0.56
	bubble.anchor_top = 0.59
	bubble.anchor_right = 1.02
	bubble.anchor_bottom = 1.03
	button.add_child(bubble)
	var number := Label.new()
	number.name = id
	number.text = str(maxi(0, quantity))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.add_theme_color_override("font_color", Color("#f8eacd"))
	number.add_theme_color_override("font_outline_color", Color("#1b1416"))
	number.add_theme_constant_override("outline_size", 1)
	number.add_theme_font_size_override("font_size", 12)
	bubble.add_child(number)
	number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bubble
