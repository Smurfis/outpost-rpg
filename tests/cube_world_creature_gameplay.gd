extends SceneTree
## Real scene regression: four native animated Quaternius creatures, their
## inherited gameplay/loot/collision, seeded dungeons by difficulty.
const GUARD = preload("res://scripts/dungeons/dungeon_guardian.gd")
const INSTANCE = preload("res://scripts/dungeons/dungeon_instance.gd")
const VISUAL = preload("res://scripts/creatures/cube_world_visual.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, desc: String) -> void:
	if ok:
		print("PASS CUBE CREATURE: " + desc)
	else:
		failures += 1
		push_error("FAIL CUBE CREATURE: " + desc)

func _run() -> void:
	for kind in ["pig", "wolf", "skeleton", "goblin"]:
		var avatar = VISUAL.new()
		root.add_child(avatar)
		check(avatar.configure(kind, 0.7), "Native model instantiates: " + kind)
		check(avatar.animator != null, "Native animation player: " + kind)
		check(avatar.model != null and is_equal_approx(avatar.model.rotation.y, PI),
			"Imported +Z artwork is turned to face Outpost -Z: " + kind)
		var motions: Array = ["Idle", "Walk", "Run", "Death"]
		if kind in ["skeleton", "goblin"]:
			motions.append_array(["Attack", "HitRecieve"])
		else:
			motions.append("Headbutt")
		for motion in motions:
			check(avatar.animation_names.has(str(motion).to_lower()), "Authentic animation %s: %s" % [motion, kind])
		avatar.play_motion(3.0)
		check(avatar.animator.is_playing(), "Animation actually plays: " + kind)
		avatar.queue_free()
		await process_frame
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Existing Outpost scene opens")
	if scene == null:
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var pigs: Array[Node] = get_nodes_in_group("wild_pigs")
	var wolves: Array[Node] = get_nodes_in_group("wild_wolves")
	check(pigs.size() == 2, "Two animated pigs in the live overworld")
	check(wolves.size() == 2, "Two animated wolves in the live overworld")
	check(get_nodes_in_group("wild_boars").size() == 3, "Three original boars preserved")
	if not pigs.is_empty():
		var pig = pigs[0]
		check(pig.species == "pig" and pig.alive and pig.hp > 0, "Pig has real health / is targetable")
		check(pig.avatar.animation_names.has("idle_eating"), "Pig has grazing animation")
		check(pig.collision_layer == 2, "Pig preserves enemy hitbox / target layer")
		var start: float = pig.hp
		pig.receive_damage(3.0)
		check(pig.hp == start - 3.0 and pig.panic > 0.0, "Hit pig becomes frightened and flees")
	if not wolves.is_empty():
		var wolf = wolves[0]
		check(wolf.species == "wolf" and wolf.hp > 0, "Wolf has real combat health")
		check(wolf.collision_layer == 2 and wolf.collision_mask == 1, "Wolf collides with terrain but not player")
		wolf.cooldown = 0.0
		game.hero.global_position = wolf.global_position + Vector3(1.0, 0.0, 0.0)
		var before: float = game.hero.health
		wolf._physics_process(0.016)
		check(game.hero.health < before and wolf.cooldown > 0.0, "Wolf attacks close targets with bite animation")
		check(wolf.avatar.current_state.to_lower().contains("headbutt"), "Wolf attack visibly uses supplied clip")
		check(wolf.visual.rotation.y < -0.01, "Wolf rotates toward nearby hero even after stopping to bite")
		# Leave the wolf out of range for the rest of the procedural dungeon test.
		game.hero.global_position = Vector3.ZERO
	for tier in [0, 1, 2, 3, 4]:
		var dungeon = INSTANCE.new()
		game.add_child(dungeon)
		dungeon.position = Vector3(2000.0 + float(tier) * 500.0, 0.0, 2500.0)
		dungeon.setup("cube_creatures_test_tier_%d" % tier, tier, game.hero, 1)
		var guards: Array[Node] = dungeon.floor_root.get_tree().get_nodes_in_group("dungeon_guardians").filter(
			func(n): return dungeon.floor_root.is_ancestor_of(n)
		)
		check(not guards.is_empty(), "Tier %d has guardians" % tier)
		for guard in guards:
			if tier <= 2:
				check(guard.appearance in ["skeleton", "goblin"], "Tier %d uses Skeleton / Goblin: %s" % [tier, guard.appearance])
				check(guard.avatar != null and guard.avatar.animator != null, "Animated guardian meshes on tier %d" % tier)
				if guard.avatar != null:
					check(is_equal_approx(guard.avatar.model.rotation.y, PI), "Dungeon imported guardian forward is corrected")
			else:
				check(guard.appearance == "", "Epic/Legendary original guardian not overridden")
		dungeon.queue_free()
		await process_frame
	game.queue_free()
	await process_frame
	print("CUBE CREATURES RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
