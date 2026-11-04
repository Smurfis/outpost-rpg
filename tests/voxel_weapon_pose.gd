extends SceneTree
## Verify the voxel skin, weapon-grip orientation, variant model swaps and
## legacy visuals without touching movement, crafting or save state.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS WEAPON: " + description)
	else:
		failures += 1
		push_error("FAIL WEAPON: " + description)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		check(false, "Game scene can load")
		quit(1)
		return
	var atlas_script = load("res://scripts/voxel/voxel_palette.gd")
	var atlas: StandardMaterial3D = atlas_script.get_material()
	var model_script = load("res://scripts/voxel/voxel_character.gd")
	for model_name in ["steel_sword", "iron_blade", "steel_spear", "kite_shield", "cloth_cloak"]:
		var model: MeshInstance3D = model_script.create_part(model_name)
		check(model != null and model.mesh != null and model.material_override == atlas, "Voxel %s uses the shared nearest-filtered atlas" % model_name)
	var game = scene.instantiate()
	game.set("voxel_art_enabled", true)
	root.add_child(game)
	await process_frame
	var player = game.hero
	var grip = player.get("weapon_grip")
	check(grip != null and grip.get_parent() == player.right_arm, "Weapon attaches to dedicated right-hand grip")
	check(grip.get_node_or_null("steel_sword") != null, "Sword remains under grip for equipment and animation")
	check(grip.transform.basis.y.y < -0.55, "Blade is rotated downwards rather than through upper arm")
	check(player.sword_mesh.material_override == atlas, "Equipped sword retains pixel material")
	check(player.sword_mesh.scale.y < 1.0, "Weapon scaling keeps floor clearance")
	var starter_mesh: Mesh = player.sword_mesh.mesh
	player.set_weapon("iron_blade")
	check(player.sword_mesh.mesh != starter_mesh, "Higher-tier iron blade uses its distinct pixel mesh")
	check(player.sword_mesh.material_override == atlas, "Iron weapon keeps pixel atlas")
	var iron_mesh: Mesh = player.sword_mesh.mesh
	player.set_weapon("spear")
	check(player.sword_mesh.mesh != iron_mesh, "Spear becomes a separately shaped voxel model")
	check(player.weapon_grip.transform.basis.y.y < -0.4, "Long spear is angled forward rather than vertical")
	check(player.sword_mesh.material_override == atlas, "Spear keeps pixel atlas")
	player.set_weapon("training_blade")
	player.set_shield(true)
	player.set_cloak(true)
	check(player.shield_mesh.visible and player.cloak_pivot.visible, "Shield and cape visuals remain equippable")
	check(player.shield_mesh.material_override == atlas, "Voxel shield shares the pixel palette")
	game.queue_free()
	await process_frame
	var legacy = scene.instantiate()
	legacy.set("voxel_art_enabled", false)
	root.add_child(legacy)
	await process_frame
	check(legacy.hero.sword_mesh != null and legacy.hero.sword_mesh.mesh != null, "Legacy OBJ equipment remains available")
	check(legacy.hero.weapon_grip != null, "Old style also uses correct neutral sword grip")
	legacy.queue_free()
	print("WEAPON POSE RESULT: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
