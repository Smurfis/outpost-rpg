extends SceneTree
## Live gameplay contract: genuine mastery gates, two-skill semantics,
## Whirlwind hitting each nearby enemy once, timed vulnerability and sword trail.
const LEVELS = preload("res://scripts/progression/character_levels.gd")
const DUMMY = preload("res://tests/support/ability_dummy.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if ok:
		print("PASS WEAPON ABILITIES: " + note)
	else:
		failures += 1
		push_error("FAIL WEAPON ABILITIES: " + note)

func spawn_target(game: Node3D, position_at: Vector3) -> Node3D:
	var target: Node3D = DUMMY.new() as Node3D
	game.add_child(target)
	target.global_position = position_at
	return target

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	root.set_meta("outpost_input_mode", "touch")
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Real Outpost scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	game.save_path = "user://weapon_abilities_alpha_test.json"
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var weapon: String = game.current_weapon_id()
	check(LEVELS.WEAPON_SKILLS == ["power_strike", "armor_break", "whirlwind"], "Slot order is Heroic Strike, Armour Break, Whirlwind")
	check(LEVELS.MASTERY_UNLOCK_RANKS == [1, 3, 5], "Unlocks occur at weapon mastery levels 1, 3 and 5")
	check(game.unlocked_skill_slots() == 1, "Heroic is first and available from mastery level 1")
	hud._refresh_quick_radials()
	check((hud.quick_buttons.skill_1.get_node("ActionLabel") as Label).text == "HEROIC", "Heroic Strike is the first ability displayed")
	check((hud.quick_buttons.skill_2.get_node("ActionLabel") as Label).text == "LV 3", "Armour Break tells the player its next unlock level")
	check((hud.quick_buttons.skill_3.get_node("ActionLabel") as Label).text == "LV 5", "Whirlwind shows its weapon level 5 requirement")
	game.weapon_mastery_xp[weapon] = 120
	hud._refresh_quick_radials()
	check(game.unlocked_skill_slots() == 2, "Armour Break unlocks at weapon level 3")
	check((hud.quick_buttons.skill_2.get_node("ActionLabel") as Label).text == "BREAK", "Second ability shows Armour Break when unlocked")
	game.weapon_mastery_xp[weapon] = 240
	hud._refresh_quick_radials()
	check(game.unlocked_skill_slots() == 3 and (hud.quick_buttons.skill_3.get_node("ActionLabel") as Label).text == "WHIRL", "Whirlwind unlocks at weapon level 5")
	check((hud.quick_buttons.skill_3.get_node("ActionIcon") as TextureRect).texture.resource_path.ends_with("/whirlwind.svg"), "Whirlwind uses its own gold spinning-sword icon")
	hud._show_skill_details()
	check(hud.skill_detail_text.text.contains("WEAPON LV 5") or hud.skill_detail_text.text.contains("Weapon Lv 5"), "Skills screen shows actual weapon mastery level")
	check(hud.skill_slot_rows[1].text.contains("ARMOR BREAK") and hud.skill_slot_rows[2].text.contains("WHIRLWIND"), "Skills panel lists the exact second and third abilities")
	hud._close_skill_details()

	# Isolate combat from the starting boars. No focus is needed for Whirlwind.
	game.hero.global_position = Vector3(73.0, 5.0, 73.0)
	var center: Vector3 = game.hero.global_position
	var near_a: Node3D = spawn_target(game, center + Vector3(1.2, 0, 0))
	var near_b: Node3D = spawn_target(game, center + Vector3(-2.3, 0, 1.1))
	var far: Node3D = spawn_target(game, center + Vector3(5.1, 0, 0))
	var above: Node3D = spawn_target(game, center + Vector3(0.6, 3.2, 0))
	game.focus_target = null
	game.attack_delay = 0.0
	game.mana = game.MAX_MANA
	var first_cast: bool = game.use_weapon_skill(2)
	check(first_cast, "Whirlwind casts with no current target")
	check(near_a.hit_count == 1 and near_b.hit_count == 1, "Whirlwind strikes two nearby enemies once each")
	check(far.hit_count == 0 and above.hit_count == 0, "Whirlwind respects horizontal range and floor height")
	check(absf(game.mana - (game.MAX_MANA - 12.0)) < 0.01, "Whirlwind spends its actual 12 MP cost")
	check(float(game.skill_cooldowns.get("whirlwind", 0.0)) == LEVELS.cooldown_for_skill("whirlwind"), "Whirlwind starts its real 13s cooldown")
	check(game.hero.whirlwind_remaining > 0.0 and get_nodes_in_group("outpost_whirlwind_trails").size() > 0, "Whirlwind starts visible rig spin and actual sword trail")
	var trail: MeshInstance3D = get_nodes_in_group("outpost_whirlwind_trails")[0] as MeshInstance3D
	game.hero.visual.rotation.y = 0.35
	trail._process(0.05)
	game.hero.visual.rotation.y = 1.45
	trail._process(0.05)
	check(trail.mesh != null and trail.mesh.get_surface_count() > 0, "Sword trail generates visible geometry between actual rotating blade positions")
	var old_damage: float = near_a.damage_taken
	check(not game.use_weapon_skill(2) and is_equal_approx(near_a.damage_taken, old_damage), "Whirlwind cooldown prevents repeat hits")

	# Armour Break genuinely raises subsequent physical damage, then expires.
	game.attack_delay = 0.0
	game.mana = game.MAX_MANA
	game.focus_target = near_a
	check(game.use_weapon_skill(1), "Armour Break casts as the second slot on a focused target")
	check(float(near_a.get_meta("outpost_armor_break_until", -1.0)) > game.world_time, "Armour Break sets a timed vulnerability status")
	var before_followup: float = near_a.damage_taken
	game.attack_delay = 0.0
	game.attack(near_a)
	check(absf((near_a.damage_taken - before_followup) - 8.0 * (1.0 + LEVELS.ARMOR_BREAK_BONUS)) < 0.1, "Follow-up attack gets +25 percent damage")
	game.world_time += LEVELS.ARMOR_BREAK_SECONDS + 0.1
	game.attack_delay = 0.0
	before_followup = near_a.damage_taken
	game.attack(near_a)
	check(absf((near_a.damage_taken - before_followup) - 8.0) < 0.1, "Armour break expires and ordinary damage returns")
	game.queue_free()
	await process_frame
	print("WEAPON ABILITIES RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
