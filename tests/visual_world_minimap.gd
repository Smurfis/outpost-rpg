extends SceneTree
## Visual feature acceptance: godot --headless --path . -s res://tests/visual_world_minimap.gd
var failures: int = 0

func _check(ok: bool, description: String) -> void:
	if ok:
		print("VISUAL PASS: " + description)
	else:
		failures += 1
		push_error("VISUAL FAIL: " + description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var atlas_path := "res://assets/voxel/outpost_visual_atlas_16px.svg"
	_check(ResourceLoader.exists(atlas_path), "New terrain and tree pixel atlas ships with feature")
	var palette_script = load("res://scripts/voxel/voxel_palette.gd")
	var atlas: StandardMaterial3D = palette_script.get_material()
	_check(atlas.albedo_texture != null and atlas.albedo_texture.get_size() == Vector2(64, 64), "All world voxels share a 64x64 nearest-filtered visual atlas")
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "Outpost main scene still imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var mini: Control = game.hud.root.get_node_or_null("LiveWorldMinimap") as Control
	_check(mini != null, "Minimap attached to existing upper-right HUD")
	if mini != null:
		mini._process(0.6)
		var texture: ImageTexture = mini.get("_texture") as ImageTexture
		_check(texture != null and texture.get_size() == Vector2(48, 48), "Minimap builds low-cost sampled terrain texture")
		_check(mini.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Minimap never blocks touch controls")
	var player = game.hero
	_check(player.visual.scale.x < 1.0, "Voxel character uses smaller proportions")
	_check(player.visual.get_node_or_null("adventurer_head") != null, "Character head remains modular for future race swaps")
	game.inventory["pickaxe"] = 1
	_check(game.select_quick_tool("pickaxe"), "Existing quick selector equips owned pickaxe")
	_check(player.tool_mesh != null and not player.sword_mesh.visible, "Pickaxe visible in hand instead of sword")
	game.select_quick_tool("training_blade")
	_check(player.tool_mesh == null and player.sword_mesh.visible, "Switch back restores the sword")
	_check(game.stations.has("forge"), "Forge remains a playable existing crafting station")
	var forge: Node3D = game.stations["forge"] as Node3D
	_check(forge != null and forge.effect != null, "Redesigned forge has emissive fire")
	var props = load("res://scripts/voxel/voxel_props.gd")
	_check(props.tree().mesh != null and props.pine_tree().mesh != null, "Original voxel trees and pine variation mesh successfully")
	game.queue_free()
	await process_frame
	print("OUTPOST VISUAL TEST: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
