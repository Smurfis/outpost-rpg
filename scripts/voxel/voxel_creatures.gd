extends RefCounted
## Pixel-world boar. Every enemy shares one atlas and one cached combined mesh.
## This affects visuals only; the original AI, health, hitbox and drops remain.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
static var _boar_mesh: ArrayMesh

static func create_boar() -> MeshInstance3D:
	if _boar_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Heavy boxy torso with short, dark haunches and a squared muzzle.
		PIXELS.box(st, Vector3(0.0, 0.75, 0.10), Vector3(1.24, 0.88, 1.65), 8, 3)
		PIXELS.box(st, Vector3(0.0, 1.17, 0.05), Vector3(0.91, 0.18, 1.12), 8, 8)
		PIXELS.box(st, Vector3(0.0, 0.83, -0.69), Vector3(0.90, 0.72, 0.81), 8, 3)
		PIXELS.box(st, Vector3(0.0, 1.15, -0.89), Vector3(0.87, 0.17, 0.38), 8, 8)
		# Two pixel-textured ears that break the otherwise flat head silhouette.
		for side in [-1.0, 1.0]:
			PIXELS.box(st, Vector3(side * 0.37, 1.33, -0.79), Vector3(0.31, 0.43, 0.21), 8, 8)
			PIXELS.box(st, Vector3(side * 0.35, 1.33, -0.91), Vector3(0.17, 0.21, 0.04), 14, 14)
		# Snout, nostrils, readable dark eyes, paired tusks and feet.
		PIXELS.box(st, Vector3(0.0, 0.54, -1.12), Vector3(0.67, 0.36, 0.44), 5, 5)
		PIXELS.box(st, Vector3(0.0, 0.58, -1.36), Vector3(0.51, 0.25, 0.08), 15, 15)
		for side in [-1.0, 1.0]:
			PIXELS.box(st, Vector3(side * 0.255, 0.97, -1.106), Vector3(0.13, 0.13, 0.08), 15, 15)
			PIXELS.box(st, Vector3(side * 0.32, 0.38, -1.22), Vector3(0.13, 0.32, 0.18), 12, 12)
			for z in [-0.54, 0.61]:
				PIXELS.box(st, Vector3(side * 0.46, 0.23, z), Vector3(0.30, 0.46, 0.36), 8, 8)
				PIXELS.box(st, Vector3(side * 0.46, 0.055, z - 0.055), Vector3(0.31, 0.10, 0.39), 15, 15)
		# Thick squared tail (no smooth sphere/primitive silhouette).
		PIXELS.box(st, Vector3(0.0, 0.89, 1.02), Vector3(0.24, 0.23, 0.46), 8, 8)
		PIXELS.box(st, Vector3(0.0, 0.99, 1.22), Vector3(0.25, 0.26, 0.24), 3, 8)
		_boar_mesh = PIXELS.create_mesh(st)
	var result := MeshInstance3D.new()
	result.name = "VoxelWildBoar"
	result.mesh = _boar_mesh
	result.material_override = PIXELS.get_material()
	return result
