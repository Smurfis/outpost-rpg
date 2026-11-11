extends SceneTree
const PICK = preload("res://scripts/interaction/world_picker.gd")
const INSPECT = preload("res://scripts/interaction/inspection.gd")
var failures: int = 0
var game

func _initialize() -> void:
	call_deferred("run")

func verify(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL PC CONTROLS: " + message)
	else:
		print("PASS PC CONTROLS: " + message)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = Vector2(1, 0)
	root.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	root.set_meta("outpost_input_mode", "desktop")
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://pc-controls-test.json"
	root.add_child(game)
	await physics_frame
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	verify(game.controls.desktop and not game.hud.joystick.visible, "PC hides joystick")
	verify(game.hud.quick_buttons.size() == 5, "Exactly three abilities and two consumable slots")
	var a: Rect2 = game.hud.quick_buttons.skill_3.get_global_rect()
	var b: Rect2 = game.hud.smart_button.get_global_rect()
	verify(a.end.x < b.position.x and a.get_center().x < root.get_visible_rect().size.x * 0.5, "Ability row precedes centred Interact")
	verify(InputMap.action_get_events("outpost_interact").is_empty(), "E never binds general interaction")
	verify(InputMap.action_get_events("outpost_jump")[0].physical_keycode == KEY_SPACE, "Space jumps")
	await key(KEY_I)
	verify(game.menu.visible and game.menu.current_page == "bag", "I opens inventory through real input")
	await key(KEY_ESCAPE)
	verify(not game.menu.visible, "Escape closes inventory")
	await key(KEY_C)
	verify(game.menu.visible and game.menu.current_page == "equipment", "C opens equipment")
	await key(KEY_ESCAPE)
	await key(KEY_K)
	verify(game.hud.skill_detail_panel.visible, "K opens Skills")
	await key(KEY_ESCAPE)
	verify(not game.hud.skill_detail_panel.visible, "Escape closes Skills")
	await key(KEY_ESCAPE)
	verify(game.hud.top_menu_open, "Escape opens game menu")
	await key(KEY_ESCAPE)
	verify(not game.hud.top_menu_open, "Escape closes game menu")
	await create_timer(0.7).timeout
	game.hero.global_position = Vector3(0, 0.2, -3)
	game._camera(1.0)
	await physics_frame
	var point := Vector3(0, -0.05, -8)
	var screen: Vector2 = game.camera.unproject_position(point)
	var hit: Dictionary = PICK.resolve(game, screen)
	print("DEBUG ground: ", screen, " modal=", game.controls.modal_open(), " menu=", game.menu.visible, " top=", game.hud.top_menu_open, " skills=", game.hud.skill_detail_panel.visible, " settings=", game.hud.control_settings_panel.visible, " leave=", game.hud.leave_menu_panel.visible, " ui=", game.controls.point_over_ui(screen), " target=", hit.get("target"), " at=", hit.get("position"))
	verify(not hit.is_empty(), "World ray resolves real terrain")
	await click(screen)
	verify(game.controls.navigating, "Ground click starts navigation")
	verify(game.get_node_or_null("GoldMoveMarker") != null, "Accepted click creates open gold ring")
	for i in range(120):
		await physics_frame
		if not game.controls.navigating:
			break
	verify(Vector2(game.hero.position.x - point.x, game.hero.position.z - point.z).length() < 0.6, "Physics navigation reaches actual clicked ground")
	game.controls.move_to(Vector3(4, 0, -6))
	Input.action_press("outpost_left")
	await physics_frame
	await physics_frame
	verify(not game.controls.navigating and not game.hero.interaction_moving, "Manual directional input cancels route")
	Input.action_release("outpost_left")
	verify(not game.controls.move_to(Vector3(500, 0, 500)), "Unreachable destination rejects bounded route")
	var enemy = get_first_node_in_group("enemies")
	enemy.global_position = game.hero.global_position + Vector3(1.5, 0, 0)
	await key(KEY_TAB)
	verify(game.focus_target == enemy, "Tab focuses nearest enemy")
	var hp: float = enemy.hp
	game.attack_delay = 0
	game.controls.approach(enemy)
	await physics_frame
	await physics_frame
	verify(enemy.hp < hp and game.focus_target == enemy, "Click-target action uses existing basic attack")
	game.controls.cancel()
	game.weapon_mastery_xp[game.current_weapon_id()] = 240
	game.attack_delay = 0
	hp = enemy.hp
	await key(KEY_1)
	verify(enemy.hp < hp and game.mana < game.MAX_MANA and not game.skill_cooldowns.is_empty(), "Ability 1 spends mana and uses cooldown")
	game.hero.health = 20
	game.inventory.tonic = 2
	game.inventory.cooked_shrimp = 2
	game.set_quick_consumable("potion", "tonic")
	game.set_quick_consumable("consumable", "cooked_shrimp")
	await key(KEY_Q)
	verify(game.inventory.tonic == 1 and game.quick_use_cooldowns.potion > 0, "Q uses inventory potion with recovery")
	await key(KEY_Q)
	verify(game.inventory.tonic == 1, "Recovery prevents repeated consumption")
	game.hero.health = 40
	await key(KEY_E)
	verify(game.inventory.cooked_shrimp == 1 and game.hero.health >= 70, "E consumes assigned cooked shrimp")
	var tree: Node3D
	for resource in get_nodes_in_group("resources"):
		if resource.kind == "wood" and resource.bundle_count == 1:
			tree = resource
			break
	game.hero.global_position = tree.global_position + Vector3(2.4, 0.1, 0)
	game.focus_target = null
	game.gather_delay = 0
	game.inventory.axe = 1
	var wood: int = game.inventory.wood
	game.controls.approach(tree)
	await physics_frame
	await physics_frame
	verify(game.inventory.wood == wood + 2 and tree.hits_left == 2, "Exact clicked tree gathers with owned tool")
	game.controls.cancel()
	verify(INSPECT.world(game, tree).contains("Chop"), "Shared hover/hold inspection describes gathering")
	game._camera(1.0)
	await physics_frame
	game.controls.inspect_at(game.camera.unproject_position(tree.global_position + Vector3.UP * 1.0))
	verify(game.controls.tooltip.visible, "World hover shows inspection tooltip")
	var yaw: float = game.camera_angle_target
	var mouse := InputEventMouseButton.new()
	mouse.position = Vector2(500, 300)
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await process_frame
	var drag := InputEventMouseMotion.new()
	drag.position = mouse.position + Vector2(40, 0)
	drag.relative = Vector2(40, 0)
	Input.parse_input_event(drag)
	await process_frame
	verify(game.camera_angle_target != yaw and not game.controls.navigating, "RMB drag rotates without interacting")
	mouse.pressed = false
	Input.parse_input_event(mouse)
	var zoom: float = game.camera.size
	await click(Vector2(500, 300), MOUSE_BUTTON_WHEEL_UP)
	verify(game.camera.size < zoom, "Wheel zoom works")
	# Real GUI hit detection: actual mouse press/release, no signal emission.
	game.hero.global_position = game.station_positions.workbench + Vector3(0, 0.1, -2.7)
	game.inventory.fiber = 10
	game.show_crafting()
	await process_frame
	await process_frame
	var button: Button = find_button(game.menu, "Shrimp Net")
	verify(button != null, "Crafting recipe exposes mouse button")
	if button != null:
		var parent: Node = button.get_parent()
		while parent != null and not parent is ScrollContainer:
			parent = parent.get_parent()
		if parent is ScrollContainer:
			parent.ensure_control_visible(button)
			await process_frame
		await click(button.get_global_rect().get_center())
		verify(game.menu.selected_id == "shrimp_net", "Mouse selects Shrimp Net recipe")
	verify(not game.controls.navigating, "Crafting UI clicks cannot move or attack")
	game.menu.close_page()
	game.controls.set_desktop(false)
	game.hud.floating_joystick_enabled = false
	game.hud._position_stick()
	verify(game.hud.joystick.visible, "Touch mode restores virtual joystick")
	verify(not game.hud.desktop_mode, "Touch switches the HUD into mobile mode")
	verify(game.hud.smart_button.size.x >= 110.0, "Mobile restores its large finger-sized Interact button")
	var top_skill: Rect2 = game.hud.quick_buttons.skill_1.get_global_rect()
	var lower_skill: Rect2 = game.hud.quick_buttons.skill_3.get_global_rect()
	verify(top_skill.get_center().y < lower_skill.get_center().y and top_skill.get_center().x > lower_skill.get_center().x, "Mobile skills return to a radial combat arc rather than the PC action row")
	verify(not game.hud.focus_button.visible, "Desktop-only target button is hidden on touch")
	verify(game.hud.quick_buttons.potion.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Mobile potion uses hold-and-slide touch handling")
	var shortcut: Label = game.hud.quick_buttons.skill_1.get_node_or_null("KeyboardShortcut") as Label
	verify(shortcut != null and not shortcut.visible, "Mobile hides keyboard shortcut hints")
	game.controls.set_desktop(true)
	verify(not game.hud.joystick.visible and game.hud.focus_button.visible, "Switching back to PC restores the desktop action UI")
	game.controls.set_desktop(false)
	verify(game.hud.smart_button.size.x >= 110.0, "Second mobile activation retains its large Interact target")
	game.queue_free()
	await process_frame
	await process_frame
	print("PC CONTROLS RESULT: %d failures" % failures)
	quit(1 if failures else 0)

func find_button(node: Node, title: String) -> Button:
	if node is Button and node.is_visible_in_tree():
		if node.text.contains(title) or node.tooltip_text.contains(title):
			return node
		for child in node.get_children():
			if child is Label and child.text.contains(title):
				return node
	for child in node.get_children():
		var found: Button = find_button(child, title)
		if found != null:
			return found
	return null
