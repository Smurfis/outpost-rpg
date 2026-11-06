extends Control
## Touch-first, Albion-inspired Outpost inventory. Visual layout only:
## reads the existing inventory/equipment/carry data and invokes game APIs.
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
const CARRY = preload("res://scripts/inventory/carry_capacity.gd")
const TOUCH_SCROLL = preload("res://scripts/ui/touch_scroll_container.gd")
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "offhand", "back", "bag", "tool_wood", "tool_mining", "tool_forage"]
const SLOT_NAMES: Dictionary = {
	"weapon":"MAIN HAND", "offhand":"OFF HAND", "back":"CLOAK", "bag":"BACKPACK",
	"tool_wood":"WOODCUTTING", "tool_mining":"MINING", "tool_forage":"FORAGING"
}
const CONSUMABLES: Array[String] = ["meal", "tonic", "stew"]
var game
var menu
var window: PanelContainer
var item_card: PanelContainer
var item_info: VBoxContainer
var equipment_body: Control
var equipment_toggle: Button
var inventory_grid: GridContainer
var scroll: ScrollContainer
var bag_weight_label: Label
var bag_meter: ProgressBar
var overflow_button: Button
var filter_buttons: Dictionary = {}
var filter_kind: String = "all"
var sort_kind: String = "name"
var selected_id: String = ""
var selected_slot: String = ""
var equipment_expanded: bool = true
var preview_rig: Node3D

func setup(game_ref: Node, menu_ref: Node) -> void:
	game = game_ref
	menu = menu_ref

func _ready() -> void:
	name = "AlbionInspiredInventory"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var outside := ColorRect.new()
	outside.name = "CloseOnOutsideTap"
	outside.color = Color(0.02, 0.01, 0.01, 0.15)
	outside.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(outside)
	outside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outside.gui_input.connect(_outside_input)

	window = PanelContainer.new()
	window.name = "InventoryWindow"
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	window.add_theme_stylebox_override("panel", SKIN.box("frame"))
	add_child(window)
	var layout := VBoxContainer.new()
	layout.name = "InventoryLayout"
	layout.add_theme_constant_override("separation", 5)
	window.add_child(layout)

	var heading := HBoxContainer.new()
	layout.add_child(heading)
	heading.add_child(_text("◈  INVENTORY", 23, SKIN.GOLD, true))
	var switch_craft := _button("CRAFT", "wood")
	switch_craft.custom_minimum_size = Vector2(76, 44)
	switch_craft.pressed.connect(func() -> void: menu.open("craft"))
	heading.add_child(switch_craft)
	var close := _button("✕", "red")
	close.name = "InventoryCloseButton"
	close.custom_minimum_size = Vector2(46, 46)
	close.pressed.connect(func() -> void: menu.close_page())
	heading.add_child(close)

	equipment_toggle = _button("EQUIPMENT  ▴", "wood")
	equipment_toggle.name = "EquipmentCollapse"
	equipment_toggle.custom_minimum_size = Vector2(0, 38)
	equipment_toggle.pressed.connect(_toggle_equipment)
	layout.add_child(equipment_toggle)
	var equipment_section := PanelContainer.new()
	equipment_section.name = "CharacterEquipmentSection"
	equipment_section.add_theme_stylebox_override("panel", SKIN.box("parchment"))
	equipment_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(equipment_section)
	equipment_body = VBoxContainer.new()
	equipment_body.name = "EquippedSlots"
	(equipment_body as VBoxContainer).add_theme_constant_override("separation", 2)
	equipment_section.add_child(equipment_body)

	var weight_block := VBoxContainer.new()
	weight_block.add_theme_constant_override("separation", 2)
	layout.add_child(weight_block)
	bag_weight_label = _text("LOAD 0 / 36", 15, SKIN.CREAM)
	bag_weight_label.name = "BagCapacityLabel"
	weight_block.add_child(bag_weight_label)
	bag_meter = ProgressBar.new()
	bag_meter.name = "BagCapacityMeter"
	bag_meter.show_percentage = false
	bag_meter.custom_minimum_size = Vector2(0, 12)
	var bar_back := SKIN.flat("inset")
	bar_back.set_border_width_all(0)
	var bar_front := SKIN.flat("green")
	bar_front.set_border_width_all(0)
	bag_meter.add_theme_stylebox_override("background", bar_back)
	bag_meter.add_theme_stylebox_override("fill", bar_front)
	weight_block.add_child(bag_meter)

	var controls := HBoxContainer.new()
	controls.name = "BagFilters"
	controls.add_theme_constant_override("separation", 3)
	layout.add_child(controls)
	for filter_id in ["all", "material", "equipment", "consumable"]:
		var tab := _button({"all":"ALL", "material":"MATS", "equipment":"GEAR", "consumable":"FOOD"}[filter_id], "wood")
		tab.name = "BagFilter_" + filter_id
		tab.custom_minimum_size = Vector2(48, 39)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 14)
		tab.pressed.connect(_change_filter.bind(filter_id))
		filter_buttons[filter_id] = tab
		controls.add_child(tab)
	var sort_button := _button("SORT", "wood")
	sort_button.name = "BagSortButton"
	sort_button.custom_minimum_size = Vector2(62, 39)
	sort_button.add_theme_font_size_override("font_size", 14)
	sort_button.pressed.connect(_cycle_sort)
	controls.add_child(sort_button)

	var bag_area := PanelContainer.new()
	bag_area.name = "CarriedItems"
	bag_area.add_theme_stylebox_override("panel", SKIN.box("parchment"))
	bag_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(bag_area)
	scroll = TOUCH_SCROLL.new()
	scroll.name = "BagScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_area.add_child(scroll)
	inventory_grid = GridContainer.new()
	inventory_grid.name = "BagItemGrid"
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 4)
	inventory_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(inventory_grid)
	overflow_button = _button("", "green")
	overflow_button.name = "RecoverStoredLoot"
	overflow_button.custom_minimum_size = Vector2(0, 36)
	overflow_button.pressed.connect(func() -> void:
		game.claim_overflow()
		refresh()
	)
	overflow_button.visible = false
	layout.add_child(overflow_button)
	layout.add_child(_text("Tap to inspect  •  Items auto-stack", 13, SKIN.CREAM))

	item_card = PanelContainer.new()
	item_card.name = "InventoryItemDetails"
	item_card.add_theme_stylebox_override("panel", SKIN.box("frame"))
	item_card.visible = false
	add_child(item_card)
	item_info = VBoxContainer.new()
	item_info.name = "ItemInformation"
	item_info.add_theme_constant_override("separation", 8)
	item_card.add_child(item_info)
	get_viewport().size_changed.connect(_layout_windows)
	_layout_windows()
	visible = false

func open_page(page: String) -> void:
	visible = true
	if page == "equipment":
		equipment_expanded = true
		filter_kind = "equipment"
		selected_slot = "weapon"
	elif page == "bag":
		filter_kind = "all"
		selected_slot = ""
	# The two entry points share one actual layout, not two competing modals.
	_layout_windows()
	refresh()

func close_page() -> void:
	item_card.visible = false
	visible = false

func _layout_windows() -> void:
	if window == null:
		return
	var bounds: Vector2 = get_viewport().get_visible_rect().size
	var width_px: float = minf(500.0, maxf(330.0, bounds.x * 0.38))
	width_px = minf(width_px, bounds.x - 24.0)
	var height_px: float = maxf(220.0, bounds.y - 20.0)
	window.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	window.position = Vector2(bounds.x - width_px - 10.0, 10.0)
	window.size = Vector2(width_px, height_px)
	if item_card != null:
		var detail_width: float = minf(320.0, maxf(230.0, bounds.x * 0.27))
		var left_x: float = maxf(10.0, window.position.x - detail_width - 9.0)
		item_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		item_card.position = Vector2(left_x, minf(80.0, bounds.y * 0.12))
		item_card.size = Vector2(minf(detail_width, maxf(210.0, window.position.x - left_x - 6.0)), 0.0)
	if bounds.y < 560.0 and equipment_expanded:
		equipment_expanded = false
	# Rebuild responsive columns whenever the viewport size changes.
	if visible:
		refresh()

func _outside_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		menu.close_page()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		menu.close_page()

func _text(value: String, font_size: int = 16, color: Color = Color.WHITE, expand: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(value: String, skin_name: String) -> Button:
	var button := Button.new()
	button.text = value
	SKIN.apply_button(button, skin_name)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return button

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _icon(item_id: String, size_px: float) -> TextureRect:
	var rect := TextureRect.new()
	var path: String = "res://assets/icons/" + item_id + ".svg"
	if not ResourceLoader.exists(path):
		path = "res://assets/icons/flag.svg"
	rect.texture = load(path) as Texture2D
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect

func _toggle_equipment() -> void:
	equipment_expanded = not equipment_expanded
	refresh()

func _change_filter(kind: String) -> void:
	filter_kind = kind
	selected_id = ""
	item_card.visible = false
	refresh()

func _cycle_sort() -> void:
	sort_kind = "count" if sort_kind == "name" else "type" if sort_kind == "count" else "name"
	refresh()

func _kind(id: String) -> String:
	if CARRY.is_bag(id) or game.equipment_slot(id) != "":
		return "equipment"
	if id in CONSUMABLES:
		return "consumable"
	return "material"

func _ordered_items() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in game.inventory:
		var id: String = str(raw_id)
		if int(game.inventory.get(id, 0)) > 0 and (filter_kind == "all" or _kind(id) == filter_kind):
			ids.append(id)
	ids.sort_custom(_item_before)
	return ids

func _item_before(a: String, b: String) -> bool:
	if sort_kind == "count":
		var ca: int = int(game.inventory.get(a, 0))
		var cb: int = int(game.inventory.get(b, 0))
		return ca > cb if ca != cb else a < b
	if sort_kind == "type":
		var ta: String = _kind(a)
		var tb: String = _kind(b)
		return ta < tb if ta != tb else a < b
	return a < b

func refresh() -> void:
	if not visible or window == null:
		return
	equipment_toggle.text = "EQUIPMENT  ▴" if equipment_expanded else "EQUIPMENT  ▾"
	equipment_body.get_parent().visible = equipment_expanded
	if equipment_expanded:
		_render_equipment()
	for id in filter_buttons:
		SKIN.apply_button(filter_buttons[id], "wood_selected" if id == filter_kind else "wood")
		filter_buttons[id].add_theme_font_size_override("font_size", 14)
	_refresh_load()
	_render_items()
	_render_details()

func _render_equipment() -> void:
	_clear(equipment_body)
	var title := _text("YOUR ADVENTURER  •  LV. %d" % game.character_level(), 15, SKIN.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_body.add_child(title)
	var band := HBoxContainer.new()
	band.alignment = BoxContainer.ALIGNMENT_CENTER
	band.add_theme_constant_override("separation", 6)
	equipment_body.add_child(band)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	band.add_child(left)
	for slot in ["weapon", "offhand", "tool_wood"]:
		left.add_child(_gear_button(slot))
	var center := VBoxContainer.new()
	band.add_child(center)
	_add_avatar(center)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	band.add_child(right)
	for slot in ["back", "bag", "tool_mining"]:
		right.add_child(_gear_button(slot))
	var extra := _button("FORAGING  " + _equipped_name("tool_forage"), "parchment_light")
	extra.name = "EquipmentSlot_tool_forage"
	extra.custom_minimum_size = Vector2(0, 32)
	extra.add_theme_font_size_override("font_size", 13)
	extra.pressed.connect(_gear_clicked.bind("tool_forage"))
	equipment_body.add_child(extra)

func _gear_button(slot: String) -> Button:
	var id: String = str(game.equipment.get(slot, ""))
	var button := _button("", "wood_selected" if slot == selected_slot else "wood")
	button.name = "EquipmentSlot_" + slot
	button.custom_minimum_size = Vector2(54, 51)
	button.tooltip_text = SLOT_NAMES[slot] + ": " + _equipped_name(slot)
	button.pressed.connect(_gear_clicked.bind(slot))
	if id != "":
		var art: TextureRect = _icon(id, 37)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 6
		art.offset_top = 4
		art.offset_right = -6
		art.offset_bottom = -6
		button.add_child(art)
	else:
		button.text = "+"
	return button

func _equipped_name(slot: String) -> String:
	var id: String = str(game.equipment.get(slot, ""))
	return "EMPTY" if id == "" else id.replace("_", " ").capitalize()

func _add_avatar(parent: Node) -> void:
	if game.hero == null or game.hero.visual == null:
		parent.add_child(_icon("flag", 113))
		return
	var container := SubViewportContainer.new()
	container.name = "LiveAdventurerPreview"
	container.custom_minimum_size = Vector2(116, 162)
	container.stretch = true
	parent.add_child(container)
	var view := SubViewport.new()
	view.size = Vector2i(192, 246)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(view)
	var scene := Node3D.new()
	view.add_child(scene)
	preview_rig = game.hero.visual.duplicate() as Node3D
	preview_rig.position = Vector3.ZERO
	preview_rig.rotation = Vector3.ZERO
	scene.add_child(preview_rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	camera.position = Vector3(3.3, 2.0, 4.3)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 0.98, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.8
	scene.add_child(light)

func _gear_clicked(slot: String) -> void:
	selected_slot = slot
	var item: String = str(game.equipment.get(slot, ""))
	if item == "" or item == "training_blade":
		filter_kind = "equipment"
		selected_id = ""
	else:
		selected_id = item
	refresh()

func _refresh_load() -> void:
	var used: float = game.bag_load()
	var limit: float = game.bag_capacity()
	var bag_id: String = game.equipped_bag_id()
	var bag_name: String = "NO BAG" if bag_id == "" else bag_id.replace("_", " ").capitalize()
	bag_weight_label.text = "LOAD  %.1f / %.1f     •     %s" % [used, limit, bag_name]
	bag_meter.max_value = maxf(1.0, limit)
	bag_meter.value = minf(used, limit)
	var fill: StyleBoxFlat = SKIN.flat("red" if used > limit else "green")
	fill.set_border_width_all(0)
	bag_meter.add_theme_stylebox_override("fill", fill)
	var stored: int = 0
	for n in game.overflow_loot.values():
		stored += int(n)
	overflow_button.visible = stored > 0
	overflow_button.text = "RECOVER STORED LOOT (%d)" % stored

func _render_items() -> void:
	_clear(inventory_grid)
	var width_px: float = window.size.x
	inventory_grid.columns = 6 if width_px >= 460.0 else 5 if width_px >= 390.0 else 4
	var column_count: int = inventory_grid.columns
	var slot_px: float = floorf((width_px - 42.0 - float(column_count - 1) * 4.0) / float(column_count))
	slot_px = clampf(slot_px, 54.0, 72.0)
	var ids: Array[String] = _ordered_items()
	for id in ids:
		var tile := _button("", "wood_selected" if id == selected_id else "wood")
		tile.name = "Item_" + id
		tile.custom_minimum_size = Vector2(slot_px, slot_px)
		tile.tooltip_text = id.replace("_", " ").capitalize() + " x%d" % int(game.inventory[id])
		tile.pressed.connect(_select_item.bind(id))
		inventory_grid.add_child(tile)
		var image: TextureRect = _icon(id, slot_px - 12.0)
		image.anchor_left = 0.08
		image.anchor_right = 0.92
		image.anchor_top = 0.04
		image.anchor_bottom = 0.85
		image.custom_minimum_size = Vector2.ZERO
		tile.add_child(image)
		var count := _text(str(int(game.inventory[id])), 14, SKIN.CREAM)
		count.name = "ItemCount"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		count.offset_left = 4.0
		count.offset_right = -4.0
		count.offset_top = -23.0
		tile.add_child(count)
		if game.is_equipped(id):
			var worn := _text("◆", 15, SKIN.GOLD)
			worn.name = "EquippedMarker"
			worn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			worn.position = Vector2(3.0, 0.0)
			tile.add_child(worn)
	var minimum_tiles: int = 24
	var target_count: int = maxi(minimum_tiles, ceili(float(ids.size()) / float(column_count)) * column_count)
	for _i in range(target_count - ids.size()):
		var placeholder := Panel.new()
		placeholder.name = "EmptyInventorySlot"
		placeholder.custom_minimum_size = Vector2(slot_px, slot_px)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.add_theme_stylebox_override("panel", SKIN.box("item"))
		inventory_grid.add_child(placeholder)

func _select_item(id: String) -> void:
	selected_id = id
	selected_slot = ""
	refresh()

func _render_details() -> void:
	_clear(item_info)
	item_card.visible = selected_id != "" and int(game.inventory.get(selected_id, 0)) > 0
	if not item_card.visible:
		return
	var top := HBoxContainer.new()
	item_info.add_child(top)
	top.add_child(_text("ITEM DETAILS", 19, SKIN.GOLD, true))
	var close := _button("✕", "red")
	close.custom_minimum_size = Vector2(39, 39)
	close.pressed.connect(func() -> void:
		selected_id = ""
		refresh()
	)
	top.add_child(close)
	var heading := HBoxContainer.new()
	item_info.add_child(heading)
	heading.add_child(_icon(selected_id, 66))
	var attrs := VBoxContainer.new()
	heading.add_child(attrs)
	attrs.add_child(_text(selected_id.replace("_", " ").capitalize(), 18, SKIN.CREAM))
	attrs.add_child(_text(_kind(selected_id).to_upper() + "  ×%d" % int(game.inventory[selected_id]), 15, SKIN.GOLD))
	var weight: float = CARRY.weight(selected_id, game.equipped_bag_id(), game.equipped_bag_stars())
	item_info.add_child(_text("WEIGHT  %.2f each" % weight, 15, SKIN.CREAM))
	if CARRY.is_bag(selected_id):
		var stars: int = int(game.bag_quality.get(selected_id, 0))
		item_info.add_child(_text("T%d  %s  •  +%.0f carry" % [CARRY.tier(selected_id), "★".repeat(stars), CARRY.capacity(selected_id, stars) - CARRY.BASE_CAPACITY], 15, SKIN.GOLD))
		if CARRY.specialty(selected_id) != "":
			item_info.add_child(_text("Specialty: " + CARRY.specialty(selected_id).capitalize(), 14, SKIN.CREAM))
	var description := "Found while exploring Outpost."
	for recipe in game.recipes:
		if str(recipe.get("result", "")) == selected_id:
			description = str(recipe.get("desc", description))
			break
	item_info.add_child(_text(description, 15, SKIN.CREAM))
	if _kind(selected_id) == "equipment":
		var equipped: bool = game.is_equipped(selected_id)
		var gear_action := _button("UNEQUIP" if equipped else "EQUIP", "green")
		gear_action.custom_minimum_size = Vector2(0, 48)
		gear_action.pressed.connect(_equip_selected)
		item_info.add_child(gear_action)
	elif selected_id in CONSUMABLES:
		var use := _button("USE", "green")
		use.custom_minimum_size = Vector2(0, 48)
		use.pressed.connect(_consume_selected)
		item_info.add_child(use)
		var assign := _button("ASSIGN QUICK SLOT", "wood")
		assign.custom_minimum_size = Vector2(0, 44)
		assign.pressed.connect(_assign_selected)
		item_info.add_child(assign)

func _equip_selected() -> void:
	if game.equip_item(selected_id):
		refresh()

func _consume_selected() -> void:
	var amount: float = 65.0 if selected_id == "tonic" else 75.0 if selected_id == "stew" else 40.0
	game.consume(selected_id, amount)
	refresh()

func _assign_selected() -> void:
	var slot: String = "potion" if selected_id == "tonic" else "consumable"
	game.set_quick_consumable(slot, selected_id)
	refresh()

func _process(delta: float) -> void:
	if visible and is_instance_valid(preview_rig):
		preview_rig.rotation.y += delta * 0.28
