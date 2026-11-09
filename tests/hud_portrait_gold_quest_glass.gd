extends SceneTree
## Alpha visual-only portrait pass: gold player name, glassless portrait,
## compact HP/MP bars, gold Quest text and unobtrusive quest panel.
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, detail: String) -> void:
	if ok:
		print("PASS PORTRAIT GOLD: " + detail)
	else:
		failures += 1
		push_error("FAIL PORTRAIT GOLD: " + detail)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Godot world loads with the integrated water/FX build")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var name_label: Label = hud.status
	var status: Panel = hud.hero_status_frame
	var portrait: Panel = hud.hero_portrait_frame
	var hp: ProgressBar = hud.health_bar
	var mana: ProgressBar = hud.mana_bar
	var q_panel: Panel = hud.quest_frame
	var q_label: Label = hud.quest

	verify(name_label != null and name_label.name == "PlayerGoldName", "Gold player-name label is an independently styled widget")
	verify(name_label.get_theme_color("font_color") == SKIN.GOLD, "Name matches inventory's actual gold text")
	verify(name_label.get_theme_constant("outline_size") >= 2, "Gold name stays readable over bright grass")
	var backing: StyleBox = status.get_theme_stylebox("panel")
	verify(backing is StyleBoxFlat, "Player status backing is flat and has no legacy alpha holes")
	if backing is StyleBoxFlat:
		verify((backing as StyleBoxFlat).bg_color.a <= 0.22, "Player status background is almost fully transparent")
		verify((backing as StyleBoxFlat).border_color.a <= 0.18, "Player status border is restrained")
	var portrait_style: StyleBox = portrait.get_theme_stylebox("panel")
	verify(portrait_style is StyleBoxFlat, "Portrait art frame remains independently styleable")
	if portrait_style is StyleBoxFlat:
		verify((portrait_style as StyleBoxFlat).bg_color.a < 0.15, "Portrait has a transparent centre, no opaque square")
		verify((portrait_style as StyleBoxFlat).border_color.a > 0.45, "Gold frame remains recognizable")

	var p: Rect2 = portrait.get_global_rect()
	var h: Rect2 = hp.get_global_rect()
	var m: Rect2 = mana.get_global_rect()
	verify(h.position.x >= p.end.x and h.position.x - p.end.x <= 11.0, "HP starts immediately alongside portrait")
	verify(absf(h.position.x - m.position.x) <= 1.0, "Mana and HP share one aligned left edge")
	verify(absf(h.size.x - m.size.x) <= 1.0, "HP and Mana have matching compact widths")
	verify(h.end.y < m.position.y, "Mana sits beneath health, not on top of it")
	verify(mana.visible and hud.mana_numbers.visible, "Real weapon-skill mana still appears")
	verify(status.get_global_rect().end.x < game.get_viewport().get_visible_rect().size.x * 0.30, "Character chrome stays compact on mobile")

	var q_style: StyleBox = q_panel.get_theme_stylebox("panel")
	verify(q_style is StyleBoxFlat, "Quest uses texture-free alpha-blended frame")
	if q_style is StyleBoxFlat:
		verify((q_style as StyleBoxFlat).bg_color.a <= 0.25, "Quest card is transparent over gameplay")
	verify(q_label.get_theme_color("font_color") == SKIN.GOLD, "Quest objective uses the gold inventory/character text")
	verify(q_label.get_theme_constant("outline_size") >= 2, "Quest objective remains legible on grass")
	verify(hud.quest_toggle.get_theme_color("font_color") == SKIN.GOLD, "Quest toggle matches gold style")
	hud.quest_toggle.pressed.emit()
	verify(hud.quest_detail.visible and hud.quest_detail_back.visible, "Quest still expands through the original functional button")
	hud.quest_toggle.pressed.emit()
	verify(not hud.quest_detail.visible, "Quest collapses through the original button")

	verify(absf(hud.xp_bar.get_global_rect().end.y - game.get_viewport().get_visible_rect().size.y) < 1.1, "XP remains flush to the bottom, untouched")
	verify(game.menu.inventory_window != null and game.mana_limit() == 35.0, "Integrated inventory and mana systems are preserved")
	game.queue_free()
	await process_frame
	print("PORTRAIT GOLD RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
