extends CanvasLayer
## Outpost mobile HUD: compact live panels, gold-ringed touch actions and a
## functioning bottom hotbar. No flattened mock-up or imaginary game stats.
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
const CONTROL_PREFS := "user://outpost_controls.cfg"
var game
var root: Control
var status: Label
var health_numbers: Label
var bag_weight_label: Label
var camera_drag_finger: int = -1
var camera_hold_seconds: float = 0.0
var camera_hold_ready: bool = false
var camera_hold_origin: Vector2 = Vector2.ZERO
var xp_level_label: Label
var quick_buttons: Dictionary = {}
var quick_hold_finger: int = -1
var quick_hold_mouse: bool = false
var quick_hold_seconds: float = 0.0
var quick_hold_kind: String = ""
var quick_hold_origin: Vector2 = Vector2.ZERO
var quick_tray: Panel
var quick_tray_list: VBoxContainer
var quick_tray_open: bool = false
var quick_options: Array[String] = []
var quick_selected: int = -1
var quick_ignore_mouse_until: int = 0
var quick_icon_cache: Dictionary = {}
var hero_detail: Label
var clock_label: Label
var torch_button: Button
var torch_label: Label
var quest: Label
var quest_frame: Panel
var quest_toggle: Button
var context_prompt_frame: Panel
var context_is_actionable: bool = false
var objective_is_complete: bool = false
var gesture_hint_timeout: float = 8.0
var tool_gesture_hint: Label
var camera_gesture_hint: Label
var quest_detail: Label
var quest_detail_back: Panel
var quest_expanded: bool = false
var hint: Label
var toast_label: Label
var health_bar: ProgressBar
var xp_bar: ProgressBar
var toast_panel: Panel
var items: Dictionary = {}
var joystick: Panel
var knob: Panel
var move_vector := Vector2.ZERO
var finger := -1
var mouse_stick := false
var gather_button: Button
var attack_button: Button
var craft_button: Button
var heal_button: Button
var smart_button: Button
var smart_tray: Panel
var smart_tool_list: VBoxContainer
var smart_tool_rows: Array[Button] = []
var smart_tool_ids: Array[String] = []
var smart_selected_index: int = -1
var smart_hold_finger: int = -1
var smart_hold_mouse: bool = false
var smart_hold_seconds: float = 0.0
var smart_hold_origin: Vector2 = Vector2.ZERO
var smart_tray_open: bool = false
var smart_icon_id: String = ""
var smart_ignore_mouse_until: int = 0
var toast_time := 0.0
var mana_bar: ProgressBar
var mana_numbers: Label
var xp_level_badge: Label
var wallet_frame: Panel
var wallet_collapse: Button
var wallet_open: bool = true
var wallet_bag: Button
var wallet_coin: Label
var wallet_resource_icon: TextureRect
var wallet_resource_count: Label
var wallet_resource_id: String = "wood"
var last_inventory_snapshot: Dictionary = {}
var menu_button: Button
var top_menu_panel: Panel
var top_menu_actions: Array[Button] = []
var top_menu_open: bool = false
var top_menu_pressed: bool = false
var top_menu_hold_seconds: float = 0.0
var top_menu_opened_by_hold: bool = false
var floating_joystick_enabled: bool = false
var player_display_name: String = "Adventurer"
var control_settings_panel: Panel
var floating_mode_toggle: CheckButton
var name_edit: LineEdit
var skill_detail_panel: Panel
var skill_detail_text: Label

func setup(ref: Node) -> void:
	game = ref

func _ready() -> void:
	root = Control.new()
	root.name = "OutpostHUD"
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Small live status strip. No generic, permanently fixed cartoon portrait:
	# the gold sigil is an independent icon; equipment retains the real 3D avatar.
	var status_frame: Panel = _panel(0.018, 0.019, 0.247, 0.127)
	status_frame.name = "HeroStatusFrame"
	var sigil := TextureRect.new()
	sigil.name = "OutpostSigil"
	sigil.texture = load("res://assets/ui/icons/outpost_sigil.svg") as Texture2D
	sigil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sigil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sigil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sigil)
	_anchors(sigil, 0.024, 0.036, 0.057, 0.103)
	status = _label("Adventurer", 16, Color("#fff1c7"), 0.063, 0.026, 0.236, 0.058)
	status.clip_text = true
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	health_bar = _meter(0.065, 0.061, 0.235, 0.083, Color("#d74c43"))
	health_numbers = _label("100 / 100 HP", 14, Color("#fff1db"), 0.068, 0.061, 0.232, 0.083)
	health_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_bar = _meter(0.065, 0.089, 0.235, 0.110, Color("#417cdb"))
	mana_bar.value = 0.0 # Reserved for real mana support; no fictitious MP values.
	mana_numbers = _label("MP —", 13, Color("#d8e6ff"), 0.070, 0.089, 0.230, 0.110)
	mana_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_bar = _meter(0.111, 0.955, 0.979, 0.990, Color("#a86ed7"))
	xp_bar.name = "CharacterLevelXP"
	xp_level_badge = _label("Lv. 1", 16, SKIN.GOLD, 0.028, 0.951, 0.111, 0.993)
	xp_level_badge.name = "CharacterLevelBadge"
	xp_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_level_label = _label("0 / 100 XP", 15, Color("#fff2d1"), 0.142, 0.957, 0.954, 0.988)
	xp_level_label.name = "CharacterLevelLabel"
	xp_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_detail = _label("Training Blade  •  M1", 13, Color("#edc98d"), 0.063, 0.110, 0.236, 0.131)
	hero_detail.clip_text = true
	hero_detail.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Small wallet shows only real coin balance and the last tracked material.
	# Other holdings and carry weight live in the bag, not in a permanent HUD.
	wallet_frame = _panel(0.302, 0.018, 0.710, 0.087)
	wallet_frame.name = "ResourceQuickChips"
	wallet_collapse = Button.new()
	wallet_collapse.name = "WalletCollapse"
	wallet_collapse.text = "‹"
	SKIN.apply_button(wallet_collapse, "wood")
	root.add_child(wallet_collapse)
	_anchors(wallet_collapse, 0.304, 0.023, 0.340, 0.082)
	wallet_collapse.pressed.connect(_toggle_wallet)
	wallet_coin = _label("◈ 0", 17, SKIN.GOLD, 0.364, 0.029, 0.460, 0.079)
	wallet_coin.name = "WalletCoinCount"
	wallet_resource_icon = TextureRect.new()
	wallet_resource_icon.name = "LastTrackedResourceIcon"
	wallet_resource_icon.texture = load("res://assets/icons/wood.svg") as Texture2D
	wallet_resource_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallet_resource_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wallet_resource_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wallet_resource_icon)
	_anchors(wallet_resource_icon, 0.472, 0.029, 0.499, 0.074)
	wallet_resource_count = _label("Wood ×0", 15, SKIN.CREAM, 0.501, 0.029, 0.628, 0.079)
	wallet_resource_count.name = "LastTrackedResourceCount"
	wallet_resource_count.clip_text = true
	wallet_bag = _action("bag", "BAG", 0.638, 0.019, 0.699, 0.089, "round")
	wallet_bag.name = "Action_bag"
	# Retain stable public dictionary keys for existing gameplay/test callers.
	for key in ["wood", "stone", "hide", "coins"]:
		var count := _label("0", 12, SKIN.CREAM, 0.0, 0.0, 0.01, 0.01)
		count.name = "HiddenResource_" + key
		count.visible = false
		items[key] = count
	# Overload notification appears only when load needs attention; the bag
	# itself shows the full capacity meter and bonus information.
	bag_weight_label = _label("", 14, Color("#e3b75d"), 0.020, 0.183, 0.247, 0.208)
	bag_weight_label.name = "CarryWeightLabel"
	bag_weight_label.visible = false

	# The persistent quest ribbon is single-line and ellipsis-safe; on
	# completion it collapses to a small journal button instead of endlessly
	# announcing the finished starter quest.
	quest_frame = _panel(0.018, 0.213, 0.316, 0.283)
	quest_frame.name = "QuestBanner"
	quest_toggle = Button.new()
	quest_toggle.name = "QuestToggle"
	quest_toggle.text = "QUESTS ▾"
	SKIN.apply_button(quest_toggle, "wood")
	root.add_child(quest_toggle)
	_anchors(quest_toggle, 0.028, 0.220, 0.113, 0.277)
	quest_toggle.pressed.connect(_toggle_quest)
	quest = _label("Gather wood and stone", 16, Color("#ffe6bb"), 0.124, 0.222, 0.304, 0.275)
	quest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest.autowrap_mode = TextServer.AUTOWRAP_OFF
	quest.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quest.clip_text = true
	quest_detail_back = _panel(0.021, 0.292, 0.320, 0.463)
	quest_detail_back.name = "QuestJournal"
	quest_detail_back.add_theme_stylebox_override("panel", SKIN.box("parchment"))
	quest_detail_back.visible = false
	quest_detail = _label("", 16, SKIN.INK, 0.038, 0.309, 0.300, 0.446)
	quest_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_detail.visible = false

	# Centered below the journal, not overlapping quest text. One notice at a time.
	toast_panel = _panel(0.355, 0.225, 0.682, 0.295)
	toast_panel.name = "LootQuestToast"
	toast_panel.add_theme_stylebox_override("panel", SKIN.box("toast"))
	toast_panel.visible = false
	toast_label = _label("", 16, SKIN.INK, 0.371, 0.228, 0.665, 0.290)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.visible = false

	clock_label = _label("DAY 09:07", 17, Color("#fff0c5"), 0.785, 0.033, 0.921, 0.098)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# A single top-right menu opens the other controls on demand.
	top_menu_panel = _panel(0.710, 0.122, 0.989, 0.391)
	top_menu_panel.name = "FunctionalHotbar"
	top_menu_panel.visible = false
	menu_button = _action("menu", "MENU", 0.925, 0.018, 0.986, 0.111, "round")
	menu_button.name = "TopRightMenuButton"
	menu_button.button_down.connect(_menu_button_down)
	menu_button.button_up.connect(_menu_button_up)
	menu_button.pressed.connect(_menu_button_pressed)
	craft_button = _action("craft", "CRAFT", 0.729, 0.148, 0.804, 0.254, "round")
	top_menu_actions.append(craft_button)
	top_menu_actions.append(_action("gear", "GEAR", 0.816, 0.148, 0.891, 0.254, "round"))
	var multiplayer_entry := Button.new()
	multiplayer_entry.name = "CoopEntryButton"
	multiplayer_entry.text = "CO-OP"
	SKIN.apply_button(multiplayer_entry, "wood")
	root.add_child(multiplayer_entry)
	_anchors(multiplayer_entry, 0.901, 0.148, 0.982, 0.254)
	multiplayer_entry.pressed.connect(_open_coop)
	top_menu_actions.append(multiplayer_entry)
	var skill_entry := Button.new()
	skill_entry.name = "SkillMenuButton"
	skill_entry.text = "SKILLS"
	SKIN.apply_button(skill_entry, "wood")
	root.add_child(skill_entry)
	_anchors(skill_entry, 0.729, 0.270, 0.804, 0.374)
	skill_entry.pressed.connect(_show_skill_details)
	top_menu_actions.append(skill_entry)
	var journal_entry := Button.new()
	journal_entry.name = "JournalMenuButton"
	journal_entry.text = "JOURNAL"
	SKIN.apply_button(journal_entry, "wood")
	root.add_child(journal_entry)
	_anchors(journal_entry, 0.816, 0.270, 0.891, 0.374)
	journal_entry.pressed.connect(_open_journal)
	top_menu_actions.append(journal_entry)
	var settings_entry := Button.new()
	settings_entry.name = "InGameSettingsButton"
	settings_entry.text = "SETTINGS"
	SKIN.apply_button(settings_entry, "wood")
	root.add_child(settings_entry)
	_anchors(settings_entry, 0.901, 0.270, 0.982, 0.374)
	settings_entry.pressed.connect(_show_control_settings)
	top_menu_actions.append(settings_entry)
	for option in top_menu_actions:
		option.visible = false
	# Offhand torch remains available without interfering with three ability slots.
	torch_button = _action("torch", "TORCH", 0.700, 0.844, 0.757, 0.934, "round")

	# The single context button replaces redundant ATTACK and GATHER tiles.
	# Three real weapon-mastery skill holders arc around its upper-left side.
	quick_buttons["skill_1"] = _action("skill_1", "POWER", 0.819, 0.600, 0.881, 0.712, "round")
	quick_buttons["skill_2"] = _action("skill_2", "CLEAVE", 0.755, 0.667, 0.814, 0.779, "round")
	quick_buttons["skill_3"] = _action("skill_3", "SUNDER", 0.705, 0.760, 0.764, 0.870, "round")
	# Both utility radials start empty. Tap uses the equipped item; hold and
	# slide upwards chooses among actually owned consumables.
	quick_buttons["consumable"] = _action("consumable", "FOOD", 0.773, 0.852, 0.830, 0.947, "round")
	quick_buttons["potion"] = _action("potion", "POTION", 0.835, 0.842, 0.894, 0.943, "round")
	for key in ["consumable", "potion"]:
		(quick_buttons[key] as Button).mouse_filter = Control.MOUSE_FILTER_IGNORE
	smart_button = _action("interact", "INTERACT", 0.895, 0.740, 0.986, 0.941, "round")
	smart_button.name = "Action_interact"
	smart_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Always-visible tiny upward cue retains the slider affordance after
	# temporary tutorial text disappears; never intercepts touch gestures.
	var chevron := Label.new()
	chevron.name = "ToolSwipeChevron"
	chevron.text = "↑"
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.add_theme_color_override("font_color", SKIN.GOLD)
	chevron.add_theme_font_size_override("font_size", 17)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smart_button.add_child(chevron)
	chevron.anchor_left = 0.76
	chevron.anchor_right = 0.97
	chevron.anchor_top = 0.02
	chevron.anchor_bottom = 0.26
	var swipe_hint := Label.new()
	swipe_hint.name = "QuickToolGestureHint"
	swipe_hint.text = "HOLD ↑ TOOLS"
	swipe_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swipe_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	swipe_hint.add_theme_color_override("font_color", Color("#ffdea0"))
	swipe_hint.add_theme_font_size_override("font_size", 13)
	swipe_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_gesture_hint = swipe_hint
	root.add_child(swipe_hint)
	_anchors(swipe_hint, 0.890, 0.696, 0.990, 0.740)
	_build_smart_tray()
	_build_quick_tray()
	# Context prompts live near the bottom center, only when something
	# is actually usable. Generic explore prose never occupies the playfield.
	context_prompt_frame = _panel(0.343, 0.856, 0.694, 0.918)
	context_prompt_frame.name = "ContextPrompt"
	hint = _label("", 16, SKIN.CREAM, 0.362, 0.861, 0.676, 0.914)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.clip_text = true
	context_prompt_frame.visible = false
	hint.visible = false

	joystick = Panel.new()
	joystick.name = "MovementStick"
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring: StyleBoxFlat = SKIN.flat("hud")
	ring.bg_color = Color(0.16, 0.10, 0.08, 0.64)
	ring.border_color = SKIN.GOLD
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(90)
	joystick.add_theme_stylebox_override("panel", ring)
	root.add_child(joystick)
	joystick.size = Vector2(148, 148)
	knob = Panel.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thumb: StyleBoxFlat = SKIN.flat("parchment_light")
	thumb.set_corner_radius_all(60)
	thumb.set_border_width_all(3)
	knob.add_theme_stylebox_override("panel", thumb)
	joystick.add_child(knob)
	knob.size = Vector2(55, 55)
	_position_stick()
	_make_camera_drag_hint()
	_build_control_settings()
	_build_skill_details()
	_load_control_prefs()
	_position_stick()

func _toggle_wallet() -> void:
	wallet_open = not wallet_open
	_apply_wallet_layout()

func _apply_wallet_layout() -> void:
	wallet_coin.visible = wallet_open
	wallet_resource_icon.visible = wallet_open
	wallet_resource_count.visible = wallet_open
	wallet_collapse.text = "‹" if wallet_open else "›"
	_anchors(wallet_frame, 0.302, 0.018, 0.710 if wallet_open else 0.410, 0.087)
	_anchors(wallet_bag, 0.638 if wallet_open else 0.349, 0.019, 0.699 if wallet_open else 0.405, 0.089)

func _refresh_wallet(inventory: Dictionary) -> void:
	if wallet_coin == null:
		return
	wallet_coin.text = "COINS  %d" % int(inventory.get("coins", 0))
	for key in inventory:
		var id: String = str(key)
		if id == "coins" or id in ["torch", "spear", "axe", "pickaxe", "shield", "meal", "tonic", "stew", "cloak", "satchel", "iron_blade"]:
			continue
		var amount: int = int(inventory.get(id, 0))
		var previous: int = int(last_inventory_snapshot.get(id, 0))
		if amount > previous:
			wallet_resource_id = id
	var current_amount: int = int(inventory.get(wallet_resource_id, 0))
	if current_amount == 0 and last_inventory_snapshot.is_empty():
		for key in inventory:
			var id: String = str(key)
			if id not in ["coins", "torch"] and int(inventory.get(id, 0)) > 0:
				wallet_resource_id = id
				current_amount = int(inventory.get(id, 0))
				break
	wallet_resource_count.text = "%s ×%d" % [wallet_resource_id.capitalize(), current_amount]
	var path: String = "res://assets/icons/" + wallet_resource_id + ".svg"
	if ResourceLoader.exists(path):
		wallet_resource_icon.texture = load(path) as Texture2D
	last_inventory_snapshot = inventory.duplicate()

func _menu_button_down() -> void:
	top_menu_pressed = true
	top_menu_hold_seconds = 0.0
	top_menu_opened_by_hold = false

func _menu_button_up() -> void:
	top_menu_pressed = false

func _menu_button_pressed() -> void:
	if top_menu_opened_by_hold:
		top_menu_opened_by_hold = false
		return
	_set_top_menu(not top_menu_open)

func _set_top_menu(open_menu: bool) -> void:
	top_menu_open = open_menu
	top_menu_panel.visible = open_menu
	for option in top_menu_actions:
		option.visible = open_menu

func _open_journal() -> void:
	_set_top_menu(false)
	if not quest_expanded:
		_toggle_quest()

func _build_skill_details() -> void:
	skill_detail_panel = _panel(0.337, 0.245, 0.680, 0.650)
	skill_detail_panel.name = "WeaponSkillDetails"
	skill_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	skill_detail_panel.add_theme_stylebox_override("panel", SKIN.box("frame"))
	skill_detail_panel.visible = false
	var title: Label = _label("WEAPON MASTERY", 21, SKIN.GOLD, 0.363, 0.274, 0.643, 0.335)
	title.name = "SkillDetailHeading"
	skill_detail_panel.add_child(title)
	root.remove_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 16
	title.offset_top = 13
	title.offset_right = -16
	title.offset_bottom = 58
	skill_detail_text = Label.new()
	skill_detail_text.name = "SkillDetailText"
	skill_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_detail_text.add_theme_font_size_override("font_size", 17)
	skill_detail_text.add_theme_color_override("font_color", SKIN.CREAM)
	skill_detail_panel.add_child(skill_detail_text)
	skill_detail_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_detail_text.offset_left = 20
	skill_detail_text.offset_top = 74
	skill_detail_text.offset_right = -20
	skill_detail_text.offset_bottom = -75
	var close := Button.new()
	close.name = "CloseSkills"
	close.text = "CLOSE"
	SKIN.apply_button(close, "wood")
	skill_detail_panel.add_child(close)
	close.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	close.offset_left = 20
	close.offset_top = -58
	close.offset_right = -20
	close.offset_bottom = -14
	close.pressed.connect(func() -> void: skill_detail_panel.visible = false)

func _show_skill_details() -> void:
	_set_top_menu(false)
	if game == null:
		return
	control_settings_panel.visible = false
	var weapon: String = game.current_weapon_id()
	var rank: int = game.mastery_rank(weapon)
	var mastery_xp: int = int(game.weapon_mastery_xp.get(weapon, 0))
	var available: int = game.unlocked_skill_slots()
	skill_detail_text.text = "%s\nRank %d  •  %d mastery XP\n\nUnlocked abilities: %d / 3\n\n1. Power Strike\n2. Cleave\n3. Sundering Blow\n\nUse the three combat buttons beside Interact to activate unlocked abilities." % [weapon.replace("_", " ").capitalize(), rank, mastery_xp, available]
	skill_detail_panel.visible = true

func _build_control_settings() -> void:
	control_settings_panel = _panel(0.329, 0.226, 0.689, 0.731)
	control_settings_panel.name = "InGameControlSettings"
	control_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	control_settings_panel.add_theme_stylebox_override("panel", SKIN.box("frame"))
	control_settings_panel.visible = false
	var stack := VBoxContainer.new()
	stack.name = "SettingsFields"
	stack.add_theme_constant_override("separation", 12)
	control_settings_panel.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 20
	stack.offset_top = 18
	stack.offset_right = -20
	stack.offset_bottom = -18
	var heading := Label.new()
	heading.text = "OUTPOST  •  CONTROLS"
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", SKIN.GOLD)
	stack.add_child(heading)
	floating_mode_toggle = CheckButton.new()
	floating_mode_toggle.name = "FloatingJoystickToggle"
	floating_mode_toggle.text = "Floating movement joystick"
	floating_mode_toggle.add_theme_font_size_override("font_size", 17)
	floating_mode_toggle.toggled.connect(_set_floating_mode)
	stack.add_child(floating_mode_toggle)
	var note := Label.new()
	note.text = "Off: joystick stays fixed. On: touch anywhere in the lower-left movement area; the ring follows your thumb."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", SKIN.CREAM)
	stack.add_child(note)
	var name_title := Label.new()
	name_title.text = "Character display name (local)"
	name_title.add_theme_color_override("font_color", SKIN.CREAM)
	name_title.add_theme_font_size_override("font_size", 16)
	stack.add_child(name_title)
	name_edit = LineEdit.new()
	name_edit.name = "CharacterDisplayNameInput"
	name_edit.placeholder_text = "Adventurer"
	name_edit.max_length = 18
	name_edit.text_submitted.connect(func(_value: String) -> void: _save_character_name())
	name_edit.focus_exited.connect(_save_character_name)
	stack.add_child(name_edit)
	var dismiss := Button.new()
	dismiss.name = "CloseControlSettings"
	dismiss.text = "CLOSE SETTINGS"
	SKIN.apply_button(dismiss, "wood")
	dismiss.custom_minimum_size = Vector2(0, 48)
	dismiss.pressed.connect(func() -> void:
		_save_character_name()
		control_settings_panel.visible = false
	)
	stack.add_child(dismiss)

func _show_control_settings() -> void:
	_set_top_menu(false)
	skill_detail_panel.visible = false
	control_settings_panel.visible = not control_settings_panel.visible
	_reset_touch()

func _set_floating_mode(enabled: bool) -> void:
	floating_joystick_enabled = enabled
	_reset_touch()
	_save_control_prefs()

func _save_character_name() -> void:
	if name_edit == null:
		return
	var chosen: String = name_edit.text.strip_edges()
	player_display_name = chosen if not chosen.is_empty() else "Adventurer"
	name_edit.text = player_display_name
	if status != null:
		status.text = player_display_name
	_save_control_prefs()

func _load_control_prefs() -> void:
	var config := ConfigFile.new()
	if config.load(CONTROL_PREFS) == OK:
		floating_joystick_enabled = bool(config.get_value("controls", "floating_joystick", false))
		player_display_name = str(config.get_value("profile", "display_name", "Adventurer")).strip_edges()
		if player_display_name.is_empty():
			player_display_name = "Adventurer"
	floating_mode_toggle.set_pressed_no_signal(floating_joystick_enabled)
	name_edit.text = player_display_name

func _save_control_prefs() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "floating_joystick", floating_joystick_enabled)
	config.set_value("profile", "display_name", player_display_name)
	config.save(CONTROL_PREFS)

func _meter(left: float, top: float, right: float, bottom: float, front: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.max_value = 100.0
	meter.value = 100.0
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: StyleBoxFlat = SKIN.flat("inset")
	bg.set_corner_radius_all(3)
	var fill: StyleBoxFlat = SKIN.flat("wood_selected")
	fill.bg_color = front
	fill.set_border_width_all(0)
	fill.set_corner_radius_all(2)
	meter.add_theme_stylebox_override("background", bg)
	meter.add_theme_stylebox_override("fill", fill)
	root.add_child(meter)
	_anchors(meter, left, top, right, bottom)
	return meter

func _anchors(n: Control, left: float, top: float, right: float, bottom: float) -> void:
	n.anchor_left = left
	n.anchor_top = top
	n.anchor_right = right
	n.anchor_bottom = bottom
	n.offset_left = 0.0
	n.offset_right = 0.0
	n.offset_top = 0.0
	n.offset_bottom = 0.0

func _panel(left: float, top: float, right: float, bottom: float) -> Panel:
	var n := Panel.new()
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_stylebox_override("panel", SKIN.box("hud"))
	root.add_child(n)
	_anchors(n, left, top, right, bottom)
	return n

func _label(value: String, size: int, color: Color, left: float, top: float, right: float, bottom: float) -> Label:
	var n := Label.new()
	n.text = value
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", color)
	n.add_theme_color_override("font_outline_color", Color("#241619"))
	n.add_theme_constant_override("outline_size", 2)
	root.add_child(n)
	_anchors(n, left, top, right, bottom)
	return n

func _action(key: String, label: String, left: float, top: float, right: float, bottom: float, kind: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.name = "Action_" + key if key != "torch" else "TorchQuickSlot"
	button.focus_mode = Control.FOCUS_NONE
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if key == "gather":
		gather_button = button
	elif key == "attack":
		attack_button = button
	elif key == "craft":
		craft_button = button
	elif key == "heal":
		heal_button = button
	SKIN.apply_button(button, "wood")
	if kind == "round":
		var normal: StyleBoxFlat = SKIN.flat("hud")
		normal.bg_color = Color("#3a2820")
		normal.border_color = SKIN.GOLD
		normal.set_border_width_all(4)
		normal.set_corner_radius_all(95)
		var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color("#9d612f")
		var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		disabled.bg_color = Color("#342d29")
		disabled.border_color = Color("#81725e")
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", normal)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("disabled", disabled)
	else:
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, SKIN.box("wood_selected") if state != "disabled" else SKIN.box("item"))
	root.add_child(button)
	_anchors(button, left, top, right, bottom)
	var art_icon := TextureRect.new()
	art_icon.name = "ActionIcon"
	var icon_path: String = "res://assets/ui/icons/" + key + ".png"
	if not ResourceLoader.exists(icon_path):
		var ui_icon: String = "res://assets/ui/icons/" + key + ".svg"
		if ResourceLoader.exists(ui_icon):
			icon_path = ui_icon
		else:
			var icon_id: String = "shield" if key == "gear" else "heart" if key == "potion" else "meal" if key == "consumable" else "attack" if key.begins_with("skill_") else key
			icon_path = "res://assets/icons/" + icon_id + ".svg"
	art_icon.texture = load(icon_path) as Texture2D
	art_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art_icon) # Existing regression expects image child first.
	art_icon.anchor_left = 0.15
	art_icon.anchor_right = 0.85
	art_icon.anchor_top = 0.06
	art_icon.anchor_bottom = 0.70
	var caption := Label.new()
	caption.name = "ActionLabel"
	caption.text = label
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color("#ffedc5"))
	caption.add_theme_color_override("font_outline_color", Color("#261a18"))
	caption.add_theme_constant_override("outline_size", 2)
	caption.add_theme_font_size_override("font_size", 15)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	caption.anchor_left = 0.0
	caption.anchor_right = 1.0
	caption.anchor_top = 0.68
	caption.anchor_bottom = 0.98
	if key == "torch":
		torch_label = caption
		button.pressed.connect(_toggle_torch)
	elif key == "gather":
		button.pressed.connect(_gather)
	elif key == "attack":
		button.pressed.connect(_attack)
	elif key == "craft":
		button.pressed.connect(_craft)
	elif key == "bag":
		button.pressed.connect(_bag)
	elif key == "gear":
		button.pressed.connect(_gear)
	elif key.begins_with("skill_"):
		button.pressed.connect(_use_skill.bind(int(key.trim_prefix("skill_")) - 1))
	elif key in ["consumable", "potion", "interact"]:
		pass # Dedicated slot / short-tap / hold-and-slide gesture handlers.
	else:
		pass
	return button

func _make_camera_drag_hint() -> void:
	# Camera movement belongs to the player's free finger on empty world;
	# the old rotated-arrow UI took important Android screen space.
	var hint_label: Label = _label("HOLD WORLD → ORBIT", 14, Color("#f7dc9c"), 0.768, 0.307, 0.987, 0.348)
	hint_label.name = "CameraDragHint"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_gesture_hint = hint_label

func _can_start_camera_drag(pos: Vector2) -> bool:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	# Reserve joystick, hotbar, co-op, quest, top HUD and smart-action areas.
	# Central visible world accepts drag even while movement uses finger 0.
	return pos.x >= screen.x * (0.38 if floating_joystick_enabled else 0.26) and pos.x <= screen.x * 0.78 and pos.y >= screen.y * 0.34 and pos.y <= screen.y * 0.77


func _build_quick_tray() -> void:
	quick_tray = Panel.new()
	quick_tray.name = "ConsumableHoldSlider"
	quick_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quick_tray.add_theme_stylebox_override("panel", SKIN.box("wood"))
	root.add_child(quick_tray)
	_anchors(quick_tray, 0.650, 0.527, 0.888, 0.824)
	quick_tray.visible = false
	quick_tray_list = VBoxContainer.new()
	quick_tray_list.name = "OwnedConsumableChoices"
	quick_tray_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quick_tray.add_child(quick_tray_list)
	quick_tray_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quick_tray_list.offset_left = 6
	quick_tray_list.offset_top = 6
	quick_tray_list.offset_right = -6
	quick_tray_list.offset_bottom = -6

func _open_quick_tray() -> void:
	if quick_tray_open or game == null or quick_hold_kind == "":
		return
	quick_options = game.available_quick_consumables(quick_hold_kind)
	if quick_options.is_empty():
		toast("Craft a %s first, then hold to assign it." % ("tonic" if quick_hold_kind == "potion" else "meal or stew"))
		return
	quick_selected = -1
	for child in quick_tray_list.get_children():
		quick_tray_list.remove_child(child)
		child.queue_free()
	for item in quick_options:
		var choice := Label.new()
		choice.text = "  " + item.capitalize() + "  ×" + str(int(game.inventory.get(item, 0)))
		choice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		choice.size_flags_vertical = Control.SIZE_EXPAND_FILL
		choice.add_theme_font_size_override("font_size", 18)
		choice.add_theme_color_override("font_color", SKIN.CREAM)
		choice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quick_tray_list.add_child(choice)
	quick_tray_open = true
	quick_tray.visible = true

func _drag_quick_slider(pos: Vector2) -> void:
	if not quick_tray_open and pos.y < quick_hold_origin.y - 28.0:
		_open_quick_tray()
	if quick_tray_open and not quick_options.is_empty() and pos.y < quick_hold_origin.y - 20.0:
		var bounds: Rect2 = quick_tray.get_global_rect()
		var fraction: float = clampf((pos.y - bounds.position.y) / maxf(1.0, bounds.size.y), 0.0, 0.999)
		quick_selected = int(floorf(fraction * float(quick_options.size())))
		for i in range(quick_tray_list.get_child_count()):
			var label: Label = quick_tray_list.get_child(i) as Label
			label.add_theme_color_override("font_color", SKIN.GOLD if i == quick_selected else SKIN.CREAM)

func _finish_quick_hold() -> void:
	var kind: String = quick_hold_kind
	var selected: int = quick_selected
	var options: Array[String] = quick_options.duplicate()
	var was_tray: bool = quick_tray_open
	_cancel_quick_hold()
	if game == null:
		return
	if was_tray:
		if selected >= 0 and selected < options.size() and game.set_quick_consumable(kind, options[selected]):
			toast("Equipped %s to %s radial." % [options[selected].capitalize(), kind])
	elif not game.use_quick_consumable(kind):
		toast("Hold and drag upward to equip an owned %s." % kind)
	_refresh_quick_radials()

func _cancel_quick_hold() -> void:
	quick_hold_finger = -1
	quick_hold_mouse = false
	quick_hold_kind = ""
	quick_hold_seconds = 0.0
	quick_tray_open = false
	quick_selected = -1
	if quick_tray != null:
		quick_tray.visible = false

func _handle_quick_input(event: InputEvent) -> bool:
	if game == null or quick_buttons.is_empty():
		return false
	if (game.menu != null and game.menu.visible) or (game.coop != null and game.coop.ui != null and game.coop.ui.visible):
		_cancel_quick_hold()
		return false
	if event is InputEventScreenTouch:
		if event.pressed and quick_hold_finger < 0:
			for key in ["potion", "consumable"]:
				var button: Button = quick_buttons[key] as Button
				if button.get_global_rect().grow(4.0).has_point(event.position):
					quick_hold_finger = event.index
					quick_hold_kind = key
					quick_hold_origin = event.position
					quick_hold_seconds = 0.0
					return true
		if not event.pressed and event.index == quick_hold_finger:
			quick_ignore_mouse_until = Time.get_ticks_msec() + 220
			_finish_quick_hold()
			return true
	elif event is InputEventScreenDrag and event.index == quick_hold_finger:
		_drag_quick_slider(event.position)
		return true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < quick_ignore_mouse_until:
			return false
		if event.pressed and quick_hold_finger < 0 and not quick_hold_mouse:
			for key in ["potion", "consumable"]:
				if (quick_buttons[key] as Button).get_global_rect().grow(4.0).has_point(event.position):
					quick_hold_mouse = true
					quick_hold_kind = key
					quick_hold_origin = event.position
					quick_hold_seconds = 0.0
					return true
		if not event.pressed and quick_hold_mouse:
			_finish_quick_hold()
			return true
	elif event is InputEventMouseMotion and quick_hold_mouse:
		_drag_quick_slider(event.position)
		return true
	return false

func _refresh_quick_radials() -> void:
	if game == null:
		return
	for i in range(3):
		var key: String = "skill_%d" % (i + 1)
		var button: Button = quick_buttons.get(key) as Button
		if button == null:
			continue
		var unlocked: bool = i < game.unlocked_skill_slots()
		var skill: String = ["power_strike", "cleave", "sundering_blow"][i]
		var time_left: float = float(game.skill_cooldowns.get(skill, 0.0))
		button.disabled = not unlocked or time_left > 0.0
		var label: Label = button.get_node_or_null("ActionLabel") as Label
		if label != null:
			label.text = "%ds" % int(ceilf(time_left)) if time_left > 0.0 else ["POWER", "CLEAVE", "SUNDER"][i] if unlocked else "LOCK"
	for kind in ["potion", "consumable"]:
		var button: Button = quick_buttons.get(kind) as Button
		if button == null:
			continue
		var item: String = str(game.quick_slots.get(kind, ""))
		if int(game.inventory.get(item, 0)) <= 0:
			item = ""
		var label: Label = button.get_node_or_null("ActionLabel") as Label
		if label != null:
			label.text = "EMPTY" if item == "" else item.to_upper()
		button.modulate = Color("#b9afae") if item == "" else Color.WHITE
		if quick_icon_cache.get(kind, "-") != item:
			quick_icon_cache[kind] = item
			var art: TextureRect = button.get_node_or_null("ActionIcon") as TextureRect
			if art != null:
				var icon_id: String = item if item != "" else "heart" if kind == "potion" else "meal"
				art.texture = load("res://assets/icons/" + icon_id + ".svg") as Texture2D

func _build_smart_tray() -> void:
	smart_tray = Panel.new()
	smart_tray.name = "QuickToolSlider"
	smart_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smart_tray.add_theme_stylebox_override("panel", SKIN.box("wood"))
	root.add_child(smart_tray)
	_anchors(smart_tray, 0.788, 0.206, 0.985, 0.731)
	smart_tray.visible = false
	smart_tool_list = VBoxContainer.new()
	smart_tool_list.name = "OwnedQuickTools"
	smart_tool_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smart_tool_list.add_theme_constant_override("separation", 3)
	smart_tray.add_child(smart_tool_list)
	smart_tool_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	smart_tool_list.offset_left = 7.0
	smart_tool_list.offset_top = 8.0
	smart_tool_list.offset_right = -7.0
	smart_tool_list.offset_bottom = -8.0

func _open_smart_tray() -> void:
	if smart_tray_open or game == null or smart_tray == null:
		return
	smart_tray_open = true
	smart_selected_index = -1
	smart_tool_ids = game.available_quick_tools()
	smart_tool_rows.clear()
	for child in smart_tool_list.get_children():
		smart_tool_list.remove_child(child)
		child.queue_free()
	for tool in smart_tool_ids:
		var row := Button.new()
		row.name = "Quick_" + tool
		row.text = "      " + tool.replace("_", " ").capitalize()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 40)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SKIN.apply_button(row, "wood")
		smart_tool_list.add_child(row)
		smart_tool_rows.append(row)
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = load("res://assets/icons/" + ("iron_blade" if tool == "training_blade" else tool) + ".svg") as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		icon.anchor_left = 0.035
		icon.anchor_right = 0.215
		icon.anchor_top = 0.12
		icon.anchor_bottom = 0.88
	smart_tray.visible = true

func _mark_smart_option(index: int) -> void:
	if smart_tool_rows.is_empty():
		return
	var chosen: int = clampi(index, 0, smart_tool_rows.size() - 1)
	if chosen == smart_selected_index:
		return
	smart_selected_index = chosen
	for i in range(smart_tool_rows.size()):
		var row: Button = smart_tool_rows[i]
		var selected: bool = i == chosen
		row.add_theme_stylebox_override("normal", SKIN.box("wood_selected") if selected else SKIN.box("item"))
		row.add_theme_color_override("font_color", SKIN.CREAM)

func _drag_smart_slider(pointer: Vector2) -> void:
	if not smart_tray_open and pointer.distance_to(smart_hold_origin) > 34.0 and pointer.y < smart_hold_origin.y:
		_open_smart_tray()
	if smart_tray_open and pointer.y < smart_hold_origin.y - 26.0:
		var bounds: Rect2 = smart_tray.get_global_rect()
		var proportion: float = clampf((pointer.y - bounds.position.y) / maxf(1.0, bounds.size.y), 0.0, 0.999)
		_mark_smart_option(int(floorf(proportion * float(smart_tool_rows.size()))))

func _finish_smart_hold() -> void:
	var was_slider: bool = smart_tray_open
	var selected: int = smart_selected_index
	var ids: Array[String] = smart_tool_ids.duplicate()
	_cancel_smart_hold()
	if game == null:
		return
	if was_slider:
		if selected >= 0 and selected < ids.size() and game.select_quick_tool(ids[selected]):
			_refresh_smart_button()
			toast("Selected " + ids[selected].replace("_", " ").capitalize())
	else:
		game.smart_interact()

func _cancel_smart_hold() -> void:
	smart_hold_finger = -1
	smart_hold_mouse = false
	smart_hold_seconds = 0.0
	smart_tray_open = false
	smart_selected_index = -1
	if smart_tray != null:
		smart_tray.visible = false

func _handle_smart_input(event: InputEvent) -> bool:
	if smart_button == null or game == null:
		return false
	if (game.menu != null and game.menu.visible) or (game.coop != null and game.coop.ui != null and game.coop.ui.visible):
		_cancel_smart_hold()
		return false
	if event is InputEventScreenTouch:
		if event.pressed and smart_hold_finger < 0 and not smart_hold_mouse and smart_button.get_global_rect().grow(6.0).has_point(event.position):
			smart_hold_finger = event.index
			smart_hold_origin = event.position
			smart_hold_seconds = 0.0
			get_viewport().set_input_as_handled()
			return true
		if not event.pressed and event.index == smart_hold_finger:
			# Android sometimes emits a synthetic mouse click after a touch.
			smart_ignore_mouse_until = Time.get_ticks_msec() + 220
			_finish_smart_hold()
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventScreenDrag and event.index == smart_hold_finger:
		_drag_smart_slider(event.position)
		get_viewport().set_input_as_handled()
		return true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < smart_ignore_mouse_until:
			return false
		if event.pressed and not smart_hold_mouse and smart_hold_finger < 0 and smart_button.get_global_rect().grow(6.0).has_point(event.position):
			smart_hold_mouse = true
			smart_hold_origin = event.position
			smart_hold_seconds = 0.0
			get_viewport().set_input_as_handled()
			return true
		if not event.pressed and smart_hold_mouse:
			_finish_smart_hold()
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventMouseMotion and smart_hold_mouse:
		_drag_smart_slider(event.position)
		get_viewport().set_input_as_handled()
		return true
	return false

func _refresh_smart_button() -> void:
	if game == null or smart_button == null:
		return
	var context: Dictionary = game.smart_context()
	var title: Label = smart_button.get_node_or_null("ActionLabel") as Label
	var icon: TextureRect = smart_button.get_node_or_null("ActionIcon") as TextureRect
	if title != null:
		title.text = str(context.get("label", "INTERACT"))
	var requested: String = str(context.get("icon", "gather"))
	if icon != null and requested != smart_icon_id:
		smart_icon_id = requested
		var path: String = "res://assets/ui/icons/" + requested + ".png"
		if not ResourceLoader.exists(path):
			path = "res://assets/icons/" + requested + ".svg"
		if ResourceLoader.exists(path):
			icon.texture = load(path) as Texture2D

func _toggle_quest() -> void:
	quest_expanded = not quest_expanded
	quest_detail_back.visible = quest_expanded
	quest_detail.visible = quest_expanded
	quest_toggle.text = "CLOSE ▴" if quest_expanded else "✓ QUESTS" if objective_is_complete else "QUESTS ▾"

func _update_quest_tracker(objective: String) -> void:
	var text_value: String = objective.strip_edges()
	var lower: String = text_value.to_lower()
	objective_is_complete = lower.contains("quest finished") or lower.contains("quest complete") or lower.contains("quest completed")
	var should_show: bool = not objective_is_complete and text_value != ""
	quest_frame.visible = should_show
	quest.visible = should_show
	quest.text = text_value
	quest_detail.text = text_value if text_value != "" else "No active quest."
	quest_toggle.text = "CLOSE ▴" if quest_expanded else "✓ QUESTS" if objective_is_complete else "QUESTS ▾"

func _update_context_prompt(helper: String) -> void:
	var text_value: String = helper.strip_edges()
	var lower: String = text_value.to_lower()
	var generic: bool = text_value.is_empty() or lower.begins_with("explore") or lower.begins_with("wander") or lower.begins_with("starter quest finished")
	var show_prompt: bool = context_is_actionable and not generic
	hint.text = text_value
	if context_prompt_frame != null:
		context_prompt_frame.visible = show_prompt
	hint.visible = show_prompt

func _process(delta: float) -> void:
	if top_menu_pressed and not top_menu_opened_by_hold:
		top_menu_hold_seconds += delta
		if top_menu_hold_seconds >= 0.34:
			top_menu_opened_by_hold = true
			_set_top_menu(true)
	if gesture_hint_timeout > 0.0:
		gesture_hint_timeout = maxf(0.0, gesture_hint_timeout - delta)
		if gesture_hint_timeout <= 0.0:
			if tool_gesture_hint != null:
				tool_gesture_hint.visible = false
			if camera_gesture_hint != null:
				camera_gesture_hint.visible = false
	if (smart_hold_finger >= 0 or smart_hold_mouse) and not smart_tray_open:
		smart_hold_seconds += delta
		if smart_hold_seconds >= 0.34:
			_open_smart_tray()
	if camera_drag_finger >= 0 and not camera_hold_ready:
		camera_hold_seconds += delta
		if camera_hold_seconds >= 0.82:
			camera_hold_ready = true
	if (quick_hold_finger >= 0 or quick_hold_mouse) and not quick_tray_open:
		quick_hold_seconds += delta
		if quick_hold_seconds >= 0.36:
			_open_quick_tray()
	_position_stick()
	knob.position = (joystick.size - knob.size) * 0.5 + move_vector * 45.0
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast_label.text = ""
			toast_label.visible = false
			toast_panel.visible = false

func _position_stick() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if floating_joystick_enabled:
		joystick.visible = finger >= 0 or mouse_stick
		return
	joystick.visible = true
	joystick.position = Vector2(26.0, screen.y - 177.0)

func _floating_zone(pos: Vector2) -> bool:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	return pos.x >= 8.0 and pos.x <= screen.x * 0.35 and pos.y >= screen.y * 0.35 and pos.y <= screen.y * 0.92

func _start_floating_stick(pos: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = Vector2(clampf(pos.x, 74.0, screen.x * 0.35 - 48.0), clampf(pos.y, screen.y * 0.38, screen.y - 83.0))
	joystick.position = center - joystick.size * 0.5
	joystick.visible = true

func _center() -> Vector2:
	return joystick.get_global_rect().get_center()

func _input(event: InputEvent) -> void:
	if _handle_smart_input(event):
		return
	if (control_settings_panel != null and control_settings_panel.visible) or (skill_detail_panel != null and skill_detail_panel.visible):
		_reset_touch()
		return
	if game != null and ((game.menu != null and game.menu.visible) or (game.coop != null and game.coop.ui != null and game.coop.ui.visible)):
		_reset_touch()
		return
	if _handle_quick_input(event):
		return
	if event is InputEventScreenTouch and game != null:
		if event.pressed and camera_drag_finger < 0 and event.index != finger and _can_start_camera_drag(event.position):
			camera_drag_finger = event.index
			camera_hold_seconds = 0.0
			camera_hold_ready = false
			camera_hold_origin = event.position
			return
		elif not event.pressed and event.index == camera_drag_finger:
			camera_drag_finger = -1
			camera_hold_seconds = 0.0
			camera_hold_ready = false
			return
	elif event is InputEventScreenDrag and event.index == camera_drag_finger and game != null:
		if camera_hold_ready:
			game.drag_camera(event.screen_relative.x)
		elif event.position.distance_to(camera_hold_origin) > 26.0:
			# Early movement is not an orbit; this prevents accidental
			# camera turns while interacting with the world.
			camera_drag_finger = -1
		return
	elif event is InputEventMouseMotion and game != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if _can_start_camera_drag(event.position):
			game.drag_camera(event.relative.x)
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and ((floating_joystick_enabled and _floating_zone(event.position)) or (not floating_joystick_enabled and event.position.distance_to(_center()) < 104.0)):
			finger = event.index
			mouse_stick = false
			if floating_joystick_enabled:
				_start_floating_stick(event.position)
			_stick(event.position)
		elif not event.pressed and event.index == finger:
			_reset_touch()
	elif event is InputEventScreenDrag and event.index == finger:
		_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and finger == -1 and ((floating_joystick_enabled and _floating_zone(event.position)) or (not floating_joystick_enabled and event.position.distance_to(_center()) < 104.0)):
			mouse_stick = true
			if floating_joystick_enabled:
				_start_floating_stick(event.position)
			_stick(event.position)
		elif not event.pressed and mouse_stick and finger == -1:
			_reset_touch()
	elif event is InputEventMouseMotion and mouse_stick and finger == -1:
		_stick(event.position)

func _reset_touch() -> void:
	_cancel_smart_hold()
	_cancel_quick_hold()
	camera_drag_finger = -1
	camera_hold_seconds = 0.0
	camera_hold_ready = false
	finger = -1
	mouse_stick = false
	move_vector = Vector2.ZERO
	_position_stick()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_reset_touch()

func _stick(pos: Vector2) -> void:
	if floating_joystick_enabled:
		var travel: Vector2 = pos - _center()
		if travel.length() > 55.0:
			joystick.position += travel.normalized() * (travel.length() - 55.0)
	move_vector = ((pos - _center()) / 55.0).limit_length(1.0)

func render_status(hp: float, inventory: Dictionary, xp: int, _kills: int, weapon: String, objective: String, helper: String) -> void:
	status.text = player_display_name
	health_numbers.text = "HP %d / 100" % int(ceilf(hp))
	if bag_weight_label != null and game != null:
		var max_load: float = maxf(1.0, game.bag_capacity())
		var current_load: float = game.bag_load()
		bag_weight_label.text = "BAG NEAR LIMIT  %.0f / %.0f" % [current_load, max_load]
		bag_weight_label.visible = current_load >= max_load * 0.85
		bag_weight_label.add_theme_color_override("font_color", Color("#e99075") if current_load >= max_load else Color("#e3b75d"))
	hero_detail.text = "%s  •  M%d" % [weapon.replace("_", " ").capitalize(), game.mastery_rank(weapon)] if game != null else weapon
	if game != null and xp_level_label != null:
		var level_data: Dictionary = game.level_state()
		var rank: int = int(level_data.get("level", 1))
		var required: float = maxf(1.0, float(level_data.get("required", 100)))
		xp_bar.value = clampf(float(level_data.get("current", 0)) * 100.0 / required, 0.0, 100.0)
		xp_level_label.text = "%d / %d XP" % [int(level_data.get("current", 0)), int(required)]
		xp_level_badge.text = "Lv. %d" % rank
		status.text = player_display_name
		_refresh_quick_radials()
	health_bar.value = clampf(hp, 0.0, 100.0)
	if torch_button != null:
		torch_button.disabled = int(inventory.get("torch", 0)) <= 0
	for key in items:
		items[key].text = str(inventory.get(key, 0))
	_refresh_wallet(inventory)
	_update_quest_tracker(objective)
	_update_context_prompt(helper)

func update_context(has_resource: bool, has_enemy: bool, at_bench: bool) -> void:
	context_is_actionable = has_resource or has_enemy or at_bench
	if hint != null:
		_update_context_prompt(hint.text)
	if gather_button != null:
		gather_button.disabled = not has_resource
	if attack_button != null:
		attack_button.disabled = not has_enemy
	if craft_button != null:
		craft_button.modulate = Color.WHITE if at_bench else Color(0.75, 0.75, 0.75)
	_refresh_smart_button()

func toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_panel.visible = true
	toast_time = 3.1

func set_day_clock(time_text: String, is_dark: bool, torch_on: bool) -> void:
	if clock_label != null:
		clock_label.text = ("NIGHT " if is_dark else "DAY ") + time_text
		clock_label.add_theme_color_override("font_color", Color("#bac4ee") if is_dark else Color("#fff0c5"))
	if torch_button != null:
		if torch_label != null:
			torch_label.text = "PUT OUT" if torch_on else "TORCH"
		torch_button.modulate = Color("#ffedb5") if torch_on else Color.WHITE

func _toggle_torch() -> void:
	if game != null:
		game.toggle_torch()

func _open_coop() -> void:
	if game != null and game.coop != null and game.coop.ui != null:
		game.coop.ui.open()

func _gather() -> void:
	game.gather()
func _attack() -> void:
	game.attack()
func _craft() -> void:
	game.craft()
func _bag() -> void:
	game.show_inventory()
func _gear() -> void:
	game.show_equipment()
func _use_skill(index: int) -> void:
	if game != null:
		game.use_weapon_skill(index)
