extends RefCounted
## Merge adjacent top surfaces with matching atlas tile and exact voxel height.
## The spatial shader repeats the 16x16 source tile inside each merged rectangle.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const ATLAS_SHADER = preload("res://scripts/voxel/voxel_greedy_atlas.gdshader")
static var _material: ShaderMaterial

static func get_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = ATLAS_SHADER
		_material.set_shader_parameter("atlas", PIXELS.get_material().albedo_texture)
	return _material

static func build_chunk(chunk_x: int, chunk_z: int, size: int, max_half: int, height_at: Callable, tile_at: Callable) -> MeshInstance3D:
	var width: int = mini(size, max_half - chunk_x)
	var depth: int = mini(size, max_half - chunk_z)
	var heights: Array = []
	var tiles: Array = []
	for z in range(depth):
		var h_row: Array = []
		var tile_row: Array = []
		for x in range(width):
			h_row.append(float(height_at.call(float(chunk_x + x) + 0.5, float(chunk_z + z) + 0.5)))
			tile_row.append(int(tile_at.call(chunk_x + x, chunk_z + z)))
		heights.append(h_row)
		tiles.append(tile_row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var visited: Dictionary = {}
	var merged_count: int = 0
	# Deterministic x-first greedy rectangles, exact atlas tile and height.
	for z in range(depth):
		for x in range(width):
			var key: Vector2i = Vector2i(x, z)
			if visited.has(key):
				continue
			var y: float = float(heights[z][x])
			var tile: int = int(tiles[z][x])
			var run: int = 1
			while x + run < width and not visited.has(Vector2i(x + run, z)) and is_equal_approx(float(heights[z][x + run]), y) and int(tiles[z][x + run]) == tile:
				run += 1
			var rows: int = 1
			while z + rows < depth:
				var match_row: bool = true
				for sx in range(x, x + run):
					if visited.has(Vector2i(sx, z + rows)) or not is_equal_approx(float(heights[z + rows][sx]), y) or int(tiles[z + rows][sx]) != tile:
						match_row = false
						break
				if not match_row:
					break
				rows += 1
			for dz in range(rows):
				for dx in range(run):
					visited[Vector2i(x + dx, z + dz)] = true
			var left: float = float(chunk_x + x)
			var right: float = left + float(run)
			var near_z: float = float(chunk_z + z)
			var far_z: float = near_z + float(rows)
			quad(st, Vector3(left, y, near_z), Vector3(left, y, far_z),
				Vector3(right, y, far_z), Vector3(right, y, near_z), tile, float(rows), float(run))
			merged_count += 1
	# Keep exposed cliff faces: they use the same exact sample function as
	# the neighbour chunk so loading/unloading cannot open visible seams.
	for z in range(depth):
		for x in range(width):
			var ax: float = float(chunk_x + x)
			var az: float = float(chunk_z + z)
			var y: float = float(heights[z][x])
			var east: float = float(height_at.call(ax + 1.5, az + 0.5)) if ax < float(max_half - 1) else -2.2
			var west: float = float(height_at.call(ax - 0.5, az + 0.5)) if ax > -float(max_half) else -2.2
			var south: float = float(height_at.call(ax + 0.5, az + 1.5)) if az < float(max_half - 1) else -2.2
			var north: float = float(height_at.call(ax + 0.5, az - 0.5)) if az > -float(max_half) else -2.2
			if east < y - 0.01:
				quad(st, Vector3(ax + 1, east, az + 1), Vector3(ax + 1, east, az), Vector3(ax + 1, y, az), Vector3(ax + 1, y, az + 1), 3)
			if west < y - 0.01:
				quad(st, Vector3(ax, west, az), Vector3(ax, west, az + 1), Vector3(ax, y, az + 1), Vector3(ax, y, az), 3)
			if south < y - 0.01:
				quad(st, Vector3(ax, south, az + 1), Vector3(ax + 1, south, az + 1), Vector3(ax + 1, y, az + 1), Vector3(ax, y, az + 1), 3)
			if north < y - 0.01:
				quad(st, Vector3(ax + 1, north, az), Vector3(ax, north, az), Vector3(ax, y, az), Vector3(ax + 1, y, az), 3)
	var result := MeshInstance3D.new()
	result.name = "GroundChunk_%d_%d" % [chunk_x, chunk_z]
	result.mesh = PIXELS.create_mesh(st)
	result.material_override = get_material()
	result.set_meta("greedy_top_quads", merged_count)
	result.set_meta("unmerged_top_quads", width * depth)
	return result

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tile: int, u_repeat: float = 1.0, v_repeat: float = 1.0) -> void:
	# Use COLOR.r as a per-face, constant tile ID. UV contains the repeat span,
	# so the shader can wrap within THAT tile rather than leaking to neighbours.
	var color := Color(float(clampi(tile, 0, 15)) / 15.0, 0.0, 0.0, 1.0)
	var points: Array[Vector3] = [a, b, c, d]
	var uv: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(u_repeat, 0.0),
		Vector2(u_repeat, v_repeat), Vector2(0.0, v_repeat)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(color)
		st.set_uv(uv[i])
		st.add_vertex(points[i])
