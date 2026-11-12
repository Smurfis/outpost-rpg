extends SceneTree
## Alpha regression: one fixed target name + HP plate replaces combat hints
## on Android and PC, and reads real current/maximum creature health.
const GUARDIAN = preload("res://scripts/dungeons/dungeon_guardian.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, description: String) -> void:
	if ok:
		print("PASS ENEMY TARGET FRAME: " + description)
	else:
		failures += 1
		push_error("FAIL ENEMY TARGET FRAME: " + description)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	root.set_meta("outpost_input_mode", "touch")
	var packed: PackedScene = load("res://scenes/main.tscn")
	verify(packed != null, "Playable world loads")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	game.save_path = "user://target_frame_alpha_test.json"
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var frame: Control = hud.enemy_target_frame
	verify(frame != null and frame.name == "EnemyTargetFrame", "Single fixed target plate is installed")
	verify(hud.root.get_node_or_null("FocusedEnemyInfo") == null, "Legacy text-only focused enemy HUD is removed")
	verify(frame.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Target frame cannot consume movement or attack touches")
	var boars: Array[Node] = get_nodes_in_group("wild_boars")
	verify(not boars.is_empty(), "Live overworld creatures are present")
	if boars.is_empty():
		game.queue_free()
		quit(1)
		return
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var boar = boars[0]
	game.hero.global_position = boar.global_position + Vector3(1.0, 0, 0)
	game.focus_target = null
	game.recent_target_seconds = 0.0
	hud._update_enemy_target_frame()
	verify(frame.visible and frame.name_label.text == "Wild boar", "Nearest creature name sits above health bar")
	verify(is_equal_approx(frame.bar.value, 100.0), "Unhurt creature shows full bar")
	verify(frame.damage_trail != null and frame.bar != null, "Crimson health meter has its own delayed-damage layer")
	verify(frame.get_global_rect().get_center().x > root.get_visible_rect().size.x * 0.40 and
		frame.get_global_rect().get_center().x < root.get_visible_rect().size.x * 0.60,
		"Health frame stays centred in screen space")
	boar.hp = boar.max_hp * 0.5
	hud._update_enemy_target_frame()
	frame._process(0.5)
	verify(absf(frame.bar.value - 50.0) < 0.1, "Visible bar reads actual boar health, not a guessed maximum")
	verify(frame.name_label.text == "Wild boar", "Health updates do not replace name with HP prose")
	var wolf = get_first_node_in_group("wild_wolves")
	if wolf != null:
		wolf.global_position = game.hero.global_position + Vector3(0.4, 0, 0)
		hud._update_enemy_target_frame()
		verify(frame.name_label.text == "Wolf", "Closest wolf takes priority without focus")
		game.remember_attacked_enemy(boar)
		hud._update_enemy_target_frame()
		verify(frame.name_label.text == "Wild boar", "Recently hit target overrides nearest creature")
		game.recent_target_seconds = 0.0
		game.focus_target = wolf
		hud._update_enemy_target_frame()
		verify(frame.name_label.text == "Wolf", "Explicit focus overrides automatic nearest")
		game.focus_target = null
		wolf.global_position = game.hero.global_position + Vector3(30.0, 0, 0)
	game.recent_target_seconds = 0.0
	boar.alive = false
	hud._update_enemy_target_frame()
	verify(not frame.visible or frame.name_label.text != "Wild boar", "Dead enemies never leave a stale HUD target")
	var guardian = GUARDIAN.new()
	guardian.set_physics_process(false)
	game.add_child(guardian)
	guardian.add_to_group("enemies")
	guardian.add_to_group("dungeon_guardians")
	guardian.name = "DungeonBoss"
	guardian.global_position = game.hero.global_position + Vector3(0.5, 0, 0)
	guardian.quality = 3
	guardian.display_name = "Brutal Ancient Warden"
	guardian.hp = 75.0
	guardian.max_hp = 300.0
	var record: Dictionary = game.target_frame_data(guardian)
	verify(record.get("name") == "Brutal Ancient Warden" and record.get("rank") == "BOSS", "Boss name and rarity come from real guardian stats")
	verify(is_equal_approx(float(record.get("max_hp")), 300.0), "Scaled boss maximum health is retained")
	hud._update_enemy_target_frame()
	frame._process(0.5)
	verify(frame.visible and frame.rank_label.text == "BOSS" and absf(frame.bar.value - 25.0) < 0.1,
		"Boss target draws an elite framed quarter-health bar")
	guardian.queue_free()
	boar.global_position = game.hero.global_position + Vector3(40.0, 0, 0)
	hud._update_enemy_target_frame()
	verify(not frame.visible, "Target frame disappears outside creature radar range")
	game.queue_free()
	await process_frame
	print("ENEMY TARGET FRAME RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
