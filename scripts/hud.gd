extends CanvasLayer
## Outpost mobile HUD: compact live panels, gold-ringed touch actions and a
## functioning bottom hotbar. No flattened mock-up or imaginary game stats.
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
const ACTION_FRAME_ROOT := "res://assets/ui/action_buttons/"
const ACTION_RADIAL = preload("res://scripts/ui/action_cooldown_ring.gd")
const ACTION_SKILL_LEVELS = preload("res://scripts/progression/character_levels.gd")
const HUD_V2 = preload("res://scripts/ui/hud_v2_components.gd")
const ITEM_VIEW = preload("res://scripts/ui/outpost_item_view.gd")
const LIVE_MINIMAP = preload("res://scripts/ui/live_world_minimap.gd")
const ZONE_NAMES = preload("res://scripts/world/outpost_zone_names.gd")
const RADIAL_LEVEL = preload("res://scripts/ui/radial_level_frame.gd")
const XP_DIVISIONS = preload("res://scripts/ui/xp_bar_divisions.gd")
const SKILL_XP_ORB = preload("res://scripts/ui/skill_xp_orb.gd")
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
var station_touch_finger: int = -1
var station_touch_name: String = ""
var station_touch_start: Vector2 = Vector2.ZERO
var station_mouse_candidate: String = ""
var station_mouse_start: Vector2 = Vector2.ZERO
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
var hero_status_frame: Panel
var hero_portrait_frame: Panel
var hero_portrait_art: TextureRect
var enemy_target_hud: Panel
var enemy_portrait_frame: Panel
var enemy_portrait_art: TextureRect
var enemy_name: Label
var enemy_health_bar: ProgressBar
var enemy_health_numbers: Label
var enemy_target_id: int = 0
var hero_sigil: TextureRect
var radial_level: Control
var minimap: Control
var clock_label: Label
var zone_pill: Panel
var zone_pill_text: Label
var zone_banner: Label
var current_zone: String = ""
var candidate_zone: String = ""
var candidate_zone_seconds: float = 0.0
var zone_poll_seconds: float = 0.0
var zone_banner_seconds: float = 0.0
var clock_footer: Panel
var calendar_mark: Label
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
var xp_bar_divisions: Control
var trained_skill_orb: Control
var toast_panel: Panel
var items: Dictionary = {}
var joystick: Panel
var knob: Panel
var movement_stick_scale: float = 1.20
var movement_stick_slider: HSlider
var movement_stick_size_label: Label
var settings_slider_finger: int = -1
var settings_slider_mouse_down: bool = false
const STICK_BASE_DIAMETER: float = 148.0
const STICK_THUMB_DIAMETER: float = 55.0
const STICK_INPUT_RADIUS: float = 55.0
var move_vector := Vector2.ZERO
var finger := -1
var mouse_stick := false
var gather_button: Button
var attack_button: Button
var craft_button: Button
var heal_button: Button
var smart_button: Button
var tool_swap_button: Button
var tool_swap_finger: int = -1
var tool_swap_mouse: bool = false
var tool_swap_origin: Vector2 = Vector2.ZERO
var tool_swap_ignore_mouse_until: int = 0
var quest_rule: ColorRect
var quest_touch_finger: int = -1
var quest_touch_origin: Vector2 = Vector2.ZERO
var quest_mouse_down: bool = false
var quest_mouse_origin: Vector2 = Vector2.ZERO
var quest_ignore_mouse_until: int = 0
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
var wallet_open: bool = false
var wallet_bag: Button
var wallet_coin: Label
var wallet_popup_title: Label
var wallet_currency_rows: Dictionary = {}
var wallet_currency_icons: Dictionary = {}
var wallet_resource_icon: TextureRect
var wallet_resource_count: Label
var wallet_resource_id: String = "wood"
## Live display components — no fictitious currency or status effect state.
var gathered_panel: Panel
var gathered_title: Label
var gathered_content: Label
var gathered_collapse: Button
var gathered_expanded: bool = true
var gathered_entries: Array[Dictionary] = []
var gathered_update_delay: float = 0.0
var loot_feed_panel: Panel
var loot_feed_title: Label
var loot_feed_rows: VBoxContainer
var loot_feed_entries: Array[Dictionary] = []
const LOOT_FEED_LINGER_SECONDS: float = 3.0
const LOOT_FEED_FADE_SECONDS: float = 0.55
var loot_icon_controls: Array[Button] = []
var loot_tooltip_panel: Panel
var loot_tooltip_name: Label
var loot_tooltip_rarity: Label
var loot_tooltip_description: Label
var loot_tooltip_item_id: String = ""
var loot_mouse_echo_until: int = 0
var status_effect_strip: HBoxContainer
var active_status_effects: Array[Dictionary] = []
var last_inventory_snapshot: Dictionary = {}
var menu_button: Button
var top_menu_panel: Panel
var top_menu_shade: ColorRect
var top_menu_close_button: Button
var top_menu_actions: Array[Button] = []
var top_menu_touch_finger: int = -1
var top_menu_touch_candidate: Button
var top_menu_touch_origin: Vector2 = Vector2.ZERO
var top_menu_mouse_down: bool = false
var top_menu_mouse_candidate: Button
var top_menu_mouse_origin: Vector2 = Vector2.ZERO
var top_menu_open: bool = false
var top_menu_pressed: bool = false
var top_menu_hold_seconds: float = 0.0
var top_menu_opened_by_hold: bool = false
var floating_joystick_enabled: bool = false
var adaptive_joystick_enabled: bool = false
var adaptive_joystick_toggle: CheckButton
var sticky_movement_enabled: bool = false
var sticky_movement_toggle: CheckButton
var stop_sticky_button: Button
var ignore_menu_synthetic_mouse_until: int = 0
var top_chrome_finger: int = -1
var top_chrome_candidate: Button
var top_chrome_origin: Vector2 = Vector2.ZERO
var top_chrome_mouse_down: bool = false
var top_chrome_mouse_candidate: Button
var top_chrome_mouse_origin: Vector2 = Vector2.ZERO
var top_chrome_ignore_mouse_until: int = 0
var player_display_name: String = "Adventurer"
var control_settings_panel: Panel
var control_settings_close_button: Button
var settings_close_finger: int = -1
var settings_ignore_mouse_until: int = 0
var status_text_modes: Dictionary = {"health": "text", "mana": "text", "xp": "text"}
var status_mode_buttons: Dictionary = {}
var settings_touch_buttons: Array[BaseButton] = []
var settings_touch_finger: int = -1
var settings_touch_candidate: BaseButton
var settings_touch_start: Vector2 = Vector2.ZERO
var settings_scroll_last_y: float = 0.0
var settings_scroll_dragging: bool = false
var settings_touch_mouse_echo_until: int = 0
var leave_menu_shade: ColorRect
var leave_menu_panel: PanelContainer
var leave_menu_info: Label
var leave_menu_confirm: Button
var leave_menu_close_button: Button
var leave_menu_actions: Array[Button] = []
var leave_touch_finger: int = -1
var leave_touch_candidate: Button
var leave_touch_origin: Vector2 = Vector2.ZERO
var leave_mouse_down: bool = false
var leave_mouse_candidate: Button
var leave_mouse_origin: Vector2 = Vector2.ZERO
var leave_ignore_synthetic_mouse_until: int = 0
var floating_mode_toggle: CheckButton
var name_edit: LineEdit
var skill_detail_panel: Panel
var skills_close_button: Button
var skills_close_x: Button
var skills_touch_finger: int = -1
var skills_touch_candidate: Button
var skills_touch_origin: Vector2 = Vector2.ZERO
var skills_mouse_down: bool = false
var skills_mouse_candidate: Button
var skills_mouse_origin: Vector2 = Vector2.ZERO
var skills_ignore_mouse_until: int = 0
var skill_detail_text: Label
var skill_mastery_bar: ProgressBar
var skill_slot_rows: Array[Label] = []

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
	var status_frame: Panel = _panel(0.018, 0.019, 0.279, 0.139)
	status_frame.name = "HeroStatusFrame"
	hero_status_frame = status_frame
	status_frame.add_theme_stylebox_override("panel", _hud_glass(0.03, 0.0))
	var sigil := TextureRect.new()
	sigil.name = "OutpostSigil"
	hero_sigil = sigil
	sigil.texture = load("res://assets/ui/icons/outpost_sigil.svg") as Texture2D
	sigil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sigil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sigil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sigil)
	_anchors(sigil, 0.074, 0.105, 0.092, 0.138)
	# Player portrait is a live independent artwork layer; the small Outpost
	# emblem remains in the corner as a crest, not a substitute for the hero.
	var portrait_back: Panel = _panel(0.022, 0.027, 0.089, 0.131)
	portrait_back.name = "HeroPortraitFrame"
	hero_portrait_frame = portrait_back
	var portrait_ring := StyleBoxFlat.new()
	portrait_ring.bg_color = Color(0.10, 0.09, 0.10, 0.11)
	portrait_ring.border_color = Color("#e9ba61")
	portrait_ring.set_border_width_all(4)
	portrait_ring.set_corner_radius_all(100)
	portrait_ring.set_content_margin_all(0)
	portrait_ring.anti_aliasing = true
	portrait_back.add_theme_stylebox_override("panel", portrait_ring)
	var hero_portrait := TextureRect.new()
	hero_portrait.name = "HeroPortrait"
	hero_portrait_art = hero_portrait
	hero_portrait.texture = load("res://assets/ui/icons/hero_portrait_v2.svg") as Texture2D
	var portrait_mask := ShaderMaterial.new()
	portrait_mask.shader = load("res://assets/ui/icons/portrait_circle.gdshader") as Shader
	hero_portrait.material = portrait_mask
	hero_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hero_portrait)
	_anchors(hero_portrait, 0.026, 0.031, 0.085, 0.126)
	root.move_child(sigil, root.get_child_count() - 1)
	status = _label("Adventurer", 20, SKIN.GOLD, 0.094, 0.026, 0.269, 0.058)
	status.name = "PlayerGoldName"
	status.add_theme_color_override("font_outline_color", Color("#171114"))
	status.add_theme_constant_override("outline_size", 2)
	status.clip_text = true
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	health_bar = _meter(0.094, 0.061, 0.269, 0.090, Color("#d74c43"))
	health_numbers = _label("100 / 100 HP", 15, Color("#fff1db"), 0.095, 0.062, 0.267, 0.087)
	health_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Real rechargeable mana, consumed by active combat skills.
	mana_bar = _meter(0.094, 0.095, 0.269, 0.120, Color("#417cdb"))
	mana_bar.name = "PlayerManaBar"
	mana_numbers = _label("MP 35 / 35", 12, Color("#d8e6ff"), 0.095, 0.096, 0.267, 0.118)
	mana_numbers.name = "PlayerManaNumbers"
	mana_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_bar = _meter(0.0, 0.975, 1.0, 1.0, Color("#a86ed7"))
	xp_bar.name = "CharacterLevelXP"
	var xp_background := StyleBoxFlat.new()
	xp_background.bg_color = Color(0.13, 0.09, 0.16, 0.24)
	xp_background.border_color = Color(0.75, 0.59, 0.37, 0.30)
	xp_background.set_border_width_all(1)
	xp_background.set_corner_radius_all(0)
	xp_background.set_content_margin_all(0)
	xp_background.anti_aliasing = false
	xp_bar.add_theme_stylebox_override("background", xp_background)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.71, 0.46, 0.86, 0.59)
	xp_fill.set_border_width_all(0)
	xp_fill.set_corner_radius_all(0)
	xp_fill.set_content_margin_all(0)
	xp_fill.anti_aliasing = false
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_bar_divisions = XP_DIVISIONS.new()
	xp_bar_divisions.name = "CharacterXPDivisions"
	xp_bar.add_child(xp_bar_divisions)
	xp_bar_divisions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Character rank belongs by the portrait, never printed redundantly
	# inside the full-width bottom XP strip. Skill rank uses its own orb.
	xp_level_badge = _label("1", 14, Color("#ffe8ab"), 0.017, 0.110, 0.047, 0.146)
	xp_level_badge.name = "CharacterLevelBadge"
	xp_level_badge.visible = true
	xp_level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_level_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	var rank_frame := StyleBoxFlat.new()
	rank_frame.bg_color = Color(0.12, 0.10, 0.10, 0.85)
	rank_frame.border_color = Color(0.91, 0.72, 0.36, 0.83)
	rank_frame.set_border_width_all(1)
	rank_frame.set_corner_radius_all(100)
	rank_frame.set_content_margin_all(1)
	var level_frame := Panel.new()
	level_frame.name = "CharacterLevelBadgeFrame"
	level_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_frame.add_theme_stylebox_override("panel", rank_frame)
	root.add_child(level_frame)
	root.move_child(level_frame, xp_level_badge.get_index())
	xp_level_badge.set_meta("badge_frame", level_frame)
	# Preserve the radial component for future gathering/skill level-up
	# feedback, but never draw the oversized circle on the persistent HUD.
	radial_level = RADIAL_LEVEL.new()
	root.add_child(radial_level)
	radial_level.visible = false
	xp_level_label = _label("0 / 100", 12, Color(1.0, 0.94, 0.81, 0.68), 0.12, 0.975, 0.93, 1.0)
	xp_level_label.name = "CharacterLevelLabel"
	xp_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	xp_level_label.clip_text = true
	trained_skill_orb = SKILL_XP_ORB.new()
	trained_skill_orb.name = "TrainedSkillOrb"
	trained_skill_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(trained_skill_orb)
	trained_skill_orb.call("set_skill", "training_blade", 0)
	_build_enemy_target_hud()
	hero_detail = _label("", 14, Color("#edc98d"), 0.094, 0.100, 0.268, 0.127)
	hero_detail.visible = false
	hero_detail.clip_text = true
	hero_detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Status effects occupy the old weapon-info line only when there are
	# real effect records. Nothing is drawn for an empty gameplay state.
	status_effect_strip = HBoxContainer.new()
	status_effect_strip.name = "PlayerStatusEffects"
	status_effect_strip.add_theme_constant_override("separation", 4)
	status_effect_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_effect_strip)
	status_effect_strip.visible = false

	# Passive one-line currency wallet. No dropdown, click target, shaded
	# panel or resource tracker is displayed over normal gameplay. The bag
	# and MENU remain independent touch inputs on the minimap shoulder.
	wallet_frame = _panel(0.302, 0.116, 0.505, 0.470)
	wallet_frame.name = "ResourceQuickChips"
	wallet_frame.add_theme_stylebox_override("panel", HUD_V2.utility_card())
	wallet_frame.visible = false
	wallet_collapse = Button.new()
	wallet_collapse.name = "WalletCollapse"
	wallet_collapse.text = "◈ WALLET ▾"
	wallet_collapse.tooltip_text = "Currency totals appear directly in the horizontal wallet readout"
	SKIN.apply_translucent_button(wallet_collapse, "wood")
	wallet_collapse.focus_mode = Control.FOCUS_NONE
	wallet_collapse.visible = false
	wallet_collapse.disabled = true
	# Native GUI events may consume release before HUD._input on Android.
	# These three top-right buttons are routed only by HUD._input.
	wallet_collapse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wallet_collapse)
	_anchors(wallet_collapse, 0.55, 0.023, 0.63, 0.095)
	# Touch is routed centrally to prevent duplicate GUI+HUD clicks on Android.
	# All three top-right controls use exactly one release activation.
	wallet_popup_title = _label("✦  WALLET", 18, SKIN.GOLD, 0.31, 0.121, 0.47, 0.160)
	wallet_popup_title.name = "WalletPopupTitle"
	wallet_popup_title.visible = false
	wallet_coin = _label("COINS    0", 17, SKIN.GOLD, 0.31, 0.160, 0.48, 0.204)
	wallet_coin.name = "WalletCoinCount"
	wallet_coin.autowrap_mode = TextServer.AUTOWRAP_OFF
	wallet_coin.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wallet_coin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet_coin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet_coin.clip_text = true
	wallet_coin.visible = false
	for denomination in ["copper", "silver", "gold", "gems"]:
		var line := _label(denomination.capitalize() + "    —", 15, SKIN.CREAM, 0.31, 0.20, 0.48, 0.24)
		line.name = "WalletCurrency_" + denomination
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.clip_text = true
		var metal: Dictionary = {
			"copper": Color("#d1a078"),
			"silver": Color("#d6e0ea"),
			"gold": Color("#f5ca76"),
			"gems": Color("#b4dded")
		}
		line.add_theme_color_override("font_color", metal[denomination])
		line.visible = false
		wallet_currency_rows[denomination] = line
	# Real compact transparent pixel-art currency symbols instead of just
	# abbreviated uppercase words. They are separate artwork layers and
	# never carry an opaque circular UI background.
	for currency_id in ["coins", "copper", "silver", "gold", "gems"]:
		var wallet_icon := TextureRect.new()
		wallet_icon.name = "WalletCurrencyIcon_" + currency_id
		wallet_icon.texture = load("res://assets/icons/" + currency_id + ".svg") as Texture2D
		wallet_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wallet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wallet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wallet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wallet_icon.visible = false
		root.add_child(wallet_icon)
		wallet_currency_icons[currency_id] = wallet_icon
	wallet_resource_icon = TextureRect.new()
	wallet_resource_icon.name = "LastTrackedResourceIcon"
	wallet_resource_icon.texture = load("res://assets/icons/wood.svg") as Texture2D
	wallet_resource_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallet_resource_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wallet_resource_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wallet_resource_icon)
	_anchors(wallet_resource_icon, 0.31, 0.40, 0.337, 0.44)
	wallet_resource_icon.visible = false
	wallet_resource_count = _label("Wood ×0", 14, SKIN.CREAM, 0.34, 0.40, 0.48, 0.44)
	wallet_resource_count.name = "LastTrackedResourceCount"
	wallet_resource_count.clip_text = true
	wallet_resource_count.visible = false
	wallet_bag = _action("bag", "BAG", 0.638, 0.019, 0.699, 0.089, "round")
	wallet_bag.name = "Action_bag"
	# Keep the actual circular image-backed wood-and-gold medallion.
	wallet_bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# _action("bag") adds a native pressed signal; disconnect it so a
	# synthetic Android mouse event cannot call _bag twice after _input.
	if wallet_bag.pressed.is_connected(_bag):
		wallet_bag.pressed.disconnect(_bag)
	# Retain stable public dictionary keys for existing gameplay/test callers.
	for key in ["wood", "stone", "hide", "coins"]:
		var count := _label("0", 12, SKIN.CREAM, 0.0, 0.0, 0.01, 0.01)
		count.name = "HiddenResource_" + key
		count.visible = false
		items[key] = count
	# Overload notification appears only when load needs attention; the bag
	# itself shows the full capacity meter and bonus information.
	bag_weight_label = _label("", 14, Color("#e3b75d"), 0.020, 0.132, 0.310, 0.157)
	bag_weight_label.name = "CarryWeightLabel"
	bag_weight_label.visible = false

	# The persistent quest ribbon is single-line and ellipsis-safe; on
	# completion it collapses to a small journal button instead of endlessly
	# announcing the finished starter quest.
	quest_frame = _panel(0.018, 0.166, 0.344, 0.230)
	quest_frame.name = "QuestBanner"
	# Quest background follows the unobtrusive transparent player card.
	quest_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	quest_rule = ColorRect.new()
	quest_rule.name = "QuestGoldUnderline"
	quest_rule.color = Color(0.87, 0.69, 0.38, 0.42)
	quest_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(quest_rule)
	quest_toggle = Button.new()
	quest_toggle.name = "QuestToggle"
	quest_toggle.text = "QUESTS ▾"
	SKIN.apply_translucent_button(quest_toggle, "wood")
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		quest_toggle.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	quest_toggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_toggle.add_theme_color_override("font_color", SKIN.GOLD)
	quest_toggle.add_theme_color_override("font_hover_color", SKIN.GOLD.lightened(0.13))
	quest_toggle.add_theme_color_override("font_pressed_color", SKIN.GOLD)
	root.add_child(quest_toggle)
	_anchors(quest_toggle, 0.028, 0.174, 0.117, 0.222)
	# Input routed through _handle_quest_input on mobile.
	quest = _label("Gather wood and stone", 16, SKIN.GOLD, 0.127, 0.173, 0.334, 0.224)
	quest.add_theme_color_override("font_outline_color", Color("#171114"))
	quest.add_theme_constant_override("outline_size", 2)
	quest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest.autowrap_mode = TextServer.AUTOWRAP_OFF
	quest.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quest.clip_text = true
	quest_detail_back = _panel(0.021, 0.236, 0.354, 0.444)
	quest_detail_back.name = "QuestJournal"
	quest_detail_back.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	quest_detail_back.visible = false
	quest_detail = _label("", 16, Color("#f1e7cf"), 0.039, 0.250, 0.334, 0.428)
	quest_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	quest_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	quest_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_detail.visible = false

	# Centered below the journal, not overlapping quest text. One notice at a time.
	toast_panel = _panel(0.355, 0.225, 0.682, 0.295)
	toast_panel.name = "LootQuestToast"
	toast_panel.add_theme_stylebox_override("panel", SKIN.translucent_surface(true))
	toast_panel.visible = false
	toast_label = _label("", 16, SKIN.INK, 0.371, 0.228, 0.665, 0.290)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.visible = false

	# Sample the actual streamed terrain, with the player and crafting stations.
	# Keep the circular map ABOVE the existing clock/menu footprint, not over abilities.
	minimap = LIVE_MINIMAP.new()
	minimap.setup(game)
	root.add_child(minimap)
	_anchors(minimap, 0.811, 0.019, 0.980, 0.309)
	zone_pill = _panel(0.82, 0.012, 0.976, 0.050)
	zone_pill.name = "MinimapZonePill"
	zone_pill.add_theme_stylebox_override("panel", HUD_V2.utility_card())
	zone_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_pill_text = _label("OUTPOST CLEARING", 16, SKIN.CREAM, 0.826, 0.018, 0.971, 0.044)
	zone_pill_text.name = "MinimapZoneName"
	zone_pill_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_pill_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_pill_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	zone_pill_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	zone_pill_text.clip_text = true
	zone_banner = _label("", 22, SKIN.GOLD, 0.31, 0.12, 0.69, 0.19)
	zone_banner.name = "ZoneEntryAnnouncement"
	zone_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_banner.visible = false
	clock_footer = _panel(0.82, 0.290, 0.975, 0.344)
	clock_footer.name = "MinimapClockFooterFrame"
	clock_footer.add_theme_stylebox_override("panel", HUD_V2.utility_card())
	calendar_mark = _label("▣", 18, SKIN.GOLD, 0.823, 0.299, 0.838, 0.334)
	calendar_mark.name = "MinimapCalendarGlyph"
	clock_label = _label("DAY 09:07", 16, Color("#fff0c5"), 0.838, 0.299, 0.960, 0.338)
	clock_label.name = "MinimapFooterClock"
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Actual harvested-item receipts only, never crafted or awarded items.
	# The card shares the accepted translucent Quest visual language.
	gathered_panel = _panel(0.814, 0.393, 0.980, 0.546)
	gathered_panel.name = "LastGatheredPanel"
	gathered_panel.add_theme_stylebox_override("panel", HUD_V2.utility_card())
	gathered_panel.visible = false
	gathered_title = _label("LAST GATHERED", 12, SKIN.CREAM, 0.820, 0.396, 0.943, 0.424)
	gathered_title.name = "LastGatheredHeading"
	gathered_title.visible = false
	gathered_content = _label("", 11, SKIN.CREAM, 0.818, 0.426, 0.975, 0.540)
	gathered_content.name = "LastGatheredItems"
	gathered_content.visible = false
	gathered_content.clip_text = true
	gathered_content.autowrap_mode = TextServer.AUTOWRAP_OFF
	gathered_collapse = Button.new()
	gathered_collapse.name = "LastGatheredCollapse"
	gathered_collapse.text = "▾"
	gathered_collapse.tooltip_text = "Collapse or expand recently gathered materials"
	gathered_collapse.custom_minimum_size = Vector2(30.0, 30.0)
	SKIN.apply_translucent_button(gathered_collapse, "wood")
	gathered_collapse.add_theme_font_size_override("font_size", 15)
	gathered_collapse.mouse_filter = Control.MOUSE_FILTER_STOP
	gathered_collapse.pressed.connect(_toggle_gathered)
	gathered_collapse.visible = false
	root.add_child(gathered_collapse)
	# Small WoW/Cube World-style item acquisition log under Last Gathered.
	# One consistent utility-card material, not another bulky HUD window.
	loot_feed_panel = _panel(0.81, 0.56, 0.98, 0.75)
	loot_feed_panel.name = "LootCombatFeed"
	loot_feed_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	loot_feed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_feed_panel.visible = false
	loot_feed_title = _label("LOOT & COMBAT", 12, SKIN.GOLD, 0.81, 0.56, 0.98, 0.60)
	loot_feed_title.name = "LootCombatFeedTitle"
	loot_feed_title.visible = false
	loot_feed_rows = VBoxContainer.new()
	loot_feed_rows.name = "LootCombatFeedRows"
	loot_feed_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_feed_rows.add_theme_constant_override("separation", 3)
	root.add_child(loot_feed_rows)
	loot_feed_rows.visible = false
	loot_tooltip_panel = _panel(0.60, 0.40, 0.80, 0.60)
	loot_tooltip_panel.name = "LootItemTooltip"
	loot_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_tooltip_panel.add_theme_stylebox_override("panel", SKIN.modal_panel())
	loot_tooltip_panel.visible = false
	loot_tooltip_name = _label("", 19, SKIN.CREAM, 0.60, 0.41, 0.80, 0.45)
	loot_tooltip_name.name = "LootItemTooltipName"
	loot_tooltip_name.visible = false
	loot_tooltip_rarity = _label("", 14, Color("#d9cbb7"), 0.60, 0.45, 0.80, 0.49)
	loot_tooltip_rarity.name = "LootItemTooltipRarity"
	loot_tooltip_rarity.visible = false
	loot_tooltip_description = _label("", 14, SKIN.CREAM, 0.60, 0.49, 0.80, 0.59)
	loot_tooltip_description.name = "LootItemTooltipDescription"
	loot_tooltip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loot_tooltip_description.clip_text = true
	loot_tooltip_description.visible = false
	# Top-right carved buttons open a true, central touch-blocking menu.
	# Keep the original six actions and their gameplay signals.
	top_menu_shade = ColorRect.new()
	top_menu_shade.name = "GameMenuShade"
	top_menu_shade.color = Color(0.025, 0.019, 0.030, 0.67)
	top_menu_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top_menu_shade)
	top_menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_menu_shade.visible = false
	top_menu_panel = _panel(0.31, 0.20, 0.69, 0.81)
	top_menu_panel.name = "FunctionalHotbar"
	top_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	top_menu_panel.add_theme_stylebox_override("panel", SKIN.modal_panel())
	top_menu_panel.visible = false
	var menu_heading_back := Panel.new()
	menu_heading_back.name = "GameMenuHeadingFrame"
	menu_heading_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_heading_back.add_theme_stylebox_override("panel", SKIN.modal_section())
	top_menu_panel.add_child(menu_heading_back)
	menu_heading_back.anchor_left = 0.035
	menu_heading_back.anchor_right = 0.965
	menu_heading_back.anchor_top = 0.038
	menu_heading_back.anchor_bottom = 0.188
	var menu_heading := Label.new()
	menu_heading.name = "GameMenuHeading"
	menu_heading.text = "OUTPOST  •  MENU"
	menu_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_heading.add_theme_font_size_override("font_size", 23)
	menu_heading.add_theme_color_override("font_color", SKIN.GOLD)
	menu_heading.add_theme_color_override("font_outline_color", Color("#21161a"))
	menu_heading.add_theme_constant_override("outline_size", 2)
	menu_heading_back.add_child(menu_heading)
	menu_heading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_menu_close_button = Button.new()
	top_menu_close_button.name = "CloseGameMenu"
	SKIN.apply_close_button(top_menu_close_button, 40.0)
	top_menu_close_button.pressed.connect(func() -> void: _set_top_menu(false))
	root.add_child(top_menu_close_button)
	top_menu_close_button.visible = false
	menu_button = _action("menu", "MENU", 0.928, 0.322, 0.989, 0.396, "round")
	menu_button.name = "TopRightMenuButton"
	# Keep the golden circular button frame; only menu contents use flat slots.
	menu_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Deliberately no button_down/hold handlers: a single tap is sufficient.
	# Click routing is centralised with WALLET and BAG to avoid double toggles.
	# Crafting stays tied to real workstations. The sixth menu action is
	# actual controls settings, not a remote crafting shortcut.
	var settings_entry := Button.new()
	settings_entry.name = "SettingsMenuButton"
	settings_entry.text = "SETTINGS"
	SKIN.apply_translucent_button(settings_entry, "wood")
	root.add_child(settings_entry)
	_anchors(settings_entry, 0.695, 0.405, 0.787, 0.482)
	settings_entry.pressed.connect(_show_control_settings)
	top_menu_actions.append(settings_entry)
	top_menu_actions.append(_action("gear", "GEAR", 0.796, 0.405, 0.888, 0.482, "slot"))
	var multiplayer_entry := Button.new()
	multiplayer_entry.name = "CoopEntryButton"
	multiplayer_entry.text = "CO-OP"
	SKIN.apply_translucent_button(multiplayer_entry, "wood")
	root.add_child(multiplayer_entry)
	_anchors(multiplayer_entry, 0.895, 0.405, 0.984, 0.482)
	multiplayer_entry.pressed.connect(_open_coop)
	# Retained by name for older scripts, but deliberately never shown.
	# Play/Continue -> Host/Join replaces the intrusive in-game CO-OP tile.
	multiplayer_entry.visible = false
	var bag_entry := Button.new()
	bag_entry.name = "BagMenuButton"
	bag_entry.text = "BAG"
	SKIN.apply_translucent_button(bag_entry, "wood")
	root.add_child(bag_entry)
	_anchors(bag_entry, 0.895, 0.405, 0.984, 0.482)
	bag_entry.pressed.connect(func() -> void:
		_set_top_menu(false)
		_bag()
	)
	top_menu_actions.append(bag_entry)
	var skill_entry := Button.new()
	skill_entry.name = "SkillMenuButton"
	skill_entry.text = "SKILLS"
	SKIN.apply_translucent_button(skill_entry, "wood")
	root.add_child(skill_entry)
	_anchors(skill_entry, 0.695, 0.500, 0.787, 0.575)
	skill_entry.pressed.connect(_show_skill_details)
	top_menu_actions.append(skill_entry)
	var journal_entry := Button.new()
	journal_entry.name = "JournalMenuButton"
	journal_entry.text = "JOURNAL"
	SKIN.apply_translucent_button(journal_entry, "wood")
	root.add_child(journal_entry)
	_anchors(journal_entry, 0.796, 0.500, 0.888, 0.575)
	journal_entry.pressed.connect(_open_journal)
	top_menu_actions.append(journal_entry)
	# The sixth flyout action is the small exit door; control settings remain
	# available inside its menu without a permanent extra HUD button.
	var exit_entry := Button.new()
	exit_entry.name = "ExitDoorMenuButton"
	exit_entry.text = "SAVE & EXIT"
	exit_entry.tooltip_text = "Save / leave Outpost"
	SKIN.apply_translucent_button(exit_entry, "wood")
	# The icon lives inside the Button instead of contributing to its minimum
	# width, keeping all six slots inside the menu on narrower phones.
	var door_path: String = "res://assets/ui/icons/exit_door.svg"
	if ResourceLoader.exists(door_path):
		var door_icon := TextureRect.new()
		door_icon.name = "ExitDoorIcon"
		door_icon.texture = load(door_path) as Texture2D
		door_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		door_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		door_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		door_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		exit_entry.add_child(door_icon)
		door_icon.anchor_left = 0.03
		door_icon.anchor_right = 0.30
		door_icon.anchor_top = 0.18
		door_icon.anchor_bottom = 0.82
	root.add_child(exit_entry)
	_anchors(exit_entry, 0.895, 0.500, 0.984, 0.575)
	exit_entry.pressed.connect(_open_leave_menu)
	top_menu_actions.append(exit_entry)
	# Integrate approved matching art into each real menu action, without
	# creating fake extra tabs or sacrificing their existing pressed signals.
	for option in top_menu_actions:
		var art_by_action: Dictionary = {
			"SettingsMenuButton": "settings", "Action_gear": "armour",
			"BagMenuButton": "backpack", "SkillMenuButton": "skills",
			"JournalMenuButton": "quests", "ExitDoorMenuButton": "exit"
		}
		var art_id: String = str(art_by_action.get(option.name, ""))
		if art_id != "":
			_decorate_menu_action(option, art_id)
		option.visible = false
	# The world HUD never shows a giant permanent Gear or Bag panel.
	# Their existing separate modal pages open only when explicitly requested,
	# leaving joystick / smart-Interact / 3 skill buttons in their own positions.
	# Offhand torch remains available without interfering with three ability slots.
	stop_sticky_button = Button.new()
	stop_sticky_button.name = "StopStickyMovement"
	stop_sticky_button.text = "■ STOP"
	SKIN.apply_button(stop_sticky_button, "red")
	stop_sticky_button.focus_mode = Control.FOCUS_NONE
	root.add_child(stop_sticky_button)
	stop_sticky_button.visible = false
	stop_sticky_button.pressed.connect(_stop_sticky_movement)
	torch_button = _action("torch", "TORCH", 0.700, 0.844, 0.757, 0.934, "round")

	# The single context button replaces redundant ATTACK and GATHER tiles.
	# Three real weapon-mastery skill holders arc around its upper-left side.
	quick_buttons["skill_1"] = _action("skill_1", "HEROIC", 0.819, 0.600, 0.881, 0.712, "round")
	quick_buttons["skill_2"] = _action("skill_2", "CLEAVE", 0.755, 0.667, 0.814, 0.779, "round")
	quick_buttons["skill_3"] = _action("skill_3", "BREAK", 0.705, 0.760, 0.764, 0.870, "round")
	# Both utility radials start empty. Tap uses the equipped item; hold and
	# slide upwards chooses among actually owned consumables.
	quick_buttons["consumable"] = _action("consumable", "HEAL", 0.773, 0.852, 0.830, 0.947, "round")
	quick_buttons["potion"] = _action("potion", "POTION", 0.835, 0.842, 0.894, 0.943, "round")
	for key in ["consumable", "potion"]:
		(quick_buttons[key] as Button).mouse_filter = Control.MOUSE_FILTER_IGNORE
	smart_button = _action("interact", "INTERACT", 0.895, 0.740, 0.986, 0.941, "round")
	smart_button.name = "Action_interact"
	smart_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dedicated tools selector: short/long pressing Interact can only act.
	tool_swap_button = _action("tool_swap", "TOOLS", 0.900, 0.645, 0.958, 0.725, "round")
	tool_swap_button.name = "Action_tool_swap"
	tool_swap_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_swap_button.tooltip_text = "Tap to cycle equipped tools"
	# Legacy selector remains hidden for old scenes/tests, never opened.
	_build_smart_tray()
	_refresh_tool_swap_button()
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
	_build_leave_menu()
	_load_control_prefs()
	_position_stick()
	# Recalculate real touch sizes and menu placement on phone rotation,
	# ultrawide aspect ratios, and Android window/safe-area changes.
	get_viewport().size_changed.connect(_layout_touch_hud)
	_layout_touch_hud()
	_apply_wallet_layout()

func set_status_effects(effects: Array) -> void:
	# The gameplay service supplies authoritative effects; this view NEVER
	# fabricates stacks, status durations or damage-over-time ticks.
	active_status_effects.clear()
	for candidate in effects:
		if candidate is Dictionary and not str(candidate.get("id", "")).is_empty():
			active_status_effects.append((candidate as Dictionary).duplicate())
	for child in status_effect_strip.get_children():
		status_effect_strip.remove_child(child)
		child.queue_free()
	var ordered: Array[Dictionary] = []
	for effect in active_status_effects:
		if str(effect.get("kind", "buff")) == "debuff":
			ordered.append(effect)
	for effect in active_status_effects:
		if str(effect.get("kind", "buff")) != "debuff":
			ordered.append(effect)
	for i in range(mini(5, ordered.size())):
		var effect: Dictionary = ordered[i]
		var negative: bool = str(effect.get("kind", "buff")) == "debuff"
		var icon := Button.new()
		icon.name = "StatusEffect_" + str(effect.get("id", "unknown"))
		icon.custom_minimum_size = Vector2(32.0, 28.0)
		icon.text = str(effect.get("glyph", "!" if negative else "✦")).substr(0, 2)
		icon.tooltip_text = "%s • %s • %s remaining • stacks: %d" % [
				str(effect.get("name", effect.get("id", "Effect"))),
				"Debuff" if negative else "Buff",
				str(effect.get("remaining", "—")),
				maxi(1, int(effect.get("stack_count", 1)))
		]
		icon.add_theme_stylebox_override("normal", HUD_V2.effect_icon(negative))
		icon.add_theme_stylebox_override("hover", HUD_V2.effect_icon(negative))
		icon.add_theme_font_size_override("font_size", 14)
		icon.add_theme_color_override("font_color", SKIN.CREAM)
		icon.focus_mode = Control.FOCUS_NONE
		status_effect_strip.add_child(icon)
	if ordered.size() > 5:
		var extra := Label.new()
		extra.text = "+%d" % (ordered.size() - 5)
		extra.add_theme_font_size_override("font_size", 13)
		extra.add_theme_color_override("font_color", SKIN.GOLD)
		status_effect_strip.add_child(extra)
	status_effect_strip.visible = not ordered.is_empty()
	hero_detail.visible = false # Equipped weapon already has an inventory/skills popup.

func record_gather(item_id: String, quantity: int) -> void:
	if quantity <= 0 or item_id.is_empty() or gathered_panel == null:
		return
	gathered_entries.push_front({"id": item_id, "amount": quantity, "at": Time.get_ticks_msec()})
	if gathered_entries.size() > 3:
		gathered_entries.resize(3)
	# Keep the bounded receipts for journal/QA only. The actual reward
	# now floats above the avatar in world-space and isn't duplicated here.
	gathered_panel.visible = false
	gathered_title.visible = false
	gathered_collapse.visible = false
	_refresh_gathered_card()

func _toggle_gathered() -> void:
	gathered_expanded = not gathered_expanded
	gathered_collapse.text = "▾" if gathered_expanded else "▸"
	_refresh_gathered_card()
	_layout_touch_hud()

func _refresh_gathered_card() -> void:
	if gathered_content == null:
		return
	gathered_content.visible = false
	var rows := PackedStringArray()
	for entry in gathered_entries:
		var seconds: int = maxi(0, int((Time.get_ticks_msec() - int(entry.get("at", 0))) / 1000))
		rows.append("%s ×%d  (%ds)" % [str(entry.get("id", "")).capitalize(), int(entry.get("amount", 0)), seconds])
	gathered_content.text = "\n".join(rows)

func record_loot(item_id: String, quantity: int, item_rarity: int = -1) -> void:
	# The feed is an ephemeral on-screen counter, NOT an inventory. A second
	# grant of the same item increments its existing receipt and starts
	# another 3-second window rather than painting another grey notification.
	if quantity <= 0 or item_id.is_empty() or loot_feed_panel == null:
		return
	var quality: int = clampi(item_rarity, -1, 4)
	for i in range(loot_feed_entries.size()):
		var old: Dictionary = loot_feed_entries[i]
		if str(old.get("kind", "")) == "item" and str(old.get("id", "")) == item_id:
			old["amount"] = int(old.get("amount", 0)) + quantity
			old["ttl"] = LOOT_FEED_LINGER_SECONDS
			old["at"] = Time.get_ticks_msec()
			if quality >= 0:
				old["rarity"] = quality
			loot_feed_entries.remove_at(i)
			loot_feed_entries.push_front(old)
			_refresh_loot_feed()
			return
	loot_feed_entries.push_front({
		"kind": "item", "id": item_id, "amount": quantity,
		"rarity": quality, "at": Time.get_ticks_msec(),
		"ttl": LOOT_FEED_LINGER_SECONDS
	})
	if loot_feed_entries.size() > 3:
		loot_feed_entries.resize(3)
	_refresh_loot_feed()
	_layout_touch_hud()


func record_combat_event(message: String) -> void:
	var clean: String = message.strip_edges()
	if clean.is_empty() or loot_feed_panel == null:
		return
	for i in range(loot_feed_entries.size()):
		var old: Dictionary = loot_feed_entries[i]
		if str(old.get("kind", "")) == "combat" and str(old.get("message", "")) == clean:
			old["count"] = int(old.get("count", 1)) + 1
			old["ttl"] = LOOT_FEED_LINGER_SECONDS
			old["at"] = Time.get_ticks_msec()
			loot_feed_entries.remove_at(i)
			loot_feed_entries.push_front(old)
			_refresh_loot_feed()
			return
	loot_feed_entries.push_front({
		"kind": "combat", "message": clean, "count": 1,
		"ttl": LOOT_FEED_LINGER_SECONDS, "at": Time.get_ticks_msec()
	})
	if loot_feed_entries.size() > 3:
		loot_feed_entries.resize(3)
	_refresh_loot_feed()
	_layout_touch_hud()


func _advance_loot_feed(delta: float) -> void:
	# Keep each receipt opaque for 3 seconds after its most recent count
	# increment, then fade for half a second. Different items expire
	# independently; newer drops never keep old text stuck on screen.
	if loot_feed_entries.is_empty():
		return
	var expired: bool = false
	for i in range(loot_feed_entries.size() - 1, -1, -1):
		var entry: Dictionary = loot_feed_entries[i]
		var lifetime: float = float(entry.get("ttl", LOOT_FEED_LINGER_SECONDS)) - delta
		entry["ttl"] = lifetime
		if lifetime <= -LOOT_FEED_FADE_SECONDS:
			loot_feed_entries.remove_at(i)
			expired = true
	if expired:
		_refresh_loot_feed()
	if loot_feed_rows == null:
		return
	var live_rows: Array[Node] = loot_feed_rows.get_children()
	for i in range(mini(loot_feed_entries.size(), live_rows.size())):
		(live_rows[i] as Control).modulate.a = clampf(
			(float(loot_feed_entries[i].get("ttl", 0.0)) + LOOT_FEED_FADE_SECONDS) / LOOT_FEED_FADE_SECONDS, 0.0, 1.0)
	if loot_feed_entries.is_empty() and loot_tooltip_panel != null and loot_tooltip_panel.visible:
		_set_loot_tooltip_visible(false)

func _refresh_loot_feed() -> void:
	if loot_feed_rows == null:
		return
	loot_icon_controls.clear()
	for child in loot_feed_rows.get_children():
		loot_feed_rows.remove_child(child)
		child.queue_free()
	var showing: bool = not loot_feed_entries.is_empty()
	loot_feed_panel.visible = showing
	# No opaque heading strip. Only floating receipts and their icons.
	loot_feed_title.visible = false
	loot_feed_rows.visible = showing
	for entry in loot_feed_entries:
		var item_id: String = str(entry.get("id", ""))
		var quality: int = int(entry.get("rarity", -1))
		var count: int = int(entry.get("amount", 0))
		var is_item: bool = str(entry.get("kind", "item")) == "item"
		var name_text: String = ITEM_VIEW.display_name(item_id)
		var times: int = int(entry.get("count", 1))
		var title_text: String = "You received ×%d %s" % [count, name_text] if is_item else str(entry.get("message", "")) + (" ×%d" % times if times > 1 else "")
		var line := HBoxContainer.new()
		line.name = "LootReceipt"
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.custom_minimum_size.y = 22.0
		line.add_theme_constant_override("separation", 5)
		loot_feed_rows.add_child(line)
		# A single framed icon is the source of truth, reused later for
		# inventories, banks and equipment. Only the frame is tappable.
		var icon_box := Button.new()
		icon_box.name = "ItemRarityFrame"
		icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_box.focus_mode = Control.FOCUS_NONE
		icon_box.custom_minimum_size = Vector2(24, 24)
		icon_box.add_theme_stylebox_override("normal", HUD_V2.loot_icon_border(quality))
		icon_box.add_theme_stylebox_override("hover", HUD_V2.loot_icon_border(quality))
		icon_box.add_theme_stylebox_override("pressed", HUD_V2.loot_icon_border(quality))
		line.add_child(icon_box)
		if is_item:
			icon_box.set_meta("loot_item_id", item_id)
			icon_box.set_meta("loot_rarity", quality)
			loot_icon_controls.append(icon_box)
			icon_box.tooltip_text = name_text + " — tap for details"
		var art := TextureRect.new()
		art.name = "ItemIcon"
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.anchor_left = 0.08
		art.anchor_top = 0.08
		art.anchor_right = 0.92
		art.anchor_bottom = 0.92
		var icon_path: String = "res://assets/icons/" + (item_id if is_item else "attack") + ".svg"
		if ResourceLoader.exists(icon_path):
			art.texture = load(icon_path) as Texture2D
		icon_box.add_child(art)
		if is_item:
			# Small circular quantity badge bottom-right of the item image.
			var bubble := Panel.new()
			bubble.name = "ItemQuantityBubble"
			bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bubble.add_theme_stylebox_override("panel", HUD_V2.loot_quantity_badge())
			bubble.anchor_left = 0.51
			bubble.anchor_top = 0.52
			bubble.anchor_right = 1.14
			bubble.anchor_bottom = 1.14
			icon_box.add_child(bubble)
			var number := Label.new()
			number.name = "ItemQuantityNumber"
			number.mouse_filter = Control.MOUSE_FILTER_IGNORE
			number.text = str(count)
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			number.add_theme_font_size_override("font_size", 11)
			number.add_theme_color_override("font_color", Color.WHITE)
			bubble.add_child(number)
			number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var caption := Label.new()
		caption.name = "LootReceiptText"
		caption.text = title_text
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size", 11)
		caption.add_theme_color_override("font_color", Color("#e9dfc8"))
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(caption)

func _set_loot_tooltip_visible(showing: bool) -> void:
	loot_tooltip_panel.visible = showing
	loot_tooltip_name.visible = showing
	loot_tooltip_rarity.visible = showing
	loot_tooltip_description.visible = showing
	if not showing:
		loot_tooltip_item_id = ""

func _toggle_loot_tooltip(item_id: String, quality: int) -> void:
	if item_id == loot_tooltip_item_id and loot_tooltip_panel.visible:
		_set_loot_tooltip_visible(false)
		return
	loot_tooltip_item_id = item_id
	var recipes: Array = game.recipes if game != null else []
	loot_tooltip_name.text = ITEM_VIEW.display_name(item_id)
	loot_tooltip_name.add_theme_color_override("font_color", ITEM_VIEW.rarity_color(quality))
	loot_tooltip_rarity.text = ITEM_VIEW.rarity_name(quality)
	loot_tooltip_rarity.add_theme_color_override("font_color", ITEM_VIEW.rarity_color(quality))
	loot_tooltip_description.text = ITEM_VIEW.description(item_id, recipes)
	_set_loot_tooltip_visible(true)

func _handle_loot_tooltip_input(event: InputEvent) -> bool:
	var pos: Vector2
	if event is InputEventScreenTouch:
		if not (event as InputEventScreenTouch).pressed:
			return false
		pos = (event as InputEventScreenTouch).position
		loot_mouse_echo_until = Time.get_ticks_msec() + 450
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < loot_mouse_echo_until:
			get_viewport().set_input_as_handled()
			return true
		if not (event as InputEventMouseButton).pressed:
			return false
		pos = (event as InputEventMouseButton).position
	else:
		return false
	for icon_box in loot_icon_controls:
		if is_instance_valid(icon_box) and icon_box.is_visible_in_tree() and icon_box.get_global_rect().has_point(pos):
			_toggle_loot_tooltip(str(icon_box.get_meta("loot_item_id", "")), int(icon_box.get_meta("loot_rarity", -1)))
			get_viewport().set_input_as_handled()
			return true
	if loot_tooltip_panel.visible and not loot_tooltip_panel.get_global_rect().has_point(pos):
		_set_loot_tooltip_visible(false)
	return false

func _toggle_wallet() -> void:
	# Backward-compatible call: the user approved a passive horizontal
	# currency strip. Tapping the old Wallet button never opens a flyout.
	_apply_wallet_layout()


func _apply_wallet_layout() -> void:
	wallet_open = false
	wallet_frame.visible = false
	wallet_popup_title.visible = false
	wallet_collapse.visible = false
	wallet_collapse.disabled = true
	wallet_coin.visible = true
	wallet_resource_icon.visible = false
	wallet_resource_count.visible = false
	for key in wallet_currency_rows:
		(wallet_currency_rows[key] as Label).visible = true
	for key in wallet_currency_icons:
		(wallet_currency_icons[key] as TextureRect).visible = true
	_layout_player_chrome()

func _short_currency(value: int) -> String:
	# Stay on one row even for large real balances; the unabridged count is
	# available in the label tooltip and is never rounded in saved inventory.
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 10000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)


func _refresh_wallet(inventory: Dictionary) -> void:
	if wallet_coin == null:
		return
	var coins: int = maxi(0, int(inventory.get("coins", 0)))
	wallet_coin.text = _short_currency(coins)
	wallet_coin.tooltip_text = "Coins: %d" % coins
	for key in wallet_currency_rows:
		var label: Label = wallet_currency_rows[key] as Label
		var actual: bool = inventory.has(key)
		var balance: int = maxi(0, int(inventory.get(key, 0)))
		label.text = _short_currency(balance) if actual else "—"
		label.tooltip_text = "%s: %d" % [str(key).capitalize(), balance] if actual else "%s not yet in wallet" % str(key).capitalize()
	for key in inventory:
		var id: String = str(key)
		if id in ["coins", "copper", "silver", "gold", "gems", "torch", "spear", "axe", "pickaxe", "shield", "meal", "tonic", "stew", "cloak", "satchel", "iron_blade"]:
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
	if open_menu:
		_set_loot_tooltip_visible(false)
	# Horizontal wallet stays visible while the Menu opens; there is no dropdown.
	top_menu_open = open_menu
	top_menu_pressed = false
	top_menu_panel.visible = open_menu
	top_menu_shade.visible = open_menu
	top_menu_close_button.visible = open_menu
	top_menu_touch_finger = -1
	top_menu_touch_candidate = null
	top_menu_mouse_down = false
	top_menu_mouse_candidate = null
	for option in top_menu_actions:
		option.visible = open_menu
	if open_menu:
		_reset_touch()
		top_menu_shade.move_to_front()
		top_menu_panel.move_to_front()
		for option in top_menu_actions:
			option.move_to_front()
		top_menu_close_button.move_to_front()


func _open_journal() -> void:
	_set_top_menu(false)
	if not quest_expanded:
		_toggle_quest()

func _build_skill_details() -> void:
	skill_detail_panel = _panel(0.292, 0.170, 0.708, 0.830)
	skill_detail_panel.name = "WeaponSkillDetails"
	skill_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	skill_detail_panel.add_theme_stylebox_override("panel", SKIN.modal_panel())
	skill_detail_panel.visible = false
	var title := Label.new()
	title.text = "✦  SKILLS  •  WEAPON MASTERY"
	title.add_theme_color_override("font_color", SKIN.GOLD)
	title.add_theme_font_size_override("font_size", 21)
	title.name = "SkillDetailHeading"
	skill_detail_panel.add_child(title)
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
	skill_detail_text.offset_top = 78
	skill_detail_text.offset_right = -20
	skill_detail_text.offset_bottom = -315
	# Reusable parchment-backed mastery panel and three real ability slots.
	var progress_back := Panel.new()
	progress_back.name = "MasterySectionFrame"
	progress_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_back.add_theme_stylebox_override("panel", SKIN.modal_section())
	skill_detail_panel.add_child(progress_back)
	_anchors(progress_back, 0.045, 0.285, 0.955, 0.383)
	skill_mastery_bar = ProgressBar.new()
	skill_mastery_bar.name = "WeaponMasteryProgress"
	skill_mastery_bar.max_value = 60.0
	skill_mastery_bar.show_percentage = false
	skill_mastery_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_mastery_bar.add_theme_stylebox_override("background", SKIN.flat("inset"))
	skill_mastery_bar.add_theme_stylebox_override("fill", SKIN.flat("wood_selected"))
	progress_back.add_child(skill_mastery_bar)
	_anchors(skill_mastery_bar, 0.05, 0.24, 0.95, 0.76)
	for i in range(3):
		var slot_frame := Panel.new()
		slot_frame.name = "MasterySkillSlot_%d" % (i + 1)
		slot_frame.add_theme_stylebox_override("panel", SKIN.modal_section())
		skill_detail_panel.add_child(slot_frame)
		_anchors(slot_frame, 0.045, 0.405 + 0.127 * float(i), 0.955, 0.515 + 0.127 * float(i))
		var status_line := Label.new()
		status_line.name = "SkillUnlocked_%d" % (i + 1)
		status_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_line.add_theme_font_size_override("font_size", 16)
		slot_frame.add_child(status_line)
		_anchors(status_line, 0.04, 0.05, 0.96, 0.95)
		skill_slot_rows.append(status_line)
	var close := Button.new()
	close.name = "CloseSkills"
	close.text = "CLOSE"
	SKIN.apply_translucent_button(close, "wood")
	skill_detail_panel.add_child(close)
	close.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	close.offset_left = 20
	close.offset_top = -58
	close.offset_right = -20
	close.offset_bottom = -14
	close.pressed.connect(_close_skill_details)
	skills_close_button = close
	# The Skills page should close as reliably as Controls and Leave Outpost:
	# a top-right red X plus the bottom CLOSE button share one handler.
	skills_close_x = Button.new()
	skills_close_x.name = "CloseSkillsX"
	SKIN.apply_close_button(skills_close_x, 43.0)
	skills_close_x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skills_close_x.offset_left = -53.0
	skills_close_x.offset_right = -10.0
	skills_close_x.offset_top = 9.0
	skills_close_x.offset_bottom = 52.0
	skills_close_x.pressed.connect(_close_skill_details)
	skill_detail_panel.add_child(skills_close_x)
	# This is the little sword/mastery orb that looked like a stray ATTACK
	# button behind the joystick. Retain real mastery XP, but show it only
	# where it belongs: inside the Skills panel, beside its header.
	trained_skill_orb.reparent(skill_detail_panel)
	trained_skill_orb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	trained_skill_orb.offset_left = -112.0
	trained_skill_orb.offset_right = -60.0
	trained_skill_orb.offset_top = 8.0
	trained_skill_orb.offset_bottom = 60.0


func _close_skill_details() -> void:
	if skill_detail_panel == null:
		return
	skill_detail_panel.visible = false
	skills_touch_finger = -1
	skills_touch_candidate = null
	skills_mouse_down = false
	skills_mouse_candidate = null
	skills_ignore_mouse_until = Time.get_ticks_msec() + 375
	_reset_touch()


func _skills_close_at(pos: Vector2) -> Button:
	if skills_close_x != null and skills_close_x.is_visible_in_tree() and skills_close_x.get_global_rect().grow(7.0).has_point(pos):
		return skills_close_x
	if skills_close_button != null and skills_close_button.is_visible_in_tree() and skills_close_button.get_global_rect().grow(7.0).has_point(pos):
		return skills_close_button
	return null


func _handle_skill_details_input(event: InputEvent) -> void:
	# The regular Button.pressed signal may never receive a complete Android
	# tap after HUD._input consumes the event. Handle down/up as one modal
	# gesture BEFORE any gameplay/quick-action touch handlers.
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		_close_skill_details()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and skills_touch_finger < 0:
			skills_touch_finger = touch.index
			skills_touch_origin = touch.position
			skills_touch_candidate = _skills_close_at(touch.position)
		elif not touch.pressed and touch.index == skills_touch_finger:
			var close_target: Button = skills_touch_candidate
			var activate: bool = close_target != null and close_target == _skills_close_at(touch.position) and touch.position.distance_to(skills_touch_origin) < 44.0
			skills_touch_finger = -1
			skills_touch_candidate = null
			if activate:
				_close_skill_details()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == skills_touch_finger and drag.position.distance_to(skills_touch_origin) >= 44.0:
			skills_touch_candidate = null
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index != MOUSE_BUTTON_LEFT or Time.get_ticks_msec() < skills_ignore_mouse_until:
			return
		if click.pressed:
			skills_mouse_down = true
			skills_mouse_origin = click.position
			skills_mouse_candidate = _skills_close_at(click.position)
		elif skills_mouse_down:
			var close_target: Button = skills_mouse_candidate
			var activate: bool = close_target != null and close_target == _skills_close_at(click.position) and click.position.distance_to(skills_mouse_origin) < 44.0
			skills_mouse_down = false
			skills_mouse_candidate = null
			if activate:
				_close_skill_details()


func _show_skill_details() -> void:
	_set_top_menu(false)
	if game == null:
		return
	control_settings_panel.visible = false
	var weapon: String = game.current_weapon_id()
	var rank: int = game.mastery_rank(weapon)
	var mastery_xp: int = int(game.weapon_mastery_xp.get(weapon, 0))
	var available: int = game.unlocked_skill_slots()
	skill_detail_text.text = "%s  •  Mastery rank %d  •  %d XP  •  %d/3 abilities" % [weapon.replace("_", " ").capitalize(), rank, mastery_xp, available]
	skill_mastery_bar.value = 60 if rank >= 10 else mastery_xp % 60
	var names: Array[String] = ["POWER STRIKE", "CLEAVE", "SUNDERING BLOW"]
	var required: Array[int] = [1, 3, 5]
	for i in range(skill_slot_rows.size()):
		var row: Label = skill_slot_rows[i]
		var unlocked: bool = i < available
		row.text = "◆  %s   •   %s" % [names[i], "UNLOCKED" if unlocked else "RANK %d REQUIRED" % required[i]]
		row.add_theme_color_override("font_color", SKIN.GOLD if unlocked else SKIN.CREAM)
	skill_detail_panel.visible = true
	skill_detail_panel.move_to_front()
	_reset_touch()

func _build_control_settings() -> void:
	# Keep the title/close control fixed; scroll the actual options on short
	# Android screens so Close never ends up below the visible viewport.
	control_settings_panel = _panel(0.275, 0.085, 0.725, 0.895)
	control_settings_panel.name = "InGameControlSettings"
	control_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	control_settings_panel.add_theme_stylebox_override("panel", SKIN.modal_panel())
	control_settings_panel.visible = false
	var heading := Label.new()
	heading.name = "SettingsTitle"
	heading.text = "OUTPOST  •  CONTROLS"
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", SKIN.GOLD)
	heading.position = Vector2(19, 13)
	heading.size = Vector2(420, 40)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_settings_panel.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.name = "ControlSettingsScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18
	scroll.offset_top = 61
	scroll.offset_right = -18
	scroll.offset_bottom = -16
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.clip_contents = true
	control_settings_panel.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.name = "SettingsFields"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	scroll.add_child(stack)
	var explanation := Label.new()
	explanation.text = "Movement & touch controls"
	explanation.add_theme_color_override("font_color", SKIN.GOLD)
	explanation.add_theme_font_size_override("font_size", 17)
	stack.add_child(explanation)

	floating_mode_toggle = CheckButton.new()
	floating_mode_toggle.name = "FloatingJoystickToggle"
	floating_mode_toggle.text = "Dynamic movement stick (appears at touch)"
	floating_mode_toggle.add_theme_font_size_override("font_size", 16)
	floating_mode_toggle.custom_minimum_size.y = 39
	floating_mode_toggle.toggled.connect(_set_floating_mode)
	stack.add_child(floating_mode_toggle)
	settings_touch_buttons.append(floating_mode_toggle)
	var stick_size_row := HBoxContainer.new()
	stick_size_row.name = "MovementStickSizeRow"
	stick_size_row.add_theme_constant_override("separation", 9)
	stack.add_child(stick_size_row)
	var stick_size_title := Label.new()
	stick_size_title.text = "Movement stick size"
	stick_size_title.add_theme_font_size_override("font_size", 16)
	stick_size_title.add_theme_color_override("font_color", SKIN.CREAM)
	stick_size_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stick_size_row.add_child(stick_size_title)
	movement_stick_size_label = Label.new()
	movement_stick_size_label.name = "MovementStickSizeValue"
	movement_stick_size_label.text = "100%"
	movement_stick_size_label.add_theme_color_override("font_color", SKIN.GOLD)
	movement_stick_size_label.add_theme_font_size_override("font_size", 17)
	stick_size_row.add_child(movement_stick_size_label)
	movement_stick_slider = HSlider.new()
	movement_stick_slider.name = "MovementStickSizeSlider"
	movement_stick_slider.min_value = 80.0
	movement_stick_slider.max_value = 150.0
	movement_stick_slider.step = 5.0
	movement_stick_slider.value = 100.0
	movement_stick_slider.custom_minimum_size = Vector2(0, 42)
	movement_stick_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	movement_stick_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	movement_stick_slider.add_theme_stylebox_override("slider", SKIN.translucent_surface(false))
	movement_stick_slider.value_changed.connect(_set_movement_stick_size)
	stack.add_child(movement_stick_slider)
	var movement_note := Label.new()
	movement_note.text = "Fixed: lower-left ring. Dynamic: appears where you touch the left movement area."
	movement_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	movement_note.add_theme_font_size_override("font_size", 13)
	movement_note.add_theme_color_override("font_color", SKIN.CREAM)
	stack.add_child(movement_note)

	adaptive_joystick_toggle = CheckButton.new()
	adaptive_joystick_toggle.name = "AdaptiveJoystickToggle"
	adaptive_joystick_toggle.text = "Adaptive joystick near thumb"
	adaptive_joystick_toggle.add_theme_font_size_override("font_size", 16)
	adaptive_joystick_toggle.custom_minimum_size.y = 39
	adaptive_joystick_toggle.toggled.connect(_set_adaptive_joystick)
	stack.add_child(adaptive_joystick_toggle)
	settings_touch_buttons.append(adaptive_joystick_toggle)

	sticky_movement_toggle = CheckButton.new()
	sticky_movement_toggle.name = "StickyMovementToggle"
	sticky_movement_toggle.text = "Sticky movement until STOP"
	sticky_movement_toggle.add_theme_font_size_override("font_size", 16)
	sticky_movement_toggle.custom_minimum_size.y = 39
	sticky_movement_toggle.toggled.connect(_set_sticky_movement)
	stack.add_child(sticky_movement_toggle)
	settings_touch_buttons.append(sticky_movement_toggle)

	var status_header := Label.new()
	status_header.name = "StatusDisplayHeader"
	status_header.text = "STATUS VALUES  •  CHOOSE ONE PER BAR"
	status_header.add_theme_font_size_override("font_size", 17)
	status_header.add_theme_color_override("font_color", SKIN.GOLD)
	stack.add_child(status_header)
	var status_info := Label.new()
	status_info.text = "Numbers show current / maximum. Percent shows progress. Off hides only the text, keeping your bars visible."
	status_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_info.add_theme_color_override("font_color", SKIN.CREAM)
	status_info.add_theme_font_size_override("font_size", 14)
	stack.add_child(status_info)
	for stat in ["health", "mana", "xp"]:
		var heading_row := Label.new()
		heading_row.text = stat.to_upper()
		heading_row.add_theme_color_override("font_color", SKIN.CREAM)
		heading_row.add_theme_font_size_override("font_size", 15)
		stack.add_child(heading_row)
		var choices := HBoxContainer.new()
		choices.name = stat.capitalize() + "ReadoutChoices"
		choices.add_theme_constant_override("separation", 7)
		stack.add_child(choices)
		for mode in ["text", "percent", "off"]:
			var mode_button := Button.new()
			mode_button.name = stat.capitalize() + mode.capitalize() + "Mode"
			mode_button.text = mode.to_upper()
			mode_button.custom_minimum_size.y = 42
			mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mode_button.add_theme_font_size_override("font_size", 14)
			mode_button.pressed.connect(_set_status_text_mode.bind(stat, mode))
			choices.add_child(mode_button)
			settings_touch_buttons.append(mode_button)
			status_mode_buttons[stat + ":" + mode] = mode_button

	var name_title := Label.new()
	name_title.text = "Character display name (local)"
	name_title.add_theme_color_override("font_color", SKIN.CREAM)
	name_title.add_theme_font_size_override("font_size", 15)
	stack.add_child(name_title)
	name_edit = LineEdit.new()
	name_edit.name = "CharacterDisplayNameInput"
	name_edit.placeholder_text = "Adventurer"
	name_edit.max_length = 18
	name_edit.custom_minimum_size.y = 42
	name_edit.text_submitted.connect(func(_value: String) -> void: _save_character_name())
	name_edit.focus_exited.connect(_save_character_name)
	stack.add_child(name_edit)

	var swim_preview := Button.new()
	swim_preview.name = "PreviewSwimmingParticles"
	swim_preview.text = "TEST SWIMMING + SPLASH PARTICLES"
	SKIN.apply_translucent_button(swim_preview, "wood_selected")
	swim_preview.custom_minimum_size.y = 48
	swim_preview.pressed.connect(_preview_swimming_fx)
	stack.add_child(swim_preview)
	settings_touch_buttons.append(swim_preview)

	var dismiss := Button.new()
	dismiss.name = "CloseControlSettings"
	dismiss.text = "DONE  •  BACK TO GAME"
	SKIN.apply_translucent_button(dismiss, "wood")
	dismiss.custom_minimum_size.y = 48
	dismiss.pressed.connect(_close_control_settings)
	stack.add_child(dismiss)
	settings_touch_buttons.append(dismiss)

	control_settings_close_button = Button.new()
	control_settings_close_button.name = "CloseInGameSettings"
	SKIN.apply_close_button(control_settings_close_button, 43.0)
	control_settings_close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	control_settings_close_button.anchor_left = 1.0
	control_settings_close_button.anchor_right = 1.0
	control_settings_close_button.offset_left = -53.0
	control_settings_close_button.offset_right = -10.0
	control_settings_close_button.offset_top = 9.0
	control_settings_close_button.offset_bottom = 52.0
	control_settings_close_button.pressed.connect(_close_control_settings)
	control_settings_panel.add_child(control_settings_close_button)
	settings_touch_buttons.append(control_settings_close_button)
	_refresh_status_mode_buttons()

func _build_leave_menu() -> void:
	# Android modal: translucent shade behind a solid, clearly bounded
	# shared V2 dialog. Its real Button signals remain available to keyboard
	# callers, while touch is dispatched explicitly in _input below.
	leave_menu_shade = ColorRect.new()
	leave_menu_shade.name = "LeaveGameShade"
	leave_menu_shade.color = Color(0.025, 0.02, 0.04, 0.74)
	leave_menu_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(leave_menu_shade)
	leave_menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_menu_shade.visible = false

	leave_menu_panel = PanelContainer.new()
	leave_menu_panel.name = "LeaveGamePanel"
	leave_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	leave_menu_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Shared new modal style, not the old oversized nine-slice dark-wood art.
	leave_menu_panel.add_theme_stylebox_override("panel", SKIN.modal_panel())
	root.add_child(leave_menu_panel)
	leave_menu_panel.visible = false
	var margins := MarginContainer.new()
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 15)
	leave_menu_panel.add_child(margins)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 9)
	margins.add_child(stack)

	var heading_frame := PanelContainer.new()
	heading_frame.name = "LeaveGameHeadingFrame"
	heading_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_frame.add_theme_stylebox_override("panel", SKIN.modal_section())
	heading_frame.custom_minimum_size = Vector2(0, 49)
	stack.add_child(heading_frame)
	var heading := Label.new()
	heading.name = "LeaveGameHeading"
	heading.text = "LEAVE OUTPOST"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_color_override("font_color", SKIN.GOLD)
	heading.add_theme_color_override("font_outline_color", Color("#1d1014"))
	heading.add_theme_constant_override("outline_size", 3)
	heading.add_theme_font_size_override("font_size", 24)
	heading_frame.add_child(heading)

	var notice_frame := PanelContainer.new()
	notice_frame.name = "LeaveGameNoticeFrame"
	notice_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_frame.add_theme_stylebox_override("panel", SKIN.modal_section(true))
	notice_frame.custom_minimum_size = Vector2(0, 72)
	stack.add_child(notice_frame)
	leave_menu_info = Label.new()
	leave_menu_info.name = "LeaveGameMessage"
	leave_menu_info.text = "Your progress will be saved before returning to the title."
	leave_menu_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave_menu_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	leave_menu_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leave_menu_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	leave_menu_info.add_theme_color_override("font_color", SKIN.INK)
	leave_menu_info.add_theme_font_size_override("font_size", 16)
	notice_frame.add_child(leave_menu_info)

	for caption in ["RESUME ADVENTURE", "CONTROLS", "VERSIONS / UPDATES", "SAVE & RETURN TO TITLE"]:
		var action := Button.new()
		action.text = caption
		action.custom_minimum_size = Vector2(0, 52)
		action.mouse_filter = Control.MOUSE_FILTER_STOP
		SKIN.apply_button(action, "red" if caption.begins_with("SAVE") else "wood")
		action.add_theme_font_size_override("font_size", 18)
		if caption == "RESUME ADVENTURE":
			action.name = "ResumeAdventureButton"
			action.pressed.connect(_close_leave_menu)
		elif caption == "CONTROLS":
			action.name = "LeaveControlsButton"
			action.pressed.connect(func() -> void:
				_close_leave_menu()
				_show_control_settings()
			)
		elif caption == "VERSIONS / UPDATES":
			action.name = "OpenVersionChannels"
			action.pressed.connect(_return_to_version_channels)
		else:
			leave_menu_confirm = action
			action.name = "ReturnToTitle"
			action.pressed.connect(_return_to_title)
		stack.add_child(action)
		leave_menu_actions.append(action)

	# Real red close control sits ON TOP of panel, but does not cover
	# gameplay outside this modal when hidden.
	leave_menu_close_button = Button.new()
	leave_menu_close_button.name = "CloseLeaveOutpost"
	SKIN.apply_close_button(leave_menu_close_button, 42.0)
	leave_menu_close_button.pressed.connect(_close_leave_menu)
	root.add_child(leave_menu_close_button)
	leave_menu_close_button.visible = false

func _layout_leave_menu_for_size(screen: Vector2, scale: float) -> void:
	if leave_menu_panel == null or screen.x <= 0.0 or screen.y <= 0.0:
		return
	var width_px: float = minf(520.0 * scale, screen.x * 0.80)
	var height_px: float = minf(478.0 * scale, screen.y * 0.87)
	var top_left: Vector2 = (screen - Vector2(width_px, height_px)) * 0.5
	_place_px(leave_menu_panel, screen, Rect2(top_left, Vector2(width_px, height_px)))
	_place_px(leave_menu_close_button, screen, Rect2(
			top_left + Vector2(width_px - 52.0 * scale, 9.0 * scale),
			Vector2.ONE * 43.0 * scale))

func _leave_button_at(pos: Vector2) -> Button:
	if leave_menu_close_button != null and leave_menu_close_button.visible and leave_menu_close_button.get_global_rect().has_point(pos):
		return leave_menu_close_button
	for action in leave_menu_actions:
		if action.visible and not action.disabled and action.get_global_rect().has_point(pos):
			return action
	return null

func _handle_leave_menu_input(event: InputEvent) -> void:
	# Consume BEFORE dispatch: a successful Save/Return changes scene.
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		_close_leave_menu()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and leave_touch_finger < 0:
			leave_touch_finger = touch.index
			leave_touch_origin = touch.position
			leave_touch_candidate = _leave_button_at(touch.position)
		elif not touch.pressed and touch.index == leave_touch_finger:
			var pressed_action: Button = leave_touch_candidate
			var activate: bool = pressed_action != null and pressed_action == _leave_button_at(touch.position) and touch.position.distance_to(leave_touch_origin) < 40.0
			leave_touch_finger = -1
			leave_touch_candidate = null
			leave_ignore_synthetic_mouse_until = Time.get_ticks_msec() + 360
			if activate:
				pressed_action.pressed.emit()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == leave_touch_finger and drag.position.distance_to(leave_touch_origin) >= 40.0:
			leave_touch_candidate = null
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() >= leave_ignore_synthetic_mouse_until:
			if click.pressed:
				leave_mouse_down = true
				leave_mouse_origin = click.position
				leave_mouse_candidate = _leave_button_at(click.position)
			elif leave_mouse_down:
				var pressed_action: Button = leave_mouse_candidate
				var activate: bool = pressed_action != null and pressed_action == _leave_button_at(click.position) and click.position.distance_to(leave_mouse_origin) < 40.0
				leave_mouse_down = false
				leave_mouse_candidate = null
				if activate:
					pressed_action.pressed.emit()
 
func _open_leave_menu() -> void:
	_set_top_menu(false)
	if leave_menu_panel == null or leave_menu_shade == null:
		return
	_reset_touch()
	if skill_detail_panel != null:
		skill_detail_panel.visible = false
	if control_settings_panel != null:
		control_settings_panel.visible = false
	var online: bool = game != null and game.coop != null and game.coop.online()
	var is_host: bool = online and game.coop.mode == "hosting"
	leave_menu_info.text = "Your progress will be saved. Friends will disconnect." if online else "Your progress will be saved before returning to the title."
	if leave_menu_confirm != null:
		leave_menu_confirm.text = ("END LAN & RETURN" if is_host else "LEAVE LAN & RETURN") if online else "SAVE & RETURN TO TITLE"
	leave_touch_finger = -1
	leave_touch_candidate = null
	leave_mouse_down = false
	leave_mouse_candidate = null
	leave_menu_shade.visible = true
	leave_menu_panel.visible = true
	leave_menu_close_button.visible = true
	leave_menu_shade.move_to_front()
	leave_menu_panel.move_to_front()
	leave_menu_close_button.move_to_front()

func _close_leave_menu() -> void:
	leave_touch_finger = -1
	leave_touch_candidate = null
	leave_mouse_down = false
	leave_mouse_candidate = null
	if leave_menu_panel != null:
		leave_menu_panel.visible = false
	if leave_menu_shade != null:
		leave_menu_shade.visible = false
	if leave_menu_close_button != null:
		leave_menu_close_button.visible = false

func _return_to_version_channels() -> void:
	# Finish the current session/save before changing or installing an APK.
	get_tree().root.set_meta("outpost_open_settings", true)
	_return_to_title()

func _return_to_title() -> void:
	if game != null and game.has_method("save_and_return_to_title"):
		game.save_and_return_to_title()

func _show_control_settings() -> void:
	_set_top_menu(false)
	skill_detail_panel.visible = false
	control_settings_panel.visible = not control_settings_panel.visible
	if control_settings_panel.visible:
		control_settings_panel.move_to_front()
		# Open at the top while the fixed red X stays reachable throughout.
		var scroll: ScrollContainer = control_settings_panel.get_node_or_null("ControlSettingsScroll") as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = 0
	_reset_touch()

func _close_control_settings() -> void:
	if control_settings_panel == null:
		return
	_save_character_name()
	control_settings_panel.visible = false
	settings_touch_finger = -1
	settings_touch_candidate = null
	settings_scroll_dragging = false
	settings_slider_finger = -1
	settings_slider_mouse_down = false
	settings_touch_mouse_echo_until = Time.get_ticks_msec() + 370
	_reset_touch()


func _preview_swimming_fx() -> void:
	if game != null and game.hero != null and game.hero.has_method("preview_swimming_fx"):
		game.hero.preview_swimming_fx()
		_close_control_settings()


func _set_status_text_mode(stat: String, mode: String) -> void:
	if stat not in ["health", "mana", "xp"] or mode not in ["text", "percent", "off"]:
		return
	status_text_modes[stat] = mode
	_refresh_status_mode_buttons()
	_save_control_prefs()


func _refresh_status_mode_buttons() -> void:
	for stat in ["health", "mana", "xp"]:
		var selected: String = str(status_text_modes.get(stat, "text"))
		for mode in ["text", "percent", "off"]:
			var button: Button = status_mode_buttons.get(stat + ":" + mode) as Button
			if button == null:
				continue
			var active: bool = mode == selected
			button.text = ("✓  " if active else "○  ") + ("NUMBERS" if mode == "text" else "PERCENT" if mode == "percent" else "OFF")
			SKIN.apply_translucent_button(button, "wood_selected" if active else "wood")
			button.add_theme_font_size_override("font_size", 13)


func _settings_button_at(position: Vector2) -> BaseButton:
	if control_settings_close_button != null and control_settings_close_button.get_global_rect().grow(7.0).has_point(position):
		return control_settings_close_button
	var scroll: ScrollContainer = control_settings_panel.get_node_or_null("ControlSettingsScroll") as ScrollContainer
	if scroll == null or not scroll.get_global_rect().has_point(position):
		return null
	for button in settings_touch_buttons:
		if button == control_settings_close_button or not button.is_visible_in_tree() or button.disabled:
			continue
		if button.get_global_rect().has_point(position):
			return button
	return null


func _apply_settings_slider_touch(position: Vector2) -> void:
	if movement_stick_slider == null:
		return
	var bounds: Rect2 = movement_stick_slider.get_global_rect()
	var fraction: float = clampf((position.x - bounds.position.x) / maxf(1.0, bounds.size.x), 0.0, 1.0)
	movement_stick_slider.value = roundf((80.0 + fraction * 70.0) / 5.0) * 5.0


func _handle_settings_touch(event: InputEvent) -> void:
	# Android sometimes routes GUI touch release to the scrolling parent
	# instead of Button. Dispatch actual settings controls at HUD input level,
	# but leave ScrollContainer drags and LineEdit typing to Godot.
	if event.is_action_pressed("ui_cancel"):
		_close_control_settings()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and movement_stick_slider != null and movement_stick_slider.get_global_rect().has_point(touch.position) and (control_settings_panel.get_node("ControlSettingsScroll") as ScrollContainer).get_global_rect().has_point(touch.position):
			settings_slider_finger = touch.index
			_apply_settings_slider_touch(touch.position)
			get_viewport().set_input_as_handled()
			return
		if touch.index == settings_slider_finger and not touch.pressed:
			_apply_settings_slider_touch(touch.position)
			settings_slider_finger = -1
			settings_touch_mouse_echo_until = Time.get_ticks_msec() + 420
			get_viewport().set_input_as_handled()
			return
		if touch.pressed and settings_touch_finger < 0:
			var scroll: ScrollContainer = control_settings_panel.get_node_or_null("ControlSettingsScroll") as ScrollContainer
			if scroll != null and scroll.get_global_rect().has_point(touch.position):
				# Capture touch anywhere in the pane, including heading labels,
				# so swipe scrolling works even when no button was touched.
				settings_touch_finger = touch.index
				settings_touch_start = touch.position
				settings_scroll_last_y = touch.position.y
				settings_scroll_dragging = false
				settings_touch_candidate = _settings_button_at(touch.position)
				get_viewport().set_input_as_handled()
			elif control_settings_close_button.get_global_rect().grow(8.0).has_point(touch.position):
				settings_touch_finger = touch.index
				settings_touch_start = touch.position
				settings_scroll_last_y = touch.position.y
				settings_scroll_dragging = false
				settings_touch_candidate = control_settings_close_button
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == settings_touch_finger:
			var action: BaseButton = settings_touch_candidate
			var activate: bool = not settings_scroll_dragging and action != null and action == _settings_button_at(touch.position) and touch.position.distance_to(settings_touch_start) < 32.0
			settings_touch_candidate = null
			settings_touch_finger = -1
			settings_scroll_dragging = false
			settings_touch_mouse_echo_until = Time.get_ticks_msec() + 420
			get_viewport().set_input_as_handled()
			if activate:
				_activate_settings_button(action)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == settings_slider_finger:
			_apply_settings_slider_touch(drag.position)
			get_viewport().set_input_as_handled()
			return
		if drag.index == settings_touch_finger:
			var scroll: ScrollContainer = control_settings_panel.get_node_or_null("ControlSettingsScroll") as ScrollContainer
			if drag.position.distance_to(settings_touch_start) >= 12.0:
				settings_scroll_dragging = true
				settings_touch_candidate = null
			if settings_scroll_dragging and scroll != null:
				scroll.scroll_vertical += roundi(settings_scroll_last_y - drag.position.y)
			settings_scroll_last_y = drag.position.y
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if Time.get_ticks_msec() < settings_touch_mouse_echo_until:
			get_viewport().set_input_as_handled()
			return
		if click.pressed and movement_stick_slider != null and movement_stick_slider.get_global_rect().has_point(click.position):
			settings_slider_mouse_down = true
			_apply_settings_slider_touch(click.position)
			get_viewport().set_input_as_handled()
			return
		if not click.pressed and settings_slider_mouse_down:
			settings_slider_mouse_down = false
			_apply_settings_slider_touch(click.position)
			get_viewport().set_input_as_handled()
			return
		if click.pressed:
			settings_touch_candidate = _settings_button_at(click.position)
			if settings_touch_candidate != null:
				settings_touch_start = click.position
				get_viewport().set_input_as_handled()
		elif settings_touch_candidate != null:
			var action: BaseButton = settings_touch_candidate
			var activate: bool = action == _settings_button_at(click.position) and click.position.distance_to(settings_touch_start) < 32.0
			settings_touch_candidate = null
			get_viewport().set_input_as_handled()
			if activate:
				_activate_settings_button(action)


func _activate_settings_button(action: BaseButton) -> void:
	if action == floating_mode_toggle:
		floating_mode_toggle.set_pressed_no_signal(not floating_mode_toggle.button_pressed)
		_set_floating_mode(floating_mode_toggle.button_pressed)
	elif action == adaptive_joystick_toggle:
		_set_adaptive_joystick(not adaptive_joystick_enabled)
	elif action == sticky_movement_toggle:
		sticky_movement_toggle.set_pressed_no_signal(not sticky_movement_toggle.button_pressed)
		_set_sticky_movement(sticky_movement_toggle.button_pressed)
	else:
		action.pressed.emit()


func _set_floating_mode(enabled: bool) -> void:
	floating_joystick_enabled = enabled
	if floating_mode_toggle != null:
		floating_mode_toggle.set_pressed_no_signal(enabled)
	_reset_touch()
	_save_control_prefs()


func _set_movement_stick_size(value: float) -> void:
	movement_stick_scale = clampf(roundf(value / 5.0) * 0.05, 0.8, 1.5)
	if movement_stick_size_label != null:
		movement_stick_size_label.text = "%d%%" % roundi(movement_stick_scale * 100.0)
	_apply_movement_stick_size()
	_save_control_prefs()


func _apply_movement_stick_size() -> void:
	if joystick == null or knob == null:
		return
	joystick.size = Vector2.ONE * STICK_BASE_DIAMETER * movement_stick_scale
	knob.size = Vector2.ONE * STICK_THUMB_DIAMETER * movement_stick_scale
	var ring: StyleBoxFlat = joystick.get_theme_stylebox("panel") as StyleBoxFlat
	if ring != null:
		ring.set_corner_radius_all(1000)
	var thumb: StyleBoxFlat = knob.get_theme_stylebox("panel") as StyleBoxFlat
	if thumb != null:
		thumb.set_corner_radius_all(1000)
	knob.position = (joystick.size - knob.size) * 0.5 + move_vector * 45.0 * movement_stick_scale
	_position_stick()

func _set_adaptive_joystick(enabled: bool) -> void:
	adaptive_joystick_enabled = enabled
	if adaptive_joystick_toggle != null:
		adaptive_joystick_toggle.set_pressed_no_signal(enabled)
	_reset_touch()
	_save_control_prefs()

func _set_sticky_movement(enabled: bool) -> void:
	sticky_movement_enabled = enabled
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
		for stat in ["health", "mana", "xp"]:
			var saved: String = str(config.get_value("status_text", stat, "text"))
			status_text_modes[stat] = saved if saved in ["text", "percent", "off"] else "text"
		floating_joystick_enabled = bool(config.get_value("controls", "floating_joystick", false))
		adaptive_joystick_enabled = bool(config.get_value("controls", "adaptive_joystick", false))
		sticky_movement_enabled = bool(config.get_value("controls", "sticky_movement", false))
		movement_stick_scale = clampf(float(config.get_value("controls", "movement_stick_scale", 1.20)), 0.8, 1.5)
		# Older Alphas saved 100% as the default. Upgrade only that legacy
		# default once to the newly requested 120%, preserving explicit
		# smaller/larger settings and all later slider selections.
		if not bool(config.get_value("controls", "stick_default_enlarged_v2", false)):
			if is_equal_approx(movement_stick_scale, 1.0):
				movement_stick_scale = 1.20
			config.set_value("controls", "movement_stick_scale", movement_stick_scale)
			config.set_value("controls", "stick_default_enlarged_v2", true)
			config.save(CONTROL_PREFS)
		player_display_name = str(config.get_value("profile", "display_name", "Adventurer")).strip_edges()
		if player_display_name.is_empty():
			player_display_name = "Adventurer"
	floating_mode_toggle.set_pressed_no_signal(floating_joystick_enabled)
	movement_stick_slider.set_value_no_signal(movement_stick_scale * 100.0)
	movement_stick_size_label.text = "%d%%" % roundi(movement_stick_scale * 100.0)
	_apply_movement_stick_size()
	adaptive_joystick_toggle.set_pressed_no_signal(adaptive_joystick_enabled)
	sticky_movement_toggle.set_pressed_no_signal(sticky_movement_enabled)
	name_edit.text = player_display_name
	_refresh_status_mode_buttons()

func _save_control_prefs() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "stick_default_enlarged_v2", true)
	config.set_value("controls", "floating_joystick", floating_joystick_enabled)
	config.set_value("controls", "movement_stick_scale", movement_stick_scale)
	config.set_value("controls", "adaptive_joystick", adaptive_joystick_enabled)
	config.set_value("controls", "sticky_movement", sticky_movement_enabled)
	config.set_value("profile", "display_name", player_display_name)
	for stat in ["health", "mana", "xp"]:
		config.set_value("status_text", stat, status_text_modes.get(stat, "text"))
	config.save(CONTROL_PREFS)

func _place_px(control: Control, screen: Vector2, region: Rect2) -> void:
	# Keep touch targets square in pixels instead of stretching circles into
	# ovals as aspect ratios change; anchors still follow viewport resizing.
	_anchors(control, region.position.x / screen.x, region.position.y / screen.y,
			region.end.x / screen.x, region.end.y / screen.y)

func _radial_px(button: Control, screen: Vector2, center: Vector2, radius: float) -> void:
	_place_px(button, screen, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))

func _layout_touch_hud() -> void:
	if root == null or minimap == null or smart_button == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return
	var scale: float = clampf(minf(screen.x / 1280.0, screen.y / 720.0), 0.8, 1.2)
	var edge: float = 18.0 * scale
	# The live minimap stays a real square instead of becoming an oval on
	# phones with wider aspect ratios. Footer and menu sit directly below it.
	var map_side: float = minf(screen.y * 0.285, minf(228.0 * scale, screen.x * 0.23))
	# Make room for the location banner ABOVE (not on top of) the live map.
	var map_top: float = 54.0 * scale
	_place_px(minimap, screen, Rect2(screen.x - edge - map_side, map_top, map_side, map_side))
	# The zone pill now sits just two scaled pixels above the round map.
	var zone_top: float = map_top - 30.0 * scale
	_place_px(zone_pill, screen, Rect2(screen.x - edge - map_side, zone_top, map_side, 30.0 * scale))
	_place_px(zone_pill_text, screen, Rect2(screen.x - edge - map_side + 7.0 * scale, zone_top + 1.0 * scale,
			map_side - 14.0 * scale, 28.0 * scale))
	_place_px(zone_banner, screen, Rect2((screen.x - 440.0 * scale) * 0.5,
			110.0 * scale, 440.0 * scale, 38.0 * scale))
	var map_bottom: float = map_top + map_side
	var toggle_side: float = 52.0 * scale
	# MENU belongs up at the map's top-left shoulder, not detached
	# beneath the clock. Leave the circular minimap unobstructed.
	var map_left: float = screen.x - edge - map_side
	# Target portrait lives beside, not inside, the minimap; it follows
	# the live player HUD proportions without hiding Bag, Menu or wallet.
	if enemy_target_hud != null:
		_place_px(enemy_target_hud, screen, Rect2(map_left - 350.0 * scale,
			77.0 * scale, 338.0 * scale, 92.0 * scale))
	# Equal-height carved mobile controls: WALLET / BAG / MENU.
	# The menu never overlaps the circular map or consumes a combat slot.
	_place_px(menu_button, screen, Rect2(map_left - 87.0 * scale,
			11.0 * scale, 58.0 * scale, 58.0 * scale))
	var footer_top: float = map_bottom - 7.0 * scale
	_place_px(clock_footer, screen, Rect2(map_left + 14.0 * scale,
			footer_top, map_side - 28.0 * scale, 35.0 * scale))
	_place_px(calendar_mark, screen, Rect2(map_left + 21.0 * scale,
			footer_top + 3.0 * scale, 25.0 * scale, 29.0 * scale))
	_place_px(clock_label, screen, Rect2(map_left + 49.0 * scale,
			footer_top + 3.0 * scale, map_side - 70.0 * scale, 29.0 * scale))
	# Keep both receipt cards below the QUEST banner on the LEFT.
	# The previous position under the right-side minimap placed them directly
	# behind POWER/LOCK/ATTACK, hiding item icons and blocking tooltip taps.
	# Compact fixed-width cards also stay clear of the lower-left joystick.
	if gathered_panel != null:
		var receipt_left: float = 16.0 * scale
		var receipt_top: float = 205.0 * scale
		var receipt_width: float = minf(285.0 * scale, screen.x * 0.31)
		var recent_height: float = 0.0 # World-space pickup text replaces tracker card.
		_place_px(gathered_panel, screen, Rect2(receipt_left, receipt_top, receipt_width, recent_height))
		_place_px(gathered_title, screen, Rect2(receipt_left + 8.0 * scale, receipt_top + 2.0 * scale,
				receipt_width - 43.0 * scale, 21.0 * scale))
		_place_px(gathered_collapse, screen, Rect2(receipt_left + receipt_width - 29.0 * scale,
				receipt_top + 2.0 * scale, 25.0 * scale, 25.0 * scale))
		_place_px(gathered_content, screen, Rect2(receipt_left + 9.0 * scale, receipt_top + 25.0 * scale,
				receipt_width - 17.0 * scale, 49.0 * scale))
		var loot_top: float = receipt_top # Only compact loot/combat feed stays on HUD.
		_place_px(loot_feed_panel, screen, Rect2(receipt_left, loot_top, receipt_width, 89.0 * scale))
		_place_px(loot_feed_title, screen, Rect2(receipt_left + 9.0 * scale, loot_top + 2.0 * scale,
				receipt_width - 18.0 * scale, 19.0 * scale))
		_place_px(loot_feed_rows, screen, Rect2(receipt_left + 4.0 * scale, loot_top + 1.0 * scale,
				receipt_width - 9.0 * scale, 86.0 * scale))
		# Tooltip opens towards the centre from the *left* card, instead
		# of sitting behind right-side combat buttons. All sizes are bounded.
		var detail_left: float = receipt_left + receipt_width + 10.0 * scale
		var detail_width: float = minf(270.0 * scale, screen.x - detail_left - 8.0 * scale)
		var detail_top: float = clampf(loot_top, 99.0 * scale, screen.y - 163.0 * scale)
		_place_px(loot_tooltip_panel, screen, Rect2(detail_left, detail_top, detail_width, 147.0 * scale))
		_place_px(loot_tooltip_name, screen, Rect2(detail_left + 13.0 * scale,
				detail_top + 12.0 * scale, detail_width - 26.0 * scale, 29.0 * scale))
		_place_px(loot_tooltip_rarity, screen, Rect2(detail_left + 13.0 * scale,
				detail_top + 42.0 * scale, detail_width - 26.0 * scale, 21.0 * scale))
		_place_px(loot_tooltip_description, screen, Rect2(detail_left + 13.0 * scale,
				detail_top + 67.0 * scale, detail_width - 26.0 * scale, 71.0 * scale))
	# A proper central modal for menu settings; never position the six
	# clickable destinations as a cramped 3x2 overlay underneath the map.
	var menu_width: float = minf(498.0 * scale, screen.x * 0.80)
	var menu_height: float = minf(432.0 * scale, screen.y * 0.86)
	var menu_origin: Vector2 = (screen - Vector2(menu_width, menu_height)) * 0.5
	_place_px(top_menu_panel, screen, Rect2(menu_origin, Vector2(menu_width, menu_height)))
	_place_px(top_menu_close_button, screen, Rect2(
			menu_origin + Vector2(menu_width - 53.0 * scale, 13.0 * scale),
			Vector2.ONE * 41.0 * scale))
	var gutter: float = 16.0 * scale
	var menu_col_width: float = (menu_width - 48.0 * scale - gutter) * 0.5
	var row_height: float = (menu_height - 152.0 * scale) / 3.0
	for index in range(top_menu_actions.size()):
		var column: int = index % 2
		var row_index: int = index / 2
		_place_px(top_menu_actions[index], screen, Rect2(
				menu_origin + Vector2(24.0 * scale + float(column) * (menu_col_width + gutter),
						99.0 * scale + float(row_index) * (row_height + 11.0 * scale)),
				Vector2(menu_col_width, row_height)))
	# Every circular holder is actually square; the centre-to-centre gaps
	# leave distinct hit targets even with two fingers on a small phone.
	# Lower smart Interact near full-width XP; keep distinct finger hitboxes.
	_radial_px(smart_button, screen,
			Vector2(screen.x - 90.0 * scale, screen.y - 120.0 * scale), 59.0 * 1.05 * scale)
	_radial_px(tool_swap_button, screen,
			Vector2(screen.x - 90.0 * scale, screen.y - 221.0 * scale), 24.0 * scale)
	var combat: Array[Vector3] = [
		Vector3(126.0, 287.0, 37.0 * 1.03), # POWER above Interact
		Vector3(205.0, 204.0, 37.0 * 1.03), # CLEAVE left of Interact
		Vector3(205.0, 121.0, 37.0 * 1.03), # SUNDER by Interact
		Vector3(380.0, 83.0, 30.0 * 1.03),  # food/heal close to combat
		Vector3(451.0, 83.0, 30.0 * 1.03)   # potion beside heal
	]
	var keys: Array[String] = ["skill_1", "skill_2", "skill_3", "consumable", "potion"]
	for index in range(keys.size()):
		var spec: Vector3 = combat[index]
		_radial_px(quick_buttons[keys[index]], screen,
				Vector2(screen.x - spec.x * scale, screen.y - spec.y * scale), spec.z * scale)
	_radial_px(torch_button, screen,
			Vector2(screen.x - 309.0 * scale, screen.y - 83.0 * scale), 30.0 * 1.03 * scale)
	if stop_sticky_button != null:
		_place_px(stop_sticky_button, screen, Rect2(24.0 * scale, screen.y - 237.0 * scale, 118.0 * scale, 48.0 * scale))
	# Follow the action target without obscuring the on-screen controls.
	if tool_gesture_hint != null:
		_place_px(tool_gesture_hint, screen, Rect2(
				screen.x - 158.0 * scale, screen.y - 257.0 * scale,
				133.0 * scale, 27.0 * scale))
	# Hold-and-slide trays are transient and remain below the map and
	# clear of the viewport edge, with rows large enough to select.
	var tool_width: float = 205.0 * scale
	var tool_height: float = 238.0 * scale
	_place_px(smart_tray, screen, Rect2(
			screen.x - edge - tool_width,
			screen.y - 120.0 * scale - 59.0 * 1.05 * scale - tool_height - 9.0 * scale,
			tool_width, tool_height))
	_layout_xp_for_size(screen, scale)
	_layout_player_chrome_for_size(screen, scale)
	_layout_leave_menu_for_size(screen, scale)
	if control_settings_panel != null:
		# The previous 81%-of-screen anchor made Controls over 1000px
		# tall on square-ish or high-resolution Android viewports. Its
		# content then fitted without scrolling, despite lower rows being
		# unreachable in landscape UI. Cap the modal to a real 590px
		# layout while keeping it centered and fully on screen.
		var controls_size := Vector2(minf(640.0 * scale, screen.x * 0.82),
				minf(590.0 * scale, screen.y * 0.83))
		_place_px(control_settings_panel, screen,
				Rect2((screen - controls_size) * 0.5, controls_size))
	# The bottom-centre prompt was covering consumables and character XP.
	# Keep short notices together in a compact top-centre stack instead.
	# Compact top-centre alert stack; reduced in both width and height
	# so combat/wildlife text doesn't dominate the world view.
	var info_width: float = minf(298.0 * scale, screen.x * 0.30)
	var info_left: float = (screen.x - info_width) * 0.5
	var info_y: float = maxf(129.0 * scale, screen.y * 0.175)
	# Enemy card occupies the upper centre-right.  When targeting, move
	# short context messages below it rather than covering the portrait.
	if enemy_target_hud != null and enemy_target_hud.visible:
		info_y = maxf(info_y, 177.0 * scale)
	_place_px(context_prompt_frame, screen, Rect2(info_left, info_y, info_width, 32.0 * scale))
	_place_px(hint, screen, Rect2(info_left + 7.0 * scale, info_y + 2.0 * scale, info_width - 14.0 * scale, 28.0 * scale))
	var toast_y: float = info_y + 38.0 * scale if enemy_target_hud != null and enemy_target_hud.visible else info_y - 43.0 * scale
	_place_px(toast_panel, screen, Rect2(info_left, toast_y, info_width, 33.0 * scale))
	_place_px(toast_label, screen, Rect2(info_left + 7.0 * scale, toast_y + 1.0 * scale, info_width - 14.0 * scale, 30.0 * scale))

func _layout_xp_for_size(screen: Vector2, scale: float) -> void:
	# Always spans x=0..viewport width and y=viewport bottom, including 20:9.
	# These are separate controls with IGNORE input, so the strip can never
	# swallow joystick, camera, bag, menu, or skill touches.
	if screen.x <= 0.0 or screen.y <= 0.0 or xp_bar == null:
		return
	var height_px: float = clampf(18.0 * scale, 17.0, 23.0)
	var y: float = screen.y - height_px
	_place_px(xp_bar, screen, Rect2(0.0, y, screen.x, height_px))
	# Weapon / gathering mastery now lives in the Skills modal, never
	# under the enlarged movement joystick on the bottom-left of the HUD.
	# Keep actual XP reading centred along the uninterrupted bottom strip.
	# The portrait rank badge is placed by _layout_player_chrome_for_size.
	_place_px(xp_level_label, screen, Rect2(0.0, y, screen.x, height_px))

func _hud_glass(opacity: float, border_alpha: float) -> StyleBoxFlat:
	# The actual UI art stays transparent and separately editable; this is
	# only the slim backing to keep health/text legible over bright terrain.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.085, 0.11, opacity)
	style.border_color = Color(0.84, 0.70, 0.48, border_alpha)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0)
	style.anti_aliasing = true
	return style

func _layout_player_chrome() -> void:
	if root == null or hero_status_frame == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return
	var scale: float = clampf(minf(screen.x / 1280.0, screen.y / 720.0), 0.8, 1.2)
	_layout_player_chrome_for_size(screen, scale)

func _layout_player_chrome_for_size(screen: Vector2, scale: float) -> void:
	# Preserve the portrait/HP and the top-right BAG/MENU controls. Keep
	# all five currency captions on a single line strictly LEFT of BAG.
	if hero_status_frame == null or screen.x <= 0.0 or screen.y <= 0.0:
		return
	var unit: float = scale
	var map_side: float = minf(screen.y * 0.285, minf(228.0 * unit, screen.x * 0.23))
	var map_left_base: float = (screen.x - 18.0 * unit - map_side) / unit
	var wallet_left: float = map_left_base - 300.0
	# Right edge of the five-column strip ends eight virtual pixels before
	# BAG (whose left edge is map_left_base - 164). Earlier code ended at
	# map_left_base - 91, drawing GOLD/GEMS UNDER the Bag button.
	var currency_right: float = map_left_base - 172.0
	var wallet_width: float = minf(545.0, maxf(0.0, currency_right - 354.0))
	var currency_start: float = currency_right - wallet_width
	var currency_cell: float = wallet_width / 5.0
	var rects: Dictionary = {
		"status": Rect2(16, 15, 326, 108),
		"portrait_frame": Rect2(22, 20, 88, 88),
		"portrait": Rect2(26, 24, 80, 80),
		"sigil": Rect2(93, 90, 19, 20),
		"portrait_level": Rect2(89, 79, 30, 30),
		"portrait_badge": Rect2(89, 79, 30, 30),
		"name": Rect2(108, 20, 220, 25),
		"health": Rect2(108, 49, 228, 20),
		"health_text": Rect2(109, 50, 226, 18),
		"mana": Rect2(108, 76, 228, 18),
		"mana_text": Rect2(109, 76, 226, 17),
		"weapon": Rect2(117, 78, 220, 22),
		"effects": Rect2(117, 99, 220, 22),
		"wallet": Rect2(wallet_left, 75, 275, 248),
		"wallet_toggle": Rect2(map_left_base - 300.0, 17, 130, 50),
		"popup_title": Rect2(wallet_left + 16, 83, 245, 28),
		"coins": Rect2(currency_start + 31.0, 17.0, maxf(22.0, currency_cell - 34.0), 43.0),
		"resource_icon": Rect2(wallet_left + 20, 278, 26, 26),
		"resource_count": Rect2(wallet_left + 53, 278, 207, 26),
		"bag": Rect2(map_left_base - 156.0, 11, 58, 58),
		"weight": Rect2(375, 112, 295, 24),
		"quest_frame": Rect2(16, 143, 347, 52),
		"quest_rule": Rect2(25, 192, 335, 1.4),
		"quest_button": Rect2(23, 151, 109, 37),
		"quest": Rect2(140, 150, 216, 38),
		"journal_frame": Rect2(24, 200, 350, 102),
		"journal_text": Rect2(35, 208, 329, 87)
	}
	var pairs: Dictionary = {
		"status": hero_status_frame,
		"portrait_frame": hero_portrait_frame,
		"portrait": hero_portrait_art,
		"sigil": hero_sigil,
		"portrait_level": xp_level_badge,
		"portrait_badge": xp_level_badge.get_meta("badge_frame") as Panel,
		"name": status,
		"health": health_bar,
		"health_text": health_numbers,
		"mana": mana_bar,
		"mana_text": mana_numbers,
		"weapon": hero_detail,
		"effects": status_effect_strip,
		"wallet": wallet_frame,
		"wallet_toggle": wallet_collapse,
		"popup_title": wallet_popup_title,
		"coins": wallet_coin,
		"resource_icon": wallet_resource_icon,
		"resource_count": wallet_resource_count,
		"bag": wallet_bag,
		"weight": bag_weight_label,
		"quest_frame": quest_frame,
		"quest_rule": quest_rule,
		"quest_button": quest_toggle,
		"quest": quest,
		"journal_frame": quest_detail_back,
		"journal_text": quest_detail
	}
	for key in pairs:
		var control: Control = pairs[key] as Control
		if control != null:
			var bounds: Rect2 = rects[key]
			_place_px(control, screen, Rect2(bounds.position * unit, bounds.size * unit))
	for i in range(5):
		var key: String = ["coins", "copper", "silver", "gold", "gems"][i]
		var x: float = currency_start + currency_cell * float(i)
		var icon: TextureRect = wallet_currency_icons[key] as TextureRect
		_place_px(icon, screen, Rect2(Vector2(x + 2.0, 24.0) * unit,
				Vector2(27.0, 27.0) * unit))
		if i > 0:
			var line: Label = wallet_currency_rows[key] as Label
			_place_px(line, screen, Rect2(Vector2(x + 31.0, 17.0) * unit,
					Vector2(maxf(22.0, currency_cell - 34.0), 43.0) * unit))

# A real enemy target HUD, styled after the existing player portrait rather
# than a generic rectangular overlay.  All pieces are children of one
# transparent container so visibility, resizing and input work together.
func _build_enemy_target_hud() -> void:
	enemy_target_hud = Panel.new()
	enemy_target_hud.name = "EnemyTargetHUD"
	enemy_target_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_target_hud.add_theme_stylebox_override("panel", _hud_glass(0.0, 0.0))
	root.add_child(enemy_target_hud)
	_anchors(enemy_target_hud, 0.52, 0.11, 0.80, 0.21)
	enemy_portrait_frame = Panel.new()
	enemy_portrait_frame.name = "EnemyPortraitFrame"
	enemy_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Reuse the actual PLAYER ring style; both portraits have matching
	# corner radius, gold border, transparent centre and 4px inset.
	enemy_portrait_frame.add_theme_stylebox_override("panel",
		hero_portrait_frame.get_theme_stylebox("panel").duplicate(true) as StyleBox)
	enemy_target_hud.add_child(enemy_portrait_frame)
	_anchors(enemy_portrait_frame, 0.0, 0.0, 88.0 / 338.0, 88.0 / 92.0)
	enemy_portrait_art = TextureRect.new()
	enemy_portrait_art.name = "EnemyPortrait"
	enemy_portrait_art.texture = load("res://assets/ui/icons/enemy_boar_portrait.svg") as Texture2D
	var portrait_mask := ShaderMaterial.new()
	portrait_mask.shader = load("res://assets/ui/icons/portrait_circle.gdshader") as Shader
	enemy_portrait_art.material = portrait_mask
	enemy_portrait_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_portrait_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_portrait_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_portrait_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_target_hud.add_child(enemy_portrait_art)
	_anchors(enemy_portrait_art, 4.0 / 338.0, 4.0 / 92.0, 84.0 / 338.0, 84.0 / 92.0)
	enemy_name = Label.new()
	enemy_name.name = "EnemyDisplayName"
	enemy_name.text = "Wild boar"
	enemy_name.add_theme_font_size_override("font_size", 20)
	enemy_name.add_theme_color_override("font_color", SKIN.GOLD)
	enemy_name.add_theme_color_override("font_outline_color", Color("#171114"))
	enemy_name.add_theme_constant_override("outline_size", 2)
	enemy_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_name.clip_text = true
	enemy_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	enemy_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_target_hud.add_child(enemy_name)
	_anchors(enemy_name, 95.0 / 338.0, 5.0 / 92.0, 1.0, 34.0 / 92.0)
	enemy_health_bar = ProgressBar.new()
	enemy_health_bar.name = "EnemyHealthBar"
	enemy_health_bar.max_value = 100.0
	enemy_health_bar.value = 100.0
	enemy_health_bar.show_percentage = false
	enemy_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_health_bar.add_theme_stylebox_override("background",
		health_bar.get_theme_stylebox("background").duplicate(true) as StyleBox)
	enemy_health_bar.add_theme_stylebox_override("fill",
		health_bar.get_theme_stylebox("fill").duplicate(true) as StyleBox)
	enemy_target_hud.add_child(enemy_health_bar)
	_anchors(enemy_health_bar, 95.0 / 338.0, 41.0 / 92.0, 1.0, 64.0 / 92.0)
	enemy_health_numbers = Label.new()
	enemy_health_numbers.name = "EnemyHealthNumbers"
	enemy_health_numbers.add_theme_font_size_override("font_size", 15)
	enemy_health_numbers.add_theme_color_override("font_color", Color("#fff1db"))
	enemy_health_numbers.add_theme_color_override("font_outline_color", Color("#1b1110"))
	enemy_health_numbers.add_theme_constant_override("outline_size", 1)
	enemy_health_numbers.text = "HP 32 / 32"
	enemy_health_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_health_numbers.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_health_numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_target_hud.add_child(enemy_health_numbers)
	_anchors(enemy_health_numbers, 97.0 / 338.0, 42.0 / 92.0, 1.0, 63.0 / 92.0)
	enemy_target_hud.visible = false

func set_enemy_target(enemy: Node) -> void:
	if enemy_target_hud == null:
		return
	var shown: bool = enemy != null and is_instance_valid(enemy)
	if shown:
		shown = bool(enemy.get("alive")) and (enemy.get("hp") is float or enemy.get("hp") is int)
	if not shown:
		var was_visible: bool = enemy_target_hud.visible
		enemy_target_hud.visible = false
		enemy_target_id = 0
		if was_visible:
			_layout_touch_hud()
		return
	var hit_points: float = maxf(0.0, float(enemy.get("hp")))
	var full_health: Variant = enemy.get("max_hp")
	var maximum: float = maxf(1.0, float(full_health)) if full_health is float or full_health is int else maxf(1.0, hit_points)
	if hit_points <= 0.0:
		set_enemy_target(null)
		return
	var next_id: int = enemy.get_instance_id()
	if next_id != enemy_target_id:
		enemy_target_id = next_id
		enemy_name.text = game.enemy_display_name(enemy) if game != null else enemy.name.capitalize()
		var portrait_path: String = "res://assets/ui/icons/enemy_guardian_portrait.svg" if enemy.is_in_group("dungeon_guardians") else "res://assets/ui/icons/enemy_boar_portrait.svg"
		enemy_portrait_art.texture = load(portrait_path) as Texture2D
	enemy_health_bar.max_value = maximum
	enemy_health_bar.value = clampf(hit_points, 0.0, maximum)
	enemy_health_numbers.text = "HP %d / %d" % [ceili(hit_points), ceili(maximum)]
	if not enemy_target_hud.visible:
		enemy_target_hud.visible = true
		_layout_touch_hud()

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
	n.add_theme_stylebox_override("panel", SKIN.translucent_surface())
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

func _decorate_menu_action(button: Button, icon_id: String) -> void:
	# Existing six menu destinations stay exactly as before, with stable
	# names, text, accessibility and touch handlers. Artwork is decorative.
	var art: TextureRect = button.get_node_or_null("ActionIcon") as TextureRect
	if art == null:
		art = button.get_node_or_null("MenuIcon") as TextureRect
	if art == null:
		art = button.get_node_or_null("ExitDoorIcon") as TextureRect
	if art == null:
		art = TextureRect.new()
		art.name = "MenuIcon"
		button.add_child(art)
	art.texture = load(ACTION_FRAME_ROOT + icon_id + ".svg") as Texture2D
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.anchor_left = 0.055
	art.anchor_top = 0.12
	art.anchor_right = 0.30
	art.anchor_bottom = 0.88
	art.offset_left = 0.0
	art.offset_top = 0.0
	art.offset_right = 0.0
	art.offset_bottom = 0.0
	var action_caption: Label = button.get_node_or_null("ActionLabel") as Label
	if action_caption != null:
		action_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		action_caption.anchor_left = 0.33
		action_caption.anchor_right = 0.97
		action_caption.anchor_top = 0.05
		action_caption.anchor_bottom = 0.96
		action_caption.add_theme_font_size_override("font_size", 14)
	else:
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_theme_font_size_override("font_size", 14)

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
		# Texture-only wooden coin: uninterrupted upper gold rim, no rope,
		# side flanges, tabs or opaque rectangular backdrop.
		for frame_state in ["normal", "hover", "pressed", "disabled"]:
			var coin := StyleBoxTexture.new()
			var asset: String = "inactive.svg" if frame_state == "disabled" else "pressed.svg" if frame_state == "pressed" else "active.svg"
			coin.texture = load(ACTION_FRAME_ROOT + asset) as Texture2D
			button.add_theme_stylebox_override(frame_state, coin)
	else:
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, SKIN.translucent_surface(false, state in ["hover", "pressed"], true))
	root.add_child(button)
	_anchors(button, left, top, right, bottom)
	var art_icon := TextureRect.new()
	art_icon.name = "ActionIcon"
	var matching_icon: String = "sword" if key == "tool_swap" else "hand" if key == "interact" else "red_potion" if key == "potion" else "backpack" if key == "bag" else "armour" if key == "gear" else "menu" if key == "menu" else "heroic_strike" if key == "skill_1" else "cleave" if key == "skill_2" else "armor_break" if key == "skill_3" else ""
	var icon_path: String = ACTION_FRAME_ROOT + matching_icon + ".svg" if matching_icon != "" else "res://assets/ui/icons/" + key + ".png"
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
	caption.add_theme_font_size_override("font_size", 14 if kind == "round" else 15)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	caption.anchor_left = 0.0
	caption.anchor_right = 1.0
	caption.anchor_top = 0.68
	caption.anchor_bottom = 0.98
	if kind == "round":
		# Leave the gilded ring and label unobstructed on small touch targets.
		art_icon.anchor_left = 0.20
		art_icon.anchor_right = 0.80
		art_icon.anchor_top = 0.075
		art_icon.anchor_bottom = 0.63
		caption.anchor_top = 0.66
		caption.anchor_bottom = 0.92
		# The central context art takes the whole button, not an extra hand
		# sitting below the combat tools or a wordy interact tooltip.
		if key == "interact":
			caption.text = ""
			art_icon.anchor_left = 0.19
			art_icon.anchor_right = 0.81
			art_icon.anchor_top = 0.17
			art_icon.anchor_bottom = 0.83
		var cooldown_overlay: Control = ACTION_RADIAL.new()
		cooldown_overlay.name = "CooldownRing"
		cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(cooldown_overlay)
		cooldown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var hint_label: Label = _label("DRAG WORLD → ORBIT", 14, Color("#f7dc9c"), 0.768, 0.307, 0.987, 0.348)
	hint_label.name = "CameraDragHint"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_gesture_hint = hint_label

func _can_start_camera_drag(pos: Vector2) -> bool:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	# The SECOND touch must be able to orbit during a held movement joystick.
	# Reserve the actual button rectangles instead of a huge blocked right zone.
	if pos.x < screen.x * 0.24 or pos.y < screen.y * 0.16 or pos.y > screen.y * 0.94:
		return false
	if floating_joystick_enabled and finger < 0 and _floating_zone(pos):
		return false
	if finger < 0 and _adaptive_stick_zone(pos):
		return false
	if minimap != null and minimap.get_global_rect().grow(7.0).has_point(pos):
		return false
	for action in [smart_button, torch_button, menu_button, stop_sticky_button]:
		if action != null and action.visible and action.get_global_rect().grow(8.0).has_point(pos):
			return false
	for action in quick_buttons.values():
		if action is Control and (action as Control).visible and (action as Control).get_global_rect().grow(8.0).has_point(pos):
			return false
	for action in top_menu_actions:
		if action.visible and action.get_global_rect().grow(6.0).has_point(pos):
			return false
	return true


func _build_quick_tray() -> void:
	quick_tray = Panel.new()
	quick_tray.name = "ConsumableHoldSlider"
	quick_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quick_tray.add_theme_stylebox_override("panel", SKIN.translucent_surface())
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
		# The last slot remains Sundering Blow mechanically (damage only).
		# Its Armour Break presentation does not invent a defence debuff.
		button.tooltip_text = ["Heroic Strike (Power Strike)", "Cleave", "Armour Break (Sundering Blow — damage skill)"][i]
		var skill: String = ["power_strike", "cleave", "sundering_blow"][i]
		var time_left: float = float(game.skill_cooldowns.get(skill, 0.0))
		button.disabled = not unlocked or time_left > 0.0
		var label: Label = button.get_node_or_null("ActionLabel") as Label
		if label != null:
			label.text = "%ds" % int(ceilf(time_left)) if time_left > 0.0 else ["HEROIC", "CLEAVE", "BREAK"][i] if unlocked else "LOCK"
		var ring: Control = button.get_node_or_null("CooldownRing") as Control
		if ring != null:
			ring.call("set_cooldown", time_left, ACTION_SKILL_LEVELS.cooldown_for_skill(skill))
		var art: TextureRect = button.get_node_or_null("ActionIcon") as TextureRect
		if art != null:
			art.modulate = Color("#88848a") if button.disabled else Color.WHITE
	for kind in ["potion", "consumable"]:
		var button: Button = quick_buttons.get(kind) as Button
		if button == null:
			continue
		var item: String = str(game.quick_slots.get(kind, ""))
		var quantity: int = int(game.inventory.get(item, 0))
		if quantity <= 0:
			item = ""
			quantity = 0
		var time_left: float = float(game.quick_use_cooldowns.get(kind, 0.0))
		var can_heal: bool = game.hero != null and game.hero.health < 99.9
		button.disabled = item == "" or time_left > 0.0 or not can_heal
		var label: Label = button.get_node_or_null("ActionLabel") as Label
		if label != null:
			label.text = "x%d" % quantity if quantity > 0 else "EMPTY"
		var ring: Control = button.get_node_or_null("CooldownRing") as Control
		if ring != null:
			ring.call("set_cooldown", time_left, game.QUICK_USE_COOLDOWN)
		var art: TextureRect = button.get_node_or_null("ActionIcon") as TextureRect
		if art != null:
			art.modulate = Color("#858188") if button.disabled else Color.WHITE
			if quick_icon_cache.get(kind, "-") != item:
				quick_icon_cache[kind] = item
				var icon_path: String = ACTION_FRAME_ROOT + "red_potion.svg" if kind == "potion" else "res://assets/icons/" + ("meal" if item == "" else item) + ".svg"
				art.texture = load(icon_path) as Texture2D

func _build_smart_tray() -> void:
	smart_tray = Panel.new()
	smart_tray.name = "QuickToolSlider"
	smart_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smart_tray.add_theme_stylebox_override("panel", SKIN.translucent_surface())
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
		SKIN.apply_translucent_button(row, "wood")
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
		row.add_theme_stylebox_override("normal", SKIN.translucent_surface(false, selected, true))
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

func _cycle_quick_tool() -> void:
	if game == null:
		return
	var owned: Array[String] = game.available_quick_tools()
	if owned.is_empty():
		return
	var index: int = (owned.find(str(game.active_quick_tool)) + 1) % owned.size()
	var item: String = owned[index]
	if game.select_quick_tool(item):
		_refresh_tool_swap_button()
		_refresh_smart_button()
		toast("Tool: " + item.replace("_", " ").capitalize())


func _refresh_tool_swap_button() -> void:
	if tool_swap_button == null or game == null:
		return
	var item: String = str(game.active_quick_tool)
	var icon: String = "axe" if item == "axe" else "pickaxe" if item == "pickaxe" else "sword" if item in ["training_blade", "iron_blade", "spear"] else "hand"
	var art: TextureRect = tool_swap_button.get_node_or_null("ActionIcon") as TextureRect
	var filename: String = ACTION_FRAME_ROOT + icon + ".svg"
	if art != null and (art.texture == null or art.texture.resource_path != filename):
		art.texture = load(filename) as Texture2D
	tool_swap_button.tooltip_text = "Swap tools (current: " + item.replace("_", " ").capitalize() + ")"
	var caption: Label = tool_swap_button.get_node_or_null("ActionLabel") as Label
	if caption != null:
		caption.text = "TOOLS"


func _handle_tool_swap_input(event: InputEvent) -> bool:
	if tool_swap_button == null or game == null:
		return false
	var bounds: Rect2 = tool_swap_button.get_global_rect().grow(4.0)
	if event is InputEventScreenTouch:
		if event.pressed and tool_swap_finger < 0 and bounds.has_point(event.position):
			tool_swap_finger = event.index
			tool_swap_origin = event.position
			get_viewport().set_input_as_handled()
			return true
		if not event.pressed and event.index == tool_swap_finger:
			tool_swap_finger = -1
			tool_swap_ignore_mouse_until = Time.get_ticks_msec() + 420
			if bounds.has_point(event.position) and event.position.distance_to(tool_swap_origin) < 35.0:
				_cycle_quick_tool()
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventScreenDrag and event.index == tool_swap_finger:
		get_viewport().set_input_as_handled()
		return true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < tool_swap_ignore_mouse_until:
			get_viewport().set_input_as_handled()
			return true
		if event.pressed and not tool_swap_mouse and bounds.has_point(event.position):
			tool_swap_mouse = true
			tool_swap_origin = event.position
			get_viewport().set_input_as_handled()
			return true
		if not event.pressed and tool_swap_mouse:
			tool_swap_mouse = false
			if bounds.has_point(event.position) and event.position.distance_to(tool_swap_origin) < 35.0:
				_cycle_quick_tool()
			get_viewport().set_input_as_handled()
			return true
	return false


func _handle_smart_input(event: InputEvent) -> bool:
	if smart_button == null or game == null:
		return false
	if (game.menu != null and game.menu.visible) or (game.coop != null and game.coop.ui != null and game.coop.ui.visible):
		_cancel_smart_hold()
		return false
	var bounds: Rect2 = smart_button.get_global_rect().grow(5.0)
	# A tap performs the action immediately. A hold repeats attacks/gathering.
	# Neither gesture opens the old Training Blade selector.
	if event is InputEventScreenTouch:
		if event.pressed and smart_hold_finger < 0 and not smart_hold_mouse and bounds.has_point(event.position):
			smart_hold_finger = event.index
			smart_hold_origin = event.position
			smart_hold_seconds = 0.0
			game.smart_interact()
			get_viewport().set_input_as_handled()
			return true
		if not event.pressed and event.index == smart_hold_finger:
			smart_ignore_mouse_until = Time.get_ticks_msec() + 420
			_cancel_smart_hold()
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventScreenDrag and event.index == smart_hold_finger:
		get_viewport().set_input_as_handled()
		return true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < smart_ignore_mouse_until:
			get_viewport().set_input_as_handled()
			return true
		if event.pressed and not smart_hold_mouse and smart_hold_finger < 0 and bounds.has_point(event.position):
			smart_hold_mouse = true
			smart_hold_origin = event.position
			smart_hold_seconds = 0.0
			game.smart_interact()
			get_viewport().set_input_as_handled()
			return true
		if not event.pressed and smart_hold_mouse:
			_cancel_smart_hold()
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventMouseMotion and smart_hold_mouse:
		get_viewport().set_input_as_handled()
		return true
	return false


func _handle_quest_input(event: InputEvent) -> bool:
	if quest_toggle == null or not quest_toggle.visible:
		return false
	var bounds: Rect2 = quest_toggle.get_global_rect().grow(5.0)
	if event is InputEventScreenTouch:
		if event.pressed and quest_touch_finger < 0 and bounds.has_point(event.position):
			quest_touch_finger = event.index
			quest_touch_origin = event.position
			get_viewport().set_input_as_handled()
			return true
		if not event.pressed and event.index == quest_touch_finger:
			quest_touch_finger = -1
			quest_ignore_mouse_until = Time.get_ticks_msec() + 420
			if bounds.has_point(event.position) and event.position.distance_to(quest_touch_origin) < 35.0:
				_toggle_quest()
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventScreenDrag and event.index == quest_touch_finger:
		get_viewport().set_input_as_handled()
		return true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < quest_ignore_mouse_until:
			get_viewport().set_input_as_handled()
			return true
		if event.pressed and not quest_mouse_down and bounds.has_point(event.position):
			quest_mouse_down = true
			quest_mouse_origin = event.position
			get_viewport().set_input_as_handled()
			return true
		if not event.pressed and quest_mouse_down:
			quest_mouse_down = false
			if bounds.has_point(event.position) and event.position.distance_to(quest_mouse_origin) < 35.0:
				_toggle_quest()
			get_viewport().set_input_as_handled()
			return true
	return false


func _refresh_smart_button() -> void:
	if game == null or smart_button == null:
		return
	var context: Dictionary = game.smart_context()
	var requested: String = str(context.get("icon", "hand"))
	if requested not in ["hand", "sword", "axe", "pickaxe"]:
		requested = "hand"
	var icon: TextureRect = smart_button.get_node_or_null("ActionIcon") as TextureRect
	if icon != null and requested != smart_icon_id:
		smart_icon_id = requested
		icon.texture = load(ACTION_FRAME_ROOT + requested + ".svg") as Texture2D
	var title: Label = smart_button.get_node_or_null("ActionLabel") as Label
	if title != null:
		title.text = ""
	var kind: String = str(context.get("kind", "none"))
	# When no action is in range, dim the Interact art but keep it receptive
	# to a tap as context changes. Tool selection uses its own button.
	_refresh_tool_swap_button()
	var time_left: float = game.attack_delay if kind == "attack" else game.gather_delay if kind == "gather" else 0.0
	var total: float = 0.55 if kind == "attack" else 0.33 if kind == "gather" else 1.0
	var available: bool = kind != "none" and time_left <= 0.0
	smart_button.modulate = Color.WHITE if available else Color("#858188")
	var ring: Control = smart_button.get_node_or_null("CooldownRing") as Control
	if ring != null:
		ring.call("set_cooldown", time_left, total)

func _toggle_quest() -> void:
	quest_expanded = not quest_expanded
	quest_detail_back.visible = quest_expanded
	quest_detail.visible = quest_expanded
	quest_toggle.text = "CLOSE ▴" if quest_expanded else "✓ QUESTS" if objective_is_complete else "QUESTS ▾"

func _quest_headline(objective: String) -> String:
	# The journal holds the complete objective. The playfield needs only
	# the first actionable clause (no permanently clipped prose).
	var headline: String = objective.strip_edges()
	for separator in [", then ", ",", " then ", ";"]:
		var position: int = headline.find(separator)
		if position > 0:
			headline = headline.substr(0, position).strip_edges()
			break
	return headline

func _update_quest_tracker(objective: String) -> void:
	var text_value: String = objective.strip_edges()
	var lower: String = text_value.to_lower()
	objective_is_complete = lower.contains("quest finished") or lower.contains("quest complete") or lower.contains("quest completed")
	var should_show: bool = not objective_is_complete and text_value != ""
	quest_frame.visible = should_show
	quest_rule.visible = should_show
	quest.visible = should_show
	quest.text = _quest_headline(text_value)
	quest_detail.text = "•  " + text_value if text_value != "" else "No active quest."
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

func _resolve_zone_name() -> String:
	if game == null:
		return ""
	var hero_ref: Node3D = game.get("hero") as Node3D
	if hero_ref == null:
		return ""
	var manager: Node = game.get_node_or_null("Dungeons")
	if manager != null and manager.get("active_instance") != null:
		var dungeon: Node = manager.get("active_instance") as Node
		if dungeon != null:
			return "DUNGEON · FLOOR %d" % int(dungeon.get("current_floor"))
		return "DUNGEON"
	var biome: Node = game.get_node_or_null("VoxelAtmosphere")
	return ZONE_NAMES.resolve(hero_ref.global_position, biome, false)

func _update_zone_state(delta: float) -> void:
	zone_poll_seconds += delta
	if zone_poll_seconds < 0.20:
		return
	var sampled: float = zone_poll_seconds
	zone_poll_seconds = 0.0
	var observed: String = _resolve_zone_name()
	if observed.is_empty() or observed == current_zone:
		candidate_zone = ""
		candidate_zone_seconds = 0.0
		return
	if observed != candidate_zone:
		candidate_zone = observed
		candidate_zone_seconds = 0.0
	else:
		candidate_zone_seconds += sampled
	if candidate_zone_seconds >= 0.40:
		_show_zone_name(candidate_zone)
		candidate_zone = ""
		candidate_zone_seconds = 0.0

func _show_zone_name(value: String) -> void:
	if value.is_empty() or zone_pill_text == null or value == current_zone:
		return
	var old_zone: String = current_zone
	current_zone = value
	zone_pill_text.text = value
	if not old_zone.is_empty():
		zone_banner.text = "ENTERING  ·  " + value
		zone_banner.visible = true
		zone_banner.modulate.a = 1.0
		zone_banner_seconds = 2.7

func _process(delta: float) -> void:
	_advance_loot_feed(delta)
	# MENU is now tap-to-open; holding is not required to interact.
	_update_zone_state(delta)
	if zone_banner_seconds > 0.0:
		zone_banner_seconds = maxf(0.0, zone_banner_seconds - delta)
		zone_banner.modulate.a = minf(1.0, zone_banner_seconds * 1.3)
		if zone_banner_seconds <= 0.0:
			zone_banner.visible = false
	if gesture_hint_timeout > 0.0:
		gesture_hint_timeout = maxf(0.0, gesture_hint_timeout - delta)
		if gesture_hint_timeout <= 0.0:
			if tool_gesture_hint != null:
				tool_gesture_hint.visible = false
			if camera_gesture_hint != null:
				camera_gesture_hint.visible = false
	# Holding Interact repeats real attacks/gathers through cooldown checks.
	# It no longer opens the Training Blade selector after 0.34 seconds.
	if (smart_hold_finger >= 0 or smart_hold_mouse) and game != null:
		smart_hold_seconds += delta
		if smart_hold_seconds >= 0.38:
			smart_hold_seconds = 0.16
			if str(game.smart_context().get("kind", "")) in ["attack", "gather"]:
				game.smart_interact()
	if camera_drag_finger >= 0 and not camera_hold_ready:
		camera_hold_seconds += delta
		if camera_hold_seconds >= 0.82:
			camera_hold_ready = true
	if (quick_hold_finger >= 0 or quick_hold_mouse) and not quick_tray_open:
		quick_hold_seconds += delta
		if quick_hold_seconds >= 0.36:
			_open_quick_tray()
	_position_stick()
	knob.position = (joystick.size - knob.size) * 0.5 + move_vector * 45.0 * movement_stick_scale
	gathered_update_delay += delta
	if gathered_update_delay >= 1.0:
		gathered_update_delay = 0.0
		if not gathered_entries.is_empty() and gathered_expanded:
			_refresh_gathered_card()
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast_label.text = ""
			toast_label.visible = false
			toast_panel.visible = false

func _position_stick() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if floating_joystick_enabled:
		joystick.visible = finger >= 0 or mouse_stick or (sticky_movement_enabled and move_vector.length_squared() > 0.001)
		return
	joystick.visible = true
	joystick.position = Vector2(26.0, screen.y - joystick.size.y - 29.0)

func _floating_zone(pos: Vector2) -> bool:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	return pos.x >= 8.0 and pos.x <= screen.x * 0.35 and pos.y >= screen.y * 0.35 and pos.y <= screen.y * 0.92

func _adaptive_stick_zone(pos: Vector2) -> bool:
	if floating_joystick_enabled or not adaptive_joystick_enabled:
		return false
	var screen: Vector2 = get_viewport().get_visible_rect().size
	return pos.x < screen.x * 0.35 and pos.y > screen.y * 0.35 and pos.distance_to(_center()) <= 162.0 * movement_stick_scale

func _start_adaptive_stick(pos: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = joystick.size.x * 0.5 + 8.0
	var target := Vector2(clampf(pos.x, margin, maxf(margin, screen.x * 0.35 - margin)),
			clampf(pos.y, screen.y * 0.38, screen.y - margin))
	joystick.position = target - joystick.size * 0.5

func _start_floating_stick(pos: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = joystick.size.x * 0.5 + 8.0
	var center: Vector2 = Vector2(clampf(pos.x, margin, maxf(margin, screen.x * 0.35 - margin)),
			clampf(pos.y, screen.y * 0.38, screen.y - margin))
	joystick.position = center - joystick.size * 0.5
	joystick.visible = true

func _center() -> Vector2:
	return joystick.get_global_rect().get_center()

func _top_chrome_button_at(pos: Vector2) -> Button:
	for control in [menu_button, wallet_bag]:
		if control != null and control.visible and not control.disabled and control.get_global_rect().has_point(pos):
			return control
	return null

func _activate_top_chrome(control: Button) -> void:
	if control == menu_button:
		_set_top_menu(not top_menu_open)
	elif control == wallet_bag:
		_bag()
	elif control == wallet_collapse:
		_toggle_wallet()

func _handle_top_chrome_input(event: InputEvent) -> bool:
	# Top bar actions are fired on the FIRST finger DOWN, never after a
	# release which Android's GUI can consume. Finger-up and synthetic
	# mouse events are swallowed, including after MENU opens its modal.
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and top_chrome_finger < 0:
			var action: Button = _top_chrome_button_at(touch.position)
			if action == null:
				return false
			top_chrome_finger = touch.index
			top_chrome_candidate = action
			top_chrome_origin = touch.position
			top_chrome_ignore_mouse_until = Time.get_ticks_msec() + 450
			get_viewport().set_input_as_handled()
			_activate_top_chrome(action)
			return true
		if not touch.pressed and touch.index == top_chrome_finger:
			top_chrome_finger = -1
			top_chrome_candidate = null
			top_chrome_ignore_mouse_until = Time.get_ticks_msec() + 450
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventScreenDrag:
		var motion: InputEventScreenDrag = event
		if motion.index == top_chrome_finger:
			if motion.position.distance_to(top_chrome_origin) >= 42.0:
				top_chrome_candidate = null
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click: InputEventMouseButton = event
		if Time.get_ticks_msec() < top_chrome_ignore_mouse_until:
			get_viewport().set_input_as_handled()
			return true
		if click.pressed:
			var action: Button = _top_chrome_button_at(click.position)
			if action == null:
				return false
			top_chrome_mouse_down = true
			top_chrome_mouse_candidate = action
			top_chrome_mouse_origin = click.position
			get_viewport().set_input_as_handled()
			_activate_top_chrome(action)
			return true
		if top_chrome_mouse_down:
			top_chrome_mouse_down = false
			top_chrome_mouse_candidate = null
			get_viewport().set_input_as_handled()
			return true
	return false

func _touch_menu_navigation(event: InputEvent) -> bool:
	if game == null or (game.menu != null and game.menu.visible):
		return false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		if not (event as InputEventScreenTouch).pressed:
			return false
		pos = (event as InputEventScreenTouch).position
		ignore_menu_synthetic_mouse_until = Time.get_ticks_msec() + 280
	elif event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
			return false
		if Time.get_ticks_msec() < ignore_menu_synthetic_mouse_until:
			return false
		pos = (event as InputEventMouseButton).position
	else:
		return false
	# Process at root input stage because on Android decorative fullscreen
	# Control children can otherwise intercept the actual UI Button signal.
	if gathered_collapse != null and gathered_collapse.visible and gathered_collapse.get_global_rect().has_point(pos):
		_toggle_gathered()
		get_viewport().set_input_as_handled()
		return true
	# Top MENU/WALLET/BAG are handled on matching touch RELEASE above.
	if top_menu_open:
		for action in top_menu_actions:
			if action.visible and action.get_global_rect().has_point(pos):
				action.pressed.emit()
				get_viewport().set_input_as_handled()
				return true
	return false

func _game_menu_button_at(pos: Vector2) -> Button:
	if top_menu_close_button != null and top_menu_close_button.visible and top_menu_close_button.get_global_rect().has_point(pos):
		return top_menu_close_button
	for option in top_menu_actions:
		if option.visible and not option.disabled and option.get_global_rect().has_point(pos):
			return option
	return null

func _handle_game_menu_input(event: InputEvent) -> void:
	# Consume before any button can launch a new scene or modal.
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		_set_top_menu(false)
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and top_menu_touch_finger < 0:
			top_menu_touch_finger = touch.index
			top_menu_touch_origin = touch.position
			top_menu_touch_candidate = _game_menu_button_at(touch.position)
		elif not touch.pressed and touch.index == top_menu_touch_finger:
			var pressed_action: Button = top_menu_touch_candidate
			var activate: bool = pressed_action != null and pressed_action == _game_menu_button_at(touch.position) and touch.position.distance_to(top_menu_touch_origin) < 40.0
			var outside: bool = not top_menu_panel.get_global_rect().has_point(touch.position)
			top_menu_touch_finger = -1
			top_menu_touch_candidate = null
			leave_ignore_synthetic_mouse_until = Time.get_ticks_msec() + 360
			if activate:
				pressed_action.pressed.emit()
			# No outside-release dismissal: Android may deliver opening touch-up
			# to the shade, which previously closed MENU immediately.
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == top_menu_touch_finger and drag.position.distance_to(top_menu_touch_origin) >= 40.0:
			top_menu_touch_candidate = null
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() >= leave_ignore_synthetic_mouse_until:
			if click.pressed:
				top_menu_mouse_down = true
				top_menu_mouse_origin = click.position
				top_menu_mouse_candidate = _game_menu_button_at(click.position)
			elif top_menu_mouse_down:
				var pressed_action: Button = top_menu_mouse_candidate
				var activate: bool = pressed_action != null and pressed_action == _game_menu_button_at(click.position) and click.position.distance_to(top_menu_mouse_origin) < 40.0
				var outside: bool = not top_menu_panel.get_global_rect().has_point(click.position)
				top_menu_mouse_down = false
				top_menu_mouse_candidate = null
				if activate:
					pressed_action.pressed.emit()
				# Ignore outside mouse release; close using X, Back or an action.
 
func _input(event: InputEvent) -> void:
	if skill_detail_panel != null and skill_detail_panel.visible:
		_handle_skill_details_input(event)
		return
	# A touch that just closed Skills can echo as an Android synthetic mouse
	# event; never let that echo activate a skill/action underneath.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() < skills_ignore_mouse_until:
		get_viewport().set_input_as_handled()
		return
	if control_settings_panel != null and control_settings_panel.visible:
		_handle_settings_touch(event)
		return
	# Leave-game has priority over every gameplay and synthetic UI event.
	if leave_menu_panel != null and leave_menu_panel.visible:
		_handle_leave_menu_input(event)
		return
	# The finger that OPENED MENU must finish its own release without
	# being seen as an outside click that immediately closes the new modal.
	if top_chrome_finger >= 0 and event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed and (event as InputEventScreenTouch).index == top_chrome_finger:
		_handle_top_chrome_input(event)
		return
	if top_chrome_mouse_down and event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		_handle_top_chrome_input(event)
		return
	# A synthetic mouse press/release can arrive AFTER first-touch MENU opens.
	# Consume that echo BEFORE the modal's outside-click handler sees it,
	# otherwise the new modal closes instantly and seems to need a double tap.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() < top_chrome_ignore_mouse_until:
		get_viewport().set_input_as_handled()
		return
	if top_menu_open:
		_handle_game_menu_input(event)
		return
	# Android can echo a mouse click after lifting the finger that dismissed
	# a modal. Never let this click strike a gameplay skill underneath.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() < leave_ignore_synthetic_mouse_until:
		get_viewport().set_input_as_handled()
		return
	if _handle_top_chrome_input(event):
		return
	if _handle_quest_input(event):
		return
	if _handle_tool_swap_input(event):
		return
	if _handle_loot_tooltip_input(event):
		return
	if _touch_menu_navigation(event):
		return
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
	# Detect a short tap on a projected Crafting Station; long drags still
	# orbit the camera. Never steal the fixed/dynamic thumbstick or UI taps.
	if event is InputEventScreenTouch and game != null:
		if event.pressed and station_touch_finger < 0 and event.index != finger and _can_start_camera_drag(event.position):
			var candidate: String = game.station_at_screen(event.position)
			if not candidate.is_empty():
				station_touch_finger = event.index
				station_touch_name = candidate
				station_touch_start = event.position
		elif not event.pressed and event.index == station_touch_finger:
			var station_name: String = station_touch_name
			var is_tap: bool = event.position.distance_to(station_touch_start) < 17.0
			station_touch_finger = -1
			station_touch_name = ""
			if is_tap and not station_name.is_empty():
				camera_drag_finger = -1
				camera_hold_ready = false
				game.visit_crafting_station(station_name)
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventScreenDrag and event.index == station_touch_finger:
		if event.position.distance_to(station_touch_start) >= 17.0:
			station_touch_finger = -1
			station_touch_name = ""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and game != null:
		if event.pressed and not mouse_stick and _can_start_camera_drag(event.position):
			station_mouse_candidate = game.station_at_screen(event.position)
			station_mouse_start = event.position
		elif not event.pressed:
			var name_on_release: String = station_mouse_candidate
			station_mouse_candidate = ""
			if not name_on_release.is_empty() and event.position.distance_to(station_mouse_start) < 17.0:
				game.visit_crafting_station(name_on_release)
				get_viewport().set_input_as_handled()
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
		# A deliberate free-world swipe orbits immediately, while small finger
		# jitter is ignored. The previous implementation cancelled the gesture
		# once it passed 26 px before a 0.82s hold, making orbit feel broken.
		# Holding still continues to enable precision dragging.
		if not camera_hold_ready and event.position.distance_to(camera_hold_origin) >= 16.0:
			camera_hold_ready = true
		if camera_hold_ready:
			game.drag_camera(event.screen_relative.x)
		return
	elif event is InputEventMouseMotion and game != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if _can_start_camera_drag(event.position):
			game.drag_camera(event.relative.x)
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and ((floating_joystick_enabled and _floating_zone(event.position)) or (not floating_joystick_enabled and (event.position.distance_to(_center()) < 104.0 * movement_stick_scale or _adaptive_stick_zone(event.position)))):
			finger = event.index
			mouse_stick = false
			if floating_joystick_enabled:
				_start_floating_stick(event.position)
			elif adaptive_joystick_enabled:
				_start_adaptive_stick(event.position)
			_stick(event.position)
		elif not event.pressed and event.index == finger:
			_end_movement_touch()
	elif event is InputEventScreenDrag and event.index == finger:
		_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and finger == -1 and ((floating_joystick_enabled and _floating_zone(event.position)) or (not floating_joystick_enabled and (event.position.distance_to(_center()) < 104.0 * movement_stick_scale or _adaptive_stick_zone(event.position)))):
			mouse_stick = true
			if floating_joystick_enabled:
				_start_floating_stick(event.position)
			elif adaptive_joystick_enabled:
				_start_adaptive_stick(event.position)
			_stick(event.position)
		elif not event.pressed and mouse_stick and finger == -1:
			_end_movement_touch()
	elif event is InputEventMouseMotion and mouse_stick and finger == -1:
		_stick(event.position)

func _end_movement_touch() -> void:
	finger = -1
	mouse_stick = false
	if not sticky_movement_enabled:
		move_vector = Vector2.ZERO
	_position_stick()
	if stop_sticky_button != null:
		stop_sticky_button.visible = sticky_movement_enabled and move_vector.length_squared() > 0.001

func _stop_sticky_movement() -> void:
	move_vector = Vector2.ZERO
	if stop_sticky_button != null:
		stop_sticky_button.visible = false
	_position_stick()

func _reset_touch() -> void:
	_cancel_smart_hold()
	_cancel_quick_hold()
	tool_swap_finger = -1
	tool_swap_mouse = false
	quest_touch_finger = -1
	quest_mouse_down = false
	camera_drag_finger = -1
	camera_hold_seconds = 0.0
	camera_hold_ready = false
	station_touch_finger = -1
	station_touch_name = ""
	station_mouse_candidate = ""
	finger = -1
	mouse_stick = false
	move_vector = Vector2.ZERO
	if stop_sticky_button != null:
		stop_sticky_button.visible = false
	_position_stick()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_reset_touch()

func _stick(pos: Vector2) -> void:
	if floating_joystick_enabled:
		var travel: Vector2 = pos - _center()
		var radius: float = STICK_INPUT_RADIUS * movement_stick_scale
		if travel.length() > radius:
			joystick.position += travel.normalized() * (travel.length() - radius)
	move_vector = ((pos - _center()) / (STICK_INPUT_RADIUS * movement_stick_scale)).limit_length(1.0)

func set_trained_skill(skill_id: String, total_skill_xp: int) -> void:
	# Ring progress is real: 60 XP per gathering/weapon mastery rank.
	# Existing weapon mastery already uses these thresholds; no fake stats.
	if trained_skill_orb != null:
		trained_skill_orb.call("set_skill", skill_id, maxi(0, total_skill_xp))

func render_status(hp: float, inventory: Dictionary, xp: int, _kills: int, weapon: String, objective: String, helper: String) -> void:
	status.text = player_display_name
	health_numbers.visible = status_text_modes["health"] != "off"
	health_numbers.text = ("%d%%" % roundi(hp)) if status_text_modes["health"] == "percent" else "HP %d / 100" % int(ceilf(hp))
	if bag_weight_label != null and game != null:
		var max_load: float = maxf(1.0, game.bag_capacity())
		var current_load: float = game.bag_load()
		bag_weight_label.text = "BAG NEAR LIMIT  %.0f / %.0f" % [current_load, max_load]
		bag_weight_label.visible = current_load >= max_load * 0.85
		bag_weight_label.add_theme_color_override("font_color", Color("#e99075") if current_load >= max_load else Color("#e3b75d"))
	hero_detail.visible = false
	if game != null and xp_level_label != null:
		var level_data: Dictionary = game.level_state()
		var rank: int = int(level_data.get("level", 1))
		var required: float = maxf(1.0, float(level_data.get("required", 100)))
		xp_bar.value = clampf(float(level_data.get("current", 0)) * 100.0 / required, 0.0, 100.0)
		var current_xp: int = int(level_data.get("current", 0))
		var required_xp: int = maxi(1, roundi(required))
		xp_level_label.visible = status_text_modes["xp"] != "off"
		xp_level_label.text = ("%d%%" % roundi(xp_bar.value)) if status_text_modes["xp"] == "percent" else "%d / %d" % [current_xp, required_xp]

		xp_level_badge.text = str(rank)
		if radial_level != null:
			radial_level.call("update_level", rank, xp_bar.value / 100.0)
		status.text = player_display_name
		_refresh_quick_radials()
	health_bar.value = clampf(hp, 0.0, 100.0)
	if game != null and mana_bar != null:
		var available_mana: float = clampf(float(game.mana), 0.0, float(game.mana_limit()))
		mana_bar.max_value = float(game.mana_limit())
		mana_bar.value = available_mana
		mana_numbers.visible = status_text_modes["mana"] != "off"
		mana_numbers.text = ("%d%%" % roundi(mana_bar.value * 100.0 / maxf(1.0, mana_bar.max_value))) if status_text_modes["mana"] == "percent" else "MP %d / %d" % [ceili(available_mana), roundi(float(game.mana_limit()))]
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
	_set_top_menu(false)
	if game != null and game.coop != null and game.coop.ui != null:
		game.coop.ui.open()

func _gather() -> void:
	game.gather()
func _attack() -> void:
	game.attack()
func _craft() -> void:
	_set_top_menu(false)
	game.craft()
func _bag() -> void:
	game.show_inventory()
func _gear() -> void:
	_set_top_menu(false)
	game.show_equipment()
func _use_skill(index: int) -> void:
	if game != null:
		game.use_weapon_skill(index)
