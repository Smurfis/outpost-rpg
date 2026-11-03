extends SceneTree
## Launch: godot --headless --path . -s res://tests/voxel_art_smoke.gd
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var palette_script = load("res://scripts/voxel/voxel_palette.gd")
	var atlas: StandardMaterial3D = palette_script.get_material()
	_check(atlas != null and atlas.albedo_texture != null, "Procedural pixel atlas is created")
	if atlas != null:
		_check(atlas.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Atlas uses nearest pixel filtering")
		_check(atlas.albedo_texture.get_width() == 64, "All sixteen tiles are sixteen source pixels each")
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "Game scene still loads")
	if scene == null:
		quit(1)
		return
	var game: Node3D = scene.instantiate() as Node3D
	_check(bool(game.get("voxel_art_enabled")), "Voxel mode enabled in the feature branch")
	root.add_child(game)
	await process_frame
	var biome: Node = game.get_node_or_null("VoxelAtmosphere")
	_check(biome != null, "Voxel terrain layer is present")
	if biome != null:
		_check(biome.get_node_or_null("GroundChunk_-23_-23") != null, "Chunk meshes replace the flat visual ground")
		_check(biome.get_node_or_null("SteppedDistanceCliffs") != null, "Background cliffs generated outside playable bounds")
	var tree_count: int = 0
	var box_count: int = 0
	for child in game.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("VoxelTree"):
			tree_count += 1
		if child is MeshInstance3D and str(child.name).begins_with("VoxelCrate"):
			box_count += 1
	_check(tree_count >= 5, "Five decorative trees use the voxel skin")
	_check(box_count >= 4, "Four supply crates use the voxel skin")
	_check(game.get_node_or_null("Terrain") != null, "Original collision floor retained")
	_check(game.get("hero") != null and game.get("menu") != null, "Gameplay/HUD still initialize")
	var body: MeshInstance3D = game.hero.visual.get_node_or_null("adventurer_torso") as MeshInstance3D
	_check(body != null and body.material_override == atlas, "Modular adventurer uses the shared pixel atlas")
	var pixel_station_blocks: int = 0
	for child in game.stations["workbench"].get_children():
		if child is MeshInstance3D and child.material_override == atlas:
			pixel_station_blocks += 1
	_check(pixel_station_blocks > 0, "Crafting stations use matching pixel textures")
	_check(game.get("recipes").size() == 13, "All existing crafting recipes retained")
	var kinds: Dictionary = {}
	for node in get_nodes_in_group("resources"):
		kinds[node.kind] = true
	_check(kinds.size() == 10, "All ten resource types preserved")
	game.queue_free()
	await process_frame
	var old: Node3D = scene.instantiate() as Node3D
	old.set("voxel_art_enabled", false)
	root.add_child(old)
	await process_frame
	_check(old.get_node_or_null("VoxelAtmosphere") == null, "Legacy visual style is still available")
	_check(old.get_node_or_null("Terrain") != null, "Legacy style keeps collision floor")
	old.queue_free()
	print("Voxel atmosphere smoke: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
