extends RefCounted
## Reconstruct a chunk's visible faces from the island's original occupancy.
## Callers supply a bounded set of solid voxel coordinates to hide. Collision
## and the source occupancy remain untouched.
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const DIRECTIONS := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
const CORNERS := [Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3(1, 1, 0),
	Vector3.BACK, Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3.ONE]
const QUADS := [[5, 1, 3, 7], [0, 4, 6, 2], [2, 6, 7, 3],
	[4, 0, 1, 5], [4, 5, 7, 6], [1, 0, 2, 3]]

static func build(terrain, origin: Vector2i, size: int, hidden: Dictionary) -> Dictionary:
	var job = new()
	job.begin(terrain, origin, size, hidden)
	while not job.advance(0):
		pass
	return job.finish()

var positions := PackedVector3Array()
var normals := PackedVector3Array()
var uv := PackedVector2Array()
var atlas_tiles := PackedVector2Array()
var terrain
var origin: Vector2i
var size: int
var hidden: Dictionary
var cursor := 0
var face_count := 0
var cut_faces := 0

func begin(source, key: Vector2i, width: int, mask: Dictionary) -> void:
	terrain = source
	origin = key
	size = width
	hidden = mask

func advance(deadline: int) -> bool:
	while cursor < size * size:
		_column(origin.x + cursor / size, origin.y + cursor % size)
		cursor += 1
		if deadline and Time.get_ticks_usec() >= deadline:
			break
	return cursor == size * size

# Sample each visible column once, including the chunk's neighbour apron.
var columns := {}
func _bits(x: int, z: int) -> int:
	var col := Vector2i(x,z)
	if columns.has(col):
		return columns[col]
	var top: int = maxi(terrain.height_at(x,z), terrain.caves.floor_at(x,z))
	assert(top - DATA.BEDROCK < 63)
	var bits := 0
	for y in range(DATA.BEDROCK,top):
		if not hidden.has(Vector3i(x,y,z)) and terrain.is_solid(x,y,z):
			bits |= 1 << (y-DATA.BEDROCK)
	columns[col] = bits
	return bits

func _column(x: int, z: int) -> void:
	var solid := _bits(x,z)
	if solid == 0:
		return
	var top: int = maxi(terrain.height_at(x,z), terrain.caves.floor_at(x,z))
	var neighbours := [_bits(x+1,z),_bits(x-1,z),solid >> 1,solid << 1,_bits(x,z+1),_bits(x,z-1)]
	for face in DIRECTIONS.size():
		var exposed: int = solid & ~int(neighbours[face])
		var y := DATA.BEDROCK
		while exposed:
			if exposed & 1:
				var voxel := Vector3i(x,y,z)
				if hidden.has(voxel + DIRECTIONS[face]):
					cut_faces += 1
				var tile: int = terrain.top_tile(x,z) if y == top-1 and face == 2 else 4
				if face == 2 and y+1 == terrain.caves.floor_at(x,z) and top > y+3:
					tile = 6 # Existing gravel atlas for the natural cave bed.
				var q: Array = QUADS[face]
				var p := Vector3(voxel)
				var tile_data := Vector2(tile, -9999 if face in [2,3] else y+1)
				for corner in [0,3,2,0,2,1]:
					var point: Vector3 = p + CORNERS[q[corner]]
					positions.append(point)
					normals.append(Vector3(DIRECTIONS[face]))
					uv.append(Vector2(point.z, point.y) if face < 2 else (Vector2(point.x, point.z) if face < 4 else Vector2(point.x, point.y)))
					atlas_tiles.append(tile_data)
				face_count += 1
			exposed >>= 1
			y += 1

func finish() -> Dictionary:
	if face_count == 0:
		return {"mesh": null, "cut_faces": cut_faces}
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = atlas_tiles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(positions)
	return {"mesh": mesh, "shape": shape, "vertices": positions.size(), "cut_faces": cut_faces}
