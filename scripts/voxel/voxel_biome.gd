extends Node3D
## Fixed-size world-skin experiment. No collisions, changes to saves, or voxel mining.
## Procedural meshes share an original 16x16-pixel atlas; terrain is grouped in 8x8 chunks.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const CHUNK_SIZE: int = 8
const MAP_HALF: int = 23

func build() -> void:
	name = "VoxelAtmosphere"
	_make_ground()
	_make_cliff_rim()
	_make_grass_detail()

func _make_ground() -> void:
	for chunk_x in range(-MAP_HALF, MAP_HALF, CHUNK_SIZE):
		for chunk_z in range(-MAP_HALF, MAP_HALF, CHUNK_SIZE):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for x in range(chunk_x, mini(chunk_x + CHUNK_SIZE, MAP_HALF)):
				for z in range(chunk_z, mini(chunk_z + CHUNK_SIZE, MAP_HALF)):
					var tile: int = _ground_tile(x, z)
					PIXELS.quad(st,
						Vector3(x, -0.055, z),
						Vector3(x, -0.055, z + 1),
						Vector3(x + 1, -0.055, z + 1),
						Vector3(x + 1, -0.055, z), tile)
					if x == -MAP_HALF:
						PIXELS.quad(st, Vector3(x, -2.2, z + 1), Vector3(x, -2.2, z),
							Vector3(x, -0.055, z), Vector3(x, -0.055, z + 1), 3)
					if x == MAP_HALF - 1:
						PIXELS.quad(st, Vector3(x + 1, -2.2, z),
							Vector3(x + 1, -2.2, z + 1), Vector3(x + 1, -0.055, z + 1),
							Vector3(x + 1, -0.055, z), 4)
					if z == -MAP_HALF:
						PIXELS.quad(st, Vector3(x, -2.2, z),
							Vector3(x + 1, -2.2, z), Vector3(x + 1, -0.055, z),
							Vector3(x, -0.055, z), 3)
					if z == MAP_HALF - 1:
						PIXELS.quad(st, Vector3(x + 1, -2.2, z + 1),
							Vector3(x, -2.2, z + 1), Vector3(x, -0.055, z + 1),
							Vector3(x + 1, -0.055, z + 1), 4)
			add_child(PIXELS.as_instance(st, "GroundChunk_%d_%d" % [chunk_x, chunk_z]))

func _ground_tile(x: int, z: int) -> int:
	var p := Vector2(float(x) + 0.5, float(z) + 0.5)
	var path_distance: float = minf(_distance_segment(p, Vector2(-18, -1), Vector2(20, 2)),
		minf(_distance_segment(p, Vector2(0, -21), Vector2(-1, 21)),
		_distance_segment(p, Vector2(-1, -4), Vector2(6, 4))))
	var hash_value: int = posmod(x * 137 + z * 113 + x * z * 7, 17)
	if path_distance < 1.55:
		return 5 if hash_value < 13 else 6
	if path_distance < 2.0 and hash_value % 2 == 0:
		return 6
	if hash_value <= 2:
		return 1
	if hash_value >= 14:
		return 2
	return 0

func _distance_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var segment: Vector2 = b - a
	var t: float = clampf((p - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return p.distance_to(a + segment * t)

func _make_cliff_rim() -> void:
	# Hills are safely beyond the existing +/-23 invisible world walls.
	# They never affect pathing, NPC/harvest positions, physics or interaction ranges.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-31, 32, 2):
		for z in range(-31, 32, 2):
			if absi(x) < 24 and absi(z) < 24:
				continue
			var height: float = 1.8 + float(posmod(x * 31 + z * 47, 6)) * 0.37
			var high: bool = posmod(x * 7 + z * 11, 11) >= 7
			if high:
				height += 0.9
			PIXELS.box(st, Vector3(float(x), (height - 2.0) * 0.5, float(z)),
				Vector3(2.0, height + 2.0, 2.0), 1 if high else 0, 4 if high else 3)
	add_child(PIXELS.as_instance(st, "SteppedDistanceCliffs"))

func _make_grass_detail() -> void:
	# Pixel-sized flowers/grass rather than hundreds of individually drawn nodes.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(90):
		var x: float = float(posmod(i * 41 + 7, 42)) - 21.0
		var z: float = float(posmod(i * 83 + 13, 42)) - 21.0
		if _ground_tile(int(floorf(x)), int(floorf(z))) in [5, 6]:
			continue
		if absf(x) < 4.0 and absf(z) < 4.0:
			continue
		var h: float = 0.11 + float(i % 4) * 0.035
		PIXELS.box(st, Vector3(x, h * 0.5 - 0.03, z),
			Vector3(0.10, h, 0.10), 1, 9)
		if i % 7 == 0:
			PIXELS.box(st, Vector3(x, h + 0.03, z), Vector3(0.17, 0.12, 0.17), 14, 14)
	add_child(PIXELS.as_instance(st, "VoxelWildflowers"))
