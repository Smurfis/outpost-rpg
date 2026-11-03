extends RefCounted
## Single-draw-call textured mesh props, safe to hide for gathering respawn.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")

static func tree() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	PIXELS.box(st, Vector3(0, 0.85, 0), Vector3(0.58, 1.70, 0.60), 8, 8)
	PIXELS.box(st, Vector3(0, 1.76, 0), Vector3(1.55, 0.9, 1.45), 9, 10)
	PIXELS.box(st, Vector3(0.12, 2.25, 0.03), Vector3(2.1, 0.92, 1.95), 9, 9)
	PIXELS.box(st, Vector3(-0.05, 2.80, 0), Vector3(1.5, 0.76, 1.45), 1, 9)
	PIXELS.box(st, Vector3(0.18, 3.24, 0.08), Vector3(0.8, 0.50, 0.8), 1, 10)
	return PIXELS.as_instance(st, "VoxelTree")

static func rock(kind: String = "stone") -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side: int = 15 if kind == "coal" else 3 if kind == "clay" else 4
	var top: int = 7 if kind == "stone" else side
	PIXELS.box(st, Vector3(-0.35, 0.33, 0.02), Vector3(1.06, 0.67, 0.94), top, side)
	PIXELS.box(st, Vector3(0.32, 0.42, -0.12), Vector3(0.9, 0.83, 0.81), side, side)
	PIXELS.box(st, Vector3(0.1, 0.24, 0.44), Vector3(0.87, 0.48, 0.56), side, side)
	if kind == "iron":
		PIXELS.box(st, Vector3(-0.27, 0.79, -0.13), Vector3(0.22, 0.43, 0.25), 13, 13)
		PIXELS.box(st, Vector3(0.45, 0.90, 0.06), Vector3(0.26, 0.38, 0.26), 13, 13)
	if kind == "coal":
		PIXELS.box(st, Vector3(0.34, 0.87, 0.10), Vector3(0.38, 0.26, 0.27), 15, 15)
	return PIXELS.as_instance(st, "Voxel" + kind.capitalize())

static func bush(has_berries: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	PIXELS.box(st, Vector3(-0.36, 0.33, -0.12), Vector3(0.85, 0.66, 0.92), 9, 10)
	PIXELS.box(st, Vector3(0.28, 0.45, 0.05), Vector3(1.01, 0.9, 0.95), 9, 9)
	PIXELS.box(st, Vector3(-0.01, 0.62, -0.10), Vector3(0.83, 0.70, 0.84), 1, 9)
	if has_berries:
		for p in [Vector3(-0.45, 0.68, 0.43), Vector3(0.48, 0.79, -0.25), Vector3(0.1, 0.97, 0.19)]:
			PIXELS.box(st, p, Vector3.ONE * 0.22, 14, 14)
	return PIXELS.as_instance(st, "VoxelBerryBush" if has_berries else "VoxelFiberBush")

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
