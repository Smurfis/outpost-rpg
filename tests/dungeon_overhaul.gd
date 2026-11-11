extends SceneTree
## Alpha dungeon overhaul: seeded affixes, actual loot props, staircase
## direction and single circular HUD map. Headless integration smoke.
const AFFIXES = preload("res://scripts/dungeons/dungeon_affixes.gd")
const INSTANCE = preload("res://scripts/dungeons/dungeon_instance.gd")
const GUARDIAN = preload("res://scripts/dungeons/dungeon_guardian.gd")
const LOOT = preload("res://scripts/dungeons/dungeon_loot.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, note: String) -> void:
	if condition:
		print("PASS DUNGEON OVERHAUL: " + note)
	else:
		failures += 1
		push_error("FAIL DUNGEON OVERHAUL: " + note)

func _run() -> void:
	var a: Array[Dictionary] = AFFIXES.roll("same_entrance", 2, 5, 4, true)
	var b: Array[Dictionary] = AFFIXES.roll("same_entrance", 2, 5, 4, true)
	check(a == b and a.size() >= 1, "Guardian affixes replay deterministically")
	check(AFFIXES.BASIC[0]["damage"] == 2.0 and AFFIXES.BASIC[1]["hp"] == 2.0, "Basic double-damage and double-health modifiers are real")
	check(LOOT.breakable("vault", 2, 1, "1:3:0") == LOOT.breakable("vault", 2, 1, "1:3:0"), "Smash rewards have stable seeded values")
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main Outpost scene imports")
	if scene == null:
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var dungeon = INSTANCE.new()
	game.add_child(dungeon)
	dungeon.position = Vector3(2300, 0, 2600)
	dungeon.setup("overhaul_integration", 4, game.hero)
	await physics_frame
	var rooms: Array = dungeon.layout["rooms"]
	var exit_room: Dictionary = rooms[int(dungeon.layout["exit"])]
	var links: Array = exit_room["links"]
	check(not links.is_empty(), "Exit room is connected to a real doorway")
	if not links.is_empty():
		var delta: Vector2i = rooms[int(links[0])]["grid"] - exit_room["grid"]
		var expected: float = atan2(float(delta.x), float(delta.y))
		if dungeon.current_floor < dungeon.floor_count:
			var art: MeshInstance3D
			for child in dungeon.chest_area.get_children():
				if child is MeshInstance3D:
					art = child
					break
			check(art != null and is_equal_approx(art.rotation.y, expected), "Staircase low step faces its linked doorway")
	var props: Array = []
	for child in dungeon.floor_root.get_children():
		if child is Area3D and child.has_meta("dungeon_prop_id"):
			props.append(child)
	check(not props.is_empty(), "Rooms contain actual breakable loot entities")
	if not props.is_empty():
		var prop = props[0]
		var key: String = str(prop.get_meta("dungeon_prop_id"))
		var rewards: Array = []
		dungeon.prop_broken.connect(func(_instance, id, payout): rewards.append({"id": id, "payout": payout}))
		prop.receive_damage(10.0)
		await process_frame
		check(dungeon.claimed_props.has(key), "Breaking prop records its unique floor ID")
		check(rewards.size() == 1 and int(rewards[0]["payout"].get("coins", 0)) > 0, "Destroying prop grants a real seeded coin reward once")
		dungeon._build_floor()
		var found_again: bool = false
		for child in dungeon.floor_root.get_children():
			if child.has_meta("dungeon_prop_id") and str(child.get_meta("dungeon_prop_id")) == key:
				found_again = true
		check(not found_again, "Destroyed props do not respawn when a floor reconstructs")
	var guardian = GUARDIAN.new()
	dungeon.floor_root.add_child(guardian)
	guardian.setup(game.hero, dungeon, 0, Vector3.ZERO)
	var base_hp: float = guardian.hp
	guardian.apply_affixes([AFFIXES.BASIC[0], AFFIXES.BASIC[1]])
	check(is_equal_approx(guardian.hp, base_hp * 2.0) and is_equal_approx(guardian.damage_multiplier, 2.0), "Both basic affix effects apply to live combat stats")
	check(guardian.affix_label != null and guardian.display_name.contains("Brutal"), "Monster affixes are visible over enemies and in target name")
	var mini = game.hud.root.get_node_or_null("LiveWorldMinimap")
	check(mini != null, "The original circular minimap exists")
	if mini != null:
		var manager = game.get_node("Dungeons")
		manager.active_instance = dungeon
		mini._process(0.05)
		check(mini.visible, "Circular minimap stays visible in dungeons")
		manager.active_instance = null
	guardian.queue_free()
	dungeon.queue_free()
	game.queue_free()
	await process_frame
	print("DUNGEON OVERHAUL RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
