extends CanvasLayer
## Actual crafting/inventory UI. Built with Godot controls, not popup toasts.
var game
var shell: Control
var panel: PanelContainer
var title: Label
var subtitle: Label
var entries: VBoxContainer
var scroll: ScrollContainer
var current_page: String = "bag"

func setup(ref: Node) -> void:
	game = ref

func _ready() -> void:
	layer = 8
	shell = Control.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shell)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.03, 0.04, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(dim)
	panel = PanelContainer.new()
	panel.anchor_left = 0.18
	panel.anchor_top = 0.09
	panel.anchor_right = 0.82
	panel.anchor_bottom = 0.92
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17272b")
	style.border_color = Color("b59a67")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	shell.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	title = Label.new()
	title.text = "OUTPOST"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("f5dfaa"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := Button.new()
	close.text = "  X  "
	close.custom_minimum_size = Vector2(72, 48)
	close.pressed.connect(close_page)
	top.add_child(close)
	subtitle = Label.new()
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("b8c9c2"))
	layout.add_child(subtitle)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	layout.add_child(tabs)
	var bag := Button.new()
	bag.text = " INVENTORY "
	bag.custom_minimum_size = Vector2(155, 49)
	bag.pressed.connect(func() -> void: open("bag"))
	tabs.add_child(bag)
	var craft := Button.new()
	craft.text = " CRAFTING "
	craft.custom_minimum_size = Vector2(155, 49)
	craft.pressed.connect(func() -> void: open("craft"))
	tabs.add_child(craft)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	entries = VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 10)
	scroll.add_child(entries)
	visible = false

func open(page: String) -> void:
	if visible and page == current_page:
		close_page()
		return
	current_page = page
	visible = true
	if game.hud != null:
		game.hud.move_vector = Vector2.ZERO
	refresh()

func close_page() -> void:
	visible = false

func refresh() -> void:
	if not visible:
		return
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	if current_page == "bag":
		_show_bag()
	else:
		_show_craft()

func _text(value: String, size: int = 18, tint: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _row() -> HBoxContainer:
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263c40")
	style.set_corner_radius_all(7)
	style.set_content_margin_all(9)
	container.add_theme_stylebox_override("panel", style)
	entries.add_child(container)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	container.add_child(row)
	return row

func _icon(name: String) -> TextureRect:
	var node := TextureRect.new()
	var safe: String = name
	if safe not in ["wood", "stone", "hide", "coins", "gather", "attack", "craft", "heart", "spear", "flag", "fiber", "berries", "axe", "pickaxe", "shield", "satchel", "meal"]:
		safe = "craft"
	node.texture = load("res://assets/icons/" + safe + ".svg") as Texture2D
	node.custom_minimum_size = Vector2(52, 52)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return node

func _show_bag() -> void:
	title.text = "INVENTORY"
	subtitle.text = "Your materials, equipment and provisions. Auto-saved locally."
	var keys := ["wood", "stone", "fiber", "berries", "hide", "coins", "spear", "axe", "pickaxe", "shield", "satchel", "meal"]
	for id in keys:
		var row := _row()
		var key: String = str(id)
		row.add_child(_icon(key))
		var qty: int = int(game.inventory.get(key, 0))
		var info := _text("%s   x%d" % [key.capitalize(), qty], 21, Color("f2e6c4") if qty > 0 else Color("81999a"))
		row.add_child(info)
		if key == "meal" and qty > 0:
			var use_button := Button.new()
			use_button.text = "EAT (+40 HP)"
			use_button.custom_minimum_size = Vector2(154, 54)
			use_button.pressed.connect(_eat)
			row.add_child(use_button)
		else:
			row.add_child(_text("OWNED" if qty > 0 and key in ["spear", "axe", "pickaxe", "shield", "satchel"] else ""))
	entries.add_child(_text("Axe doubles wood • Pickaxe doubles stone • Shield reduces boar damage.", 16, Color("d0c49d")))

func _show_craft() -> void:
	title.text = "WORKSHOP RECIPES"
	var in_range: bool = game.near_workshop()
	subtitle.text = "In workshop range — tap CRAFT on a recipe." if in_range else "Walk near the workbench to craft. You can browse recipes anywhere."
	for record in game.recipes:
		if not (record is Dictionary):
			continue
		var recipe: Dictionary = record
		var id: String = str(recipe.get("id", ""))
		var result_id: String = str(recipe.get("result", ""))
		var row := _row()
		row.add_child(_icon(result_id))
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(body)
		body.add_child(_text(str(recipe.get("name", id)), 20, Color("f0d8a7")))
		body.add_child(_text(str(recipe.get("desc", "")), 15, Color("c0c8bd")))
		var cost_parts: PackedStringArray = []
		var ingredients: Dictionary = recipe.get("ingredients", {})
		for item in ingredients:
			var owned: int = int(game.inventory.get(str(item), 0))
			cost_parts.append("%s %d/%d" % [str(item), owned, int(ingredients[item])])
		body.add_child(_text(" • ".join(cost_parts), 16, Color("bddbc0")))
		var button := Button.new()
		button.text = "OWNED" if game.owns_unique(result_id) else "CRAFT"
		button.disabled = not game.can_craft(id)
		button.custom_minimum_size = Vector2(100, 60)
		button.pressed.connect(_craft_click.bind(id))
		row.add_child(button)

func _craft_click(id: String) -> void:
	game.craft_item(id)

func _eat() -> void:
	game.use_meal()

