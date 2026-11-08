extends CanvasLayer
## Full-screen, low-overhead world generation scene for Android.
## Supports real cancellation before the generated world is revealed.
const GAME_SCENE: String = "res://scenes/main.tscn"
const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const SCENERY: String = "res://assets/ui/title/title_background.png"
const FALLBACK_SCENERY: String = "res://assets/ui/title/title_backdrop.svg"
const CREST: String = "res://assets/ui/title/outpost_logo.png"
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
const READY_PAUSE_FRAMES: int = 2

var _progress: ProgressBar
var _stage: Label
var _detail: Label
var _cancel_button: Button
var _loaded_world: Node3D
var _started: bool = false
var _cancel_requested: bool = false

func _ready() -> void:
	layer = 100
	_build_screen()
	call_deferred("_begin_world_generation")

func _build_screen() -> void:
	var page := Control.new()
	page.name = "LoadingArtboard"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(page)

	var ground := ColorRect.new()
	ground.color = Color("171c2d")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(ground)

	var background_path: String = SCENERY if ResourceLoader.exists(SCENERY) else FALLBACK_SCENERY
	if ResourceLoader.exists(background_path):
		var scenic := TextureRect.new()
		scenic.name = "Landscape"
		scenic.texture = load(background_path) as Texture2D
		scenic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scenic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		scenic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scenic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scenic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		page.add_child(scenic)

	var veil := ColorRect.new()
	veil.name = "DuskVeil"
	veil.color = Color(0.03, 0.026, 0.075, 0.51)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(veil)

	# Keep the approved scenery but use the same translucent wood/bronze
	# frame as the Menu and Changelog. The world load remains cancellable.
	var middle := CenterContainer.new()
	middle.name = "LoadingCenter"
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(middle)
	var loading_frame := PanelContainer.new()
	loading_frame.name = "WorldLoadingFrame"
	var glass := SKIN.modal_panel()
	glass.bg_color = Color(0.17, 0.11, 0.10, 0.80)
	loading_frame.add_theme_stylebox_override("panel", glass)
	middle.add_child(loading_frame)
	var column := VBoxContainer.new()
	column.name = "LoadingStack"
	column.custom_minimum_size = Vector2(450, 400)
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	loading_frame.add_child(column)

	var crest := TextureRect.new()
	crest.name = "OutpostLoadingCrest"
	crest.custom_minimum_size = Vector2(245, 185)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(CREST):
		crest.texture = load(CREST) as Texture2D
	column.add_child(crest)

	_stage = Label.new()
	_stage.name = "WorldGenerationStage"
	_stage.text = "Preparing your adventure..."
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_theme_font_size_override("font_size", 24)
	_stage.add_theme_color_override("font_color", Color("ffe0a3"))
	_stage.add_theme_color_override("font_outline_color", Color("221a29"))
	_stage.add_theme_constant_override("outline_size", 4)
	column.add_child(_stage)

	_progress = ProgressBar.new()
	_progress.name = "WorldGenerationProgress"
	_progress.min_value = 0
	_progress.max_value = 100
	_progress.value = 0
	_progress.custom_minimum_size = Vector2(420, 25)
	_progress.show_percentage = false
	var rail: StyleBoxFlat = SKIN.flat("inset")
	var filled: StyleBoxFlat = SKIN.flat("wood_selected")
	filled.bg_color = Color("#eabf70")
	_progress.add_theme_stylebox_override("background", rail)
	_progress.add_theme_stylebox_override("fill", filled)
	column.add_child(_progress)

	_detail = Label.new()
	_detail.name = "ProgressDetail"
	_detail.text = "Preparing terrain... 0%"
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_theme_font_size_override("font_size", 18)
	_detail.add_theme_color_override("font_color", Color("fff1d5"))
	_detail.add_theme_color_override("font_outline_color", Color("211a28"))
	_detail.add_theme_constant_override("outline_size", 3)
	column.add_child(_detail)

	_cancel_button = Button.new()
	_cancel_button.name = "CancelLoading"
	_cancel_button.text = "CANCEL  •  RETURN TO TITLE"
	_cancel_button.custom_minimum_size = Vector2(300, 58)
	_cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SKIN.apply_button(_cancel_button, "wood")
	_cancel_button.pressed.connect(_cancel_to_title)
	column.add_child(_cancel_button)

func _cancel_to_title() -> void:
	if _cancel_requested or (_progress != null and _progress.value >= 100.0):
		return
	_cancel_requested = true
	_cancel_button.disabled = true
	_stage.text = "Returning to title..."
	# The world is added as a hidden root child. Do not strand it when the
	# loader is cancelled halfway through terrain streaming on Android.
	if is_instance_valid(_loaded_world):
		_loaded_world.queue_free()
		_loaded_world = null
	if get_tree().root.has_meta("outpost_defer_world_generation"):
		get_tree().root.remove_meta("outpost_defer_world_generation")
	for key in ["outpost_new_adventure", "outpost_lan_mode", "outpost_lan_ip", "outpost_lan_name"]:
		if get_tree().root.has_meta(key):
			get_tree().root.remove_meta(key)
	get_tree().change_scene_to_file(TITLE_SCENE)

func _begin_world_generation() -> void:
	if _started or _cancel_requested:
		return
	_started = true
	await get_tree().process_frame
	if _cancel_requested or not is_inside_tree():
		return
	await get_tree().process_frame
	if _cancel_requested or not is_inside_tree():
		return
	_stage.text = "Setting up your camp..."
	_progress.value = 5.0
	_detail.text = "Building your outpost..."
	var packed: PackedScene = load(GAME_SCENE)
	if _cancel_requested or not is_inside_tree():
		return
	if packed == null:
		_stage.text = "Couldn't load the world"
		_detail.text = "Return to title and try again."
		return
	_loaded_world = packed.instantiate() as Node3D
	if _loaded_world == null:
		_stage.text = "Couldn't create the world"
		return
	_loaded_world.visible = false
	get_tree().root.set_meta("outpost_defer_world_generation", true)
	get_tree().root.add_child(_loaded_world)
	get_tree().root.remove_meta("outpost_defer_world_generation")
	if _cancel_requested or not is_inside_tree():
		return

	var terrain: Node = _loaded_world.get_node_or_null("VoxelAtmosphere")
	if terrain != null and terrain.has_method("initial_generation_complete"):
		while is_instance_valid(terrain) and not terrain.initial_generation_complete():
			if _cancel_requested or not is_inside_tree():
				return
			var ratio: float = clampf(float(terrain.initial_generation_progress()), 0.0, 1.0)
			_progress.value = 10.0 + ratio * 88.0
			_stage.text = "Generating your world..."
			_detail.text = "Building terrain and paths  •  %d%%" % int(roundf(ratio * 100.0))
			await get_tree().process_frame
	else:
		_stage.text = "Preparing your first steps..."
		await get_tree().process_frame

	if _cancel_requested or not is_inside_tree():
		return
	_progress.value = 100.0
	_cancel_button.disabled = true
	_stage.text = "Welcome to Outpost!"
	_detail.text = "Your adventure is ready."
	for i in range(READY_PAUSE_FRAMES):
		await get_tree().process_frame
		if _cancel_requested or not is_inside_tree():
			return
	if not is_instance_valid(_loaded_world):
		push_error("Outpost loading: world disappeared before reveal")
		return
	_loaded_world.visible = true
	get_tree().current_scene = _loaded_world
	queue_free()
