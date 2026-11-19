extends RefCounted
## Reconstruct a chunk's visible faces from the island's original occupancy.
## Callers supply a bounded set of solid voxel coordinates to hide. Collision
## and the source occupancy remain untouched.
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const DIRECTIONS := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
const CORNERS := [Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3(1, 1, 0),
	Vector3.BACK, Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3.ONE]
const QUADS := [[5, 1, 3, 7], [0, 4, 6, 2], [2, 6, 7, 3],
	[4, 0, 1, 5], [4, 5, 7, 6], [1, 0, 2, 3]]
const AXES := ["x", "x", "top", "top", "z", "z"]

static func build(terrain, origin: Vector2i, size: int, hidden: Dictionary) -> Dictionary:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var face_count := 0
	var cut_faces := 0
	for x in range(origin.x, origin.x + size):
		for z in range(origin.y, origin.y + size):
			var top: int = terrain.height_at(x, z)
			var cave_floor: int = terrain.caves.floor_at(x, z)
			if cave_floor != -99999:
				top = maxi(top, cave_floor)
			for y in range(DATA.BEDROCK, top):
				var voxel := Vector3i(x, y, z)
				if hidden.has(voxel) or not terrain.is_solid(x, y, z):
					continue
				for face in DIRECTIONS.size():
					var neighbor: Vector3i = voxel + DIRECTIONS[face]
					if not hidden.has(neighbor) and terrain.is_solid(neighbor.x, neighbor.y, neighbor.z):
						continue
					if hidden.has(neighbor):
						cut_faces += 1
					var tile: int = terrain.top_tile(x, z) if y == top - 1 and face == 2 else 4
					var q: Array = QUADS[face]
					var p := Vector3(voxel)
					GREEDY.tiled_quad(surface, p + CORNERS[q[0]], p + CORNERS[q[3]],
						p + CORNERS[q[2]], p + CORNERS[q[1]], tile, AXES[face])
					face_count += 1
	if face_count == 0:
		return {"mesh": null, "cut_faces": cut_faces}
	return {"mesh": PALETTE.create_mesh(surface), "cut_faces": cut_faces}
