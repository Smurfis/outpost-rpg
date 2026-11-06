extends Control
## Fully standalone Outpost title menu (Godot 4.7.x / Android landscape).
## The PNG artwork is optional until final art sign-off; transparent SVG placeholders render without it.
const DESIGN := Vector2(1280.0, 720.0)
# Preserve the hand-painted middle of the image; stretch only scenery at the edges.
const WIDE_LEFT_CUT := 320.0
const WIDE_RIGHT_CUT := 1120.0
const MAIN_GAME := "res://scenes/main.tscn"
const WORLD_LOADING := "res://scenes/ui/world_loading.tscn"
const SAVE_PATH := "user://outpost_progress_v02.json"
const UI_PREFS := "user://outpost_ui.cfg"
const APPROVED_RASTER := "res://assets/ui/title/title_background.png"
const APPROVED_LOGO := "res://assets/ui/title/outpost_logo.png"
const BAKED_VERSION_ART := "res://assets/ui/title/version_badge_original.png"
const BUTTON_SCENE := preload("res://scenes/ui/title_menu_button.tscn")
const LOGO_SCENE := preload("res://scenes/ui/title_logo.tscn")
const SPLASH_SCENE := preload("res://scenes/ui/title_splash.tscn")
const EMBER_SCRIPT := preload("res://scripts/ui/title_embers.gd")
const ANDROID_UPDATER := preload("res://scripts/ui/android_updater.gd")
const SKIN := preload("res://scripts/ui/outpost_skin.gd")
const CREST_BLEND := preload("res://assets/ui/title/crest_edge_blend.gdshader")
const TIPS := [
	"Tip: Gather wood and stone before visiting the workbench.",
	"Tip: Equipped tools increase your harvest from the right resources.",
	"Tip: Smelt iron at the forge before crafting stronger equipment.",
	"Tip: Switch weapons and armour through the BAG and GEAR screens.",
	"Tip: Workbenches turn simple resources into useful equipment.",
	"Tip: A shield reduces incoming damage but occupies your off-hand.",
	"Tip: A torch shares the off-hand slot with your shield.",
	"Tip: Keep a torch handy before the light begins to fade.",
	"Tip: The Fields stretch beyond the clearing. Bring supplies.",
	"Tip: Portals lead to dungeons. Prepare your gear before entering.",
	"Tip: A cloak can help you travel through the world a little faster.",
	"Tip: Harvestable trees and ore deposits recover after a while.",
	"Tip: Search near cliffs and paths for stone, ore and plants.",
	"Tip: Stock up on herbs, berries and mushrooms while exploring.",
	"Tip: Your bag has a carry limit. Upgrade it before a long expedition.",
	"Tip: Gather materials first, then load a recipe at its crafting station.",
	"Tip: Finish the station's work actions to complete crafting.",
	"Tip: Keep an eye on enemy movement before closing the distance.",
	"Tip: A forged blade is a useful upgrade over your starting weapon.",
	"Tip: Your gathering, crafting and combat all help your adventure grow.",
	"Tip: Try rotating the camera to see what's hidden behind the trees.",
	"Tip: On a keyboard, press E to interact and C to open crafting.",
	"Tip: A brighter campfire makes the night feel less lonely.",
	"Tip: Every outpost begins with one small shelter and a little hope.",
	"Tip: The purple glow on the horizon may hide a dungeon entrance.",
	"Tip: What you craft today may save you when night falls.",
	"Tip: Take time to explore. Not every reward is found in a fight.",
	"Tip: However dark the world gets, you are its light.",
	"Tip: Keep the campfire burning — Chloe and Iyla need a safe outpost after dark."
]
var _canvas: Control
var _approved_backdrop: TextureRect
var _wide_backdrop: Control
var _previous_window_aspect: int = -1
var _splash: Label
var _tip_text: Label
var _tip_plaque: TextureRect
var _light_layer: TextureRect
var _embers: Control
var _ambient_elapsed: float = 0.0
var _approved_art: bool = false
var _continue_button: Button
var _settings_panel: PanelContainer
var _adventure_panel: PanelContainer
var _adventure_dim: ColorRect
var _adventure_name: LineEdit
var _adventure_ip: LineEdit
var _adventure_feedback: Label
var _adventure_heading: Label
var _new_adventure_pending: bool = true
var _volume: float = 0.85
var _download_button: Button
var _updater: Node
var _update_button: Button
var _update_status: Label
var _update_notice: Button
var _update_download_url: String = ""
var _selected_channel: String = ""
var _channel_stable_button: Button
var _channel_alpha_button: Button
var _channel_note: Label
var _changelog_button: Button
var _changelog_panel: PanelContainer
var _selection_glow: TextureRect
var _show_tips := true
var _reduced_motion := false
var _tip_index := 0
var _tip_elapsed := 0.0
const TIP_CYCLE_SECONDS: float = 9.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_approved_art = ResourceLoader.exists(APPROVED_RASTER) and ResourceLoader.exists(APPROVED_LOGO)
	if _approved_art:
		# Godot defaults to 16:9 pillarboxing. Expand ONLY while the title is open:
		# gameplay/world-loading/HUD retain their previous aspect behaviour.
		var window: Window = get_window()
		_previous_window_aspect = window.content_scale_aspect
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var had_preferences: bool = FileAccess.file_exists(UI_PREFS)
	_read_prefs()
	_apply_volume()
	# The approved composition intentionally has no bottom tip plaque.
	# Keep tips fully available in Settings, but default them off on first launch.
	if _approved_art and not had_preferences:
		_show_tips = false
	# Pick a different opening tip each session; every tip remains in the rotation.
	_tip_index = randi_range(0, TIPS.size() - 1)
	_make_screen()
	_layout()
	# The in-game exit panel can return straight here after saving.
	if bool(get_tree().root.get_meta("outpost_open_settings", false)):
		get_tree().root.remove_meta("outpost_open_settings")
		if _settings_panel != null:
			_settings_panel.visible = true
			_settings_panel.move_to_front()
	get_viewport().size_changed.connect(_layout)
	if OS.has_feature("Android") and _updater != null:
		# Passive, single startup check; only display a banner if there's
		# a newer signed APK. Never download or install automatically.
		_updater.check_for_updates.call_deferred()
	set_process(true)

func _exit_tree() -> void:
	# Scope aspect expansion to the title so the 3D game/HUD does not change.
	if _previous_window_aspect >= 0:
		get_window().content_scale_aspect = _previous_window_aspect

func _layout() -> void:
	_layout_for_size(get_viewport_rect().size)

func _layout_for_size(available: Vector2) -> void:
	# Public-sized seam for headless 16:9 and ultrawide layout regression tests.
	if _canvas == null or available.x <= 0.0 or available.y <= 0.0:
		return
	var fit: float = minf(available.x / DESIGN.x, available.y / DESIGN.y)
	_canvas.scale = Vector2.ONE * fit
	_canvas.position = (available - DESIGN * fit) * 0.5
	if _wide_backdrop == null or _approved_backdrop == null:
		return
	# Convert physical spare width back into 1280x720 design-space units.
	var half_extra: float = maxf(0.0, (available.x / fit - DESIGN.x) * 0.5)
	var is_wide: bool = half_extra > 0.5
	# The Android screenshot's lower-right grey area was the expanded edge
	# of the painted background. Anchor the actual version plaque to the
	# RIGHT of the full ultrawide view, instead of leaving it beside that area.
	# On 16:9 displays half_extra == 0, so the approved position is kept.
	var version_plaque: TextureRect = _canvas.get_node_or_null("VersionPlaque") as TextureRect
	var version_label: Label = _canvas.get_node_or_null("Version") as Label
	if version_plaque != null:
		version_plaque.position = Vector2(1058.0 + half_extra, 642.0)
	if version_label != null:
		version_label.position = Vector2(1068.0 + half_extra, 652.0)
	if _changelog_button != null:
		_changelog_button.position.x = 1164.0 + half_extra
	if _changelog_panel != null:
		_changelog_panel.position.x = 800.0 + half_extra
	_approved_backdrop.visible = not is_wide
	_wide_backdrop.visible = is_wide
	if not is_wide:
		return
	# Keep central x=320..1120 pixels exactly as approved so the tent logo,
	# all four button cutouts and their painted surroundings remain aligned.
	# Only side scenery expands into the additional phone-screen width.
	var left: TextureRect = _wide_backdrop.get_node("WideLeft") as TextureRect
	var center: TextureRect = _wide_backdrop.get_node("WideCenter") as TextureRect
	var right: TextureRect = _wide_backdrop.get_node("WideRight") as TextureRect
	left.position = Vector2(-half_extra, 0.0)
	left.size = Vector2(WIDE_LEFT_CUT + half_extra, DESIGN.y)
	center.position = Vector2(WIDE_LEFT_CUT, 0.0)
	center.size = Vector2(WIDE_RIGHT_CUT - WIDE_LEFT_CUT, DESIGN.y)
	right.position = Vector2(WIDE_RIGHT_CUT, 0.0)
	right.size = Vector2(DESIGN.x - WIDE_RIGHT_CUT + half_extra, DESIGN.y)

func _make_screen() -> void:
	var curtain := ColorRect.new()
	curtain.color = Color("151c32")
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)

	_canvas = Control.new()
	_canvas.name = "Artboard"
	_canvas.size = DESIGN
	add_child(_canvas)
	_add_image("Backdrop", "title_background.png", "title_backdrop.svg", Vector2.ZERO, DESIGN)
	_approved_backdrop = _canvas.get_node_or_null("Backdrop") as TextureRect
	if _approved_art and _approved_backdrop != null:
		_make_wide_background()
	# Independent light pass: campsite lanterns, fire, distant portal and waterfall.
	_add_image("TitleLights", "title_lights.png", "title_lights.svg", Vector2.ZERO, DESIGN)
	_light_layer = _canvas.get_node_or_null("TitleLights") as TextureRect
	_add_image("TitleFrame", "title_frame.png", "title_frame.svg", Vector2.ZERO, DESIGN)
	_add_image("LeftBanner", "banner_star.png", "banner_star.svg", Vector2(51, 17), Vector2(90, 115))
	_add_image("RightBanner", "banner_star.png", "banner_star.svg", Vector2(1140, 17), Vector2(90, 115))
	if _approved_art:
		# The PNG already has its wood/stone border and star banners; hiding
		# duplicate legacy SVG layers keeps the approved pixels intact.
		for decorative in ["TitleLights", "TitleFrame", "LeftBanner", "RightBanner"]:
			var old_overlay: Control = _canvas.get_node_or_null(decorative) as Control
			if old_overlay != null:
				old_overlay.visible = false
	
	var logo: Control = LOGO_SCENE.instantiate() as Control
	logo.name = "OutpostLogo"
	# Clear the .tscn's old 650×358 minimum BEFORE assigning approved dimensions;
	# otherwise Godot silently clamps the new size and wrecks pixel alignment.
	logo.custom_minimum_size = Vector2.ZERO
	_canvas.add_child(logo)
	logo.position = Vector2(416, 0) if _approved_art else Vector2(392, 8)
	logo.size = Vector2(438, 350) if _approved_art else Vector2(496, 330)
	if _approved_art:
		var edge_material := ShaderMaterial.new()
		edge_material.shader = CREST_BLEND
		logo.material = edge_material
	if _approved_art:
		# Cheap 2D ember glints over the real campsite and crest campfires.
		# Particles ignore mouse/touch and leave the button art untouched.
		_embers = EMBER_SCRIPT.new()
		_embers.name = "CampfireEmbers"
		_embers.size = DESIGN
		_embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_embers.set("reduced_motion", _reduced_motion)
		_canvas.add_child(_embers)

	_splash = SPLASH_SCENE.instantiate() as Label
	_splash.name = "UpdateSplash"
	# The standalone slogan scene had a 350px minimum width; remove it
	# before its first size assignment so the yellow PNG stays aligned.
	_splash.custom_minimum_size = Vector2.ZERO
	_canvas.add_child(_splash)
	# Keep rotating text entirely to the right of the painted crest.
	_splash.position = Vector2(903, 80) if _approved_art else Vector2(870, 92)
	_splash.size = Vector2(312, 129) if _approved_art else Vector2(365, 135)
	_splash.pivot_offset = _splash.size * 0.5
	if _reduced_motion:
		_splash.animate_bounce = false

	# A single independently authored soft gold glow moves between menu buttons.
	_selection_glow = TextureRect.new()
	_selection_glow.name = "SelectedTitleButtonGlow"
	_selection_glow.texture = load("res://assets/ui/title/button_selected_glow.svg") as Texture2D
	_selection_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selection_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_selection_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_glow.visible = false
	_canvas.add_child(_selection_glow)
	# Cutout positions use the source image's 1280x720 pixel coordinates.
	# These are REAL Button nodes: touch/focus, signals and disabled state survive.
	var approved_rects: Dictionary = {
		"play": Rect2(427, 344, 422, 92),
		"continue": Rect2(459, 430, 360, 79),
		"settings": Rect2(474, 504, 336, 76),
		"quit": Rect2(497, 575, 296, 76)
	}
	for i in range(4):
		var kind: String = ["play", "continue", "settings", "quit"][i]
		var b: Button = BUTTON_SCENE.instantiate() as Button
		b.name = kind.capitalize() + "Button"
		b.set("button_kind", kind)
		b.set("reduced_motion", _reduced_motion)
		var placement: Rect2 = approved_rects[kind] if _approved_art else Rect2(425, 342 + 79 * i, 430, 72)
		_canvas.add_child(b)
		# Button._ready() restores legacy 430×76 minimum; reset it before
		# assigning the exact PNG cutout's independent pixel footprint.
		b.custom_minimum_size = Vector2.ZERO
		b.position = placement.position
		b.size = placement.size
		b.custom_minimum_size = placement.size
		b.focus_entered.connect(_set_title_button_glow.bind(b))
		b.mouse_entered.connect(_set_title_button_glow.bind(b))
		b.focus_exited.connect(_hide_title_glow_if_idle)
		match kind:
			"play":
				b.pressed.connect(_on_play)
				b.grab_focus.call_deferred()
			"continue":
				_continue_button = b
				b.pressed.connect(_begin_continue)
			"settings":
				b.pressed.connect(_toggle_settings)
			"quit":
				b.pressed.connect(func() -> void: get_tree().quit())
	_continue_button.disabled = not _has_valid_save()

	# A single live version label over a matching textless PNG plaque.
	# _layout_for_size moves both to the actual ultrawide right edge.
	var live_version: String = "v" + str(ProjectSettings.get_setting("application/config/version", "0.5.0-dev")).trim_prefix("v")
	_add_image("VersionPlaque", "version_badge_textless.png", "version_badge.svg", Vector2(1058, 642), Vector2(203, 61))
	var version := Label.new()
	version.name = "Version"
	version.text = "%s  •  %d" % [live_version, int(ProjectSettings.get_setting("application/config/android_build_code", 11))]
	version.position = Vector2(1068, 652)
	version.size = Vector2(183, 40)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_style(version, 18, Color("fff1d5"), Color("2b1e25"))
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(version)

	_add_image("TipPlaque", "tip_panel.png", "tip_panel.svg", Vector2(247, 656), Vector2(785, 53))
	_tip_plaque = _canvas.get_node_or_null("TipPlaque") as TextureRect
	if _tip_plaque != null:
		_tip_plaque.visible = _show_tips
	_tip_text = Label.new()
	_tip_text.name = "WorldTip"
	_tip_text.position = Vector2(280, 662)
	_tip_text.size = Vector2(720, 41)
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.clip_text = true
	_tip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_text.text = TIPS[_tip_index]
	_tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_style(_tip_text, 17, Color("fff2cc"), Color("2b1a21"))
	_canvas.add_child(_tip_text)
	_tip_text.visible = _show_tips

	_build_settings()
	_build_adventure_panel()
	_build_changelog_scroll()
	_update_notice = Button.new()
	_update_notice.name = "UpdateAvailable"
	_update_notice.text = "OUTPOST UPDATE AVAILABLE"
	_update_notice.position = Vector2(912, 591)
	_update_notice.size = Vector2(314, 53)
	_update_notice.visible = false
	_update_notice.add_theme_font_size_override("font_size", 18)
	_update_notice.add_theme_color_override("font_color", Color("ffefbd"))
	var update_frame := StyleBoxFlat.new()
	update_frame.bg_color = Color("392833")
	update_frame.border_color = Color("f1bd69")
	update_frame.set_border_width_all(4)
	update_frame.set_corner_radius_all(7)
	_update_notice.add_theme_stylebox_override("normal", update_frame)
	_update_notice.pressed.connect(_check_or_download_update)
	_canvas.add_child(_update_notice)

func _make_wide_background() -> void:
	# Atlas slices use the SAME PNG as the approved screen, rather than a
	# duplicate image/blur that would break the source-matched art cutouts.
	_wide_backdrop = Control.new()
	_wide_backdrop.name = "WideBackdrop"
	_wide_backdrop.size = DESIGN
	_wide_backdrop.visible = false
	_wide_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_wide_backdrop)
	var regions: Dictionary = {
		"WideLeft": Rect2(0.0, 0.0, WIDE_LEFT_CUT, DESIGN.y),
		"WideCenter": Rect2(WIDE_LEFT_CUT, 0.0, WIDE_RIGHT_CUT - WIDE_LEFT_CUT, DESIGN.y),
		"WideRight": Rect2(WIDE_RIGHT_CUT, 0.0, DESIGN.x - WIDE_RIGHT_CUT, DESIGN.y)
	}
	for part_name in ["WideLeft", "WideCenter", "WideRight"]:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = _approved_backdrop.texture
		atlas.region = regions[part_name]
		var part: TextureRect = TextureRect.new()
		part.name = part_name
		part.texture = atlas
		part.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		part.stretch_mode = TextureRect.STRETCH_SCALE
		part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wide_backdrop.add_child(part)

func _add_image(node_name: String, png: String, svg: String, where: Vector2, how_big: Vector2) -> void:
	# The screenshot/mock-up is not one flattened UI. Every asset stays a
	# separate clickable/replaceable Godot node, including the backdrop.
	var base := "res://assets/ui/title/"
	var texture: Texture2D
	for path in [base + png, base + svg]:
		if not ResourceLoader.exists(path):
			continue
		texture = load(path) as Texture2D
		if texture != null:
			break
	if texture == null:
		push_warning("Outpost title artwork missing: " + png + " / " + svg)
		return
	var image := TextureRect.new()
	image.name = node_name
	image.texture = texture
	image.position = where
	image.size = how_big
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture.resource_path.get_extension().to_lower() == "png" or node_name in ["Backdrop", "TitleLights"]:
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.add_child(image)

func _label_style(label: Label, font_size: int, ink: Color, outline: Color) -> void:
	var s := LabelSettings.new()
	s.font_size = font_size
	s.font_color = ink
	s.outline_color = outline
	s.outline_size = 3
	label.label_settings = s

func _has_valid_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (data is Dictionary):
		return false
	return int(data.get("version", 0)) in [2, 3, 4, 5]

func _on_play() -> void:
	_open_adventure_panel(true)

func _begin_continue() -> void:
	# Continue is one action, not a second adventure-selection menu.
	# The existing save is loaded by the world scene after streaming finishes.
	if _has_valid_save():
		_launch_game(false)

func _launch_game(new_adventure: bool, lan_mode: String = "solo", address: String = "", preferred_name: String = "Adventurer") -> void:
	get_tree().root.set_meta("outpost_new_adventure", new_adventure)
	# The main game owns ENet and starts it only AFTER the player/avatar exists.
	get_tree().root.set_meta("outpost_lan_mode", lan_mode)
	get_tree().root.set_meta("outpost_lan_ip", address)
	get_tree().root.set_meta("outpost_lan_name", preferred_name)
	get_tree().change_scene_to_file(WORLD_LOADING)

func _process(delta: float) -> void:
	# Do not tint just the painted background: the approved crest is a
	# separate screenshot-derived cutout, and mixed opacity made seams visible.
	# A matching full-frame night master will reintroduce day/night later.
	if _approved_art:
		if _approved_backdrop != null:
			_approved_backdrop.modulate = Color.WHITE
		if _wide_backdrop != null:
			_wide_backdrop.modulate = Color.WHITE
	# Legacy SVG light pass remains available as an optional fallback.
	if _light_layer != null:
		_light_layer.modulate.a = 0.79 if _reduced_motion else 0.78 + 0.14 * sin(float(Time.get_ticks_msec()) * 0.0017)
	if _show_tips and _tip_text != null:
		_tip_elapsed += delta
		if _tip_elapsed >= TIP_CYCLE_SECONDS:
			_tip_elapsed = 0.0
			_advance_tip()

func _advance_tip() -> void:
	_tip_index = (_tip_index + 1) % TIPS.size()
	if _reduced_motion:
		_tip_text.text = TIPS[_tip_index]
		_tip_text.modulate.a = 1.0
		return
	var fade := create_tween()
	fade.tween_property(_tip_text, "modulate:a", 0.12, 0.20)
	fade.tween_callback(func() -> void: _tip_text.text = TIPS[_tip_index])
	fade.tween_property(_tip_text, "modulate:a", 1.0, 0.26)

func _menu_label(value: String, font_px: int = 23) -> Label:
	var output := Label.new()
	output.text = value
	output.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	output.add_theme_font_size_override("font_size", font_px)
	output.add_theme_color_override("font_color", Color("fff0d0"))
	output.add_theme_color_override("font_outline_color", Color("302019"))
	output.add_theme_constant_override("outline_size", 2)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return output

func _menu_button(caption: String, action: Callable, kind: String = "wood") -> Button:
	var output := Button.new()
	output.text = caption
	output.custom_minimum_size = Vector2(0, 50)
	SKIN.apply_button(output, kind)
	output.focus_mode = Control.FOCUS_ALL
	output.add_theme_stylebox_override("focus", SKIN.box("wood_selected"))
	output.pressed.connect(action)
	return output

func _menu_field(placeholder: String, starting: String = "") -> LineEdit:
	var output := LineEdit.new()
	output.placeholder_text = placeholder
	output.text = starting
	output.custom_minimum_size = Vector2(0, 47)
	output.add_theme_stylebox_override("normal", SKIN.box("parchment"))
	output.add_theme_stylebox_override("focus", SKIN.box("parchment_light"))
	output.add_theme_color_override("font_color", Color("3e281d"))
	output.add_theme_color_override("font_placeholder_color", Color("836c54"))
	output.add_theme_font_size_override("font_size", 19)
	return output

func _menu_frame(title_value: String, width_px: float, height_px: float) -> Dictionary:
	var frame := PanelContainer.new()
	frame.position = (DESIGN - Vector2(width_px, height_px)) * 0.5
	frame.size = Vector2(width_px, height_px)
	frame.custom_minimum_size = Vector2(width_px, height_px)
	frame.add_theme_stylebox_override("panel", SKIN.box("frame"))
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.add_child(frame)
	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 24)
	frame.add_child(margins)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margins.add_child(stack)
	stack.add_child(_menu_label(title_value, 31))
	return {"frame": frame, "stack": stack}

func _set_title_button_glow(selected_button: Button) -> void:
	if _selection_glow == null or selected_button.disabled:
		return
	_selection_glow.position = selected_button.position - Vector2(44, 24)
	_selection_glow.size = selected_button.size + Vector2(88, 48)
	_selection_glow.visible = true

func _hide_title_glow_if_idle() -> void:
	if _selection_glow != null:
		_selection_glow.visible = false

func _build_settings() -> void:
	var parts: Dictionary = _menu_frame("SETTINGS  •  OUTPOST", 660.0, 590.0)
	_settings_panel = parts["frame"] as PanelContainer
	_settings_panel.name = "SettingsPanel"
	var stack: VBoxContainer = parts["stack"] as VBoxContainer
	stack.add_child(_menu_label("Sound and accessibility", 18))
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	stack.add_child(volume_row)
	var volume_label := _menu_label("MASTER VOLUME", 18)
	volume_label.custom_minimum_size = Vector2(184, 36)
	volume_row.add_child(volume_label)
	var volume_slider := HSlider.new()
	volume_slider.name = "MasterVolumeSlider"
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.custom_minimum_size = Vector2(260, 43)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = _volume * 100.0
	volume_slider.add_theme_stylebox_override("slider", SKIN.flat("inset"))
	volume_slider.add_theme_stylebox_override("grabber_area", SKIN.flat("wood_selected"))
	volume_slider.add_theme_stylebox_override("grabber_area_highlight", SKIN.flat("wood_selected"))
	volume_slider.value_changed.connect(func(value: float) -> void:
		_volume = clampf(value / 100.0, 0.0, 1.0)
		_apply_volume()
		_write_prefs()
	)
	volume_row.add_child(volume_slider)
	var motion := CheckButton.new()
	motion.name = "ReduceMotionToggle"
	motion.text = "Reduce menu animation and embers"
	motion.button_pressed = _reduced_motion
	motion.add_theme_color_override("font_color", Color("fff0d0"))
	motion.add_theme_font_size_override("font_size", 20)
	motion.toggled.connect(func(enabled: bool) -> void:
		_reduced_motion = enabled
		_splash.animate_bounce = not enabled
		if _embers != null:
			_embers.set("reduced_motion", enabled)
			_embers.queue_redraw()
		for kind in ["Play", "Continue", "Settings", "Quit"]:
			var btn: Button = _canvas.get_node_or_null(kind + "Button") as Button
			if btn != null:
				btn.set("reduced_motion", enabled)
				btn.queue_redraw()
		if enabled:
			_splash.scale = Vector2.ONE
		_write_prefs()
	)
	stack.add_child(motion)
	var tips := CheckButton.new()
	tips.name = "AdventureTipsToggle"
	tips.text = "Show adventure tips"
	tips.button_pressed = _show_tips
	tips.add_theme_color_override("font_color", Color("fff0d0"))
	tips.add_theme_font_size_override("font_size", 20)
	tips.toggled.connect(func(enabled: bool) -> void:
		_show_tips = enabled
		_tip_text.visible = enabled
		if _tip_plaque != null:
			_tip_plaque.visible = enabled
		_write_prefs()
	)
	stack.add_child(tips)
	stack.add_child(_menu_label("ANDROID BUILDS  •  SELECT CHANNEL", 22))
	var channels := HBoxContainer.new()
	channels.name = "BuildChannelSelector"
	channels.add_theme_constant_override("separation", 9)
	stack.add_child(channels)
	_channel_stable_button = _menu_button("STABLE", _select_update_channel.bind("stable"))
	_channel_stable_button.name = "StableChannel"
	_channel_stable_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channels.add_child(_channel_stable_button)
	_channel_alpha_button = _menu_button("ALPHA TEST", _select_update_channel.bind("alpha"))
	_channel_alpha_button.name = "AlphaChannel"
	_channel_alpha_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channels.add_child(_channel_alpha_button)
	_channel_note = _menu_label("", 16)
	_channel_note.name = "BuildChannelDescription"
	_channel_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_channel_note.custom_minimum_size = Vector2(0, 28)
	stack.add_child(_channel_note)
	_updater = ANDROID_UPDATER.new()
	_updater.name = "AndroidUpdater"
	add_child(_updater)
	_updater.status_changed.connect(_on_update_status)
	_updater.update_found.connect(_on_update_found)
	if _selected_channel not in ["stable", "alpha"]:
		_selected_channel = _updater.installed_channel()
	_updater.set_target_channel(_selected_channel)
	_refresh_channel_buttons()
	var update_row := HBoxContainer.new()
	update_row.add_theme_constant_override("separation", 10)
	stack.add_child(update_row)
	_update_button = _menu_button("CHECK FOR UPDATES", _check_updates_only)
	_update_button.name = "CheckForUpdates"
	_update_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	update_row.add_child(_update_button)
	_download_button = _menu_button("DOWNLOAD APK", _check_or_download_update, "wood_selected")
	_download_button.name = "DownloadUpdate"
	_download_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_download_button.disabled = true
	update_row.add_child(_download_button)
	_update_status = _menu_label("Android build %d • Downloads open in your browser." % int(ProjectSettings.get_setting("application/config/android_build_code", 11)), 16)
	_update_status.name = "UpdateStatus"
	_update_status.custom_minimum_size = Vector2(0, 42)
	stack.add_child(_update_status)
	stack.add_child(_menu_button("BACK TO OUTPOST", _toggle_settings, "parchment"))
	_settings_panel.visible = false

func _build_changelog_scroll() -> void:
	# A separate original transparent icon, not another opaque baked title crop.
	_changelog_button = Button.new()
	_changelog_button.name = "ChangelogScrollButton"
	_changelog_button.position = Vector2(1164, 266)
	_changelog_button.size = Vector2(62, 70)
	_changelog_button.tooltip_text = "Read the latest Outpost changes"
	_changelog_button.icon = load("res://assets/ui/title/changelog_scroll.svg") as Texture2D
	_changelog_button.expand_icon = true
	_changelog_button.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		_changelog_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_changelog_button.pressed.connect(_toggle_changelog)
	_canvas.add_child(_changelog_button)
	_changelog_panel = PanelContainer.new()
	_changelog_panel.name = "ChangelogPanel"
	_changelog_panel.position = Vector2(800, 257)
	_changelog_panel.size = Vector2(358, 346)
	_changelog_panel.custom_minimum_size = Vector2(358, 346)
	_changelog_panel.add_theme_stylebox_override("panel", SKIN.box("frame"))
	_changelog_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.add_child(_changelog_panel)
	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 14)
	_changelog_panel.add_child(margins)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margins.add_child(stack)
	stack.add_child(_menu_label("OUTPOST  ◆  WHAT'S NEW", 23))
	var scroll := ScrollContainer.new()
	scroll.name = "ChangelogScrollList"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var details := _menu_label("LATEST ALPHA TEST\\n\\n• Stable / Alpha version selection in Settings\\n• Mainline title and world-loading updates\\n• New hero portrait, radial XP jewel and crafting flow\\n• Escape and outside-tap controls for crafting\\n\\nTESTING NEXT\\nTitle button cutouts, moving glow, HUD icon artwork, camera and minimap layout.", 17)
	details.name = "ChangelogBody"
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.text = details.text.replace("\\n", "\n")
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	stack.add_child(_menu_button("CLOSE SCROLL", _toggle_changelog, "parchment"))
	_changelog_panel.visible = false

func _toggle_changelog() -> void:
	if _changelog_panel == null:
		return
	if _changelog_panel.visible:
		_changelog_panel.visible = false
		return
	if _settings_panel != null:
		_settings_panel.visible = false
	if _adventure_panel != null and _adventure_panel.visible:
		_close_adventure_panel()
	_changelog_panel.visible = true
	_changelog_panel.move_to_front()

func _apply_volume() -> void:
	var master: int = AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, linear_to_db(maxf(0.001, _volume)))

func _select_update_channel(channel: String) -> void:
	if channel not in ["stable", "alpha"]:
		return
	_selected_channel = channel
	if _updater != null:
		_updater.set_target_channel(channel)
	_update_download_url = ""
	if _download_button != null:
		_download_button.disabled = true
		_download_button.text = "DOWNLOAD APK"
	if _update_notice != null:
		_update_notice.visible = false
	_refresh_channel_buttons()
	_on_update_status("Selected %s. Tap CHECK FOR UPDATES to find its APK." % channel.capitalize())
	_write_prefs()

func _refresh_channel_buttons() -> void:
	if _channel_stable_button != null:
		SKIN.apply_button(_channel_stable_button, "wood_selected" if _selected_channel == "stable" else "wood")
	if _channel_alpha_button != null:
		SKIN.apply_button(_channel_alpha_button, "wood_selected" if _selected_channel == "alpha" else "wood")
	if _channel_note != null:
		var current: String = _updater.installed_channel() if _updater != null else "stable"
		_channel_note.text = "INSTALLED: %s  •  INSTALLS SIDE BY SIDE, SAVES STAY SEPARATE." % current.to_upper()

func _check_updates_only() -> void:
	if _updater != null:
		_updater.check_for_updates()

func _build_adventure_panel() -> void:
	_adventure_dim = ColorRect.new()
	_adventure_dim.name = "AdventureShade"
	_adventure_dim.color = Color(0.03, 0.02, 0.05, 0.47)
	_adventure_dim.size = DESIGN
	_adventure_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_adventure_dim)
	var parts: Dictionary = _menu_frame("ADVENTURE  •  OUTPOST", 700.0, 525.0)
	_adventure_panel = parts["frame"] as PanelContainer
	_adventure_panel.name = "AdventurePanel"
	var stack: VBoxContainer = parts["stack"] as VBoxContainer
	_adventure_heading = _menu_label("Choose how to begin your adventure", 20)
	stack.add_child(_adventure_heading)
	stack.add_child(_menu_button("SOLO  •  ENTER OUTPOST", func() -> void: _launch_game(_new_adventure_pending)))
	stack.add_child(_menu_button("HOST LAN  •  FRIENDS MAY REQUEST TO JOIN", func() -> void:
		_launch_game(_new_adventure_pending, "host")
	))
	stack.add_child(_menu_label("JOIN A FRIEND ON THE SAME WI-FI", 18))
	var inputs := HBoxContainer.new()
	inputs.add_theme_constant_override("separation", 9)
	stack.add_child(inputs)
	_adventure_name = _menu_field("Adventurer name", "Adventurer")
	_adventure_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inputs.add_child(_adventure_name)
	_adventure_ip = _menu_field("Host LAN IPv4")
	_adventure_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inputs.add_child(_adventure_ip)
	stack.add_child(_menu_button("JOIN FRIEND'S OUTPOST", _join_friend))
	_adventure_feedback = _menu_label("", 16)
	stack.add_child(_adventure_feedback)
	stack.add_child(_menu_button("BACK", _close_adventure_panel, "parchment"))
	_adventure_dim.visible = false
	_adventure_panel.visible = false

func _open_adventure_panel(new_game: bool) -> void:
	_new_adventure_pending = new_game
	if _settings_panel != null:
		_settings_panel.visible = false
	_adventure_heading.text = "Starting fresh replaces the save when you next save." if new_game and _has_valid_save() else ("Begin a new adventure" if new_game else "Resume your saved adventure")
	_adventure_feedback.text = ""
	_adventure_dim.visible = true
	_adventure_panel.visible = true
	_adventure_dim.move_to_front()
	_adventure_panel.move_to_front()

func _close_adventure_panel() -> void:
	_adventure_panel.visible = false
	_adventure_dim.visible = false

func _join_friend() -> void:
	var address: String = _adventure_ip.text.strip_edges()
	if not address.is_valid_ip_address() or address.contains(":"):
		_adventure_feedback.text = "Enter a valid IPv4 address on your local network."
		return
	_launch_game(_new_adventure_pending, "join", address, _adventure_name.text)

func _check_or_download_update() -> void:
	if not _update_download_url.is_empty():
		# The Android installer always needs the user's approval. A browser
		# download avoids unsafe file:// URI / FileProvider workarounds.
		var error: Error = OS.shell_open(_update_download_url)
		if error != OK:
			_on_update_status("Couldn't open your browser; use the GitHub Releases page.")
		return
	if _updater != null:
		_updater.check_for_updates()

func _on_update_status(message: String) -> void:
	if _update_status != null:
		_update_status.text = message

func _on_update_found(download_url: String, version_code: int, _release_url: String) -> void:
	_update_download_url = download_url
	if _download_button != null:
		_download_button.disabled = false
		_download_button.text = "DOWNLOAD BUILD %d" % version_code
	if _update_notice != null:
		_update_notice.text = "%s APK  •  BUILD %d" % [_selected_channel.to_upper(), version_code]
		_update_notice.visible = true
	_on_update_status("%s build %d available. Tap Download, then approve Android install. Different channels have separate saves." % [_selected_channel.capitalize(), version_code])

func _toggle_settings() -> void:
	if _changelog_panel != null:
		_changelog_panel.visible = false
	if _adventure_panel != null and _adventure_panel.visible:
		_close_adventure_panel()
	_settings_panel.visible = not _settings_panel.visible
	if _settings_panel.visible:
		_settings_panel.move_to_front()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _changelog_panel != null and _changelog_panel.visible:
			_toggle_changelog()
			get_viewport().set_input_as_handled()
		elif _adventure_panel != null and _adventure_panel.visible:
			_close_adventure_panel()
			get_viewport().set_input_as_handled()
		elif _settings_panel != null and _settings_panel.visible:
			_toggle_settings()
			get_viewport().set_input_as_handled()

func _read_prefs() -> void:
	var prefs := ConfigFile.new()
	if prefs.load(UI_PREFS) == OK:
		_reduced_motion = bool(prefs.get_value("title", "reduced_motion", false))
		_show_tips = bool(prefs.get_value("title", "show_tips", true))
		_volume = clampf(float(prefs.get_value("title", "volume", 0.85)), 0.0, 1.0)
		_selected_channel = str(prefs.get_value("title", "build_channel", ""))

func _write_prefs() -> void:
	var prefs := ConfigFile.new()
	prefs.set_value("title", "reduced_motion", _reduced_motion)
	prefs.set_value("title", "show_tips", _show_tips)
	prefs.set_value("title", "volume", _volume)
	prefs.set_value("title", "build_channel", _selected_channel)
	prefs.save(UI_PREFS)
