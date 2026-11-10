extends RefCounted
## Dedicated, nearest-filtered 16px foliage atlas and single-surface voxel meshes.
## The checked-in padded PNG prevents bleeding and is independent of terrain/water.
const ATLAS_PATH: String = "res://assets/textures/trees/tree_atlas_padded_16.png"
const ATLAS_WIDTH: float = 80.0
const ATLAS_HEIGHT: float = 60.0
const CELL: int = 20
const INSET: int = 2

const OAK: int = 0
const SUNLIT: int = 1
const BIRCH: int = 2
const PINE: int = 3
const AUTUMN: int = 4
const BLOSSOM: int = 5
const TWILIGHT: int = 6

# Tile order in the included 4 x 3 atlas.
const OAK_BARK: int = 0
const BIRCH_BARK: int = 1
const PINE_BARK: int = 2
const MOSSY_BARK: int = 3
const OAK_LEAVES: int = 4
const SUNLIT_LEAVES: int = 5
const BIRCH_LEAVES: int = 6
const PINE_NEEDLES: int = 7
const AUTUMN_LEAVES: int = 8
const BLOSSOM_LEAVES: int = 9
const TWILIGHT_LEAVES: int = 10
const LOG_END: int = 11

static var _material: StandardMaterial3D
static var _meshes: Dictionary = {}

static func material() -> StandardMaterial3D:
	if _material != null:
		return _material
	var texture: Texture2D = load(ATLAS_PATH) as Texture2D
	if texture == null or texture.get_size() != Vector2(80, 60):
		push_error("Missing or invalid Outpost foliage atlas: " + ATLAS_PATH)
		var backup := Image.create(80, 60, false, Image.FORMAT_RGBA8)
		backup.fill(Color("628f42"))
		texture = ImageTexture.create_from_image(backup)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.metallic = 0.0
	_material = mat
	return mat

static func species_at(x: float, z: float, seed: int = 64012) -> int:
	# Stable clumps rather than per-frame randomness; reloading a chunk is exact.
	var cx: int = floori(x / 14.0)
	var cz: int = floori(z / 14.0)
	var sample: int = posmod(cx * 71 + cz * 101 + seed * 13 + cx * cz * 7, 20)
	if sample < 7:
		return OAK
	if sample < 9:
		return SUNLIT
	if sample < 12:
		return BIRCH
	if sample < 15:
		return PINE
	if sample < 17:
		return AUTUMN
	if sample < 19:
		return BLOSSOM
	return TWILIGHT

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tile: int, light: float) -> void:
	var t: int = clampi(tile, 0, 11)
	# Two transparent-safe padding pixels enclose each 16x16 tile.
	var u0: float = float((t % 4) * CELL + INSET) + 0.5
	var v0: float = float((t / 4) * CELL + INSET) + 0.5
	var u1: float = u0 + 15.0
	var v1: float = v0 + 15.0
	var uv: Array[Vector2] = [
		Vector2(u0, v1) / Vector2(ATLAS_WIDTH, ATLAS_HEIGHT),
		Vector2(u1, v1) / Vector2(ATLAS_WIDTH, ATLAS_HEIGHT),
		Vector2(u1, v0) / Vector2(ATLAS_WIDTH, ATLAS_HEIGHT),
		Vector2(u0, v0) / Vector2(ATLAS_WIDTH, ATLAS_HEIGHT)
	]
	var vertices: Array[Vector3] = [a, b, c, d]
	for index in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color(light, light, light))
		st.set_uv(uv[index])
		st.add_vertex(vertices[index])

static func box(st: SurfaceTool, center: Vector3, size: Vector3, top_tile: int, side_tile: int, bottom_tile: int = -1) -> void:
	var x0: float = center.x - size.x * 0.5
	var x1: float = center.x + size.x * 0.5
	var y0: float = center.y - size.y * 0.5
	var y1: float = center.y + size.y * 0.5
	var z0: float = center.z - size.z * 0.5
	var z1: float = center.z + size.z * 0.5
	var bottom: int = side_tile if bottom_tile < 0 else bottom_tile
	_quad(st, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), top_tile, 1.0)
	_quad(st, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), bottom, 0.64)
	_quad(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), side_tile, 0.94)
	_quad(st, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), side_tile, 0.81)
	_quad(st, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), side_tile, 0.87)
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), side_tile, 0.75)

static func append_tree(st: SurfaceTool, origin: Vector3, species: int = OAK, size: float = 1.0, variation: int = 0) -> void:
	var bark: int = BIRCH_BARK if species == BIRCH else PINE_BARK if species == PINE else MOSSY_BARK if species == TWILIGHT else OAK_BARK
	var leaves: int = OAK_LEAVES
	match species:
		SUNLIT:
			leaves = SUNLIT_LEAVES
		BIRCH:
			leaves = BIRCH_LEAVES
		PINE:
			leaves = PINE_NEEDLES
		AUTUMN:
			leaves = AUTUMN_LEAVES
		BLOSSOM:
			leaves = BLOSSOM_LEAVES
		TWILIGHT:
			leaves = TWILIGHT_LEAVES
	var lean: float = float(posmod(variation, 3) - 1) * 0.12
	var width: float = 0.36 if species == BIRCH else 0.48 if species == PINE else 0.61
	var trunk_height: float = 3.65 if species == PINE else 3.15 if species == BIRCH else 2.90
	box(st, origin + Vector3(lean * 0.25, trunk_height * 0.5, 0) * size, Vector3(width, trunk_height, width) * size, LOG_END, bark)
	if species == PINE:
		# Layered stepped pine: six whorls with exposed trunk between branches.
		for tier in range(5):
			var t: float = float(tier)
			var spread: float = 2.85 - t * 0.46
			var y: float = 2.05 + t * 0.66
			box(st, origin + Vector3(0, y, 0) * size, Vector3(spread, 0.55, spread) * size, leaves, leaves)
			box(st, origin + Vector3(0, y + 0.30, 0) * size, Vector3(spread * 0.73, 0.44, spread * 0.73) * size, leaves, leaves)
		box(st, origin + Vector3(0, 5.22, 0) * size, Vector3(0.50, 0.67, 0.50) * size, leaves, leaves)
		return
	# Trunk branches remain visible between the irregular canopy clusters.
	box(st, origin + Vector3(-0.48, 2.44, 0) * size, Vector3(1.30, 0.23, 0.28) * size, bark, bark)
	box(st, origin + Vector3(0.49, 2.91, -0.06) * size, Vector3(1.12, 0.25, 0.28) * size, bark, bark)
	var crown_rise: float = 0.22 if species == BIRCH else 0.0
	var lobes: Array[Vector3] = [
		Vector3(-0.66, 2.86, 0.14), Vector3(0.67, 2.98, 0.16),
		Vector3(-0.08, 3.52, -0.41), Vector3(0.38, 3.64, 0.55),
		Vector3(-0.82, 3.62, 0.62), Vector3(0.93, 3.47, -0.45),
		Vector3(0.0, 4.19, 0.07), Vector3(-0.35, 4.53, -0.26)
	]
	var dimensions: Array[Vector3] = [
		Vector3(1.65, 0.91, 1.67), Vector3(1.62, 0.83, 1.52),
		Vector3(2.06, 0.89, 1.60), Vector3(1.56, 0.76, 1.65),
		Vector3(1.34, 0.75, 1.28), Vector3(1.37, 0.78, 1.43),
		Vector3(2.12, 0.94, 1.98), Vector3(1.27, 0.65, 1.20)
	]
	for i in range(lobes.size()):
		var location: Vector3 = lobes[i]
		var shape: Vector3 = dimensions[i]
		if species == BIRCH:
			shape.x *= 0.84
			shape.z *= 0.84
			location.y += crown_rise
		box(st, origin + (location + Vector3(lean, 0, 0)) * size, shape * size, leaves, leaves)

static func batched(st: SurfaceTool, label: String) -> MeshInstance3D:
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = st.commit()
	node.material_override = material()
	return node

static func tree(species: int = OAK, variation: int = 0) -> MeshInstance3D:
	# One cached surface/mesh per shape; individual trees only add cheap nodes.
	var key: int = clampi(species, OAK, TWILIGHT) * 3 + posmod(variation, 3)
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		append_tree(st, Vector3.ZERO, clampi(species, OAK, TWILIGHT), 1.0, variation)
		st.generate_normals()
		_meshes[key] = st.commit()
	var node := MeshInstance3D.new()
	node.name = "VoxelPineTree" if species == PINE else "VoxelTree"
	node.mesh = _meshes[key] as Mesh
	node.material_override = material()
	return node

static func bush(has_berries: bool = false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	box(st, Vector3(-0.32, 0.37, 0.0), Vector3(0.92, 0.69, 0.86), OAK_LEAVES, OAK_LEAVES)
	box(st, Vector3(0.28, 0.49, -0.08), Vector3(1.03, 0.87, 0.92), SUNLIT_LEAVES, OAK_LEAVES)
	box(st, Vector3(0.02, 0.79, 0.19), Vector3(0.74, 0.45, 0.75), BIRCH_LEAVES, OAK_LEAVES)
	if has_berries:
		for pos in [Vector3(-0.48, 0.70, 0.44), Vector3(0.45, 0.86, 0.12), Vector3(0.12, 1.00, -0.18)]:
			box(st, pos, Vector3.ONE * 0.19, BLOSSOM_LEAVES, BLOSSOM_LEAVES)
	return batched(st, "VoxelBerryBush" if has_berries else "VoxelFiberBush")
