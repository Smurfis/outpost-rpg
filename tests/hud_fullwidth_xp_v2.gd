extends SceneTree
## Pixel Fantasy V2: full-width character-level XP at the LAST screen Y.
## Assertions also exercise generated 20:9 anchor geometry without altering
## gameplay viewport, camera, or mobile touch controls.
var failures: int = 0

func verify(ok: bool, message: String) -> void:
	if ok:
		print("PASS EDGE XP: " + message)
	else:
		failures += 1
		push_error("FAIL EDGE XP: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Game imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var view: Vector2 = hud.get_viewport().get_visible_rect().size
	hud._layout_touch_hud()
	await process_frame
	var bar: ProgressBar = hud.xp_bar
	var bounds: Rect2 = bar.get_global_rect()
	verify(absf(bounds.position.x) <= 1.0, "XP starts at x=0")
	verify(absf(bounds.end.x - view.x) <= 1.0, "XP ends at viewport width")
	verify(absf(bounds.end.y - view.y) <= 1.0, "XP ends exactly at bottom Y")
	verify(bounds.size.y >= 16.0 and bounds.size.y <= 23.0, "XP stays slim on Android")
	verify(bar.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud.xp_bar_divisions.mouse_filter == Control.MOUSE_FILTER_IGNORE, "No touch control is intercepted by XP visuals")
	verify(hud.xp_bar_divisions.get_parent() == bar, "Segmentation scales with the actual XP bar")
	verify(hud.radial_level != null and not hud.radial_level.visible, "No persistent giant radial level icon")
	verify(hud.xp_level_badge.visible and not bar.get_global_rect().intersects(hud.xp_level_badge.get_global_rect()), "Character level badge is no longer inside bottom XP")
	verify(hud.hero_portrait_frame.get_global_rect().grow(12.0).intersects(hud.xp_level_badge.get_global_rect()), "Character level appears beside player portrait")
	verify(absf(hud.xp_level_label.get_global_rect().get_center().x - view.x * 0.5) < 1.0, "XP progress text is centred over full-width bottom bar")
	hud.render_status(100.0, {"wood": 3, "coins": 2}, 94, 0, "training_blade", "", "")
	var level_info: Dictionary = game.level_state()
	var left: int = maxi(0, int(level_info.get("required", 100)) - int(level_info.get("current", 0)))
	verify(hud.xp_level_label.text.contains(str(int(level_info.get("current", 0)))) and not hud.xp_level_label.text.contains("TO NEXT"), "Slim XP strip shows actual progress without the long textual countdown")
	verify(hud.xp_level_badge.text == str(int(level_info.get("level", 1))), "Portrait badge shows the actual character rank without repeating Lv. on bottom XP")
	verify(hud.trained_skill_orb != null and hud.trained_skill_orb.skill_id == "training_blade", "A radial skill icon shows the currently trained ability")
	verify((bar.get_theme_stylebox("background") as StyleBoxFlat).bg_color.a < 0.5, "XP strip uses a transparent backing")
	for screen in [Vector2(1280, 720), Vector2(2400, 1080)]:
		var scale: float = clampf(minf(screen.x / 1280.0, screen.y / 720.0), 0.8, 1.2)
		hud._layout_xp_for_size(screen, scale)
		verify(is_zero_approx(bar.anchor_left) and is_equal_approx(bar.anchor_right, 1.0), "Correct full-width anchors at %s" % screen)
		verify(is_equal_approx(bar.anchor_bottom, 1.0), "Correct bottom anchor at %s" % screen)
		var required_height: float = clampf(18.0 * scale, 17.0, 23.0)
		verify(absf((bar.anchor_bottom - bar.anchor_top) * screen.y - required_height) < 0.1, "Pixel-sized height on %s" % screen)
		verify(hud.trained_skill_orb.get_parent() == hud.skill_detail_panel and not hud.trained_skill_orb.is_visible_in_tree(),
			"Mastery radial is in the Skills panel, not behind movement joystick at %s" % screen)
		verify(absf(hud.trained_skill_orb.size.x - 52.0) < 2.0, "Mastery radial is 52px within its own modal")
	hud._layout_touch_hud()
	verify(not game.menu.visible and hud.smart_button != null, "Gameplay and smart action are preserved")
	game.queue_free()
	await process_frame
	print("EDGE XP RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
