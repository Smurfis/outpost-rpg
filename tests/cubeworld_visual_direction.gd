extends SceneTree
## Cube World-inspired visual direction only: no crafting, collision, saves
## or navigation changes. Deterministic, headless regression for Alpha.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, label: String) -> void:
	if condition:
		print("PASS CUBE STYLE: " + label)
	else:
		failures += 1
		push_error("FAIL CUBE STYLE: " + label)

func _run() -> void:
	var pixels = load("res://scripts/voxel/voxel_palette.gd")
	var props = load("res://scripts/voxel/voxel_props.gd")
	var character = load("res://scripts/voxel/voxel_character.gd")
	var atlas: StandardMaterial3D = pixels.get_material()
	verify(atlas != null and atlas.vertex_color_use_as_albedo, "One shared atlas accepts per-vertex seasonal foliage")
	verify(atlas != null and atlas.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Atlas remains crisp nearest-filtered voxels")
	verify(atlas.albedo_texture.get_size() == Vector2(64, 64), "No new large foliage textures created")
	var colours: Dictionary = {}
	for x in range(-84, 84, 7):
		for z in range(-70, 70, 9):
			var tint: Color = pixels.foliage_tint_at(float(x), float(z), 64012)
			colours[tint.to_html()] = true
	verify(colours.size() >= 4, "Forest includes cherry, jade, sunlit and violet foliage regions")
	verify(pixels.foliage_tint_at(22.0, -36.0) == pixels.foliage_tint_at(22.0, -36.0), "Tree colours stable across world streaming")
	var blossom: MeshInstance3D = props.tree(Color(1.0, 0.35, 0.78))
	var pine: MeshInstance3D = props.pine_tree(Color(0.85, 1.0, 0.55))
	verify(blossom != null and blossom.mesh != null and blossom.material_override == atlas, "Colourful blossom tree still uses one atlas mesh")
	verify(pine != null and pine.mesh != null and pine.material_override == atlas, "Voxel pine also supports palette changes")
	if blossom != null:
		var colors: PackedColorArray = blossom.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		verify(colors.size() > 0, "Canopy tints are encoded into mesh vertex colors")
		var has_tint: bool = false
		for color in colors:
			if color != Color.WHITE:
				has_tint = true
				break
		verify(has_tint, "Leaf vertices differ from bark without splitting draw calls")
	for item in ["adventurer_head", "adventurer_torso", "steel_sword", "iron_blade", "steel_spear", "hand_axe", "hand_pickaxe"]:
		var part: MeshInstance3D = character.create_part(item)
		verify(part != null and part.mesh != null and part.material_override == atlas, "Detailed modular voxel mesh: " + item)
	root.set_meta("outpost_new_adventure", true)
	var packed: PackedScene = load("res://scenes/main.tscn")
	verify(packed != null, "Outpost scene still imports")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	var head: MeshInstance3D = game.hero.visual.get_node_or_null("adventurer_head") as MeshInstance3D
	verify(head != null and head.scale.x >= 1.30, "Adventurer keeps enlarged expressive voxel head")
	var has_collision: bool = false
	for child in game.hero.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
			has_collision = true
			break
	verify(has_collision, "Existing movement collision preserved")
	var map: Control = game.hud.root.get_node_or_null("LiveWorldMinimap") as Control
	verify(map != null and map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Circular minimap does not steal camera touch input")
	if map != null:
		map._process(0.5)
		verify(int(map._relief_samples) > 0, "Actual terrain heights shade the round miniature map")
		var sampled: int = int(map._refresh_count)
		game.camera_angle = PI * 0.5
		map._process(0.02)
		verify(int(map._refresh_count) == sampled, "Camera orbit reuses cached map textures and terrain samples")
	game.queue_free()
	await process_frame
	print("CUBE STYLE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
