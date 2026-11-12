extends Control
## One fixed, Diablo-style target frame. Its backing, name and red health
## meter stay in screen space; no mob-following labels or damage text spam.
## Built from stock Godot controls for GL Compatibility on Android.
var backing: Panel
var name_label: RichTextLabel
var _name_markup: String = ""
var rank_label: Label
var accent_rule: ColorRect
var bar: ProgressBar
var damage_trail: ProgressBar
var _target_id: int = -1
var _wanted_percent: float = 100.0
var _accent: Color = Color("#987b60")

func _ready() -> void:
	name = "EnemyTargetFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	backing = Panel.new()
	backing.name = "TargetCarvedBacking"
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	_rect(backing, 0.0, 0.0, 1.0, 1.0)
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.055, 0.047, 0.055, 0.89)
	shell.border_color = _accent
	shell.set_border_width_all(2)
	shell.set_corner_radius_all(4)
	shell.shadow_color = Color(0.02, 0.015, 0.02, 0.6)
	shell.shadow_size = 5
	shell.set_content_margin_all(0)
	backing.add_theme_stylebox_override("panel", shell)
	# Rich text colours each affix separately, with the base creature
	# name inheriting its dungeon rarity even when multiple affixes roll.
	name_label = RichTextLabel.new()
	name_label.name = "TargetCreatureName"
	name_label.bbcode_enabled = true
	name_label.scroll_active = false
	name_label.selection_enabled = false
	name_label.fit_content = false
	name_label.clip_contents = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.add_theme_font_size_override("normal_font_size", 19)
	name_label.add_theme_color_override("default_color", Color("#f8ecdb"))
	name_label.add_theme_color_override("font_outline_color", Color("#170f10"))
	name_label.add_theme_constant_override("outline_size", 2)
	add_child(name_label)
	_rect(name_label, 0.06, 0.08, 0.94, 0.48)
	rank_label = Label.new()
	rank_label.name = "TargetCreatureRank"
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_label.add_theme_font_size_override("font_size", 11)
	rank_label.add_theme_color_override("font_color", Color("#dbbd8d"))
	rank_label.add_theme_color_override("font_outline_color", Color("#130d0b"))
	rank_label.add_theme_constant_override("outline_size", 1)
	rank_label.visible = false
	add_child(rank_label)
	_rect(rank_label, 0.77, 0.09, 0.96, 0.47)
	accent_rule = ColorRect.new()
	accent_rule.name = "TargetAccentRule"
	accent_rule.color = _accent
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent_rule)
	_rect(accent_rule, 0.05, 0.49, 0.95, 0.51)
	# Both meters are built once. The rear meter lags behind recent damage;
	# the inner red meter always represents actual mob HP.
	damage_trail = _create_meter("TargetDamageTrail", Color("#9b6b50"), true)
	bar = _create_meter("TargetHealthBar", Color("#ba262e"), false)
	_rect(damage_trail, 0.055, 0.59, 0.945, 0.86)
	_rect(bar, 0.055, 0.59, 0.945, 0.86)
	hide()

func _rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

func _create_meter(id: String, fill_color: Color, background: bool) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.name = id
	meter.show_percentage = false
	meter.min_value = 0.0
	meter.max_value = 100.0
	meter.value = 100.0
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color("#120b11") if background else Color(0, 0, 0, 0)
	empty.set_border_width_all(0)
	empty.set_content_margin_all(0)
	meter.add_theme_stylebox_override("background", empty)
	var colored := StyleBoxFlat.new()
	colored.bg_color = fill_color
	colored.set_border_width_all(0)
	colored.set_content_margin_all(0)
	meter.add_theme_stylebox_override("fill", colored)
	add_child(meter)
	return meter

## Render only real affix prefixes from authoritative combat data; never
## colour the entire label using just the last rolled affix.
func _set_coloured_name(caption: String, rarity_color: Color, affixes: Array) -> void:
	var remainder: String = caption
	var segments: PackedStringArray = []
	for descriptor in affixes:
		if not (descriptor is Dictionary):
			continue
		var affix_name: String = str(descriptor.get("text", "")).strip_edges()
		var affix_color: Variant = descriptor.get("color", rarity_color)
		if affix_name.is_empty() or not (affix_color is Color):
			continue
		# Only peel genuine prefixes; retain custom or renamed mob text.
		if remainder.begins_with(affix_name + " "):
			var shade: Color = affix_color
			segments.append("[color=#%s]%s[/color]" % [
				shade.to_html(false), affix_name.replace("[", "[lb]")])
			remainder = remainder.substr(affix_name.length() + 1)
	segments.append("[color=#%s]%s[/color]" % [
		rarity_color.to_html(false), remainder.replace("[", "[lb]")])
	var markup: String = "[center]%s[/center]" % " ".join(segments)
	if markup != _name_markup:
		_name_markup = markup
		name_label.text = markup

func show_target(target_id: int, caption: String, hp: float, max_hp: float, rank: String, accent: Color,
		rarity_name_color: Color = Color("#f8ecdb"), affixes: Array = []) -> void:
	if max_hp <= 0.0 or target_id <= 0:
		clear_target()
		return
	var fresh: bool = _target_id != target_id
	_target_id = target_id
	_wanted_percent = clampf(100.0 * hp / max_hp, 0.0, 100.0)
	_set_coloured_name(caption, rarity_name_color, affixes)
	rank_label.text = rank
	rank_label.visible = not rank.is_empty()
	name_label.anchor_right = 0.78 if rank_label.visible else 0.94
	if accent != _accent:
		_accent = accent
		accent_rule.color = accent
		(backing.get_theme_stylebox("panel") as StyleBoxFlat).border_color = accent
		rank_label.add_theme_color_override("font_color", accent.lightened(0.18))
	if fresh:
		bar.value = _wanted_percent
		damage_trail.value = _wanted_percent
	elif _wanted_percent > bar.value:
		# No false delayed-damage stripe when the target heals.
		damage_trail.value = _wanted_percent
	show()

func clear_target() -> void:
	_target_id = -1
	hide()

func _process(delta: float) -> void:
	if not visible:
		return
	bar.value = move_toward(bar.value, _wanted_percent, delta * 160.0)
	if damage_trail.value < bar.value:
		damage_trail.value = bar.value
	else:
		damage_trail.value = move_toward(damage_trail.value, bar.value, delta * 24.0)
