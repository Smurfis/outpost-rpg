extends CanvasLayer
## Outpost v0.4: physical-material loading and animated hands-on craft actions.
## Browse remotely; to produce an item you must stand beside its matching station.
var game
var shell: Control
var title: Label
var subtitle: Label
var station_tabs: HBoxContainer
var recipes_list: VBoxContainer
var details: VBoxContainer
var left_scroll: ScrollContainer
var right_scroll: ScrollContainer
var current_page: String = "craft"
var selected_station: String = "workbench"
var selected_id: String = ""
var loaded: Dictionary = {}
var completed_id: String = ""
var progress_bar: ProgressBar
var work_counter: Label
var work_label: Label
var action_button: Button
var action_art: TextureRect
var preview_rig: Node3D
var preview_angle: float = 0.0
var station_names: Dictionary = {"workbench":"WOODWORK", "forge":"FORGE", "loom":"LOOM", "campfire":"CAMPFIRE"}
var action_names: Dictionary = {"workbench":"HAMMER", "forge":"STRIKE", "loom":"WEAVE", "campfire":"STIR"}
var item_ids: Array = ["wood", "stone", "fiber", "berries", "iron", "coal", "clay", "herbs", "mushrooms", "reeds", "hide", "coins", "iron_ingot", "linen", "bricks", "meal", "tonic", "stew", "spear", "axe", "pickaxe", "shield", "satchel", "iron_blade", "cloak"]

func setup(ref: Node) -> void:
	game = ref

func _ready() -> void:
	layer = 8
	shell = Control.new()
	shell.name = "CraftingInterface"
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := PanelContainer.new()
	frame.anchor_left = 0.075
	frame.anchor_right = 0.925
	frame.anchor_top = 0.045
	frame.anchor_bottom = 0.965
	frame.add_theme_stylebox_override("panel", _style(Color("172c30"), Color("baa278"), 13))
	shell.add_child(frame)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	frame.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	title = _label("OUTPOST | CRAFTING", 26, Color("f5e2b8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var bag := Button.new()
	bag.text = "BAG"
	bag.custom_minimum_size = Vector2(80, 46)
	bag.pressed.connect(_switch_bag)
	header.add_child(bag)
	var gear := Button.new()
	gear.text = "GEAR"
	gear.custom_minimum_size = Vector2(86, 46)
	gear.pressed.connect(_switch_equipment)
	header.add_child(gear)
	var progression := Button.new()
	progression.text = "SKILLS / GEAR+"
	progression.custom_minimum_size = Vector2(152, 46)
	progression.pressed.connect(_open_progression)
	header.add_child(progression)
	var craft := Button.new()
	craft.text = "CRAFT"
	craft.custom_minimum_size = Vector2(88, 46)
	craft.pressed.connect(_switch_craft)
	header.add_child(craft)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(58, 46)
	close.pressed.connect(close_page)
	header.add_child(close)
	subtitle = _label("", 15, Color("b8cec5"))
	page.add_child(subtitle)
	station_tabs = HBoxContainer.new()
	station_tabs.add_theme_constant_override("separation", 6)
	page.add_child(station_tabs)
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 12)
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(panes)
	left_scroll = ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(260, 0)
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.72
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panes.add_child(left_scroll)
	recipes_list = VBoxContainer.new()
	recipes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipes_list.add_theme_constant_override("separation", 7)
	left_scroll.add_child(recipes_list)
	right_scroll = ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(315, 0)
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 1.28
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panes.add_child(right_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 10)
	right_scroll.add_child(details)
	visible = false

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
	label.add_theme_font_size_override("font_size", font_size)
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
	return image

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _column_panel(target: Node, color: Color) -> VBoxContainer:
	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel", _style(color))
	target.add_child(container)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	container.add_child(column)
	return column

func _switch_bag() -> void:
	current_page = "bag"
	refresh()

func _switch_craft() -> void:
	current_page = "craft"
	refresh()

func _open_progression() -> void:
	close_page()
	game.show_progression("skills")

func _switch_equipment() -> void:
	current_page = "equipment"
	refresh()

func open(page: String) -> void:
	if visible and current_page == page:
		close_page()
		return
	current_page = page
	visible = true
	if game.hud != null:
		game.hud.move_vector = Vector2.ZERO
	if page == "craft" and game.crafting.is_empty():
		var station: String = game.closest_station()
		if station != "":
			selected_station = station
		if selected_id == "":
			selected_id = _first_recipe(selected_station)
	refresh()

func close_page() -> void:
	visible = false

func _first_recipe(station: String) -> String:
	for recipe in game.recipes:
		if str(recipe.get("station", "workbench")) == station:
			return str(recipe.get("id", ""))
	return ""

func _station_change(station: String) -> void:
	if not game.crafting.is_empty():
		return
	selected_station = station
	selected_id = _first_recipe(station)
	loaded.clear()
	completed_id = ""
	refresh()

func _recipe_change(id: String) -> void:
	if not game.crafting.is_empty():
		return
	selected_id = id
	loaded.clear()
	completed_id = ""
	refresh()

func refresh() -> void:
	if not visible:
		return
	progress_bar = null
	work_counter = null
	work_label = null
	action_button = null
	action_art = null
	_clear(station_tabs)
	_clear(recipes_list)
	_clear(details)
	if current_page == "bag":
		_render_bag()
	elif current_page == "equipment":
		_render_equipment()
	else:
		_render_craft()

func _render_bag() -> void:
	title.text = "OUTPOST | INVENTORY"
	subtitle.text = "Resources, crafted materials, tools and food. Stored on this device."
	station_tabs.add_child(_label("EQUIPMENT & RESOURCES", 17, Color("f1d3a0")))
	var owned: int = 0
	for id in item_ids:
		var item: String = str(id)
		var qty: int = int(game.inventory.get(item, 0))
		if qty > 0:
			owned += 1
		var row := _column_panel(recipes_list, Color("233b3e"))
		var horizontal := HBoxContainer.new()
		row.add_child(horizontal)
		horizontal.add_child(_icon(item, 42))
		horizontal.add_child(_label(item.replace("_", " ").capitalize(), 19, Color("f3deae") if qty > 0 else Color("a3afa9")))
		horizontal.add_child(_label("x%d" % qty, 18, Color("efead2")))
		if item in ["meal", "tonic", "stew"] and qty > 0:
			var use_button := Button.new()
			use_button.text = "USE"
			use_button.pressed.connect(_use_food.bind(item))
			horizontal.add_child(use_button)
	var overview := _column_panel(details, Color("263b3d"))
	overview.add_child(_label("YOUR ADVENTURER", 24, Color("f1ddb1")))
	overview.add_child(_icon("shield", 90))
	overview.add_child(_label("%d / %d item types collected" % [owned, item_ids.size()], 18))
	overview.add_child(_label("XP: %d     Boars defeated: %d" % [game.experience, game.kills], 18))
	overview.add_child(_label("Tools automatically improve harvest yields.\nWeapons automatically upgrade combat.\nFood can restore health.", 17, Color("c4d7c7")))
	overview.add_child(_label("Tip: Use CRAFT near a station to make new equipment.", 17, Color("e3c58b")))
	var equip_button := Button.new()
	equip_button.text = "OPEN EQUIPMENT"
	equip_button.custom_minimum_size = Vector2(0, 54)
	equip_button.pressed.connect(_switch_equipment)
	overview.add_child(equip_button)

func _render_equipment() -> void:
	title.text = "OUTPOST | EQUIPMENT"
	subtitle.text = "Equip or unequip your crafted gear. Bonuses only apply while worn."
	station_tabs.add_child(_label("GEAR SLOTS | TAP OWNED ITEMS TO EQUIP", 16, Color("e7d5a2")))
	var slot_names: Dictionary = {
		"weapon": "MAIN HAND",
		"offhand": "OFF HAND",
		"back": "CLOAK",
		"tool_wood": "WOODCUTTING",
		"tool_mining": "MINING",
		"tool_forage": "FORAGING"
	}
	var possible: Dictionary = {
		"weapon": ["spear", "iron_blade"],
		"offhand": ["shield"],
		"back": ["cloak"],
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
			unequip.pressed.connect(_equip_click.bind(str(game.equipment[slot])))
			row.add_child(unequip)
		for item in possible[slot]:
			var item_id: String = str(item)
			if int(game.inventory.get(item_id, 0)) <= 0:
				continue
			var option := Button.new()
			option.text = ("EQUIPPED  " if game.is_equipped(item_id) else "EQUIP  ") + item_id.replace("_", " ").capitalize()
			option.custom_minimum_size = Vector2(0, 50)
			option.disabled = game.is_equipped(item_id)
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
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	details_text.add_child(_label("Tip: craft new gear at the four stations, then equip it here.", 16, Color("bcc9be")))

func _use_food(id: String) -> void:
	var amount: float = 40.0
	if id == "tonic":
		amount = 65.0
	elif id == "stew":
		amount = 75.0
	game.consume(id, amount)

func _render_craft() -> void:
	title.text = "OUTPOST | HANDCRAFTING"
	var nearby: String = game.closest_station()
	subtitle.text = "Nearby: %s     |     Pick a recipe, load materials and work the station." % (nearby.capitalize() if nearby != "" else "None — explore recipes; move to station to craft")
	for station_id in ["workbench", "forge", "loom", "campfire"]:
		var tab := Button.new()
		tab.text = str(station_names[station_id])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.disabled = not game.crafting.is_empty() and selected_station != station_id
		tab.modulate = Color("f2dcaa") if selected_station == station_id else Color("9aaead")
		tab.pressed.connect(_station_change.bind(station_id))
		station_tabs.add_child(tab)
	for recipe in game.recipes:
		if str(recipe.get("station", "workbench")) != selected_station:
			continue
		var id: String = str(recipe.get("id", ""))
		var result_id: String = str(recipe.get("result", ""))
		var row := HBoxContainer.new()
		recipes_list.add_child(row)
		row.add_child(_icon(result_id, 46))
		var choose := Button.new()
		choose.text = str(recipe.get("name", id))
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choose.custom_minimum_size = Vector2(0, 55)
		choose.disabled = not game.crafting.is_empty()
		if selected_id == id:
			choose.modulate = Color("f8d9a0")
		choose.pressed.connect(_recipe_change.bind(id))
		row.add_child(choose)
	if not game.crafting.is_empty():
		_render_work()
	elif completed_id != "":
		_render_result()
	else:
		if selected_id == "" or game._recipe_by_id(selected_id).is_empty() or str(game._recipe_by_id(selected_id).get("station", "")) != selected_station:
			selected_id = _first_recipe(selected_station)
		_render_recipe()

func _render_recipe() -> void:
	var recipe: Dictionary = game._recipe_by_id(selected_id)
	if recipe.is_empty():
		details.add_child(_label("Choose a recipe from the list.", 21))
		return
	var product_id: String = str(recipe.get("result", ""))
	var intro := _column_panel(details, Color("2b403e"))
	var head := HBoxContainer.new()
	intro.add_child(head)
	head.add_child(_icon(product_id, 87))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	info.add_child(_label(str(recipe.get("name", "")), 24, Color("f0d9aa")))
	info.add_child(_label(str(recipe.get("desc", "")), 16, Color("bdd0c8")))
	info.add_child(_label("Output x%d     •     %s" % [int(recipe.get("amount", 1)), str(station_names[selected_station])], 17))
	details.add_child(_label("1. LOAD MATERIALS", 18, Color("e5d5a4")))
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for key in ingredients:
		var id: String = str(key)
		var needed: int = int(ingredients[key])
		var owned: int = int(game.inventory.get(id, 0))
		var loaded_now: bool = bool(loaded.get(id, false))
		var available: bool = owned >= needed
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(0, 65)
		slot.disabled = not available or game.owns_unique(product_id)
		slot.text = ("LOADED   " if loaded_now else "TAP TO LOAD   ") + id.replace("_", " ").capitalize() + "   " + str(owned) + "/" + str(needed)
		slot.modulate = Color("b0e9b9") if loaded_now else Color("edc8a3") if available else Color("ab7673")
		slot.pressed.connect(_toggle_ingredient.bind(id))
		var row := HBoxContainer.new()
		details.add_child(row)
		row.add_child(_icon(id, 54))
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slot)
	var loaded_count: int = 0
	for key in ingredients:
		if bool(loaded.get(str(key), false)):
			loaded_count += 1
	details.add_child(_label("Material slots: %d / %d" % [loaded_count, ingredients.size()], 16, Color("d7d8c6")))
	var begin := Button.new()
	begin.text = "2. BEGIN CRAFTING"
	begin.custom_minimum_size = Vector2(0, 60)
	begin.disabled = loaded_count < ingredients.size() or not game.can_craft(selected_id)
	begin.pressed.connect(_start_craft)
	details.add_child(begin)
	if not game.near_station(selected_station):
		details.add_child(_label("Move beside the %s to start." % selected_station.capitalize(), 17, Color("f0bf8a")))
	elif game.owns_unique(product_id):
		details.add_child(_label("You already own this unique equipment.", 17, Color("d6c591")))

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
	stage.add_child(progress_bar)
	work_counter = _label("", 18)
	stage.add_child(work_counter)
	work_label = _label("", 17, Color("b9dfce"))
	stage.add_child(work_label)
	action_button = Button.new()
	action_button.text = str(action_names.get(str(active.get("station", "")), "WORK")) + " • TAP"
	action_button.custom_minimum_size = Vector2(0, 78)
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
	selected_id = ""
	if visible:
		refresh()

func _render_result() -> void:
	var result := _column_panel(details, Color("305141"))
	result.add_child(_label("CRAFT COMPLETE", 27, Color("e4dfaa")))
	result.add_child(_icon(completed_id, 126))
	result.add_child(_label(completed_id.replace("_", " ").capitalize() + " added to your inventory!", 21, Color("c3e9b7")))
	var again := Button.new()
	again.text = "CHOOSE ANOTHER RECIPE"
	again.custom_minimum_size = Vector2(0, 60)
	again.pressed.connect(_clear_result)
	result.add_child(again)

func _clear_result() -> void:
	completed_id = ""
	selected_id = _first_recipe(selected_station)
	refresh()
