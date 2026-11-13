extends SceneTree
## Kept at the original test path for existing CI jobs. The voxel boar
## is now a Quaternius animated raccoon, with the same hostile gameplay.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS BOAR: " + description)
	else:
		failures += 1
		push_error("FAIL BOAR: " + description)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Outpost scene imports")
	if scene == null:
		quit(1)
		return
	for voxel in [true, false]:
		root.set_meta("outpost_new_adventure", true)
		var game = scene.instantiate()
		game.voxel_art_enabled = voxel
		root.add_child(game)
		await process_frame
		var raccoons: Array = []
		for child in game.get_children():
			if child is CharacterBody3D and child.is_in_group("wild_raccoons"):
				raccoons.append(child)
		check(raccoons.size() == 3, "Three wild raccoons spawn in voxel mode %s" % str(voxel))
		check(get_nodes_in_group("wild_boars").is_empty(), "The old boar population is gone")
		if not raccoons.is_empty():
			var target = raccoons[0]
			check(target.name == "WildRaccoon" and target.alive, "Raccoon is a living hostile mob")
			check(target.avatar != null and target.avatar.model != null, "Imported raccoon replaces old mesh")
			check(target.avatar.animator != null, "Imported raccoon is animated")
			for clip in ["idle", "walk", "run", "headbutt", "death"]:
				check(target.avatar.animation_names.has(clip), "Raccoon clip %s exists" % clip)
			check(target.collision_layer == 2 and target.collision_mask == 1,
				"Raccoon preserves terrain collision and enemy targeting")
			check(target.hp == 32.0, "Raccoon starts with original hostile health")
			var start_hp: float = target.hp
			target.receive_damage(5.0)
			check(target.hp == start_hp - 5.0 and target.alive, "Raccoon takes normal combat damage")
			check(game.enemy_display_name(target) == "Wild raccoon", "Target HUD uses new species name")
		game.queue_free()
		await process_frame
	print("VOXEL BOAR RESULT: %d failed assertion(s)." % failures)
	quit(0 if failures == 0 else 1)
