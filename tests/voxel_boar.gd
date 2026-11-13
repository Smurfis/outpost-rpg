extends SceneTree
## Existing CI test path retained: upgraded Cube World boars AND added raccoons.
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
		var boars: Array = get_nodes_in_group("wild_boars")
		var raccoons: Array = get_nodes_in_group("wild_raccoons")
		check(boars.size() == 3, "Three boars spawn in voxel mode %s" % str(voxel))
		check(raccoons.size() == 2, "Raccoons do not replace the boar population")
		if not boars.is_empty():
			var target = boars[0]
			check(target.name == "WildBoar" and target.alive, "Boar remains a hostile creature")
			check(target.avatar != null and target.avatar.model != null, "Boar uses the animated pig rig")
			check(target.avatar.animator != null, "Boar has native animation")
			check(target.avatar.model.get_node_or_null("BoarAccents") != null, "Distinct tusks and bristles decorate boar")
			check(target.collision_layer == 2 and target.collision_mask == 1, "Boar preserves original hitbox")
			check(target.hp == 32.0, "Boar starts with original health")
			var previous: float = target.hp
			target.receive_damage(5.0)
			check(target.hp == previous - 5.0, "Boar still takes original combat damage")
			check(game.enemy_display_name(target) == "Wild boar", "Target HUD identifies boar")
		if not raccoons.is_empty():
			var raccoon = raccoons[0]
			check(raccoon.species == "raccoon" and raccoon.avatar.model != null,
				"Raccoon has an independent animated mesh")
			check(raccoon.map_record()["disposition"] == "neutral", "Neutral map marker is retained")
		game.queue_free()
		await process_frame
	print("VOXEL BOAR RESULT: %d failed assertion(s)." % failures)
	quit(0 if failures == 0 else 1)
