extends CanvasLayer
## A real multi-frame world generation gateway; never freeze Android's first Play frame.
## Keeps the title's new-adventure metadata and existing game save logic intact.
const GAME_SCENE: String = "res://scenes/main.tscn"
const SCENERY: String = "res://assets/ui/title/title_backdrop.svg"
const READY_PAUSE_FRAMES: int = 2

var _progress: ProgressBar
var _stage: Label
var _detail: Label
var _loaded_world: Node3D
var _started: bool = false

func _ready() -> void:
	layer = 100 # Overlays in-game HUD while the hidden world is assembled.
	_build_screen()
	call_deferred("_begin_world_generation")

func _build_screen() -> void:
	var page := Control.new()
	page.name = "LoadingArtboard"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(page)

	var ground := ColorRect.new()
	ground.color = Color("1b1d32")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(ground)

	if ResourceLoader.exists(SCENERY):
		var scenic := TextureRect.new()
		scenic.name = "Landscape"
		scenic.texture = load(SCENERY) as Texture2D
		scenic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scenic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		scenic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scenic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(scenic)

	var veil := ColorRect.new()
	veil.name = "DuskVeil"
	veil.color = Color(0.035, 0.037, 0.06, 0.77)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(veil)

	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(middle)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(460, 245)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var wood := StyleBoxFlat.new()
	wood.bg_color = Color("35252d")
	wood.border_color = Color("c28c58")
	wood.set_border_width_all(5)
	wood.set_corner_radius_all(10)
	wood.set_content_margin_all(25)
	frame.add_theme_stylebox_override("panel", wood)
	middle.add_child(frame)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	frame.add_child(content)
	var heading := Label.new()
	heading.text = "OUTPOST"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 45)
	heading.add_theme_color_override("font_color", Color("ffd48f"))
	content.add_child(heading)
	_stage = Label.new()
	_stage.text = "Preparing your adventure..."
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_theme_font_size_override("font_size", 23)
	_stage.add_theme_color_override("font_color", Color("fff1d5"))
	content.add_child(_stage)

	_progress = ProgressBar.new()
	_progress.name = "WorldGenerationProgress"
	_progress.min_value = 0
	_progress.max_value = 100
	_progress.value = 0
	_progress.custom_minimum_size = Vector2(390, 22)
	_progress.show_percentage = false
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("1b1825")
	rail.set_corner_radius_all(5)
	var filled := StyleBoxFlat.new()
	filled.bg_color = Color("f4bd66")
	filled.set_corner_radius_all(5)
	_progress.add_theme_stylebox_override("background", rail)
	_progress.add_theme_stylebox_override("fill", filled)
	content.add_child(_progress)

	_detail = Label.new()
	_detail.name = "ProgressDetail"
	_detail.text = "Preparing terrain... 0%"
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_theme_font_size_override("font_size", 16)
	_detail.add_theme_color_override("font_color", Color("e4c3a8"))
	content.add_child(_detail)
	var encouragement := Label.new()
	encouragement.text = "However dark the world gets, you are its light."
	encouragement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encouragement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encouragement.add_theme_font_size_override("font_size", 16)
	encouragement.add_theme_color_override("font_color", Color("ffd47e"))
	content.add_child(encouragement)

func _begin_world_generation() -> void:
	if _started:
		return
	_started = true
	# Present loading UI before creating any WorldEnvironment, mesh, or collider.
	await get_tree().process_frame
	await get_tree().process_frame
	_stage.text = "Setting up your camp..."
	_progress.value = 5
	_detail.text = "Building your outpost..."
	var packed: PackedScene = load(GAME_SCENE)
	if packed == null:
		_stage.text = "Couldn't load the world"
		_detail.text = "Please report this build's loading error."
		push_error("Outpost loading: failed to load main scene")
		return
	_loaded_world = packed.instantiate() as Node3D
	if _loaded_world == null:
		_stage.text = "Couldn't create the world"
		push_error("Outpost loading: failed to instantiate main scene")
		return
	_loaded_world.visible = false
	get_tree().root.add_child(_loaded_world)
	# The voxel biome was instructed to stream the spawn region gradually;
	# the main game still owns every gameplay/UI/save system normally.
	var terrain: Node = _loaded_world.get_node_or_null("VoxelAtmosphere")
	if terrain != null and terrain.has_method("initial_generation_complete"):
		while is_instance_valid(terrain) and not terrain.initial_generation_complete():
			var ratio: float = clampf(float(terrain.initial_generation_progress()), 0.0, 1.0)
			_progress.value = 10.0 + ratio * 88.0
			_stage.text = "Generating your world..."
			_detail.text = "Sculpting terrain and building paths • %d%%" % int(roundf(ratio * 100.0))
			await get_tree().process_frame
	else:
		_stage.text = "Preparing your first steps..."
		await get_tree().process_frame
	_progress.value = 100
	_stage.text = "Welcome to Outpost!"
	_detail.text = "The world is ready."
	for i in range(READY_PAUSE_FRAMES):
		await get_tree().process_frame
	if not is_instance_valid(_loaded_world):
		push_error("Outpost loading: world disappeared before reveal")
		return
	_loaded_world.visible = true
	get_tree().current_scene = _loaded_world
	queue_free()
