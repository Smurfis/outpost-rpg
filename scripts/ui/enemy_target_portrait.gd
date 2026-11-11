extends Control
## Live, touch-transparent enemy target display, deliberately modelled after
## the player's circular portrait and compact HP/name stack.
## Rarity comes from actual enemy data, NEVER from arbitrary spawn proximity.
const BOAR_ART: Texture2D = preload("res://assets/ui/icons/enemy_boar_portrait.svg")
const UNKNOWN_ART: Texture2D = preload("res://assets/ui/icons/enemy_unknown_portrait.svg")
const PORTRAIT_MASK: Shader = preload("res://assets/ui/icons/portrait_circle.gdshader")
const RARITY_COLORS: Dictionary = {
    "normal": Color("#9a8a81"),
    "rare": Color("#c7d6e5"),
    "elite": Color("#efbe68"),
}
var current_target: Node
var displayed_rarity: String = "normal"
var portrait_art: TextureRect
var portrait_frame: Panel
var portrait_inner_ring: Panel
var name_label: Label
var rarity_label: Label
var level_label: Label
var health_bar: ProgressBar
var health_label: Label

func _ready() -> void:
    name = "EnemyTargetHUD"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    portrait_art = TextureRect.new()
    portrait_art.name = "EnemyPortraitImage"
    portrait_art.texture = UNKNOWN_ART
    portrait_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    portrait_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mask := ShaderMaterial.new()
    mask.shader = PORTRAIT_MASK
    portrait_art.material = mask
    add_child(portrait_art)
    portrait_inner_ring = Panel.new()
    portrait_inner_ring.name = "EnemyPortraitInnerRing"
    portrait_inner_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(portrait_inner_ring)
    portrait_frame = Panel.new()
    portrait_frame.name = "EnemyPortraitFrame"
    portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(portrait_frame)
    name_label = _make_label("EnemyName", 18, Color("#f7e9ce"))
    name_label.clip_text = true
    name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    name_label.add_theme_color_override("font_outline_color", Color("#1c1518"))
    name_label.add_theme_constant_override("outline_size", 2)
    level_label = _make_label("EnemyLevel", 11, Color("#deccb3"))
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    rarity_label = _make_label("EnemyRarity", 11, Color("#c7d6e5"))
    rarity_label.text = ""
    health_bar = ProgressBar.new()
    health_bar.name = "EnemyHealthBar"
    health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    health_bar.show_percentage = false
    health_bar.min_value = 0.0
    health_bar.max_value = 100.0
    health_bar.value = 100.0
    var track := StyleBoxFlat.new()
    track.bg_color = Color(0.12, 0.08, 0.10, 0.65)
    track.border_color = Color(0.69, 0.42, 0.37, 0.60)
    track.set_border_width_all(1)
    track.set_corner_radius_all(3)
    health_bar.add_theme_stylebox_override("background", track)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color("#b94443")
    fill.set_corner_radius_all(2)
    health_bar.add_theme_stylebox_override("fill", fill)
    add_child(health_bar)
    health_label = _make_label("EnemyHealthText", 12, Color("#fff0df"))
    health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    health_label.add_theme_color_override("font_outline_color", Color("#1c1013"))
    health_label.add_theme_constant_override("outline_size", 1)
    _apply_rarity("normal")
    resized.connect(_reflow)
    call_deferred("_reflow")

func _make_label(id: String, font_size: int, tint: Color) -> Label:
    var result := Label.new()
    result.name = id
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result.add_theme_font_size_override("font_size", font_size)
    result.add_theme_color_override("font_color", tint)
    result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    add_child(result)
    return result

func _style_ring(tint: Color, width: int, alpha: float) -> StyleBoxFlat:
    var ring := StyleBoxFlat.new()
    ring.bg_color = Color(0.08, 0.07, 0.09, 0.06)
    ring.border_color = Color(tint.r, tint.g, tint.b, alpha)
    ring.set_border_width_all(width)
    ring.set_corner_radius_all(100)
    ring.set_content_margin_all(0)
    ring.anti_aliasing = true
    return ring

func _apply_rarity(rarity: String) -> void:
    displayed_rarity = rarity if RARITY_COLORS.has(rarity) else "normal"
    var tint: Color = RARITY_COLORS[displayed_rarity]
    if portrait_frame == null:
        return
    portrait_frame.add_theme_stylebox_override("panel", _style_ring(tint, 4, 1.0))
    portrait_inner_ring.add_theme_stylebox_override("panel", _style_ring(tint.lightened(0.15), 1, 0.70))
    name_label.add_theme_color_override("font_color", tint if displayed_rarity != "normal" else Color("#f7e9ce"))
    rarity_label.add_theme_color_override("font_color", tint)
    rarity_label.text = displayed_rarity.to_upper() if displayed_rarity != "normal" else ""

func _field(target: Node, field_name: String) -> Variant:
    # Calling Object.get() on a missing script property logs an error in Godot.
    for descriptor in target.get_property_list():
        if str(descriptor.get("name", "")) == field_name:
            return target.get(field_name)
    if target.has_meta(field_name):
        return target.get_meta(field_name)
    return null

func _health_value(target: Node, choices: Array[String]) -> float:
    for key in choices:
        var candidate: Variant = _field(target, key)
        if candidate is float or candidate is int:
            return maxf(0.0, float(candidate))
    return -1.0

func _rarity_for(target: Node) -> String:
    if target.is_in_group("elite_enemies"):
        return "elite"
    if target.is_in_group("rare_enemies"):
        return "rare"
    for field_name in ["enemy_rarity", "rarity", "rarity_tier"]:
        var value: Variant = _field(target, field_name)
        if value is String and str(value).to_lower() in ["normal", "rare", "elite"]:
            return str(value).to_lower()
    return "normal"

func set_target(target: Node, label_text: String = "") -> void:
    if not is_instance_valid(target) or target == null or not target.is_inside_tree():
        clear_target()
        return
    var target_visible: Variant = _field(target, "visible")
    if target_visible is bool and not bool(target_visible):
        clear_target()
        return
    var alive: Variant = _field(target, "alive")
    if alive is bool and not bool(alive):
        clear_target()
        return
    var hp: float = _health_value(target, ["hp", "health", "current_health"])
    if hp == 0.0:
        clear_target()
        return
    if current_target != target:
        current_target = target
        portrait_art.texture = BOAR_ART if target.is_in_group("wild_boars") else UNKNOWN_ART
        var custom_icon: Variant = _field(target, "enemy_portrait")
        if custom_icon is Texture2D:
            portrait_art.texture = custom_icon
    var rarity: String = _rarity_for(target)
    if rarity != displayed_rarity:
        _apply_rarity(rarity)
    name_label.text = label_text if not label_text.strip_edges().is_empty() else target.name.replace("_", " ").capitalize()
    var level: Variant = _field(target, "level")
    level_label.visible = (level is int or level is float) and int(level) > 0
    level_label.text = "LV %d" % int(level) if level_label.visible else ""
    var maximum: float = _health_value(target, ["max_hp", "max_health", "maximum_health"])
    var hp_known: bool = hp >= 0.0 and maximum > 0.0
    health_bar.visible = hp_known
    health_label.visible = hp >= 0.0
    if hp_known:
        health_bar.max_value = maximum
        health_bar.value = clampf(hp, 0.0, maximum)
        health_label.text = "%d / %d HP" % [ceili(hp), ceili(maximum)]
    elif hp >= 0.0:
        health_label.text = "%d HP" % ceili(hp)
    visible = true

func clear_target() -> void:
    current_target = null
    visible = false

func _put(c: Control, px: Rect2, factor: float) -> void:
    if c != null:
        c.position = px.position * factor
        c.size = px.size * factor

func _reflow() -> void:
    if size.y <= 0.0:
        return
    var factor: float = size.y / 84.0
    _put(portrait_art, Rect2(7, 9, 68, 68), factor)
    _put(portrait_inner_ring, Rect2(4, 6, 74, 74), factor)
    _put(portrait_frame, Rect2(0, 2, 82, 82), factor)
    _put(name_label, Rect2(93, 7, 179, 29), factor)
    _put(level_label, Rect2(278, 8, 42, 27), factor)
    _put(health_bar, Rect2(93, 38, 222, 23), factor)
    _put(health_label, Rect2(97, 39, 212, 21), factor)
    _put(rarity_label, Rect2(95, 63, 165, 18), factor)
