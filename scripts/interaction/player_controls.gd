extends Node
## Mouse and touch are adapters for the same range-checked gameplay actions.
const PICKER = preload("res://scripts/interaction/world_picker.gd")
const INSPECT = preload("res://scripts/interaction/inspection.gd")
const PATH = preload("res://scripts/navigation/crafting_station_path.gd")
const MARKER = preload("res://scripts/vfx/move_marker.gd")
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
const REPATH_SECONDS: float = 0.35
var game
var desktop: bool = true
var target: Node3D
var navigating: bool = false
var destination := Vector3.ZERO
var route_age: float = 0.0
var stalled: float = 0.0
var last_position := Vector3.ZERO
var repath_left: float = 0.0
var hold_ground: bool = false
var rotating: bool = false
var ignore_mouse_until: int = 0
var hover_elapsed: float = 0.0
var inspected: Node3D
var tooltip: PanelContainer
var tooltip_label: Label
var highlight: MeshInstance3D

func setup(ref: Node) -> void:
	game = ref
	var preferred: String = str(get_tree().root.get_meta("outpost_input_mode", OS.get_environment("OUTPOST_INPUT_MODE")))
	desktop = preferred != "touch" if preferred != "" else OS.get_name() != "Android"
	_build_inspection()
	game.hud.set_desktop_mode(desktop)

func set_desktop(value: bool) -> void:
	if desktop == value:
		return
	desktop = value
	hold_ground = false
	rotating = false
	game.hud._reset_touch()
	game.hud.set_desktop_mode(desktop)
	hide_inspection()

func modal_open() -> bool:
	var hud = game.hud
	var dungeon = game.get_node_or_null("Dungeons")
	return (game.menu != null and game.menu.visible) or (game.coop != null and game.coop.ui != null and game.coop.ui.visible) or hud.top_menu_open or hud.control_settings_panel.visible or hud.skill_detail_panel.visible or hud.leave_menu_panel.visible or (dungeon != null and dungeon.dimmer != null and dungeon.dimmer.visible) or game.hero.interaction_locked

func point_over_ui(point: Vector2) -> bool:
	return modal_open() or _ui_at(get_tree().root, point)

func _ui_at(node: Node, point: Vector2) -> bool:
	if node == tooltip:
		return false
	if node is CanvasLayer and not node.visible:
		return false
	if node is SubViewport:
		return false
	if node is Control:
		if not node.is_visible_in_tree():
			return false
		if (node.mouse_filter != Control.MOUSE_FILTER_IGNORE or node.name in ["HeroStatusFrame", "PlayerPortrait", "QuestTracker", "WorldMinimap"]) and node.get_global_rect().has_point(point):
			return true
	for child in node.get_children():
		if _ui_at(child, point):
			return true
	return false

func _input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.device == -1:
			return # Godot's mouse-to-touch emulation must not enable mobile HUD.
		ignore_mouse_until = Time.get_ticks_msec() + 650
		set_desktop(false)
	elif event is InputEventMouse:
		# Android emits synthetic mouse input for some real screen taps. A
		# delayed compatibility event must never flip the phone back to PC UI.
		if OS.has_feature("mobile"):
			return
		if event.device == -1 or Time.get_ticks_msec() < ignore_mouse_until:
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length_squared() > 0):
			set_desktop(true)
	elif event is InputEventKey and event.pressed and not event.echo:
		if not OS.has_feature("mobile"):
			set_desktop(true)
		if event.is_action_pressed("outpost_cancel"):
			close_interface()
			get_viewport().set_input_as_handled()
			return
	# Releases must always clear gestures, including over UI or outside a modal.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			hold_ground = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = false
	if event is InputEventMouseMotion and rotating:
		if not modal_open():
			game.drag_camera(event.relative.x)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if modal_open():
			return
		var actions: Array[String] = ["ability_1", "ability_2", "ability_3", "potion", "food", "tool_cycle", "bag", "character", "skills", "focus", "interact"]
		for action in actions:
			if event.is_action_pressed("outpost_" + action):
				game.perform_action(action)
				get_viewport().set_input_as_handled()
				return
	if not desktop or modal_open():
		return
	if event is InputEventMouseButton and event.pressed:
		if point_over_ui(event.position):
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not rotating:
					primary_at(event.position)
			MOUSE_BUTTON_RIGHT:
				rotating = true
				hold_ground = false
			MOUSE_BUTTON_WHEEL_UP:
				game.camera.size = clampf(game.camera.size - 1.5, 10.0, 32.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				game.camera.size = clampf(game.camera.size + 1.5, 10.0, 32.0)
		get_viewport().set_input_as_handled()

func primary_at(screen: Vector2, allow_hold: bool = true) -> bool:
	if point_over_ui(screen):
		return false
	var hit: Dictionary = PICKER.resolve(game, screen)
	if hit.is_empty():
		cancel()
		return false
	var clicked: Node3D = hit.get("target")
	if clicked != null:
		return approach(clicked)
	if (hit.normal as Vector3).y < 0.7:
		cancel()
		game.hud.toast("That surface cannot be reached.")
		return false
	var accepted: bool = move_to(hit.position)
	hold_ground = accepted and desktop and allow_hold
	return accepted

func move_to(point: Vector3) -> bool:
	cancel()
	destination = point
	if not _plan(0.0):
		return false
	var marker = MARKER.new()
	game.add_child(marker)
	marker.global_position = point + Vector3.UP * 0.06
	return true

func approach(clicked: Node3D) -> bool:
	cancel()
	if not game.target_available(clicked):
		return false
	# Crafting stations already have a specialised proven A-star route that
	# stops outside their solid collider and opens the correct recipe window.
	# The generic world planner can reject dense camp geometry as unreachable.
	# Use the same station journey for both touch taps and desktop clicks.
	if clicked.is_in_group("stations"):
		return game.visit_crafting_station(str(clicked.station_id))
	target = clicked
	if target.is_in_group("enemies"):
		game.focus_target = target
	else:
		game.focus_target = null
	destination = target.global_position
	if game.target_in_range(target):
		navigating = true
		return true
	return _plan(game.target_range(target))

func _plan(reach: float) -> bool:
	var path: PackedVector3Array = PATH.plan_world(game, game.hero.global_position, destination, reach)
	if path.is_empty():
		cancel()
		game.hud.toast("No safe route to that location.")
		return false
	navigating = true
	last_position = game.hero.global_position
	repath_left = REPATH_SECONDS
	game.hero.move_along_station_path(path)
	return true

func cancel() -> void:
	target = null
	navigating = false
	hold_ground = false
	route_age = 0.0
	stalled = 0.0
	if game != null and game.hero != null:
		game.hero.stop_interaction_move()
		game.cancel_station_walk()

func _physics_process(delta: float) -> void:
	if game == null:
		return
	var manual: bool = Input.get_vector("outpost_left", "outpost_right", "outpost_up", "outpost_down").length() > 0.15 or game.hud.move_vector.length() > 0.15
	if modal_open() or manual:
		if navigating or hold_ground:
			cancel()
		return
	repath_left = maxf(0.0, repath_left - delta)
	if navigating:
		route_age += delta
		if route_age > 22.0:
			_fail_route()
			return
		if target != null:
			if not game.target_available(target):
				cancel()
				return
			if game.target_in_range(target):
				game.hero.stop_interaction_move()
				if game.target_on_cooldown(target):
					return
				var arrived: Node3D = target
				var remaining: int = int(arrived.hits_left) if arrived.is_in_group("resources") else -1
				game.interact_target(arrived)
				if arrived.is_in_group("resources"):
					if not arrived.active or int(arrived.hits_left) == remaining:
						cancel()
				elif not arrived.is_in_group("enemies") or not game.target_available(arrived):
					cancel()
				return
			if target.global_position.distance_to(destination) > 1.0 and repath_left <= 0.0:
				destination = target.global_position
				if not _plan(game.target_range(target)):
					return
		if not game.hero.interaction_moving:
			if target != null:
				_fail_route()
			else:
				navigating = false
		elif game.hero.global_position.distance_to(last_position) > 0.15:
			last_position = game.hero.global_position
			stalled = 0.0
		else:
			stalled += delta
			if stalled > 1.5:
				_fail_route()
	if hold_ground and repath_left <= 0.0 and not rotating:
		var screen: Vector2 = get_viewport().get_mouse_position()
		if point_over_ui(screen):
			hold_ground = false
		else:
			var hit: Dictionary = PICKER.resolve(game, screen)
			if not hit.is_empty() and hit.get("target") == null and (hit.position as Vector3).distance_to(destination) > 1.0:
				primary_at(screen)
			repath_left = REPATH_SECONDS

func _fail_route() -> void:
	cancel()
	game.hud.toast("Movement stopped: destination is unreachable.")

func close_interface() -> void:
	cancel()
	game.focus_target = null
	hide_inspection()
	var hud = game.hud
	var dungeon = game.get_node_or_null("Dungeons")
	if dungeon != null and dungeon.dimmer != null and dungeon.dimmer.visible:
		dungeon._cancel_dialog()
	elif game.menu.visible:
		game.menu.close_page()
	elif hud.skill_detail_panel.visible:
		hud._close_skill_details()
	elif hud.control_settings_panel.visible:
		hud._close_control_settings()
	elif hud.leave_menu_panel.visible:
		hud._close_leave_menu()
	elif game.coop != null and game.coop.ui != null and game.coop.ui.visible:
		game.coop.ui.hide()
	else:
		hud._set_top_menu(not hud.top_menu_open)

func _build_inspection() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	tooltip = PanelContainer.new()
	tooltip.name = "SharedInspection"
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_theme_stylebox_override("panel", SKIN.translucent_surface(false, false, true))
	layer.add_child(tooltip)
	tooltip_label = Label.new()
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.add_theme_font_size_override("font_size", 16)
	tooltip_label.add_theme_color_override("font_color", SKIN.CREAM)
	tooltip.add_child(tooltip_label)
	tooltip.hide()
	highlight = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.68
	ring.outer_radius = 0.71
	ring.rings = 4
	ring.ring_segments = 16
	highlight.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.86, 0.72, 0.41, 0.55)
	highlight.material_override = mat
	game.add_child(highlight)
	highlight.hide()

func inspect_at(screen: Vector2) -> void:
	if point_over_ui(screen):
		hide_inspection()
		return
	var hit: Dictionary = PICKER.resolve(game, screen)
	inspected = hit.get("target")
	if not is_instance_valid(inspected):
		hide_inspection()
		return
	show_tip(INSPECT.world(game, inspected), screen)
	highlight.global_position = inspected.global_position + Vector3.UP * 0.07
	highlight.show()
	if desktop:
		Input.set_default_cursor_shape(Input.CURSOR_CROSS if inspected.is_in_group("enemies") else Input.CURSOR_POINTING_HAND)

func show_tip(message: String, screen: Vector2) -> void:
	tooltip_label.text = message
	tooltip.reset_size()
	tooltip.position = (screen + Vector2(18, 18)).clamp(Vector2(8, 8), get_viewport().get_visible_rect().size - tooltip.size - Vector2(8, 8))
	tooltip.show()

func hide_inspection() -> void:
	inspected = null
	if tooltip != null:
		tooltip.hide()
	if highlight != null:
		highlight.hide()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _process(delta: float) -> void:
	if game == null:
		return
	hover_elapsed += delta
	if modal_open():
		hide_inspection()
	elif desktop and hover_elapsed >= 0.10:
		hover_elapsed = 0.0
		inspect_at(get_viewport().get_mouse_position())
	elif not desktop and is_instance_valid(inspected) and not inspected.is_visible_in_tree():
		hide_inspection()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		rotating = false
		cancel()
		hide_inspection()
