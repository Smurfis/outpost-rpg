extends SceneTree
## Pixel boar regression: mesh/material identity, untouched combat and legacy art.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
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
	check(scene != null, "Gameplay scene imports")
	if scene == null:
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var boars: Array = []
	for child in game.get_children():
		if child is CharacterBody3D and child.is_in_group("enemies"):
			boars.append(child)
	check(boars.size() == 3, "All original boars remain in overworld")
	if not boars.is_empty():
		var first: MeshInstance3D
		for boar in boars:
			check(boar.hp == 32.0 and boar.alive, "Enemy health and AI begin unchanged")
			check(boar.visual.get_child_count() == 1, "Boar renders as one combined voxel mesh")
			var mesh: MeshInstance3D = boar.visual.get_child(0) as MeshInstance3D
			check(mesh != null and mesh.mesh != null, "Voxel creature owns a valid mesh")
			if mesh == null:
				continue
			check(mesh.material_override == PIXELS.get_material(), "Boar shares the 16x16 nearest-filtered world atlas")
			check(mesh.material_override.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Creature preserves crisp pixel textures")
			if first != null:
				check(mesh.mesh == first.mesh, "Boars reuse a single cached mesh")
			else:
				first = mesh
		var target = boars[0]
		var start_hp: float = target.hp
		target.receive_damage(5.0)
		check(target.hp == start_hp - 5.0 and target.alive, "Original boar damage and combat health stay intact")
		check(target.collision_layer == 2 and target.collision_mask == 1, "Original enemy collision groups stay intact")
	game.queue_free()
	await process_frame
	var original = scene.instantiate()
	original.voxel_art_enabled = false
	root.add_child(original)
	await process_frame
	var old_boar
	for child in original.get_children():
		if child is CharacterBody3D and child.is_in_group("enemies"):
			old_boar = child
			break
	check(old_boar != null, "Legacy appearance still spawns original boars")
	if old_boar != null:
		check(old_boar.visual.get_child_count() > 10, "Legacy boar keeps original multi-piece model")
		check(old_boar.visual.get_node_or_null("VoxelWildBoar") == null, "Legacy graphics toggle prevents voxel creature override")
	original.queue_free()
	await process_frame
	print("VOXEL BOAR RESULT: %d failed assertion(s)." % failures)
	quit(0 if failures == 0 else 1)
