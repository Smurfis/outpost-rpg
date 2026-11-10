extends RefCounted
## Single-draw-call textured mesh props, safe to hide for gathering respawn.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const FOLIAGE = preload("res://scripts/voxel/foliage_renderer.gd")

static func tree(tint: Color = Color.WHITE, foliage_tile: int = 9) -> MeshInstance3D:
	# Keep the old tint/tile API for mods and tests; select real leaf artwork
	# rather than multiplying terrain pixels into pink or lavender.
	var species: int = FOLIAGE.OAK
	if foliage_tile == 1:
		species = FOLIAGE.SUNLIT
	elif foliage_tile == 14:
		species = FOLIAGE.BLOSSOM
	elif foliage_tile in [7, 13]:
		species = FOLIAGE.TWILIGHT
	elif tint.r > tint.g * 1.3 and tint.b > tint.g * 1.1:
		species = FOLIAGE.BLOSSOM
	elif tint.g > tint.r * 1.2 and tint.g > tint.b * 1.05:
		species = FOLIAGE.SUNLIT
	return FOLIAGE.tree(species)

static func pine_tree(_tint: Color = Color.WHITE, _foliage_tile: int = 9) -> MeshInstance3D:
	return FOLIAGE.tree(FOLIAGE.PINE)

static func rock(kind: String = "stone") -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side: int = 15 if kind == "coal" else 3 if kind == "clay" else 4
	var top: int = 7 if kind == "stone" else side
	PIXELS.box(st, Vector3(-0.35, 0.33, 0.02), Vector3(1.06, 0.67, 0.94), top, side)
	PIXELS.box(st, Vector3(0.32, 0.42, -0.12), Vector3(0.9, 0.83, 0.81), side, side)
	PIXELS.box(st, Vector3(0.1, 0.24, 0.44), Vector3(0.87, 0.48, 0.56), side, side)
	# Iron gets a separate silver/white metal vein rather than tile 13
	# (purple MAGIC CRYSTAL, which should never be used for iron).
	if kind == "iron":
		var silver_mesh := BoxMesh.new()
		silver_mesh.size = Vector3.ONE
		var silver := StandardMaterial3D.new()
		silver.albedo_color = Color("dfe8ee")
		silver.metallic = 0.48
		silver.roughness = 0.36
		silver.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		var vein_a := MeshInstance3D.new()
		vein_a.name = "SilverWhiteIronVein"
		vein_a.mesh = silver_mesh
		vein_a.material_override = silver
		vein_a.scale = Vector3(0.26, 0.46, 0.28)
		vein_a.position = Vector3(-0.27, 0.81, -0.12)
		var vein_b := MeshInstance3D.new()
		vein_b.name = "SilverWhiteIronVeinSecond"
		vein_b.mesh = silver_mesh
		vein_b.material_override = silver
		vein_b.scale = Vector3(0.29, 0.36, 0.29)
		vein_b.position = Vector3(0.43, 0.91, 0.06)
		var root: MeshInstance3D = PIXELS.as_instance(st, "VoxelIron")
		root.add_child(vein_a)
		root.add_child(vein_b)
		return root
	if kind == "coal":
		PIXELS.box(st, Vector3(0.34, 0.87, 0.10), Vector3(0.38, 0.26, 0.27), 15, 15)
	return PIXELS.as_instance(st, "Voxel" + kind.capitalize())

static func bush(has_berries: bool) -> MeshInstance3D:
	return FOLIAGE.bush(has_berries)

## Fully voxelised red-and-white forest mushrooms, shared by gatherable nodes
## and streamed decorative clusters (batched into their existing mesh).
static func append_mushroom_cluster(st: SurfaceTool, origin: Vector3, size_factor: float = 1.0, compact: bool = false) -> void:
	var count: int = 2 if compact else 3
	var positions: Array[Vector3] = [Vector3(-0.34, 0.0, 0.05), Vector3(0.20, 0.0, -0.16), Vector3(0.48, 0.0, 0.23)]
	for index in range(count):
		var s: float = size_factor * (1.0 if index == 0 else 0.74 if index == 1 else 0.88)
		var pos: Vector3 = origin + positions[index] * size_factor
		# Pale stem, flat red cap lip, raised crown and cream flecks: unlike
		# the old smooth cylinders, all geometry uses the shared 16px atlas.
		PIXELS.box(st, pos + Vector3(0, 0.23 * s, 0), Vector3(0.15, 0.46, 0.16) * s, 5, 5)
		PIXELS.box(st, pos + Vector3(0, 0.46 * s, 0), Vector3(0.61, 0.15, 0.56) * s, 14, 14)
		PIXELS.box(st, pos + Vector3(0, 0.57 * s, 0), Vector3(0.43, 0.10, 0.41) * s, 14, 14)
		PIXELS.box(st, pos + Vector3(-0.12 * s, 0.63 * s, 0.07 * s), Vector3(0.12, 0.035, 0.11) * s, 5, 5)
		PIXELS.box(st, pos + Vector3(0.14 * s, 0.63 * s, -0.08 * s), Vector3(0.11, 0.035, 0.10) * s, 5, 5)
		PIXELS.box(st, pos + Vector3(0.24 * s, 0.53 * s, 0.04 * s), Vector3(0.045, 0.05, 0.08) * s, 5, 5)

static func mushrooms() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_mushroom_cluster(st, Vector3.ZERO, 1.0, false)
	return PIXELS.as_instance(st, "VoxelMushrooms")


static func crate() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	PIXELS.box(st, Vector3(0, 0.46, 0), Vector3(0.92, 0.92, 0.92), 11, 8)
	PIXELS.box(st, Vector3(0, 0.91, 0), Vector3(1.04, 0.12, 1.04), 11, 11)
	return PIXELS.as_instance(st, "VoxelCrate")


static func tent() -> MeshInstance3D:
	# Deliberately stepped canvas tent instead of a smooth primitive cone.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	PIXELS.box(st, Vector3(0, 0.06, 0), Vector3(3.9, 0.12, 3.2), 11, 8)
	for layer in range(5):
		var level: float = float(layer)
		PIXELS.box(st, Vector3(0, 0.29 + level * 0.31, 0),
			Vector3(3.2 - level * 0.49, 0.31, 3.05), 5, 5)
	PIXELS.box(st, Vector3(0, 1.83, 0), Vector3(0.28, 0.2, 3.3), 8, 8)
	PIXELS.box(st, Vector3(0, 0.64, 1.55), Vector3(0.97, 1.03, 0.09), 8, 8)
	PIXELS.box(st, Vector3(0, 0.2, 1.63), Vector3(0.95, 0.39, 0.09), 15, 15)
	return PIXELS.as_instance(st, "VoxelCanvasTent")
