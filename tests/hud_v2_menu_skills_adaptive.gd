extends SceneTree
## Regression for real Android first-tap MENU, skill layout and adaptive thumbstick.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, msg: String) -> void:
	if ok:
		print("PASS HUD POLISH: " + msg)
	else:
		failures += 1
		push_error("FAIL HUD POLISH: " + msg)

func _touch(hud: Node, pressed: bool, pos: Vector2, idx: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = idx
	event.pressed = pressed
	event.position = pos
	hud._input(event)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "World scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var button: Button = hud.menu_button
	var position: Vector2 = button.get_global_rect().get_center()
	_touch(hud, true, position, 22)
	verify(hud.top_menu_open, "First Menu finger-down opens the real popup")
	_touch(hud, false, position, 22)
	verify(hud.top_menu_open, "Lifting the same finger never closes MENU")
	_touch(hud, true, Vector2(8, 480), 23)
	_touch(hud, false, Vector2(8, 480), 23)
	verify(hud.top_menu_open, "An outside release never dismisses Menu accidentally")
	hud.top_menu_close_button.pressed.emit()
	verify(not hud.top_menu_open, "The proper red X still closes Menu")

	hud._show_skill_details()
	verify(hud.skill_detail_panel.visible, "Skills page opens")
	verify(hud.skill_detail_panel.get_theme_stylebox("panel") is StyleBoxFlat, "Skills uses new shared modal frame")
	verify(hud.skill_mastery_bar != null and hud.skill_mastery_bar.max_value == 60.0, "Real mastery rank is based on actual 60-XP progression")
	verify(hud.skill_slot_rows.size() == 3, "Skill page has three framed ability slots")
	verify(hud.skill_slot_rows[0].text.contains("POWER STRIKE") and hud.skill_slot_rows[0].text.contains("UNLOCKED"), "Existing first ability is live and unlocked")
	verify(hud.skill_slot_rows[2].text.contains("RANK 5"), "Third ability correctly displays actual unlock rank")
	hud.skill_detail_panel.visible = false

	hud._set_floating_mode(false)
	hud._set_adaptive_joystick(true)
	verify(hud.adaptive_joystick_enabled and hud.adaptive_joystick_toggle.button_pressed, "Adaptive joystick setting is on and reflected in controls")
	hud._position_stick()
	var original: Vector2 = hud._center()
	var off_centre: Vector2 = original + Vector2(124, -12)
	verify(hud._adaptive_stick_zone(off_centre), "Slightly off-centre lower-left touch is eligible")
	verify(not hud._can_start_camera_drag(off_centre), "Adaptive movement touch cannot be stolen by camera rotation")
	_touch(hud, true, off_centre, 62)
	verify(hud.finger == 62 and hud._center().distance_to(off_centre) <= 15.0, "Joystick recentres to finger on the first touch")
	var slide := InputEventScreenDrag.new()
	slide.index = 62
	slide.position = off_centre + Vector2(32, -14)
	hud._input(slide)
	verify(hud.move_vector.length() > 0.15, "Off-centre joystick still controls movement")
	_touch(hud, false, slide.position, 62)
	verify(hud.finger == -1 and hud.move_vector == Vector2.ZERO, "Releasing stick ends movement normally")
	verify(hud._center().distance_to(original) < 1.5, "Fixed adaptive stick returns to its home when released")
	hud._set_adaptive_joystick(false)
	verify(not hud._adaptive_stick_zone(off_centre), "Disabling adaptive preserves classic fixed stick")
	hud._set_floating_mode(true)
	verify(hud.floating_joystick_enabled and hud._floating_zone(off_centre), "Existing fully floating joystick remains an independent mode")
	hud._set_floating_mode(false)
	game.queue_free()
	await process_frame
	print("HUD POLISH RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
