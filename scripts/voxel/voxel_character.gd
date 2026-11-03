extends RefCounted
## Original chunky avatar body parts, using the same 16x16 pixel material as the world.
## These are purely visual replacements; the existing animated pivot rig, collision,
## weapon/equipment attachment and combat logic are untouched.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")

static func create_part(part_name: String) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match part_name:
		"adventurer_torso":
			# Adventurer tunic, shoulder pads, leather belt and small gold clasp.
			PIXELS.box(st, Vector3(0, 1.27, 0), Vector3(0.94, 0.78, 0.56), 2, 10)
			PIXELS.box(st, Vector3(0, 1.57, 0), Vector3(1.05, 0.20, 0.64), 10, 2)
			PIXELS.box(st, Vector3(0, 0.91, 0), Vector3(0.96, 0.18, 0.62), 8, 8)
			PIXELS.box(st, Vector3(0, 0.91, -0.33), Vector3(0.18, 0.16, 0.05), 5, 5)
			PIXELS.box(st, Vector3(0, 1.34, -0.29), Vector3(0.21, 0.30, 0.07), 11, 11)
		"adventurer_head":
			# Pixel-sculpted face, dark hair and two square dark eyes (faces -Z).
			PIXELS.box(st, Vector3(0, 0, 0), Vector3(0.61, 0.58, 0.56), 5, 5)
			PIXELS.box(st, Vector3(0, 0.32, 0), Vector3(0.68, 0.18, 0.64), 8, 8)
			PIXELS.box(st, Vector3(0, 0.22, -0.28), Vector3(0.60, 0.10, 0.10), 8, 8)
			PIXELS.box(st, Vector3(-0.13, 0.01, -0.31), Vector3(0.10, 0.11, 0.05), 15, 15)
			PIXELS.box(st, Vector3(0.13, 0.01, -0.31), Vector3(0.10, 0.11, 0.05), 15, 15)
		"adventurer_arm":
			PIXELS.box(st, Vector3(0, -0.28, 0), Vector3(0.42, 0.61, 0.42), 2, 10)
			PIXELS.box(st, Vector3(0, -0.12, 0), Vector3(0.49, 0.16, 0.48), 10, 10)
			PIXELS.box(st, Vector3(0, -0.60, 0), Vector3(0.31, 0.20, 0.31), 8, 5)
		"adventurer_leg":
			PIXELS.box(st, Vector3(0, -0.33, 0), Vector3(0.39, 0.73, 0.42), 10, 10)
			PIXELS.box(st, Vector3(0, -0.69, -0.03), Vector3(0.42, 0.22, 0.49), 8, 8)
		"steel_sword":
			# Matching pixel-atlas blade, gold crossguard and leather-wrapped grip.
			# Blade points +Y locally; WeaponGrip aims it down/forward in-game.
			PIXELS.box(st, Vector3(0, 0.74, 0), Vector3(0.20, 1.05, 0.12), 6, 4)
			PIXELS.box(st, Vector3(0, 1.29, 0), Vector3(0.13, 0.20, 0.10), 4, 6)
			PIXELS.box(st, Vector3(0, 0.18, 0), Vector3(0.62, 0.13, 0.20), 5, 8)
			PIXELS.box(st, Vector3(0, -0.06, 0), Vector3(0.13, 0.41, 0.13), 8, 8)
			PIXELS.box(st, Vector3(0, -0.29, 0), Vector3(0.25, 0.13, 0.22), 5, 8)
		"iron_blade":
			# Chunky higher-tier blade with wider spine and brass guard.
			PIXELS.box(st, Vector3(0, 0.75, 0), Vector3(0.29, 1.13, 0.14), 4, 6)
			PIXELS.box(st, Vector3(0, 1.31, 0), Vector3(0.16, 0.16, 0.12), 6, 4)
			PIXELS.box(st, Vector3(0, 0.17, 0), Vector3(0.74, 0.14, 0.22), 5, 8)
			PIXELS.box(st, Vector3(0, -0.06, 0), Vector3(0.15, 0.41, 0.14), 8, 8)
			PIXELS.box(st, Vector3(0, -0.30, 0), Vector3(0.25, 0.14, 0.24), 5, 8)
		"steel_spear":
			# Wood shaft and a recognizable flat diamond-tip silhouette.
			PIXELS.box(st, Vector3(0, 0.63, 0), Vector3(0.13, 1.79, 0.13), 8, 8)
			PIXELS.box(st, Vector3(0, 1.44, 0), Vector3(0.30, 0.40, 0.17), 6, 4)
			PIXELS.box(st, Vector3(0, 1.68, 0), Vector3(0.17, 0.21, 0.14), 4, 6)
			PIXELS.box(st, Vector3(0, 0.26, 0), Vector3(0.42, 0.12, 0.19), 5, 8)
		"kite_shield":
			# Shield facing -Z, copper rim, leather and steel center boss.
			PIXELS.box(st, Vector3(0, 0, 0), Vector3(0.81, 0.88, 0.15), 8, 5)
			PIXELS.box(st, Vector3(0, 0.03, -0.09), Vector3(0.66, 0.72, 0.08), 12, 4)
			PIXELS.box(st, Vector3(0, -0.15, -0.15), Vector3(0.20, 0.27, 0.06), 5, 5)
			PIXELS.box(st, Vector3(0, 0.15, -0.16), Vector3(0.52, 0.11, 0.07), 5, 5)
		"cloth_cloak":
			# Stepped cape rather than the smooth imported OBJ cloth silhouette.
			PIXELS.box(st, Vector3(0, -0.21, 0.04), Vector3(0.88, 0.58, 0.13), 2, 10)
			PIXELS.box(st, Vector3(0, -0.65, 0.09), Vector3(0.96, 0.39, 0.13), 10, 2)
			PIXELS.box(st, Vector3(0, -0.98, 0.12), Vector3(1.04, 0.28, 0.15), 2, 10)
			PIXELS.box(st, Vector3(0, -0.13, -0.03), Vector3(0.20, 0.10, 0.23), 5, 5)
		_:
			return null
	return PIXELS.as_instance(st, "Voxel" + part_name.capitalize())
