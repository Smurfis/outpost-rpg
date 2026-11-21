extends CanvasLayer
const RELIEF = preload("res://scripts/map/map_relief.gd")
const MARKERS = preload("res://scripts/ui/map_marker_layer.gd")
const UNCHARTED = preload("res://scripts/map/uncharted_island_silhouettes.gd")
const MIN_VIEW_SIZE: float = 9.0 # Two 1.15x increments closer than the previous 12m limit.
const PITCH: float = deg_to_rad(50.0)
var game: Node
var service: Node
var has_remote_islands: bool = false
var show_island_circles: bool = false # Temporary GM-only debug overlay, off by default.
var screen: Control
var map_art: TextureRect
var map_viewport: SubViewport
var map_camera: Camera3D
var mini_viewport: SubViewport
var mini_camera: Camera3D
var relief: Node3D
var uncharted: Node3D
var marker_layer: Control
var search_box: LineEdit
var results: ItemList
var search_results: Array[Dictionary] = []
var footer: Label
var view_span: float = 250.0
var target_span: float = 250.0
var focus := Vector3.ZERO
var target_focus := Vector3.ZERO
var map_yaw: float = PI * 0.25
var fingers: Dictionary = {}
var dragging: bool = false
var rotating: bool = false
var press_at := Vector2.ZERO
var mini_clock: float = 0.0
var schedule_clock: float = 0.0
var last_schedule := Vector3.INF
var dirty: bool = true
var input_guard_until: int = 0
var mini_touch_index: int = -1
var mini_touch_origin := Vector2.ZERO

func setup(owner_game: Node, source: Node) -> void:
	game = owner_game
	service = source
	has_remote_islands = service.biome != null and service.biome.archipelago != null
	layer = 40
	map_viewport = SubViewport.new()
	map_viewport.own_world_3d = true
	map_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	map_viewport.size = Vector2i(960, 540)
	add_child(map_viewport)
	var world := Node3D.new()
	map_viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("142022")
	world.add_child(environment)
	relief = RELIEF.new()
	world.add_child(relief)
	relief.setup(service)
	uncharted = UNCHARTED.new()
	world.add_child(uncharted)
	uncharted.setup(service.biome)
	map_camera = Camera3D.new()
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	map_camera.far = 4000
	world.add_child(map_camera)
	map_camera.current = true
	mini_viewport = SubViewport.new()
	mini_viewport.size = Vector2i(192, 192)
	mini_viewport.world_3d = map_viewport.find_world_3d()
	mini_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mini_viewport)
	mini_camera = Camera3D.new()
	mini_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	mini_camera.cull_mask = 1 # The main world map alone shows undiscovered silhouettes.
	mini_camera.size = 72.0
	mini_camera.far = 4000
	mini_viewport.add_child(mini_camera)
	mini_camera.current = true
	_build_ui()
	service.changed.connect(func(): dirty = true; _search(search_box.text))
	game.hero.combat_state_changed.connect(func(active: bool):
		if active: close_map())
	get_viewport().size_changed.connect(_resize)
	_resize()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(48, 44)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	screen = Control.new()
	screen.name = "WorldMapScreen"
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	map_art = TextureRect.new()
	map_art.texture = map_viewport.get_texture()
	map_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_art.stretch_mode = TextureRect.STRETCH_SCALE
	map_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.add_child(map_art)
	map_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_art.gui_input.connect(_canvas_input)
	marker_layer = MARKERS.new()
	marker_layer.map = self
	marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(marker_layer)
	marker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := HBoxContainer.new()
	screen.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_top = 12
	top.offset_right = -12
	var title := Label.new()
	title.text = "WORLD MAP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("ffe5a1"))
	top.add_child(title)
	_button(top, "Player", centre_player)
	_button(top, "Islands" if has_remote_islands else "Island", overview)
	_button(top, "Close", close_map)
	var left := VBoxContainer.new()
	left.position = Vector2(12, 68)
	screen.add_child(left)
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search discovered places"
	search_box.custom_minimum_size = Vector2(235, 44)
	left.add_child(search_box)
	search_box.text_changed.connect(_search)
	search_box.focus_entered.connect(func(): _search(search_box.text))
	results = ItemList.new()
	results.custom_minimum_size = Vector2(235, 150)
	left.add_child(results)
	results.hide()
	results.item_selected.connect(_select_result)
	var filters := GridContainer.new()
	filters.columns = 2
	left.add_child(filters)
	filters.hide()
	_button(left, "Layers", func(): filters.visible = not filters.visible)
	for key in ["mobs", "stations", "portals", "zones", "resources"]:
		var check := CheckButton.new()
		check.text = str(key).capitalize()
		check.button_pressed = service.preferences[key]
		check.custom_minimum_size.y = 40
		filters.add_child(check)
		check.toggled.connect(func(value: bool): service.preferences[key] = value; service.dirty = true; marker_layer.queue_redraw())
	var types := OptionButton.new()
	for kind in ["all", "wood", "stone", "iron", "coal", "clay", "fiber", "shrimp"]:
		types.add_item(kind.capitalize())
	filters.add_child(types)
	types.item_selected.connect(func(index: int): service.preferences.resource_type = types.get_item_text(index).to_lower(); service.dirty = true; marker_layer.queue_redraw())
	var zooms := HBoxContainer.new()
	screen.add_child(zooms)
	zooms.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	zooms.offset_left = -232
	zooms.offset_top = -60
	zooms.offset_right = -12
	zooms.offset_bottom = -12
	_button(zooms, "-", func(): zoom_by(1.15))
	_button(zooms, "+", func(): zoom_by(1.0 / 1.15))
	_button(zooms, "<", func(): map_yaw -= PI / 8; dirty = true)
	_button(zooms, ">", func(): map_yaw += PI / 8; dirty = true)
	footer = Label.new()
	screen.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 12
	footer.offset_top = -35
	footer.offset_right = -250
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_color_override("font_color", Color("e4ce9f"))
	footer.text = "Drag to pan | Wheel / pinch to zoom | Dark land = uncharted" if has_remote_islands else "Drag to pan | Wheel / pinch to zoom"
	screen.hide()

func _resize() -> void:
	if map_viewport == null:
		return
	var dimensions: Vector2 = get_viewport().get_visible_rect().size
	var scale_factor: float = minf(1.0, (960.0 if OS.has_feature("mobile") else 1440.0) / maxf(dimensions.x, dimensions.y))
	map_viewport.size = Vector2i(maxi(2, roundi(dimensions.x * scale_factor)), maxi(2, roundi(dimensions.y * scale_factor)))
	dirty = true

func overview() -> void:
	map_yaw = PI * 0.25
	var aspect: float = float(map_viewport.size.x) / float(map_viewport.size.y)
	# Fit Outpost and all remote exploration islands. Previously this used
	# home map_half=96 and silently cropped every new island from the map.
	var left: float = -float(service.biome.map_half)
	var right: float = float(service.biome.map_half)
	var north: float = -float(service.biome.map_half)
	var south: float = float(service.biome.map_half)
	if service.biome.archipelago != null:
		for island in service.biome.archipelago.terrain.islands:
			var centre: Vector2i = island["center"]
			var radius: float = float(island["radius"]) + 6.0
			left = minf(left, float(centre.x) - radius)
			right = maxf(right, float(centre.x) + radius)
			north = minf(north, float(centre.y) - radius)
			south = maxf(south, float(centre.y) + radius)
	target_focus = Vector3((left + right) * 0.5, 0.0, (north + south) * 0.5)
	var extent: float = maxf(right - left, south - north)
	target_span = extent * sqrt(2.0) * maxf(sin(PITCH), 1.0 / aspect) * 1.20
	dirty = true

func set_island_circles_visible(enabled: bool) -> bool:
	# Never change discovered cells or reveal terrain; only toggle the
	# ring overlay in the full Diorama map. Not part of the minimap.
	if not has_remote_islands or service.biome.archipelago.terrain == null:
		return false
	show_island_circles = enabled
	if marker_layer != null:
		marker_layer.queue_redraw()
	dirty = true
	return true

func centre_player() -> void:
	target_focus = game.hero.global_position
	target_span = 64.0
	dirty = true

func open_map() -> bool:
	if service.biome == null or not service.in_overworld() or game.hero.in_combat:
		game.hud.toast("Map unavailable in combat or inside a dungeon.")
		return false
	if game.controls != null:
		game.controls.cancel()
	game.hero.stop_interaction_move()
	game.hero.velocity.x = 0
	game.hero.velocity.z = 0
	game.hud._reset_touch()
	game.hud.move_vector = Vector2.ZERO
	fingers.clear()
	screen.show()
	_resize()
	overview()
	focus = target_focus
	view_span = target_span
	_update_camera(map_camera, focus, map_yaw, view_span)
	_search("")
	results.hide()
	relief.schedule(focus)
	dirty = true
	return true

func close_map() -> void:
	if screen == null or not screen.visible:
		return
	screen.hide()
	fingers.clear()
	dragging = false
	rotating = false
	search_box.release_focus()
	game.hud._reset_touch()
	game.hud.move_vector = Vector2.ZERO
	input_guard_until = Time.get_ticks_msec() + 200
	map_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	dirty = true

func is_open() -> bool:
	return screen != null and screen.visible

func _update_camera(camera: Camera3D, at: Vector3, yaw: float, span: float) -> void:
	camera.position = at + Vector3(sin(yaw) * cos(PITCH), sin(PITCH), cos(yaw) * cos(PITCH)) * 600.0
	camera.look_at(at, Vector3.UP)
	camera.size = span

func _process(delta: float) -> void:
	if service.biome == null or game.hero == null:
		return
	if not service.in_overworld():
		if is_open(): close_map()
		game.hud.map_expand_button.hide()
		mini_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	game.hud.map_expand_button.visible = game.hud.minimap.visible
	game.hud.map_expand_button.disabled = game.hero.in_combat
	var blend: float = 1.0 - exp(-12.0 * delta)
	var moving: bool = focus.distance_to(target_focus) > 0.01 or absf(view_span - target_span) > 0.01
	if is_open():
		focus = focus.lerp(target_focus, blend)
		view_span = lerpf(view_span, target_span, blend)
		_update_camera(map_camera, focus, map_yaw, view_span)
	var at: Vector3 = focus if is_open() else game.hero.global_position
	schedule_clock += delta
	if schedule_clock > 0.5 and (relief.seen_revision != service.revision or at.distance_to(last_schedule) > 12):
		schedule_clock = 0
		last_schedule = at
		relief.schedule(at)
	var built: bool = relief.tick()
	mini_clock += delta
	if mini_clock >= 0.12:
		mini_clock = 0
		_update_camera(mini_camera, game.hero.global_position, game.camera_angle, 72.0)
		mini_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		if is_open():
			marker_layer.queue_redraw()
			dirty = true # Updates visibility shading, without rebuilding meshes.
	if is_open() and (dirty or built or moving):
		map_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		marker_layer.queue_redraw()
	dirty = false

func project(point: Vector3) -> Vector2:
	return map_camera.unproject_position(point) * screen.size / Vector2(map_viewport.size)

func ground_at(point: Vector2) -> Vector3:
	var pixel := point * Vector2(map_viewport.size) / screen.size
	var origin := map_camera.project_ray_origin(pixel)
	var direction := map_camera.project_ray_normal(pixel)
	return origin + direction * ((focus.y - origin.y) / direction.y)

func pan(relative: Vector2) -> void:
	var shift := ground_at(screen.size * 0.5) - ground_at(screen.size * 0.5 + relative)
	target_focus += shift
	focus += shift
	dirty = true

func zoom_by(factor: float, cursor: Vector2 = Vector2.INF) -> void:
	var old: float = target_span
	target_span = clampf(target_span * factor, MIN_VIEW_SIZE, maxf(512.0, service.biome.map_world_half * 8.0))
	if cursor != Vector2.INF:
		var anchor := ground_at(cursor)
		target_focus += (anchor - focus) * (1.0 - target_span / old)
	dirty = true

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.device == -1: return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_by(1.0 / 1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_by(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed: press_at = event.position
			elif press_at.distance_to(event.position) < 6: _inspect(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT: rotating = event.pressed
	elif event is InputEventMouseMotion:
		if dragging: pan(event.relative)
		if rotating: map_yaw -= event.relative.x * 0.008; dirty = true
	elif event is InputEventScreenTouch:
		if event.pressed: fingers[event.index] = event.position; press_at = event.position
		else:
			if fingers.size() == 1 and press_at.distance_to(event.position) < 6: _inspect(event.position)
			fingers.erase(event.index)
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var old: Vector2 = fingers[event.index]
		if fingers.size() >= 2:
			for index in fingers:
				if index != event.index:
					var before: float = old.distance_to(fingers[index])
					var after: float = event.position.distance_to(fingers[index])
					if before > 2 and after > 2: zoom_by(before / after)
					break
		else: pan(event.position - old)
		fingers[event.index] = event.position
	map_art.accept_event()

func _inspect(point: Vector2) -> void:
	var record: Dictionary = marker_layer.inspect(point)
	if not record.is_empty():
		footer.text = "%s | %dm" % [record.get("label", "Creature"), roundi(game.hero.global_position.distance_to(record.position))]
	else:
		var at := ground_at(point)
		footer.text = "Unexplored" if service.visibility_at(at) == 0 else "Explored terrain"

func _search(query: String) -> void:
	if results == null: return
	search_results = service.search(query)
	results.clear()
	for record in search_results: results.add_item(record.label)
	results.visible = is_open() and search_box.has_focus()

func _select_result(index: int) -> void:
	if index < 0 or index >= search_results.size(): return
	target_focus = search_results[index].position
	target_span = 64
	results.hide()
	search_box.release_focus()
	dirty = true

func _minimap_hit(point: Vector2) -> bool:
	if service.biome == null or not service.in_overworld() or not game.hud.minimap.visible:
		return false
	# The expand button has absolute input priority where its square slightly
	# overlaps the round map: never move the player when expanding.
	var expand: Button = game.hud.map_expand_button
	if expand != null and expand.visible and expand.get_global_rect().has_point(point):
		return false
	var mini: Control = game.hud.minimap
	var rect: Rect2 = mini.get_global_rect()
	return point.distance_to(rect.get_center()) < minf(rect.size.x, rect.size.y) * 0.5 - 11.0

func _minimap_destination(point: Vector2) -> Vector3:
	# The same real orthographic viewport drives both the circular relief
	# pixels and click-to-move coordinates: no flat-world approximation.
	var mini: Control = game.hud.minimap
	var rect: Rect2 = mini.get_global_rect()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.5 - 11.0
	var normalized: Vector2 = (point - rect.get_center()) / (2.0 * radius) + Vector2(0.5, 0.5)
	var pixel: Vector2 = normalized * Vector2(mini_viewport.size)
	var origin: Vector3 = mini_camera.project_ray_origin(pixel)
	var direction: Vector3 = mini_camera.project_ray_normal(pixel)
	if absf(direction.y) < 0.001:
		return Vector3.INF
	var land: Vector3 = origin + direction * ((game.hero.global_position.y - origin.y) / direction.y)
	if not service.inside(land) or not service.biome.is_land_at(land.x, land.z):
		return Vector3.INF
	return land

func _minimap_move(point: Vector2) -> bool:
	if game.controls == null or game.controls.modal_open() or not _minimap_hit(point):
		return false
	var destination: Vector3 = _minimap_destination(point)
	if not destination.is_finite():
		return false
	# Existing path planner validates solid terrain and obstacles. A failed
	# route must not teleport, reveal map cells or switch to the map view.
	return game.controls.move_to(destination)

func _input(event: InputEvent) -> void:
	if not is_open():
		if Time.get_ticks_msec() < input_guard_until and (event is InputEventMouseButton or event is InputEventScreenTouch):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch and event.device != -1:
			if event.pressed and _minimap_hit(event.position):
				mini_touch_index = event.index
				mini_touch_origin = event.position
				get_viewport().set_input_as_handled()
			elif not event.pressed and event.index == mini_touch_index:
				mini_touch_index = -1
				if event.position.distance_to(mini_touch_origin) < 14.0:
					_minimap_move(event.position)
				get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenDrag and event.index == mini_touch_index:
			# Drags must never issue accidental tap-to-move commands.
			if event.position.distance_to(mini_touch_origin) >= 14.0:
				mini_touch_index = -1
			get_viewport().set_input_as_handled()
			return
		# Android emulates mouse events after real touches; touch above owns
		# movement on mobile so a second synthetic destination is impossible.
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != -1 and not OS.has_feature("mobile") and _minimap_hit(event.position):
			_minimap_move(event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.is_action_pressed("outpost_cancel") or (event.is_action_pressed("outpost_map") and not search_box.has_focus()):
				close_map()
				get_viewport().set_input_as_handled()
				return
		if not search_box.has_focus(): get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open(): close_map()
