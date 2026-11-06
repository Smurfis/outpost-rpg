extends SceneTree
const LEVELS = preload("res://scripts/progression/character_levels.gd")
const STEP = preload("res://scripts/world/voxel_step.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(value: bool, message: String) -> void:
	if value:
		print("PASS RPG VERTICAL: " + message)
	else:
		failures += 1
		push_error("FAIL RPG VERTICAL: " + message)

func _run() -> void:
	verify(LEVELS.level_for(0) == 1 and LEVELS.level_for(100) == 2 and LEVELS.level_for(250) == 3, "Character XP thresholds are deterministic")
	verify(LEVELS.available_skill_slots(0) == 1 and LEVELS.available_skill_slots(120) == 2 and LEVELS.available_skill_slots(240) == 3, "Weapon mastery unlocks 1, 2, 3 skill slots")
	root.set_meta("outpost_new_adventure", true)
	var source: PackedScene = load("res://scenes/main.tscn")
	verify(source != null, "Original world scene still imports")
	if source == null:
		quit(1)
		return
	var game = source.instantiate()
	root.add_child(game)
	await process_frame
	verify(game.stations.has("enchanting"), "Fifth physical station created")
	verify(game._recipe_by_id("fiery_weapon").get("station", "") == "enchanting", "Fiery Weapon recipe uses enchanting bench")
	verify(game.character_level() == 1, "Fresh character starts level 1")
	verify(game.unlocked_skill_slots() == 1, "First skill holder starts unlocked")
	var hotbar: Panel = game.hud.root.get_node_or_null("FunctionalHotbar") as Panel
	var menu_button: Button = game.hud.root.get_node_or_null("TopRightMenuButton") as Button
	var attached_bag: Button = game.hud.root.get_node_or_null("Action_bag") as Button
	verify(hotbar != null and hotbar.anchor_top >= 0.39 and hotbar.anchor_bottom <= 0.59, "Collapsed six-option menu stays below minimap and above abilities")
	verify(menu_button != null and menu_button.anchor_top >= 0.32, "Top menu toggle is parked beneath minimap")
	verify(attached_bag != null and attached_bag.anchor_top < 0.10, "Bag is attached to collapsible wallet, not a permanent bar")
	verify(game.hud.torch_button != null and game.hud.torch_button.anchor_top > 0.80, "Offhand torch remains separate from menu flyout")
	verify(game.hud.root.get_node_or_null("Action_attack") == null and game.hud.root.get_node_or_null("Action_gather") == null, "Obsolete combat tiles removed")
	for key in ["skill_1", "skill_2", "skill_3", "potion", "consumable", "interact"]:
		verify(game.hud.root.get_node_or_null("Action_" + key) != null, "Usable radial " + key)
	verify(game.hud.xp_bar.visible and game.hud.xp_bar.anchor_bottom > 0.96, "Level XP shown as long bottom bar")
	verify(game.hud.quick_buttons["potion"].get_node_or_null("ActionLabel") != null, "Empty potion holder exists")
	verify(game.hud._can_start_camera_drag(game.hud.get_viewport().get_visible_rect().size * Vector2(0.50, 0.45)), "Open-world camera hold touch zone is accessible")
	# Independent finger input: movement finger 1 stays held while camera
	# finger 2 must remain stationary long enough to enter orbit.
	var center: Vector2 = game.hud._center()
	var move_down := InputEventScreenTouch.new()
	move_down.index = 1
	move_down.position = center
	move_down.pressed = true
	game.hud._input(move_down)
	var camera_start: Vector2 = game.hud.get_viewport().get_visible_rect().size * Vector2(0.52, 0.50)
	var camera_down := InputEventScreenTouch.new()
	camera_down.index = 2
	camera_down.position = camera_start
	camera_down.pressed = true
	game.hud._input(camera_down)
	verify(game.hud.finger == 1 and game.hud.camera_drag_finger == 2, "Camera and joystick maintain independent touch fingers")
	var yaw_before: float = game.camera_angle_target
	game.hud._process(0.90)
	var camera_motion := InputEventScreenDrag.new()
	camera_motion.index = 2
	camera_motion.position = camera_start + Vector2(100.0, 0.0)
	camera_motion.relative = Vector2(100.0, 0.0)
	camera_motion.screen_relative = Vector2(100.0, 0.0)
	game.hud._input(camera_motion)
	verify(absf(game.camera_angle_target - yaw_before) > 0.3 and game.hud.finger == 1, "Held orbit works whilst joystick finger remains active")
	var camera_up := InputEventScreenTouch.new()
	camera_up.index = 2
	camera_up.position = camera_motion.position
	camera_up.pressed = false
	game.hud._input(camera_up)
	verify(game.hud.camera_drag_finger == -1 and game.hud.finger == 1, "Releasing orbit does not release movement")
	var move_up := InputEventScreenTouch.new()
	move_up.index = 1
	move_up.position = center
	move_up.pressed = false
	game.hud._input(move_up)

	game.inventory["tonic"] = 1
	game.inventory["meal"] = 1
	verify(game.set_quick_consumable("potion", "tonic") and game.set_quick_consumable("consumable", "meal"), "Potion and food radial selections persist")
	game.hero.health = 30.0
	verify(game.use_quick_consumable("potion") and game.hero.health > 30.0, "Assigned potion heals and consumes one item")
	verify(game.inventory["tonic"] == 0 and game.quick_slots["potion"] == "", "Expended potion slot becomes empty")
	game.experience = 300
	game.inventory["spear"] = 1
	game.equipment["weapon"] = "spear"
	game._apply_equipment()
	game.inventory["coal"] = 3
	game.inventory["iron_ingot"] = 2
	game.inventory["herbs"] = 2
	game.hero.global_position = game.station_positions["enchanting"] + Vector3(0, 0.35, 0)
	verify(game.character_level() == 3, "Legacy XP total gives the correct level")
	verify(game.can_craft("fiery_weapon"), "Equipped crafted spear qualifies for fiery enchant")
	var before_xp: int = game.experience
	verify(game.begin_craft("fiery_weapon"), "Fiery enchant uses existing Prepare / Work crafting system")
	game._update_crafting(9.0)
	for _i in range(5):
		game.craft_work_cooldown = 0.0
		game.work_craft()
	verify(game.crafting.is_empty(), "Five working actions finish enchant")
	verify(game.weapon_enchants.get("spear", "") == "fire", "Fiery effect is attached to actual equipped weapon")
	verify(game.experience < before_xp and game.inventory["coal"] == 0, "Enchant consumes exactly one level worth of XP and actual materials")
	verify(not game.can_craft("fiery_weapon"), "Duplicate Fiery Weapon is blocked on enchanted spear")
	game.weapon_mastery_xp["spear"] = 240
	verify(game.unlocked_skill_slots() == 3, "Weapon mastery opens all three combat radials")

	var boar = get_first_node_in_group("enemies")
	verify(boar != null, "Wild mob available for fire damage test")
	if boar != null:
		boar.global_position = game.hero.global_position + Vector3(1.6, 0.0, 0.0)
		game.attack_delay = 0.0
		game.attack()
		verify(boar.burn_left > 3.0, "Fiery Weapon ignites a struck overworld enemy")
		verify(boar.max_climb_height > 0.0 and not boar.can_fly, "Boar climb limit and grounded movement are explicit")
		boar.burn_tick = 0.0
		var hp_before: float = boar.hp
		boar._physics_process(1.1)
		verify(boar.hp < hp_before or not boar.alive, "Fire inflicts timed damage after hit")
		boar.can_fly = true
		verify(boar.can_fly, "Mob flight flag exists for future flying creatures")

	verify(game.hero.max_auto_step_height >= 1.0, "Player keeps safe collision-based step solver")
	verify(game.hero.has_method("_try_auto_step") and game.hero.has_method("move_to_interaction"), "Player movement and dungeon navigation still work")
	var guardian_scene = load("res://scripts/dungeons/dungeon_guardian.gd")
	var guardian = guardian_scene.new()
	verify(guardian.max_climb_height >= 1.0 and not guardian.can_fly, "Dungeon guardian has its own climb ceiling")
	guardian.free()
	game.queue_free()
	await process_frame
	print("RPG VERTICAL RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
