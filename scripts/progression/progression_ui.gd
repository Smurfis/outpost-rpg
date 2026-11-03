extends CanvasLayer
## Separate landscape-friendly progression screen: craft gear, equip, learn skills,
## socket skills, inspect four combat stats, safely salvage single/bulk items.
const GEAR = preload("res://scripts/progression/gear_service.gd")
const SKILLS = preload("res://scripts/progression/skill_service.gd")
const SALVAGE = preload("res://scripts/progression/salvage_service.gd")
const PAGES: Array[String] = ["gear", "equipment", "skills", "salvage"]
const COLORS: Dictionary = {"red": Color("e98075"), "yellow": Color("e8d28b"), "blue": Color("88bfed"), "prismatic": Color("dcb4f6")}

var game
var root: Control
var title: Label
var subtitle: Label
var tabs: HBoxContainer
var listing: VBoxContainer
var details: VBoxContainer
var page: String = "gear"
var selected_template: String = "pioneer_blade"
var selected_uid: String = ""
var selected_skill: String = "power_strike"
var level: int = 5
var rarity: int = 0
var selection: Dictionary = {}
var confirming: bool = false

func setup(ref: Node) -> void:
	game = ref

func _ready() -> void:
	layer = 26
	root = Control.new()
	root.name = "ProgressionOverlay"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.006, 0.015, 0.020, 0.85)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := PanelContainer.new()
	frame.anchor_left = 0.055
	frame.anchor_right = 0.945
	frame.anchor_top = 0.045
	frame.anchor_bottom = 0.955
	frame.add_theme_stylebox_override("panel", _style(Color("182c32"), Color("bfaa78")))
	root.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	title = _text("OUTPOST | PROGRESSION", 27, Color("f0dbab"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := Button.new()
	close.text = "X CLOSE"
	close.custom_minimum_size = Vector2(100, 52)
	close.pressed.connect(close_page)
	heading.add_child(close)
	subtitle = _text("", 17, Color("c7d7cb"))
	column.add_child(subtitle)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 12)
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panes)
	var left := ScrollContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.72
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panes.add_child(left)
	listing = VBoxContainer.new()
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.add_theme_constant_override("separation", 8)
	left.add_child(listing)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.28
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panes.add_child(right)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	right.add_child(details)
	visible = false

func _style(color: Color, edge: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(11)
	return style

func _text(message: String, text_size: int = 19, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", text_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(message: String, action: Callable, disabled: bool = false, tint: Color = Color.WHITE) -> Button:
	var button := Button.new()
	button.text = message
	button.disabled = disabled
	button.modulate = tint
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button

func _panel(parent: Node, color: Color = Color("293c3c")) -> VBoxContainer:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", _style(color))
	parent.add_child(holder)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	holder.add_child(box)
	return box

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func open(destination: String = "gear") -> void:
	if destination in PAGES:
		page = destination
	visible = true
	confirming = false
	selection.clear()
	if game.menu != null:
		game.menu.close_page()
	if game.hud != null:
		game.hud.move_vector = Vector2.ZERO
	refresh()

func close_page() -> void:
	visible = false
	confirming = false

func refresh() -> void:
	if not visible or tabs == null:
		return
	_clear(tabs)
	_clear(listing)
	_clear(details)
	title.text = "OUTPOST | " + page.to_upper()
	var station: String = game.closest_station()
	subtitle.text = "Nearby station: " + (station.replace("_", " ").capitalize() if station != "" else "None (browse anywhere)")
	for p in PAGES:
		var tab := _button(p.to_upper(), _change_page.bind(p), false, Color("e2d3aa") if p == page else Color("b3c9c9"))
		tabs.add_child(tab)
	match page:
		"gear":
			_render_gear()
		"equipment":
			_render_equipment()
		"skills":
			_render_skills()
		"salvage":
			_render_salvage()

func _change_page(to: String) -> void:
	page = to
	confirming = false
	selection.clear()
	refresh()

func _stats() -> void:
	var stats: Dictionary = game.gear_stats()
	var bar := _panel(details, Color("263e43"))
	bar.add_child(_text("FOUR PRIMARY COMBAT STATS", 20, Color("e5d39c")))
	bar.add_child(_text("Damage  %.1f     Attack Speed  %.2f /sec" % [float(stats["damage"]), float(stats["attack_speed"])], 17))
	bar.add_child(_text("Crit  %.1f%%     Ability Power  %.1f" % [float(stats["crit"]) * 100.0, float(stats["ability_power"])], 17))
	bar.add_child(_text("Armour reduces incoming damage by %.1f%% (derived from item level, not a primary stat)." % [float(stats["mitigation"]) * 100.0], 15, Color("a7c3c1")))

func _render_gear() -> void:
	for definition in GEAR.definitions():
		var id: String = str(definition.get("id", ""))
		listing.add_child(_button(str(definition.get("name", id)), _choose_template.bind(id), false, Color("ead3ab") if id == selected_template else Color.WHITE))
	var item: Dictionary = GEAR.template(selected_template)
	if item.is_empty():
		return
	var card := _panel(details)
	card.add_child(_text(str(item.get("name", "")), 23, Color("eddda8")))
	card.add_child(_text(str(item.get("description", "")), 17, Color("bfcfc5")))
	card.add_child(_text("Slot: %s   •   Station: %s" % [str(item.get("slot", "")).capitalize(), str(item.get("station", "")).capitalize()], 16))
	var tiers := HBoxContainer.new()
	card.add_child(tiers)
	tiers.add_child(_button("− 5 LVL", _level_delta.bind(-5), level <= 1))
	tiers.add_child(_text("LEVEL %d" % level, 20, Color("f7dfb2")))
	tiers.add_child(_button("+ 5 LVL", _level_delta.bind(5), level >= 50))
	card.add_child(_button("RARITY: %s  (TAP TO CHANGE)" % GEAR.rarity_name(rarity), _cycle_rarity))
	var rarity_tint: Color = [Color("bcbcb6"),Color("95ca9a"),Color("81b4e4"),Color("c8a1ec"),Color("edc48c")][rarity]
	card.add_child(_text("Item Level determines strength. Rarity controls socket possibilities.", 16, rarity_tint))
	var predicted: Dictionary = GEAR.item_stats({"template":selected_template,"item_level":level})
	card.add_child(_text("Base contribution: Damage +%.1f   Speed +%.2f   Crit +%.1f%%   AP +%.1f" % [float(predicted["damage"]), float(predicted["attack_speed"]), float(predicted["crit"]) * 100.0, float(predicted["ability_power"])], 16))
	var cost: Dictionary = GEAR.recipe_cost(selected_template, level, rarity)
	var cost_box := _panel(details, Color("324244"))
	cost_box.add_child(_text("REQUIRED MATERIALS", 18, Color("e6d4a2")))
	for key in cost:
		var owned: int = int(game.inventory.get(str(key), 0))
		var need: int = int(cost[key])
		cost_box.add_child(_text("%s   %d / %d" % [str(key).replace("_"," ").capitalize(), owned, need], 17, Color("abd6b2") if owned >= need else Color("dfa297")))
	var allowed: bool = game.near_station(str(item.get("station", ""))) and GEAR.can_pay(game.inventory, cost)
	details.add_child(_button("CRAFT EQUIPMENT", _make_gear, not allowed, rarity_tint))
	details.add_child(_text("Gear is only created here at the station. A fresh socket seed is rolled once and permanently saved.", 15, Color("adbfb8")))
	_stats()

func _choose_template(id: String) -> void:
	selected_template = id
	refresh()

func _level_delta(delta: int) -> void:
	level = clampi(level + delta, 1, 50)
	refresh()

func _cycle_rarity() -> void:
	rarity = (rarity + 1) % 5
	refresh()

func _make_gear() -> void:
	if game.craft_gear(selected_template, level, rarity):
		var newest: Dictionary = game.crafted_gear.back()
		selected_uid = str(newest.get("uid", ""))
		page = "equipment"
		refresh()

func _gear(uid: String) -> Dictionary:
	for item in game.crafted_gear:
		if item is Dictionary and str(item.get("uid", "")) == uid:
			return item
	return {}

func _render_equipment() -> void:
	if game.crafted_gear.is_empty():
		listing.add_child(_text("No crafted equipment yet.\nUse the GEAR tab at a forge or loom.", 18))
	else:
		for item in game.crafted_gear:
			var uid: String = str(item.get("uid", ""))
			var rarity_name: String = GEAR.rarity_name(int(item.get("rarity", 0)))
			var active: bool = str(game.gear_loadout.get(str(item.get("slot", "")), "")) == uid
			var prefix: String = "● " if active else ""
			var gear_caption: String = "%s%s  Lv.%d\n%s  %s" % [prefix, str(item.get("name", "")), int(item.get("item_level", 1)), rarity_name, str(item.get("slot", ""))]
			listing.add_child(_button(gear_caption, _select_gear.bind(uid), false, Color("eddbab") if uid == selected_uid else Color("d2dfdb")))
	if selected_uid == "" and not game.crafted_gear.is_empty():
		selected_uid = str(game.crafted_gear[0].get("uid", ""))
	var current: Dictionary = _gear(selected_uid)
	if current.is_empty():
		_stats()
		return
	var section := _panel(details)
	section.add_child(_text(str(current.get("name", "")) + "  •  " + GEAR.rarity_name(int(current.get("rarity", 0))), 23, Color("efdcab")))
	section.add_child(_text("Item Level %d  |  %s" % [int(current.get("item_level", 1)), str(current.get("slot", ""))], 17))
	var stats: Dictionary = GEAR.item_stats(current)
	section.add_child(_text("Damage +%.1f | Attack Speed +%.2f\nCrit +%.1f%% | Ability Power +%.1f" % [float(stats["damage"]), float(stats["attack_speed"]), float(stats["crit"]) * 100.0, float(stats["ability_power"])], 17))
	var current_uid: String = str(current.get("uid", ""))
	var equipped: bool = str(game.gear_loadout.get(str(current.get("slot", "")), "")) == current_uid
	section.add_child(_button("UNEQUIP" if equipped else "EQUIP", _equip.bind(current_uid)))
	section.add_child(_button("UNLOCK ITEM" if bool(current.get("locked", false)) else "LOCK ITEM", _toggle_flag.bind(current_uid,"locked")))
	section.add_child(_button("REMOVE FAVOURITE" if bool(current.get("favourite", false)) else "FAVOURITE", _toggle_flag.bind(current_uid,"favourite")))
	var equipped_item: Dictionary = GEAR.get_equipped(game.crafted_gear, game.gear_loadout, str(current.get("slot", "")))
	if not equipped_item.is_empty() and str(equipped_item.get("uid", "")) != current_uid:
		var old_stats: Dictionary = GEAR.item_stats(equipped_item)
		section.add_child(_text("VERSUS EQUIPPED %s  •  DAMAGE %+.1f  SPEED %+.2f  CRIT %+.1f%%  AP %+.1f" % [str(equipped_item.get("name", "")), float(stats["damage"]) - float(old_stats["damage"]), float(stats["attack_speed"]) - float(old_stats["attack_speed"]), (float(stats["crit"]) - float(old_stats["crit"])) * 100.0, float(stats["ability_power"]) - float(old_stats["ability_power"])], 16, Color("c6d8d4")))
	section.add_child(_text("Sockets (rolled at crafting, never on equip/reload)", 17, Color("d5c7ae")))
	var sockets: Array = current.get("sockets", [])
	for i in range(sockets.size()):
		var socket: Dictionary = sockets[i]
		var color_name: String = str(socket.get("color", ""))
		var skill_name: String = str(socket.get("skill", ""))
		section.add_child(_text("%d. %s SOCKET  •  %s" % [i + 1, color_name.to_upper(), ("EMPTY" if skill_name == "" else skill_name.replace("_"," ").capitalize())], 17, COLORS.get(color_name, Color.WHITE)))
	if int(current.get("rarity", 0)) == 4 and int(current.get("item_level", 0)) >= 15:
		var exists: bool = false
		for socket in sockets:
			if str(socket.get("color", "")) == "prismatic":
				exists = true
		section.add_child(_button("INSTALL PRISMATIC GEM  •  OWNED %d" % int(game.inventory.get("prismatic_gem", 0)), _install_gem.bind(current_uid), exists or int(game.inventory.get("prismatic_gem", 0)) < 1 or not game.near_station("skill_forge"), Color("dcb4f6")))
	section.add_child(_button("OPEN SKILL LIBRARY / FORGE", _change_page.bind("skills")))
	_stats()

func _select_gear(uid: String) -> void:
	selected_uid = uid
	refresh()

func _equip(uid: String) -> void:
	game.equip_crafted(uid)
	refresh()

func _toggle_flag(uid: String, flag: String) -> void:
	game.toggle_gear_flag(uid, flag)
	refresh()

func _render_skills() -> void:
	for skill in SKILLS.all_skills():
		var id: String = str(skill.get("id", ""))
		var color_name: String = str(skill.get("family", ""))
		var owned: bool = bool(game.learned_skills.get(id, false))
		var caption: String = ("%s %s " % ["✓" if owned else "○", str(skill.get("name", id))]) + "(" + color_name.to_upper() + ")"
		var entry_line := HBoxContainer.new()
		listing.add_child(entry_line)
		var image := TextureRect.new()
		image.texture = load("res://assets/icons/skills/" + id + ".svg") as Texture2D
		image.custom_minimum_size = Vector2(51, 51)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry_line.add_child(image)
		entry_line.add_child(_button(caption, _select_skill.bind(id), false, COLORS.get(color_name, Color.WHITE)))
	var skill: Dictionary = SKILLS.definition(selected_skill)
	if skill.is_empty():
		return
	var card := _panel(details)
	var family: String = str(skill.get("family", ""))
	var large_icon := TextureRect.new()
	large_icon.texture = load("res://assets/icons/skills/" + selected_skill + ".svg") as Texture2D
	large_icon.custom_minimum_size = Vector2(82, 82)
	large_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	large_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(large_icon)
	card.add_child(_text(str(skill.get("name", "")), 23, COLORS.get(family, Color.WHITE)))
	card.add_child(_text(str(skill.get("desc", "")), 18))
	card.add_child(_text("Colour: %s    Cooldown: %.1fs" % [family.to_upper(), float(skill.get("cooldown", 0))], 16))
	var book_id: String = str(skill.get("book", ""))
	var count: int = int(game.inventory.get(book_id, 0))
	var known: bool = bool(game.learned_skills.get(selected_skill, false))
	card.add_child(_text("Skill book: %d owned  •  %s" % [count, "LEARNED" if known else "NOT LEARNED"], 18))
	card.add_child(_text("CRAFT A BOOK: 3 ether dust + 1 linen + 1 crystal shard", 16, Color("cfddd5")))
	card.add_child(_button("FORGE SKILL BOOK", _craft_book.bind(selected_skill), not game.near_station("skill_forge") or not GEAR.can_pay(game.inventory, {"ether_dust":3, "linen":1, "crystal_shard":1})))
	card.add_child(_button("LEARN BOOK", _learn.bind(book_id), count == 0 or known or not game.near_station("skill_forge")))
	card.add_child(_button("RECYCLE DUPLICATE → 2 ETHER DUST", _recycle_book.bind(book_id), count == 0 or not known or not game.near_station("skill_forge")))
	var sockets := _panel(details, Color("2a3b43"))
	sockets.add_child(_text("EQUIPPED GEAR SOCKETS", 19, Color("eed4a0")))
	var possible: int = 0
	for item in game.crafted_gear:
		if not (item is Dictionary):
			continue
		var uid: String = str(item.get("uid", ""))
		if str(game.gear_loadout.get(str(item.get("slot", "")), "")) != uid:
			continue
		var list: Array = item.get("sockets", [])
		for i in range(list.size()):
			var socket: Dictionary = list[i]
			var color_id: String = str(socket.get("color", ""))
			var matched: bool = SKILLS.compatible(socket, skill)
			var button := _button("%s: %s  •  %s" % [str(item.get("name", "")), color_id.to_upper(), "ASSIGN" if matched else "INCOMPATIBLE"], _assign.bind(uid, i, selected_skill), not known or not matched or not game.near_station("skill_forge"), COLORS.get(color_id, Color.WHITE))
			button.tooltip_text = "%s socket — %s" % [color_id, "Accepts all colours" if color_id == "prismatic" else "Only %s skills" % color_id]
			sockets.add_child(button)
			possible += 1
	if possible == 0:
		sockets.add_child(_text("Equip crafted gear to see socket choices.", 16))
	sockets.add_child(_text("Learn and assign books at the SKILL FORGE. Prismatic legendary sockets accept any colour.", 16, Color("bdcbd1")))
	var available: Array = SKILLS.active_skills(game.crafted_gear, game.gear_loadout, game.learned_skills)
	if not available.is_empty():
		sockets.add_child(_button("CAST FIRST EQUIPPED ABILITY", _cast, false, Color("b5d4ed")))
	_stats()

func _select_skill(id: String) -> void:
	selected_skill = id
	refresh()

func _craft_book(id: String) -> void:
	game.craft_skill_book(id)
	refresh()

func _install_gem(uid: String) -> void:
	game.apply_prismatic_gem(uid)
	refresh()

func _learn(book: String) -> void:
	game.skill_learn(book)
	refresh()

func _recycle_book(book: String) -> void:
	game.recycle_book(book)
	refresh()

func _assign(uid: String, index: int, id: String) -> void:
	game.socket_skill(uid, index, id)
	refresh()

func _cast() -> void:
	close_page()
	if not game.cast_skill(selected_skill):
		game.cast_skill()

func _render_salvage() -> void:
	var protected_count: int = 0
	for item in game.crafted_gear:
		var uid: String = str(item.get("uid", ""))
		var safe: bool = SALVAGE.protected(item, game.gear_loadout)
		if safe:
			protected_count += 1
		var checkbox := CheckBox.new()
		checkbox.text = "%s Lv.%d%s" % [str(item.get("name", uid)), int(item.get("item_level", 1)), "  •  PROTECTED" if safe else ""]
		checkbox.button_pressed = bool(selection.get(uid, false))
		checkbox.disabled = safe
		checkbox.toggled.connect(_select_salvage.bind(uid))
		listing.add_child(checkbox)
	var info := _panel(details)
	info.add_child(_text("SALVAGE STATION", 23, Color("e8d0a2")))
	info.add_child(_text("Equipped, locked and favourite items cannot be salvaged. Prismatic gems are NOT automatically recovered intact.", 16))
	info.add_child(_text("Protected gear: %d item(s)" % protected_count, 16))
	info.add_child(_button("SELECT ALL SAFE GEAR", _select_all))
	info.add_child(_button("CLEAR SELECTION", _clear_selection))
	var chosen: Array = _chosen_safe()
	var preview: Dictionary = {}
	for uid in chosen:
		var item: Dictionary = _gear(str(uid))
		if item.is_empty():
			continue
		var refund: Dictionary = SALVAGE.refund(item)
		for key in refund:
			preview[str(key)] = int(preview.get(str(key), 0)) + int(refund[key])
	info.add_child(_text("RETURN PREVIEW (%d item(s))" % chosen.size(), 19, Color("f2d7ac")))
	for key in preview:
		info.add_child(_text("%s  +%d" % [str(key).replace("_"," ").capitalize(), int(preview[key])], 17, Color("acd2b7")))
	if chosen.size() == 0:
		info.add_child(_text("Select one or more unprotected items.", 16))
	if confirming:
		info.add_child(_text("CONFIRM DESTRUCTION — this cannot be undone.", 18, Color("eea7a2")))
		info.add_child(_button("YES — DISMANTLE SELECTED", _confirm_salvage, chosen.is_empty() or not game.near_station("salvage")))
		info.add_child(_button("CANCEL", _cancel_confirmation))
	else:
		info.add_child(_button("PREVIEW & CONFIRM SALVAGE", _request_salvage, chosen.is_empty() or not game.near_station("salvage")))
	_stats()

func _chosen_safe() -> Array:
	var result: Array = []
	for item in game.crafted_gear:
		var uid: String = str(item.get("uid", ""))
		if bool(selection.get(uid, false)) and not SALVAGE.protected(item, game.gear_loadout):
			result.append(uid)
	return result

func _select_salvage(checked: bool, uid: String) -> void:
	selection[uid] = checked
	confirming = false
	refresh()

func _select_all() -> void:
	for item in game.crafted_gear:
		if not SALVAGE.protected(item, game.gear_loadout):
			selection[str(item.get("uid", ""))] = true
	confirming = false
	refresh()

func _clear_selection() -> void:
	selection.clear()
	confirming = false
	refresh()

func _request_salvage() -> void:
	confirming = true
	refresh()

func _cancel_confirmation() -> void:
	confirming = false
	refresh()

func _confirm_salvage() -> void:
	var chosen: Array = _chosen_safe()
	if chosen.is_empty() or not game.near_station("salvage"):
		return
	game.salvage_bulk(chosen)
	selection.clear()
	confirming = false
	refresh()
