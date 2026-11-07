extends CanvasLayer
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
const TOUCH_SCROLL = preload("res://scripts/ui/touch_scroll_container.gd")
const CARRY = preload("res://scripts/inventory/carry_capacity.gd")
const INVENTORY_WINDOW = preload("res://scripts/ui/albion_inventory_window.gd")
## Outpost v0.4: physical-material loading and animated hands-on craft actions.
## Browse remotely; to produce an item you must stand beside its matching station.
var game
var shell: Control
var popup_frame: PanelContainer
var inventory_window: Control
var dismiss_button: Button
var emergency_close: Button
var title: Label
var subtitle: Label
var station_badge: TextureRect
var header_buttons: Dictionary = {}
var station_tabs: HBoxContainer
var recipes_list: VBoxContainer
var details: VBoxContainer
var left_scroll: ScrollContainer
var right_scroll: ScrollContainer
var current_page: String = "craft"
var craft_step: String = "browse"
var selected_station: String = "workbench"
var selected_id: String = ""
var loaded: Dictionary = {}
var completed_id: String = ""
var selected_bag_id: String = ""
var bag_filter: String = "all"
var craft_stage_strip: HBoxContainer
var progress_bar: ProgressBar
var work_counter: Label
var work_label: Label
var action_button: Button
var action_art: TextureRect
var preview_rig: Node3D
var preview_angle: float = 0.0
var station_names: Dictionary = {"workbench":"WOODWORK", "forge":"FORGE", "loom":"LOOM", "campfire":"CAMPFIRE", "enchanting":"ENCHANT"}
var action_names: Dictionary = {"workbench":"HAMMER", "forge":"STRIKE", "loom":"WEAVE", "campfire":"STIR", "enchanting":"IMBUE"}
var item_ids: Array = ["wood", "stone", "fiber", "berries", "iron", "coal", "clay", "herbs", "mushrooms", "reeds", "hide", "coins", "iron_ingot", "linen", "bricks", "meal", "tonic", "stew", "spear", "axe", "pickaxe", "shield", "torch", "satchel", "iron_blade", "cloak", "backpack_t1", "backpack_t2", "wood_satchel_t1", "wood_satchel_t2", "ore_satchel_t1", "ore_satchel_t2", "fiery_weapon"]

func setup(ref: Node) -> void:
	game = ref

func _ready() -> void:
	layer = 8
	shell = Control.new()
	shell.name = "CraftingInterface"
	shell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.01, 0.22)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_dismiss_from_shade)
	shell.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := PanelContainer.new()
	frame.name = "CompactMenuFrame"
	frame.add_theme_stylebox_override("panel", SKIN.modal_panel())
	frame.clip_contents = true
	shell.add_child(frame)
	popup_frame = frame
	_layout_popup()
	get_viewport().size_changed.connect(_layout_popup)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	frame.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	station_badge = TextureRect.new()
	station_badge.name = "InteractedStationIcon"
	station_badge.custom_minimum_size = Vector2(61, 61)
	station_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	station_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	station_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	station_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(station_badge)
	title = _label("CRAFTING STATION", 25, Color("fff0ce"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var bag := Button.new()
	bag.text = "BAG"
	bag.custom_minimum_size = Vector2(66, 48)
	SKIN.apply_button(bag, "wood")
	bag.pressed.connect(_switch_bag)
	header_buttons["bag"] = bag
	header.add_child(bag)
	var gear := Button.new()
	gear.text = "GEAR"
	gear.custom_minimum_size = Vector2(67, 48)
	SKIN.apply_button(gear, "wood")
	gear.pressed.connect(_switch_equipment)
	header_buttons["equipment"] = gear
	header.add_child(gear)
	var craft := Button.new()
	craft.text = "CRAFT"
	craft.custom_minimum_size = Vector2(74, 48)
	SKIN.apply_button(craft, "wood")
	craft.pressed.connect(_switch_craft)
	header_buttons["craft"] = craft
	header.add_child(craft)
	var close := Button.new()
	SKIN.apply_close_button(close, 57.0)
	close.name = "CraftModalClose"
	close.tooltip_text = "Return to game"
	close.focus_mode = Control.FOCUS_ALL
	close.pressed.connect(close_page)
	dismiss_button = close
	header.add_child(close)
	subtitle = _label("", 16, Color("f4d9a6"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle.clip_text = true
	page.add_child(subtitle)
	# A real workflow breadcrumb, not four fake buttons. Only the active stage
	# is highlighted; transitions remain managed by the crafting service.
	craft_stage_strip = HBoxContainer.new()
	craft_stage_strip.name = "CraftWorkflowSteps"
	craft_stage_strip.add_theme_constant_override("separation", 5)
	page.add_child(craft_stage_strip)
	station_tabs = HBoxContainer.new()
	station_tabs.add_theme_constant_override("separation", 6)
	page.add_child(station_tabs)
	station_tabs.visible = false # Single real-world station, never a five-tab hub.
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 8)
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var surface := PanelContainer.new()
	surface.add_theme_stylebox_override("panel", SKIN.modal_section(true))
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(surface)
	surface.add_child(panes)
	left_scroll = TOUCH_SCROLL.new()
	left_scroll.name = "RecipeSwipeList"
	left_scroll.custom_minimum_size = Vector2(206, 0)
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.94
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panes.add_child(left_scroll)
	recipes_list = VBoxContainer.new()
	recipes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipes_list.add_theme_constant_override("separation", 7)
	left_scroll.add_child(recipes_list)
	right_scroll = TOUCH_SCROLL.new()
	right_scroll.name = "CraftingDetailsSwipe"
	right_scroll.custom_minimum_size = Vector2(230, 0)
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 1.06
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panes.add_child(right_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 7)
	right_scroll.add_child(details)
	inventory_window = INVENTORY_WINDOW.new()
	inventory_window.setup(game, self)
	add_child(inventory_window)
	inventory_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_window.visible = false
	# Put the escape action above both modal systems, outside their panels.
	# This remains reachable even if a nested recipe/tab control captures touch.
	emergency_close = Button.new()
	emergency_close.name = "EmergencyBackToGame"
	emergency_close.position = Vector2(12, 12)
	emergency_close.size = Vector2(50, 50)
	emergency_close.focus_mode = Control.FOCUS_ALL
	emergency_close.mouse_filter = Control.MOUSE_FILTER_STOP
	SKIN.apply_close_button(emergency_close, 50)
	emergency_close.tooltip_text = "Emergency exit from Bag or Gear"
	emergency_close.pressed.connect(close_page)
	add_child(emergency_close)
	visible = false

func _layout_popup() -> void:
	# Stable *pixel* dimensions rather than a huge percentage of ultra-wide
	# mobile screens. Leave the game visible around the frame, but keep
	# enough room for a single-station icon, recipe list and details.
	if popup_frame == null:
		return
	var bounds: Vector2 = get_viewport().get_visible_rect().size
	var max_width: float = maxf(300.0, bounds.x - 30.0)
	var max_height: float = maxf(320.0, bounds.y - 34.0)
	var width_px: float = minf(clampf(bounds.x * 0.68, 620.0, 900.0), max_width)
	var height_px: float = minf(clampf(bounds.y * 0.68, 380.0, 565.0), max_height)
	popup_frame.anchor_left = 0.5
	popup_frame.anchor_right = 0.5
	popup_frame.anchor_top = 0.5
	popup_frame.anchor_bottom = 0.5
	popup_frame.offset_left = -width_px * 0.5
	popup_frame.offset_right = width_px * 0.5
	popup_frame.offset_top = -height_px * 0.5
	popup_frame.offset_bottom = height_px * 0.5
	if emergency_close != null:
		emergency_close.position = Vector2(maxf(8.0, (bounds.x - width_px) * 0.5 - 61.0), maxf(10.0, (bounds.y - height_px) * 0.5 + 6.0))

func _style(background: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(10)
	return style

func _label(value: String, font_size: int = 18, tint: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", tint)
	label.add_theme_font_size_override("font_size", maxi(16, font_size))
	label.add_theme_color_override("font_outline_color", Color("1c1117"))
	label.add_theme_constant_override("outline_size", 2)
	return label

func _icon(id: String, size: float = 58.0) -> TextureRect:
	var image := TextureRect.new()
	var id_safe: String = id
	if id_safe not in item_ids and id_safe not in ["gather", "attack", "craft", "heart", "flag"]:
		id_safe = "craft"
	image.texture = load("res://assets/icons/" + id_safe + ".svg") as Texture2D
	image.custom_minimum_size = Vector2(size, size)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return image

func _ingredient_state_icon(available: bool) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "IngredientAvailability"
	icon.texture = load("res://assets/ui/icons/ingredient_ready.svg" if available else "res://assets/ui/icons/ingredient_missing.svg") as Texture2D
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _column_panel(target: Node, color: Color) -> VBoxContainer:
	var container := PanelContainer.new()
	# Text in these nested detail cards is cream/gold, so use dark carved
	# wood instead of a light item-card surface with unreadable cream text.
	container.add_theme_stylebox_override("panel", SKIN.box("frame"))
	target.add_child(container)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	container.add_child(column)
	return column

func _switch_bag() -> void:
	open("bag")

func _switch_craft() -> void:
	open("craft")

func _switch_equipment() -> void:
	open("equipment")

func open(page: String) -> void:
	if visible and current_page == page:
		close_page()
		return
	current_page = page
	if page == "craft" and game.crafting.is_empty():
		craft_step = "browse"
	visible = true
	if emergency_close != null:
		emergency_close.visible = page == "bag" or page == "equipment"
		emergency_close.move_to_front()
	if game.hud != null:
		game.hud.move_vector = Vector2.ZERO
	if page == "bag" or page == "equipment":
		shell.visible = false
		inventory_window.open_page(page)
		return
	shell.visible = true
	inventory_window.close_page()
	if page == "craft":
		# Lock the UI to the world object actually interacted with. Never
		# silently keep an old forge recipe while looking at a campfire.
		var station: String = str(game.crafting.get("station", "")) if not game.crafting.is_empty() else game.closest_station()
		if station != selected_station:
			selected_station = station
			selected_id = _first_recipe(station)
			loaded.clear()
		elif selected_id == "":
			selected_id = _first_recipe(selected_station)
	# Never throw an already-open Prepare step away when returning from another
	# modal; only new sessions and explicit navigation reset the workflow.
	if page == "craft" and game.crafting.is_empty() and completed_id == "":
		craft_step = "browse"
	refresh()

func close_page() -> void:
	visible = false
	shell.visible = false
	if inventory_window != null:
		inventory_window.close_page()

func _dismiss_from_shade(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		close_page()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close_page()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_page()
		get_viewport().set_input_as_handled()
		return
	# Handle this escape region before any Control can swallow the event.
	# Android often has no hardware Back button in landscape immersive mode.
	var pressed: bool = false
	var pointer := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
		pointer = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = (event as InputEventMouseButton).pressed
		pointer = (event as InputEventMouseButton).position
	if pressed and ((emergency_close != null and emergency_close.visible and emergency_close.get_global_rect().grow(10.0).has_point(pointer)) or (current_page == "craft" and dismiss_button != null and dismiss_button.get_global_rect().grow(8.0).has_point(pointer))):
		close_page()
		get_viewport().set_input_as_handled()

func _first_recipe(station: String) -> String:
	for recipe in game.recipes:
		if str(recipe.get("station", "workbench")) == station:
			return str(recipe.get("id", ""))
	return ""

func _station_change(station: String) -> void:
	if not game.crafting.is_empty():
		return
	selected_station = station
	craft_step = "browse"
	selected_id = _first_recipe(station)
	loaded.clear()
	completed_id = ""
	refresh()

func _recipe_change(id: String) -> void:
	if not game.crafting.is_empty():
		return
	selected_id = id
	craft_step = "detail" # Detail remains alongside the recipe list.
	loaded.clear()
	completed_id = ""
	refresh()

func refresh() -> void:
	if not visible:
		return
	if current_page == "bag" or current_page == "equipment":
		inventory_window.refresh()
		return
	progress_bar = null
	work_counter = null
	work_label = null
	action_button = null
	action_art = null
	for page_key in header_buttons:
		var button: Button = header_buttons[page_key] as Button
		if button != null:
			# No redundant BAG / GEAR / CRAFT navigation in a station modal.
			button.visible = false
	_clear(station_tabs)
	_clear(craft_stage_strip)
	craft_stage_strip.visible = false
	station_tabs.visible = false
	_clear(recipes_list)
	_clear(details)
	if current_page == "bag":
		_render_bag()
	elif current_page == "equipment":
		_render_equipment()
	else:
		_render_craft()
	# Albion-like layout: always see station recipes on the left and the
	# selected item/required materials on the right. During active crafting
	# focus the right on the real work action (not a dead recipe selector).
	var browse: bool = current_page == "craft" and game.crafting.is_empty() and completed_id == ""
	left_scroll.visible = current_page != "craft" or browse
	right_scroll.visible = true
	right_scroll.scroll_vertical = 0 if current_page == "craft" else right_scroll.scroll_vertical

func _render_bag() -> void:
	title.text = "OUTPOST  •  BAG"
	var current_bag: String = game.equipped_bag_id()
	var stars: int = game.equipped_bag_stars()
	subtitle.text = "CARRY  %.1f / %.1f    •    %s" % [game.bag_load(), game.bag_capacity(), current_bag.replace("_", " ").capitalize() if current_bag != "" else "No backpack"]
	var carry_column := VBoxContainer.new()
	carry_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station_tabs.add_child(carry_column)
	var used := _label("INVENTORY WEIGHT  •  %.1f / %.1f" % [game.bag_load(), game.bag_capacity()], 17, SKIN.CREAM)
	carry_column.add_child(used)
	var meter := ProgressBar.new()
	meter.name = "BagCapacityMeter"
	meter.max_value = game.bag_capacity()
	meter.value = minf(game.bag_load(), game.bag_capacity())
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(0, 16)
	var bag_background: StyleBoxFlat = SKIN.flat("inset")
	bag_background.set_corner_radius_all(3)
	var bag_fill: StyleBoxFlat = SKIN.flat("green")
	bag_fill.set_border_width_all(0)
	bag_fill.set_corner_radius_all(3)
	meter.add_theme_stylebox_override("background", bag_background)
	meter.add_theme_stylebox_override("fill", bag_fill)
	carry_column.add_child(meter)
	if game.bag_load() > game.bag_capacity():
		carry_column.add_child(_label("OVERLOADED — equip a larger bag or unload items.", 15, Color("#ffb29a")))
	var stored: int = 0
	for amount in game.overflow_loot.values():
		stored += int(amount)
	if stored > 0:
		var claim := Button.new()
		claim.name = "RecoverStoredLoot"
		claim.text = "RECOVER LOOT (%d)" % stored
		claim.custom_minimum_size = Vector2(0, 48)
		SKIN.apply_button(claim, "green")
		claim.pressed.connect(game.claim_overflow)
		station_tabs.add_child(claim)
	# Compact working bag tabs; these filter actual owned objects rather than
	# moving data into invented storage categories.
	var filters := HBoxContainer.new()
	filters.name = "BagFilters"
	filters.add_theme_constant_override("separation", 4)
	recipes_list.add_child(filters)
	for category in ["all", "material", "equipment", "consumable"]:
		var tab := Button.new()
		tab.name = "BagFilter_" + category
		tab.text = {"all": "ALL", "material": "MATS", "equipment": "GEAR", "consumable": "FOOD"}[category]
		tab.custom_minimum_size = Vector2(60, 42)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SKIN.apply_button(tab, "wood_selected" if bag_filter == category else "wood")
		tab.add_theme_font_size_override("font_size", 15)
		tab.pressed.connect(_set_bag_filter.bind(category))
		filters.add_child(tab)
	var owned_ids: Array[String] = []
	for raw_id in item_ids:
		var item: String = str(raw_id)
		if int(game.inventory.get(item, 0)) > 0 and (bag_filter == "all" or _bag_type(item).to_lower() == bag_filter):
			owned_ids.append(item)
	if selected_bag_id == "" or int(game.inventory.get(selected_bag_id, 0)) <= 0:
		selected_bag_id = owned_ids[0] if not owned_ids.is_empty() else ""
	if owned_ids.is_empty():
		recipes_list.add_child(_label("No items in this category." if bag_filter != "all" else "Your satchel is empty. Gather resources to begin.", 19, SKIN.INK))
		details.add_child(_label("No items selected", 21, SKIN.INK))
		return

	var grid := GridContainer.new()
	grid.name = "BagItemGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 7)
	recipes_list.add_child(grid)
	for item in owned_ids:
		var qty: int = int(game.inventory.get(item, 0))
		var slot := Button.new()
		slot.name = "Item_" + item
		slot.custom_minimum_size = Vector2(66, 69)
		slot.tooltip_text = item.replace("_", " ").capitalize() + " x%d" % qty
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for state in ["normal", "hover", "pressed", "disabled"]:
			slot.add_theme_stylebox_override(state, SKIN.box("parchment_light") if item == selected_bag_id else SKIN.box("item"))
		slot.pressed.connect(_bag_select.bind(item))
		grid.add_child(slot)
		var art: TextureRect = _icon(item, 45)
		art.name = "ItemIcon"
		art.custom_minimum_size = Vector2.ZERO
		art.anchor_left = 0.12
		art.anchor_right = 0.88
		art.anchor_top = 0.02
		art.anchor_bottom = 0.74
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(art)
		var count := Label.new()
		count.text = str(qty)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 16)
		count.add_theme_color_override("font_color", SKIN.INK)
		count.add_theme_color_override("font_outline_color", Color("#241619"))
		count.add_theme_constant_override("outline_size", 2)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.anchor_left = 0.45
		count.anchor_right = 0.93
		count.anchor_top = 0.68
		count.anchor_bottom = 0.96
		slot.add_child(count)
		if item == selected_bag_id:
			var gold_outline := Panel.new()
			gold_outline.name = "SelectedItemBorder"
			gold_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gold_outline.add_theme_stylebox_override("panel", SKIN.box("wood_selected"))
			slot.add_child(gold_outline)
			gold_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if game.is_equipped(item):
			var equipped := Label.new()
			equipped.text = "◆"
			equipped.add_theme_color_override("font_color", SKIN.GOLD)
			equipped.add_theme_font_size_override("font_size", 16)
			equipped.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(equipped)
	var focused: String = selected_bag_id
	var detail := _column_panel(details, Color("#38271d"))
	detail.add_child(_label(focused.replace("_", " ").capitalize(), 23, SKIN.CREAM))
	var item_header := HBoxContainer.new()
	detail.add_child(item_header)
	item_header.add_child(_icon(focused, 82))
	var facts := VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_header.add_child(facts)
	facts.add_child(_label("OWNED  x%d" % int(game.inventory.get(focused, 0)), 19, SKIN.GOLD))
	if CARRY.is_bag(focused):
		facts.add_child(_label("T%d   %s" % [CARRY.tier(focused), "★".repeat(int(game.bag_quality.get(focused, 0)))], 19, SKIN.GOLD))
		facts.add_child(_label("Capacity +%.0f • weight bonus for %s" % [CARRY.capacity(focused, int(game.bag_quality.get(focused, 0))) - CARRY.BASE_CAPACITY, CARRY.specialty(focused) if CARRY.specialty(focused) != "" else "all items"], 16, SKIN.CREAM))
	facts.add_child(_label("EQUIPPED" if game.is_equipped(focused) else _bag_type(focused), 17, Color("#cde8bc")))
	var description: String = "Collected while exploring Outpost."
	for recipe in game.recipes:
		if str(recipe.get("result", "")) == focused:
			description = str(recipe.get("desc", description))
			break
	detail.add_child(_label(description, 17, SKIN.CREAM))
	if focused in ["meal", "tonic", "stew"]:
		var slot: String = "potion" if focused == "tonic" else "consumable"
		var assign := Button.new()
		assign.text = "ASSIGN TO " + slot.to_upper() + " RADIAL"
		assign.custom_minimum_size = Vector2(0, 48)
		SKIN.apply_button(assign, "wood")
		assign.pressed.connect(_assign_quick.bind(slot, focused))
		detail.add_child(assign)
		var use_button := Button.new()
		use_button.text = "USE " + focused.replace("_", " ").to_upper()
		use_button.custom_minimum_size = Vector2(0, 54)
		SKIN.apply_button(use_button, "green")
		use_button.pressed.connect(_use_food.bind(focused))
		detail.add_child(use_button)
	elif _bag_type(focused) == "EQUIPMENT":
		var equip_button := Button.new()
		equip_button.text = "UNEQUIP" if game.is_equipped(focused) else "EQUIP"
		equip_button.custom_minimum_size = Vector2(0, 54)
		SKIN.apply_button(equip_button, "green")
		equip_button.pressed.connect(_equip_click.bind(focused))
		detail.add_child(equip_button)
	var gear_button := Button.new()
	gear_button.text = "VIEW EQUIPMENT"
	gear_button.custom_minimum_size = Vector2(0, 48)
	SKIN.apply_button(gear_button, "wood")
	gear_button.pressed.connect(_switch_equipment)
	detail.add_child(gear_button)

func _assign_quick(slot: String, item_id: String) -> void:
	if game.set_quick_consumable(slot, item_id):
		refresh()

func _set_bag_filter(category: String) -> void:
	bag_filter = category
	selected_bag_id = ""
	refresh()

func _bag_type(id: String) -> String:
	if id in ["spear", "iron_blade", "shield", "torch", "cloak", "axe", "pickaxe", "satchel"] or CARRY.is_bag(id):
		return "EQUIPMENT"
	if id in ["meal", "tonic", "stew"]:
		return "CONSUMABLE"
	return "MATERIAL"

func _bag_select(id: String) -> void:
	selected_bag_id = id
	refresh()

func _render_equipment() -> void:
	title.text = "OUTPOST | EQUIPMENT"
	subtitle.text = "Equip or unequip your crafted gear. Bonuses only apply while worn."
	station_tabs.add_child(_label("GEAR SLOTS | TAP OWNED ITEMS TO EQUIP", 16, Color("e7d5a2")))
	var slot_names: Dictionary = {
		"weapon": "MAIN HAND",
		"offhand": "OFF HAND",
		"back": "CLOAK",
		"bag": "BACKPACK / SPECIALIST SATCHEL",
		"tool_wood": "WOODCUTTING",
		"tool_mining": "MINING",
		"tool_forage": "FORAGING"
	}
	var possible: Dictionary = {
		"weapon": ["spear", "iron_blade"],
		"offhand": ["shield", "torch"],
		"back": ["cloak"],
		"bag": ["backpack_t1", "backpack_t2", "wood_satchel_t1", "wood_satchel_t2", "ore_satchel_t1", "ore_satchel_t2"],
		"tool_wood": ["axe"],
		"tool_mining": ["pickaxe"],
		"tool_forage": ["satchel"]
	}
	for slot in slot_names:
		var holder := _column_panel(recipes_list, Color("23383c"))
		holder.add_child(_label(str(slot_names[slot]), 15, Color("dbbd8a")))
		var active: String = str(game.equipment.get(str(slot), ""))
		if active == "":
			active = "EMPTY"
		elif active == "training_blade":
			active = "TRAINING BLADE"
		var row := HBoxContainer.new()
		holder.add_child(row)
		var icon_id: String = str(game.equipment.get(str(slot), ""))
		if icon_id == "" or icon_id == "training_blade":
			icon_id = "flag"
		row.add_child(_icon(icon_id, 48))
		row.add_child(_label(active.replace("_", " ").to_upper(), 19, Color("f2dfb4")))
		if str(game.equipment.get(str(slot), "")) not in ["", "training_blade"]:
			var unequip := Button.new()
			unequip.text = "OFF"
			unequip.custom_minimum_size = Vector2(60, 44)
			SKIN.apply_button(unequip, "red")
			unequip.pressed.connect(_equip_click.bind(str(game.equipment[slot])))
			row.add_child(unequip)
		for item in possible[slot]:
			var item_id: String = str(item)
			if int(game.inventory.get(item_id, 0)) <= 0:
				continue
			var option := Button.new()
			option.text = ("EQUIPPED  " if game.is_equipped(item_id) else "EQUIP  ") + item_id.replace("_", " ").capitalize() + ("  %s" % "★".repeat(int(game.bag_quality.get(item_id, 0))) if CARRY.is_bag(item_id) else "")
			option.custom_minimum_size = Vector2(0, 50)
			option.disabled = game.is_equipped(item_id)
			SKIN.apply_button(option, "wood_selected" if game.is_equipped(item_id) else "green")
			option.pressed.connect(_equip_click.bind(item_id))
			holder.add_child(option)
	_render_preview()

func _equip_click(id: String) -> void:
	game.equip_item(id)
	refresh()

func _render_preview() -> void:
	var portrait := _column_panel(details, Color("1c3033"))
	portrait.add_child(_label("YOUR ADVENTURER", 23, Color("f3d8a0")))
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(210, 265)
	portrait.add_child(container)
	var view := SubViewport.new()
	view.size = Vector2i(400, 380)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(view)
	var root3d := Node3D.new()
	view.add_child(root3d)
	preview_rig = game.hero.visual.duplicate() as Node3D
	root3d.add_child(preview_rig)
	preview_rig.position = Vector3.ZERO
	preview_rig.rotation = Vector3.ZERO
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.1
	camera.position = Vector3(3.8, 2.4, 4.8)
	root3d.add_child(camera)
	camera.look_at(Vector3(0.0, 1.06, 0.0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	light.light_energy = 2.0
	root3d.add_child(light)
	var details_text := _column_panel(details, Color("2c4445"))
	details_text.add_child(_label("EQUIPMENT BONUSES", 20, Color("dfc898")))
	var weapon: String = str(game.equipment.get("weapon", "training_blade"))
	var damage: int = 24 if weapon == "iron_blade" else 16 if weapon == "spear" else 8
	details_text.add_child(_label("Attack: %d  •  %s" % [damage, weapon.replace("_", " ").capitalize()], 17))
	details_text.add_child(_label("Defense: %s" % ("40% less boar damage" if game.is_equipped("shield") else "Unarmoured"), 17))
	details_text.add_child(_label("Movement: %s" % ("Fast (+18%)" if game.is_equipped("cloak") else "Normal"), 17))
	details_text.add_child(_label("Tools: %d active" % [int(game.is_equipped("axe")) + int(game.is_equipped("pickaxe")) + int(game.is_equipped("satchel"))], 17))
	details_text.add_child(_label("Load: %.1f / %.1f  %s" % [game.bag_load(), game.bag_capacity(), "★".repeat(game.equipped_bag_stars())], 17))
	details_text.add_child(_label("Tip: craft new gear at the four stations, then equip it here.", 16, Color("bcc9be")))

func _use_food(id: String) -> void:
	var amount: float = 40.0
	if id == "tonic":
		amount = 65.0
	elif id == "stew":
		amount = 75.0
	game.consume(id, amount)

func _render_craft_steps() -> void:
	var active: int = 0
	if not game.crafting.is_empty():
		active = 2
	elif completed_id != "":
		active = 3
	elif craft_step == "prepare":
		active = 1
	for index in range(4):
		var card := PanelContainer.new()
		card.name = "CraftStage_%d" % (index + 1)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", SKIN.box("wood_selected" if index == active else "wood"))
		craft_stage_strip.add_child(card)
		var text_label := _label(["1  SELECT", "2  PREPARE", "3  WORK", "4  COLLECT"][index], 15, SKIN.GOLD if index == active else SKIN.CREAM)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.custom_minimum_size = Vector2(0, 27)
		card.add_child(text_label)

func _render_craft() -> void:
	# This screen belongs to exactly ONE station, chosen by world proximity
	# (or the active crafting job). No wood/forge/loom/campfire/enchant tabs.
	var station: String = selected_station
	station_badge.visible = station_names.has(station)
	if station_badge.visible:
		station_badge.texture = load("res://assets/ui/icons/station_" + station + ".svg") as Texture2D
		title.text = str(station_names[station]) + "  •  CRAFTING"
	else:
		station_badge.texture = null
		title.text = "CRAFTING STATION"
	if station.is_empty():
		subtitle.text = "Move closer to a crafting station to see its items."
		recipes_list.add_child(_label("No crafting station nearby.", 18, SKIN.INK))
		details.add_child(_label("Use INTERACT beside a workbench, forge, loom, campfire or enchanting table.", 18, SKIN.INK))
		return
	var count: int = 0
	for candidate in game.recipes:
		if str(candidate.get("station", "workbench")) == station:
			count += 1
	if not game.crafting.is_empty():
		subtitle.text = "WORK IN PROGRESS  •  " + str(station_names[station])
	elif completed_id != "":
		subtitle.text = "ITEM COMPLETE  •  " + str(station_names[station])
	else:
		subtitle.text = "NEARBY " + str(station_names[station]) + "  •  %d recipes" % count
	# Selection remains in sync with the interacted station even after moving
	# between stations, and no recipe from another bench can leak through.
	if selected_id.is_empty() or str(game._recipe_by_id(selected_id).get("station", "")) != station:
		selected_id = _first_recipe(station)
	for recipe in game.recipes:
		if str(recipe.get("station", "workbench")) != selected_station:
			continue
		var id: String = str(recipe.get("id", ""))
		var result_id: String = str(recipe.get("result", ""))
		var owned_unique: bool = game.owns_unique(result_id)
		var affordable: bool = true
		var requirements: Array[String] = []
		var ingredients: Dictionary = recipe.get("ingredients", {})
		for ingredient in ingredients:
			var ingredient_id: String = str(ingredient)
			var required: int = int(ingredients[ingredient])
			var current: int = int(game.inventory.get(ingredient_id, 0))
			requirements.append("%s %d/%d" % [ingredient_id.capitalize(), current, required])
			if current < required:
				affordable = false
		var choose := Button.new()
		choose.name = "Recipe_" + id
		choose.text = ""
		choose.custom_minimum_size = Vector2(0, 79)
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choose.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for state in ["normal", "hover", "pressed", "disabled"]:
			choose.add_theme_stylebox_override(state, SKIN.box("parchment_light") if selected_id == id else SKIN.box("item"))
		choose.disabled = not game.crafting.is_empty()
		choose.pressed.connect(_recipe_change.bind(id))
		recipes_list.add_child(choose)
		var art: TextureRect = _icon(result_id, 60)
		art.custom_minimum_size = Vector2.ZERO
		art.anchor_left = 0.01
		art.anchor_right = 0.20
		art.anchor_top = 0.12
		art.anchor_bottom = 0.88
		choose.add_child(art)
		# The item-card texture is light parchment. Dark ink stays legible in
		# both selected and unselected states (the old cream text vanished).
		var foreground: Color = SKIN.INK
		var name_label := Label.new()
		name_label.text = str(recipe.get("name", id))
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_color_override("font_color", foreground)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.anchor_left = 0.23
		name_label.anchor_right = 0.70
		name_label.anchor_top = 0.11
		name_label.anchor_bottom = 0.48
		choose.add_child(name_label)
		var material_label := Label.new()
		var affordable_count: int = 0
		for requirement in ingredients:
			if int(game.inventory.get(str(requirement), 0)) >= int(ingredients[requirement]):
				affordable_count += 1
		material_label.text = "MATERIALS  %d / %d AVAILABLE" % [affordable_count, ingredients.size()]
		material_label.add_theme_font_size_override("font_size", 15)
		material_label.add_theme_color_override("font_color", foreground)
		material_label.clip_text = true
		material_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		material_label.anchor_left = 0.23
		material_label.anchor_right = 0.96
		material_label.anchor_top = 0.52
		material_label.anchor_bottom = 0.85
		choose.add_child(material_label)
		var badge := Label.new()
		badge.text = "★%d → ★%d" % [int(game.bag_quality.get(result_id, 0)), mini(3, int(game.bag_quality.get(result_id, 0)) + 1)] if CARRY.is_bag(result_id) and int(game.inventory.get(result_id, 0)) > 0 else "OWNED" if owned_unique else "READY" if affordable else "MISSING"
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color("#355b31") if affordable and not owned_unique else Color("#873b2c"))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.anchor_left = 0.72
		badge.anchor_right = 0.95
		badge.anchor_top = 0.10
		badge.anchor_bottom = 0.42
		choose.add_child(badge)
		# Selected recipe is already highlighted by its parchment surface.
		# An extra full-card outline hid text and recreated opaque borders.
	if not game.crafting.is_empty():
		_render_work()
	elif completed_id != "":
		_render_result()
	else:
		if selected_id == "" or game._recipe_by_id(selected_id).is_empty() or str(game._recipe_by_id(selected_id).get("station", "")) != selected_station:
			selected_id = _first_recipe(selected_station)
		_render_recipe() # One-step craft action; no ingredient-loading menu.

func _craft_selected() -> void:
	# Skip the extra Prepare/Load screens for ordinary station crafting:
	# the authoritative game service still validates station, inventory,
	# unique equipment and character level before consuming materials.
	if selected_id.is_empty() or not game.can_craft(selected_id):
		return
	if game.begin_craft(selected_id):
		loaded.clear()
		completed_id = ""
		refresh()

func _begin_prepare() -> void:
	craft_step = "prepare"
	loaded.clear()
	refresh()

func _back_to_browse() -> void:
	craft_step = "browse"
	loaded.clear()
	refresh()

func _render_recipe() -> void:
	var recipe: Dictionary = game._recipe_by_id(selected_id)
	if recipe.is_empty():
		details.add_child(_label("Choose a recipe to see its requirements.", 20, Color("f5deb0")))
		return
	# Recipes remain visible alongside details; no back-navigation button.
	var product_id: String = str(recipe.get("result", ""))
	var intro := _column_panel(details, Color("5f3b29"))
	var head := HBoxContainer.new()
	intro.add_child(head)
	head.add_child(_icon(product_id, 78))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	info.add_child(_label(str(recipe.get("name", "")), 23, Color("ffe2a6")))
	info.add_child(_label(str(recipe.get("category", "Equipment")).to_upper() + "  •  TIER %d" % maxi(1, CARRY.tier(product_id)), 15, Color("eabf77")))
	if CARRY.is_bag(product_id):
		info.add_child(_label("QUALITY   %s    •    RECRAFT TO IMPROVE" % "★".repeat(int(game.bag_quality.get(product_id, 0))), 16, SKIN.GOLD))
	info.add_child(_label(str(recipe.get("desc", "")), 16, Color("f3dfbb")))
	if selected_id == "fiery_weapon":
		info.add_child(_label("CHARACTER LEVEL %d / 3   •   COST: ONE LEVEL" % game.character_level(), 17, SKIN.GOLD))
		info.add_child(_label("TARGET: %s" % game.current_weapon_id().replace("_", " ").capitalize(), 17, SKIN.CREAM))
	details.add_child(_label("REQUIRED MATERIALS", 18, SKIN.INK))
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for key in ingredients:
		var id: String = str(key)
		var need: int = int(ingredients[key])
		var own: int = int(game.inventory.get(id, 0))
		var row := HBoxContainer.new()
		details.add_child(row)
		row.add_child(_icon(id, 38))
		row.add_child(_ingredient_state_icon(own >= need))
		row.add_child(_label("%s    %d / %d" % [id.capitalize(), own, need], 18, Color("#32542c") if own >= need else Color("#88422d")))
	var next := Button.new()
	next.text = "IMPROVE QUALITY" if CARRY.is_bag(product_id) and int(game.inventory.get(product_id, 0)) > 0 else "CRAFT  ◆  %s" % str(recipe.get("name", "ITEM")).to_upper()
	next.custom_minimum_size = Vector2(0, 56)
	SKIN.apply_button(next, "green")
	next.disabled = not game.can_craft(selected_id)
	next.pressed.connect(_craft_selected)
	details.add_child(next)
	if game.owns_unique(product_id):
		details.add_child(_label("Already owned — unique equipment cannot be duplicated.", 15, Color("ffe2a6")))
	elif CARRY.is_bag(product_id) and int(game.bag_quality.get(product_id, 0)) >= 3:
		details.add_child(_label("Maximum 3 stars. Select a different bag or tier.", 15, SKIN.GOLD))
	elif selected_id == "fiery_weapon" and game.character_level() < 3:
		details.add_child(_label("Gain character levels before using this bench.", 15, SKIN.GOLD))
	elif not game.can_craft(selected_id):
		details.add_child(_label(game.craft_block_reason(selected_id), 14, Color("88422d")))

func _render_prepare() -> void:
	var recipe: Dictionary = game._recipe_by_id(selected_id)
	if recipe.is_empty():
		details.add_child(_label("Choose a recipe from the list.", 21))
		return
	var product_id: String = str(recipe.get("result", ""))
	var intro := _column_panel(details, Color("5f3b29"))
	var head := HBoxContainer.new()
	intro.add_child(head)
	head.add_child(_icon(product_id, 87))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	info.add_child(_label(str(recipe.get("name", "")), 24, Color("f0d9aa")))
	info.add_child(_label(str(recipe.get("desc", "")), 16, Color("bdd0c8")))
	info.add_child(_label("Output x%d     •     %s" % [int(recipe.get("amount", 1)), str(station_names[selected_station])], 17))
	if CARRY.is_bag(product_id):
		info.add_child(_label("Improves star quality, not duplicate stock." if int(game.inventory.get(product_id, 0)) > 0 else "Equips automatically after crafting.", 16, SKIN.CREAM))
	if selected_id == "fiery_weapon":
		info.add_child(_label("Fiery Weapon  •  Costs 1 level at completion.", 16, SKIN.GOLD))
	details.add_child(_label("STEP 2  •  LOAD MATERIALS", 18, SKIN.INK))
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for key in ingredients:
		var id: String = str(key)
		var needed: int = int(ingredients[key])
		var owned: int = int(game.inventory.get(id, 0))
		var loaded_now: bool = bool(loaded.get(id, false))
		var available: bool = owned >= needed
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(0, 56)
		SKIN.apply_button(slot, "wood_selected" if loaded_now else "parchment_light")
		slot.disabled = not available or game.owns_unique(product_id)
		slot.text = ("✓ LOADED   " if loaded_now else "LOAD   ") + id.replace("_", " ").capitalize() + "   " + str(owned) + "/" + str(needed)
		slot.pressed.connect(_toggle_ingredient.bind(id))
		var row := HBoxContainer.new()
		details.add_child(row)
		row.add_child(_icon(id, 54))
		row.add_child(_ingredient_state_icon(loaded_now or available))
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slot)
	var loaded_count: int = 0
	for key in ingredients:
		if bool(loaded.get(str(key), false)):
			loaded_count += 1
	details.add_child(_label("MATERIALS LOADED: %d / %d" % [loaded_count, ingredients.size()], 17, SKIN.INK))
	var begin := Button.new()
	begin.text = "BEGIN CRAFTING  ◆  WORK STATION"
	begin.custom_minimum_size = Vector2(0, 54)
	SKIN.apply_button(begin, "green")
	begin.disabled = loaded_count < ingredients.size() or not game.can_craft(selected_id)
	begin.pressed.connect(_start_craft)
	details.add_child(begin)
	var back := Button.new()
	back.text = "BACK TO RECIPES"
	back.custom_minimum_size = Vector2(0, 42)
	SKIN.apply_button(back, "wood")
	back.pressed.connect(_back_to_browse)
	details.add_child(back)
	if not game.near_station(selected_station):
		details.add_child(_label("Move beside the %s to begin." % selected_station.capitalize(), 17, Color("#88422d")))
	elif game.owns_unique(product_id):
		details.add_child(_label("You already own this unique equipment.", 17, Color("#88422d")))
	elif loaded_count == ingredients.size() and not game.can_craft(selected_id):
		details.add_child(_label(game.craft_block_reason(selected_id), 17, Color("#88422d")))

func _toggle_ingredient(id: String) -> void:
	loaded[id] = not bool(loaded.get(id, false))
	refresh()

func _start_craft() -> void:
	var recipe: Dictionary = game._recipe_by_id(selected_id)
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for key in ingredients:
		if not bool(loaded.get(str(key), false)):
			return
	if game.begin_craft(selected_id):
		loaded.clear()
		completed_id = ""
		refresh()

func on_craft_started() -> void:
	if visible:
		refresh()

func _render_work() -> void:
	var active: Dictionary = game.crafting
	var id: String = str(active.get("id", ""))
	var recipe: Dictionary = game._recipe_by_id(id)
	var item: String = str(recipe.get("result", "craft"))
	var stage := _column_panel(details, Color("29413f"))
	stage.add_child(_label("PRODUCTION IN PROGRESS", 23, Color("f1d5a2")))
	action_art = _icon(item, 118)
	stage.add_child(action_art)
	stage.add_child(_label(str(recipe.get("name", id)), 21))
	progress_bar = ProgressBar.new()
	progress_bar.max_value = 100.0
	progress_bar.custom_minimum_size = Vector2(0, 26)
	progress_bar.show_percentage = false
	var craft_background: StyleBoxFlat = SKIN.flat("inset")
	craft_background.set_corner_radius_all(3)
	var craft_fill: StyleBoxFlat = SKIN.flat("green")
	craft_fill.set_border_width_all(0)
	craft_fill.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("background", craft_background)
	progress_bar.add_theme_stylebox_override("fill", craft_fill)
	stage.add_child(progress_bar)
	work_counter = _label("", 18)
	stage.add_child(work_counter)
	work_label = _label("", 17, Color("b9dfce"))
	stage.add_child(work_label)
	action_button = Button.new()
	action_button.text = str(action_names.get(str(active.get("station", "")), "WORK")) + " • TAP"
	action_button.custom_minimum_size = Vector2(0, 62)
	SKIN.apply_button(action_button, "green")
	action_button.pressed.connect(_do_work)
	stage.add_child(action_button)
	stage.add_child(_label("Watch the station as you work. Closing this panel does not cancel the job.", 15, Color("b4bfb8")))
	_update_visual()

func _do_work() -> void:
	if game.work_craft() and action_art != null:
		var tw := create_tween()
		tw.tween_property(action_art, "rotation_degrees", -13.0, 0.08)
		tw.tween_property(action_art, "rotation_degrees", 11.0, 0.10)
		tw.tween_property(action_art, "rotation_degrees", 0.0, 0.10)
	_update_visual()

func _process(_delta: float) -> void:
	if visible and current_page == "equipment" and is_instance_valid(preview_rig):
		preview_angle += _delta * 0.32
		preview_rig.rotation.y = preview_angle
	if visible and current_page == "craft" and not game.crafting.is_empty() and progress_bar != null:
		_update_visual()

func _update_visual() -> void:
	if game.crafting.is_empty() or progress_bar == null:
		return
	var running: Dictionary = game.crafting
	var elapsed: float = float(running.get("elapsed", 0.0))
	var duration: float = float(running.get("duration", 1.0))
	var strokes: int = int(running.get("strokes", 0))
	var total: int = int(running.get("required", 1))
	progress_bar.value = clampf(elapsed / duration, 0.0, 1.0) * 100.0
	work_counter.text = "Working: %d / %d actions" % [strokes, total]
	work_label.text = "HOLDING HEAT / WORKING MATERIAL..." if elapsed < duration else "Ready! Finish remaining work actions." if strokes < total else "FINISHING ITEM..."
	action_button.disabled = strokes >= total or game.craft_work_cooldown > 0.0

func on_craft_completed(result_id: String) -> void:
	completed_id = result_id
	loaded.clear()
	current_page = "craft"
	craft_step = "browse"
	selected_id = ""
	if visible:
		refresh()

func _render_result() -> void:
	var result := _column_panel(details, Color("305141"))
	result.add_child(_label("CRAFT COMPLETE", 27, Color("e4dfaa")))
	result.add_child(_icon(completed_id, 126))
	result.add_child(_label(completed_id.replace("_", " ").capitalize() + (" • now %s!" % "★".repeat(int(game.bag_quality.get(completed_id, 0))) if CARRY.is_bag(completed_id) else " added to your inventory!"), 21, Color("c3e9b7")))
	var again := Button.new()
	again.text = "CRAFT ANOTHER"
	again.custom_minimum_size = Vector2(0, 52)
	SKIN.apply_button(again, "green")
	again.pressed.connect(_clear_result)
	result.add_child(again)

func _clear_result() -> void:
	completed_id = ""
	selected_id = _first_recipe(selected_station)
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_page()
		get_viewport().set_input_as_handled()
