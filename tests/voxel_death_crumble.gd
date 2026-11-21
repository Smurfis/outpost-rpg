extends SceneTree
## Real animated imported creatures -> colour-matched voxel falling cubes.
## Verify original kills, loot, respawn and guardian defeat still work.
const CRUMBLE = preload("res://scripts/vfx/voxel_death_crumble.gd")
const GUARD = preload("res://scripts/dungeons/dungeon_guardian.gd")
var errors: int = 0

class FakeDungeon:
	extends Node3D
	var defeated: int = 0
	func guardian_defeated() -> void:
		defeated += 1

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS VOXEL CRUMBLE: " + what)
	else:
		errors += 1
		push_error("FAIL VOXEL CRUMBLE: " + what)

func _new_rig_color_test(world: Node3D) -> void:
	var actor := Node3D.new()
	world.add_child(actor)
	var rig := Node3D.new()
	actor.add_child(rig)
	for tone in [Color.RED, Color.BLUE, Color.GREEN]:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.75, 0.75, 0.75)
		box.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = tone
		box.material_override = material
		box.position = Vector3(float(rig.get_child_count()) * 0.88 - 0.88, 1.0, 0.0)
		rig.add_child(box)
	var effect = CRUMBLE.spawn(world, actor, rig)
	check(effect != null and effect.cube_count() > 20, "Uses geometry of all coloured body pieces, not a flat explosion")
	var unique: Dictionary = {}
	var min_x: float = INF
	var max_x: float = -INF
	for i in range(effect._positions.size()):
		var colour: Color = effect._colours[i]
		unique["%02d:%02d:%02d" % [roundi(colour.r * 10), roundi(colour.g * 10), roundi(colour.b * 10)]] = true
		min_x = minf(min_x, effect._positions[i].x)
		max_x = maxf(max_x, effect._positions[i].x)
	check(unique.size() >= 3, "Cubies retain three distinct source material colours")
	check(max_x - min_x > 1.5, "Cubies retain the model's relative body layout")
	check(effect._instance_mesh.instance_count == effect.cube_count(), "One GPU MultiMesh holds all fragments")
	check(effect._instance_mesh.instance_count <= CRUMBLE.MAX_PC, "Capped GPU and simulation cube count")
	effect.queue_free()
	actor.queue_free()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	root.add_child(game)
	await physics_frame
	_new_rig_color_test(game)
	await physics_frame
	var boars: Array[Node] = get_nodes_in_group("wild_boars")
	var wildlife: Array[Node] = get_nodes_in_group("overworld_wildlife")
	check(not boars.is_empty() and wildlife.size() >= 2, "Live overworld has animated boars, pigs and wolves")
	for target in [boars[0], wildlife[0], wildlife[1]]:
		var before: int = get_nodes_in_group("outpost_death_crumbles").size()
		var old_hp: float = target.hp
		target.receive_damage(old_hp + 100.0)
		var effects: Array[Node] = get_nodes_in_group("outpost_death_crumbles")
		check(not target.alive and not target.visual.visible, "Death swaps original animated model immediately")
		check(effects.size() == before + 1, "Exactly one independent crumble per defeat")
		var burst = effects.back()
		check(burst.cube_count() > 20 and burst.cube_count() <= CRUMBLE.MAX_PC,
			"Real imported model sampled into bounded cubies")
		check(burst.get_parent() == game, "Falling debris outlives the respawning creature")
		check(target.respawn > 0.0, "Creature original respawn timer still active")
		if target.has_method("map_record"):
			check(target.map_record().get("alive") == false, "Dead creature map state is unchanged")
	var fake := FakeDungeon.new()
	game.add_child(fake)
	var guard = GUARD.new()
	fake.add_child(guard)
	guard.setup(game.hero, fake, 1, Vector3(2, 0.0, 2), "goblin")
	check(guard.avatar != null, "Imported animated dungeon guardian is available")
	var before_guard: int = get_nodes_in_group("outpost_death_crumbles").size()
	guard.receive_damage(100000.0)
	check(not guard.alive and not guard.visual.visible, "Dungeon guardian also crumbles without death animation")
	check(fake.defeated == 1, "Dungeon defeat / reward callback still fires exactly once")
	check(get_nodes_in_group("outpost_death_crumbles").size() == before_guard + 1, "Dungeon crumble is independent of despawning guardian")
	for frame in range(125):
		await physics_frame
	var landings: int = 0
	var settling: int = 0
	for effect in get_nodes_in_group("outpost_death_crumbles"):
		landings += effect.landed_count()
		for resting in effect._resting:
			if resting:
				settling += 1
	check(landings > 0 and settling > 0, "Physics cubes strike terrain, bounce and settle")
	for effect in get_nodes_in_group("outpost_death_crumbles"):
		effect._physics_process(CRUMBLE.LIFETIME + 0.1)
	await physics_frame
	check(get_nodes_in_group("outpost_death_crumbles").is_empty(), "All voxel particles shrink away and despawn")
	game.queue_free()
	await process_frame
	print("VOXEL CRUMBLE RESULT: %d failures." % errors)
	quit(0 if errors == 0 else 1)
