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
			# Raised shoulders and a square leather satchel strap add a readable
			# adventurer silhouette at phone-camera distances.
			PIXELS.box(st, Vector3(-0.52, 1.52, -0.01), Vector3(0.26, 0.26, 0.58), 11, 8)
			PIXELS.box(st, Vector3(0.52, 1.52, -0.01), Vector3(0.26, 0.26, 0.58), 11, 8)
			PIXELS.box(st, Vector3(-0.26, 1.35, -0.315), Vector3(0.13, 0.60, 0.055), 8, 8)
			# Visible green collar, cloth folds, gold buckle and a compact leather
			# travelling pack; still part of the original animated torso mesh.
			PIXELS.box(st, Vector3(0, 1.65, -0.16), Vector3(0.57, 0.10, 0.33), 1, 10)
			PIXELS.box(st, Vector3(0.25, 1.20, -0.30), Vector3(0.09, 0.43, 0.05), 7, 1)
			PIXELS.box(st, Vector3(0.0, 0.91, -0.365), Vector3(0.20, 0.13, 0.075), 5, 5)
			PIXELS.box(st, Vector3(0, 1.24, 0.42), Vector3(0.69, 0.72, 0.36), 8, 8)
			PIXELS.box(st, Vector3(0, 1.52, 0.63), Vector3(0.73, 0.15, 0.14), 11, 8)
			PIXELS.box(st, Vector3(0, 1.19, 0.64), Vector3(0.38, 0.12, 0.10), 5, 8)
		"adventurer_head":
			# Pixel-sculpted face, dark hair and two square dark eyes (faces -Z).
			PIXELS.box(st, Vector3(0, 0, 0), Vector3(0.61, 0.58, 0.56), 5, 5)
			PIXELS.box(st, Vector3(0, 0.32, 0), Vector3(0.68, 0.18, 0.64), 8, 8)
			PIXELS.box(st, Vector3(0, 0.22, -0.28), Vector3(0.60, 0.10, 0.10), 8, 8)
			PIXELS.box(st, Vector3(-0.13, 0.01, -0.31), Vector3(0.10, 0.11, 0.05), 15, 15)
			PIXELS.box(st, Vector3(0.13, 0.01, -0.31), Vector3(0.10, 0.11, 0.05), 15, 15)
			# Irregular stepped fringe and small rosy cheeks make the face
			# expressive while remaining a single simple voxel mesh.
			PIXELS.box(st, Vector3(-0.20, 0.28, -0.23), Vector3(0.22, 0.13, 0.17), 8, 8)
			PIXELS.box(st, Vector3(0.11, 0.31, -0.28), Vector3(0.29, 0.12, 0.15), 8, 8)
			PIXELS.box(st, Vector3(-0.27, -0.07, -0.315), Vector3(0.08, 0.07, 0.035), 14, 14)
			PIXELS.box(st, Vector3(0.27, -0.07, -0.315), Vector3(0.08, 0.07, 0.035), 14, 14)
			PIXELS.box(st, Vector3(0.0, -0.12, -0.319), Vector3(0.06, 0.05, 0.045), 8, 8)
			# Character pass: a stepped chestnut quiff and square side locks,
			# echoing the ranger portrait without altering head rig placement.
			PIXELS.box(st, Vector3(0.01, 0.39, -0.05), Vector3(0.78, 0.16, 0.65), 8, 8)
			PIXELS.box(st, Vector3(-0.20, 0.32, -0.29), Vector3(0.35, 0.15, 0.16), 8, 8)
			PIXELS.box(st, Vector3(0.12, 0.28, -0.32), Vector3(0.23, 0.13, 0.13), 8, 8)
			PIXELS.box(st, Vector3(-0.38, 0.11, -0.03), Vector3(0.11, 0.40, 0.48), 8, 8)
			PIXELS.box(st, Vector3(0.38, 0.10, -0.02), Vector3(0.11, 0.36, 0.47), 8, 8)
			# Slightly wider pale cheeks, with the existing eye positions intact.
			PIXELS.box(st, Vector3(-0.25, -0.06, -0.337), Vector3(0.08, 0.08, 0.04), 14, 14)
			PIXELS.box(st, Vector3(0.25, -0.06, -0.337), Vector3(0.08, 0.08, 0.04), 14, 14)
		"adventurer_arm":
			PIXELS.box(st, Vector3(0, -0.28, 0), Vector3(0.42, 0.61, 0.42), 2, 10)
			PIXELS.box(st, Vector3(0, -0.12, 0), Vector3(0.49, 0.16, 0.48), 10, 10)
			PIXELS.box(st, Vector3(0, -0.60, 0), Vector3(0.31, 0.20, 0.31), 8, 5)
			PIXELS.box(st, Vector3(0, -0.39, -0.23), Vector3(0.32, 0.13, 0.06), 11, 8)
		"adventurer_leg":
			PIXELS.box(st, Vector3(0, -0.33, 0), Vector3(0.39, 0.73, 0.42), 10, 10)
			PIXELS.box(st, Vector3(0, -0.69, -0.03), Vector3(0.42, 0.22, 0.49), 8, 8)
			PIXELS.box(st, Vector3(0, -0.56, -0.14), Vector3(0.43, 0.11, 0.30), 11, 8)
			PIXELS.box(st, Vector3(0, -0.76, -0.14), Vector3(0.45, 0.13, 0.53), 8, 8)
		"steel_sword":
			# Matching pixel-atlas blade, gold crossguard and leather-wrapped grip.
			# Blade points +Y locally; WeaponGrip aims it down/forward in-game.
			PIXELS.box(st, Vector3(0, 0.74, 0), Vector3(0.20, 1.05, 0.12), 6, 4)
			PIXELS.box(st, Vector3(0, 1.29, 0), Vector3(0.13, 0.20, 0.10), 4, 6)
			PIXELS.box(st, Vector3(0, 0.80, -0.076), Vector3(0.065, 0.84, 0.035), 7, 7) # Steel fuller.
			PIXELS.box(st, Vector3(0, 1.42, 0), Vector3(0.10, 0.10, 0.08), 6, 6) # Tiered tip.
			PIXELS.box(st, Vector3(0, 0.18, 0), Vector3(0.62, 0.13, 0.20), 5, 8)
			PIXELS.box(st, Vector3(0, -0.06, 0), Vector3(0.13, 0.41, 0.13), 8, 8)
			PIXELS.box(st, Vector3(0, -0.29, 0), Vector3(0.25, 0.13, 0.22), 5, 8)
		"iron_blade":
			# Chunky higher-tier blade with wider spine and brass guard.
			PIXELS.box(st, Vector3(0, 0.75, 0), Vector3(0.29, 1.13, 0.14), 4, 6)
			PIXELS.box(st, Vector3(0, 1.31, 0), Vector3(0.16, 0.16, 0.12), 6, 4)
			PIXELS.box(st, Vector3(0, 0.72, -0.09), Vector3(0.085, 0.91, 0.045), 6, 6)
			PIXELS.box(st, Vector3(-0.15, 1.04, 0), Vector3(0.08, 0.44, 0.13), 7, 4)
			PIXELS.box(st, Vector3(0.15, 1.04, 0), Vector3(0.08, 0.44, 0.13), 7, 4)
			PIXELS.box(st, Vector3(0, 0.17, 0), Vector3(0.74, 0.14, 0.22), 5, 8)
			PIXELS.box(st, Vector3(0, -0.06, 0), Vector3(0.15, 0.41, 0.14), 8, 8)
			PIXELS.box(st, Vector3(0, -0.30, 0), Vector3(0.25, 0.14, 0.24), 5, 8)
		"steel_spear":
			# Wood shaft and a recognizable flat diamond-tip silhouette.
			PIXELS.box(st, Vector3(0, 0.63, 0), Vector3(0.13, 1.79, 0.13), 8, 8)
			PIXELS.box(st, Vector3(0, 1.44, 0), Vector3(0.30, 0.40, 0.17), 6, 4)
			PIXELS.box(st, Vector3(0, 1.68, 0), Vector3(0.17, 0.21, 0.14), 4, 6)
			PIXELS.box(st, Vector3(-0.16, 1.37, 0), Vector3(0.11, 0.22, 0.15), 4, 7)
			PIXELS.box(st, Vector3(0.16, 1.37, 0), Vector3(0.11, 0.22, 0.15), 4, 7)
			PIXELS.box(st, Vector3(0, 0.26, 0), Vector3(0.42, 0.12, 0.19), 5, 8)
		"hand_axe":
			# One atlas-batched, bevelled-looking woodcutter's axe. The hilt is
			# centered on the wrist; the broad left cutting edge points down.
			# Keep the same local +Y head direction as the OBJ fallback model.
			PIXELS.box(st, Vector3(0, 0.22, 0), Vector3(0.15, 1.40, 0.15), 8, 11)
			PIXELS.box(st, Vector3(0, -0.42, 0), Vector3(0.22, 0.12, 0.20), 8, 8)
			for y in [-0.28, -0.14, 0.00, 0.14]:
				PIXELS.box(st, Vector3(0, y, -0.003), Vector3(0.17, 0.048, 0.18), 8, 5)
			PIXELS.box(st, Vector3(0, 0.89, 0), Vector3(0.22, 0.20, 0.23), 4, 4) # Head socket
			PIXELS.box(st, Vector3(-0.23, 0.86, 0), Vector3(0.49, 0.32, 0.25), 4, 6)
			PIXELS.box(st, Vector3(-0.49, 0.86, 0), Vector3(0.28, 0.43, 0.23), 4, 4)
			PIXELS.box(st, Vector3(-0.65, 0.86, 0), Vector3(0.14, 0.55, 0.18), 6, 4) # Bright edge
			PIXELS.box(st, Vector3(-0.56, 1.10, 0), Vector3(0.22, 0.13, 0.19), 4, 6)
			PIXELS.box(st, Vector3(-0.56, 0.62, 0), Vector3(0.22, 0.13, 0.19), 4, 6)
			PIXELS.box(st, Vector3(-0.31, 0.86, -0.142), Vector3(0.30, 0.07, 0.035), 6, 6)
		"hand_pickaxe":
			# Heavy forged center and tapered double-tipped head, all on one mesh.
			PIXELS.box(st, Vector3(0, 0.22, 0), Vector3(0.15, 1.40, 0.15), 8, 11)
			PIXELS.box(st, Vector3(0, -0.42, 0), Vector3(0.22, 0.12, 0.20), 8, 8)
			for y in [-0.28, -0.14, 0.00, 0.14]:
				PIXELS.box(st, Vector3(0, y, -0.003), Vector3(0.17, 0.048, 0.18), 8, 5)
			PIXELS.box(st, Vector3(0, 0.92, 0), Vector3(0.28, 0.33, 0.26), 4, 6)
			PIXELS.box(st, Vector3(0, 0.99, 0), Vector3(0.77, 0.22, 0.24), 4, 4)
			for side in [-1.0, 1.0]:
				PIXELS.box(st, Vector3(side * 0.50, 0.98, 0), Vector3(0.37, 0.17, 0.20), 4, 6)
				PIXELS.box(st, Vector3(side * 0.70, 0.95, 0), Vector3(0.19, 0.13, 0.17), 6, 4)
				PIXELS.box(st, Vector3(side * 0.82, 0.91, 0), Vector3(0.13, 0.10, 0.13), 6, 6)
			PIXELS.box(st, Vector3(0, 0.99, -0.145), Vector3(0.38, 0.055, 0.035), 6, 6)
		"torch":
			PIXELS.box(st, Vector3(0, 0.0, 0), Vector3(0.18, 0.85, 0.20), 8, 8)
			PIXELS.box(st, Vector3(0, 0.43, 0), Vector3(0.30, 0.13, 0.29), 5, 8)
			PIXELS.box(st, Vector3(0, 0.59, 0), Vector3(0.28, 0.29, 0.26), 13, 14)
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
