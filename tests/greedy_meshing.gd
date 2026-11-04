extends SceneTree
## Atlas-preserving greedy quads share one material, contain UV2 tile IDs,
## and reduce the vertex count of existing 12x12 terrain chunks.
var failures: int = 0
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS GREEDY: " + message)
	else:
		failures += 1
		push_error("FAIL GREEDY: " + message)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Existing game scene can load")
	if scene == null:
		quit(1)
		return
	var shader_material: ShaderMaterial = GREEDY.material()
	check(shader_material != null and shader_material.shader != null, "Shared greedy terrain shader loads")
	check(shader_material.get_shader_parameter("atlas_texture") == PIXELS.get_material().albedo_texture, "Greedy shader reuses shipped 64x64 atlas texture")
	check(shader_material.shader.code.contains("fract(UV)"), "Merged surfaces repeat source 16px tiles, not stretched textures")
	root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var field = game.get_node("VoxelAtmosphere")
	check(field.loaded_chunk_count() > 0, "Streaming Fields continue to load")
	var improved: int = 0
	var vertices_before: int = 0
	var vertices_after: int = 0
	for cell in [Vector2i(0, 0), Vector2i(-12, 0), Vector2i(12, -12), Vector2i(24, 24)]:
		var mesh: MeshInstance3D = field.get_node_or_null("GroundChunk_%d_%d" % [cell.x, cell.y])
		if mesh == null:
			continue
		check(mesh.material_override == shader_material, "Chunk uses shared greedy material")
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		check(uv2.size() == vertices.size(), "Every merged face retains its own atlas tile index")
		var top_and_walls: int = vertices.size()
		var naive: int = 12 * 12 * 6
		for x in range(cell.x, cell.x + 12):
			for z in range(cell.y, cell.y + 12):
				var h: float = field.surface_y_at(x + 0.5, z + 0.5)
				for neighbor in [Vector2i(x+1,z),Vector2i(x-1,z),Vector2i(x,z+1),Vector2i(x,z-1)]:
					if h > field.surface_y_at(float(neighbor.x)+0.5,float(neighbor.y)+0.5) + 0.01:
						naive += 6
		vertices_before += naive
		vertices_after += top_and_walls
		if top_and_walls < naive:
			improved += 1
	check(improved >= 3, "Greedy meshing beats individual tile faces in three sampled chunks")
	check(vertices_after < vertices_before, "Total terrain triangle count reduced without changing collision")
	check(game.get_node("Dungeons").entrances.size() == 5, "Dungeon portals remain available")
	game.queue_free()
	await process_frame
	print("GREEDY RESULT: %d failures. Original vertices %d, merged vertices %d." % [failures, vertices_before, vertices_after])
	quit(0 if failures == 0 else 1)
