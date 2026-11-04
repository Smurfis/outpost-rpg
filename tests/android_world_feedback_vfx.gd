extends SceneTree
## Android phone report regression: iron ore, visible combat bursts, and active
## harvestables in streamed terrain outside the starting Outpost.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, name: String) -> void:
	if ok:
		print("PASS WORLD FEEDBACK: " + name)
	else:
		failures += 1
		push_error("FAIL WORLD FEEDBACK: " + name)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Game scene loads")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var world: Node = game.get_node("VoxelAtmosphere")
	var outer: Array = []
	var iron = null
	for node in get_nodes_in_group("resources"):
		if node.kind == "iron" and iron == null:
			iron = node
		if node.get_parent() != null and node.get_parent().name.begins_with("ChunkInteractables_"):
			outer.append(node)
	check(outer.size() >= 7, "Outside spawn ring contains multiple actual harvestable nodes")
	if not outer.is_empty():
		var resource = outer[0]
		check(resource.kind in ["wood", "stone", "fiber", "berries", "iron", "coal", "clay", "herbs", "mushrooms", "reeds"], "Streamed harvestables retain real item IDs")
		check(resource._is_voxel_skin(), "Streamed harvestables use the voxel visual style")
		check(resource.harvest() == resource.kind, "Streamed harvestables award their original item type")
		var visual = resource.get_child(0)
		check(visual != null, "Streamed harvestable has an actual visible resource model")
	check(iron != null, "Iron ore is present in starting map")
	if iron != null:
		var voxel_iron: Node = iron.get_node_or_null("VoxelIron")
		check(voxel_iron != null, "Iron node uses voxel rock model")
		if voxel_iron != null:
			check(voxel_iron.get_node_or_null("SilverWhiteIronVein") != null, "Iron is silver/white, not purple magic crystal")
	game.hero.swing()
	await physics_frame
	check(game.hero.right_arm.rotation.x > 0.0, "Sword begins its animation as a forward swing")
	var boar = get_first_node_in_group("enemies")
	check(boar != null, "Boar enemy is present")
	if boar != null:
		var before: float = boar.hp
		boar.receive_damage(6.0)
		check(is_equal_approx(boar.hp, before - 6.0), "Damage math preserved")
		var found_number: bool = false
		for child in get_nodes_in_group("outpost_pixel_feedback"):
			if child.get_node_or_null("PixelFragments") != null and child.get_node_or_null("DamageNumber") != null:
				found_number = true
		print("DEBUG PIXEL BURSTS: ", get_nodes_in_group("outpost_pixel_feedback").size(), " children=", game.get_child_count())
	check(found_number, "Hits create readable floating damage numbers and pixel sparks")
		boar.receive_damage(100.0)
		check(not boar.alive and not boar.visible, "Defeated boar still follows original respawn rules")
		var lethal_visual: bool = false
		for child in get_nodes_in_group("outpost_pixel_feedback"):
			if child.get_node_or_null("PixelFragments") != null and bool(child.get("_lethal")):
				lethal_visual = true
		check(lethal_visual, "Enemy death triggers voxel disintegration")
	game.hero.health = 5.0
	game.hero.take_hit(9.0)
	check(is_equal_approx(game.hero.health, 100.0), "Hero defeat preserves current solo respawn behavior")
	var hero_burst: bool = false
	for child in get_nodes_in_group("outpost_pixel_feedback"):
		if child.get_node_or_null("PixelFragments") != null and bool(child.get("_lethal")):
			hero_burst = true
	check(hero_burst, "Hero defeat also creates pixel burst")
	var before_count: int = world.loaded_chunk_count()
	game.hero.global_position = Vector3(78.0, 3.5, 78.0)
	# Procedural portals are enabled in real Play -> loading workflows;
	# direct-scene tests deliberately preserve the five starter previews.
	world.defer_streaming = true
	world.update_streaming_for(Vector3(78.0, 0.0, 78.0))
	var manager: Node = game.get_node("Dungeons")
	check(manager.entrances.size() > 5, "Exploring distant chunks offers new functional dungeon portals")
	await physics_frame
	check(world.loaded_chunk_count() <= before_count, "Streamed harvestables do not keep distant terrain resident")
	check(world.get_node_or_null("ChunkInteractables_72_72") != null, "Distant traversable terrain contains new interactive world nodes")
	game.queue_free()
	await process_frame
	print("WORLD FEEDBACK RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
