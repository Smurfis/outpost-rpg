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

# Transform complete quads with the engine's packed-array operations. Store
# the original winding and projected atlas coordinates once per orientation.
static var face_points: Array[PackedVector3Array] = []
static var face_normals: Array[PackedVector3Array] = []
static var face_uv: Array[PackedVector2Array] = []

static func _init_quads() -> void:
	for face in DIRECTIONS.size():
		var points := PackedVector3Array()
		var directions := PackedVector3Array()
		var uvs := PackedVector2Array()
		for corner in [0,3,2,0,2,1]:
			var p: Vector3 = CORNERS[QUADS[face][corner]]
			points.append(p)
			directions.append(Vector3(DIRECTIONS[face]))
			uvs.append(Vector2(p.z,p.y) if face<2 else (Vector2(p.x,p.z) if face<4 else Vector2(p.x,p.y)))
		face_points.append(points)
		face_normals.append(directions)
		face_uv.append(uvs)

static func build(terrain, origin: Vector2i, size: int, hidden: Dictionary) -> Dictionary:
	var job = new()
	var masks := {}
	for voxel: Vector3i in hidden:
		var col := Vector2i(voxel.x,voxel.z)
		masks[col] = int(masks.get(col,0)) | (1 << (voxel.y-DATA.BEDROCK))
	job.begin(terrain, origin, size, masks)
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
var signature: PackedInt64Array # World-space hidden occupancy over this patch and its apron.
var cursor := 0
var face_count := 0
var cut_faces := 0

func begin(source, key: Vector2i, width: int, mask: Dictionary) -> void:
	if face_points.is_empty():
		_init_quads()
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
var reusable: Dictionary
var packet_hits := 0
var packet_bytes_delta := 0
func _bits(x: int, z: int) -> int:
	var col := Vector2i(x,z)
	if columns.has(col):
		return columns[col]
	if reusable.has("solid") and reusable.solid.has(col):
		var sampled := int(reusable.solid[col]) & ~int(hidden.get(col,0))
		columns[col] = sampled
		return sampled
	var bits: int = terrain.solid_column(x,z)
	if reusable.has("solid"):
		reusable.solid[col] = bits
	bits &= ~int(hidden.get(col,0))
	columns[col] = bits
	return bits

func _column(x: int, z: int) -> void:
	var solid := _bits(x,z)
	if solid == 0:
		return
	var top: int = maxi(terrain.height_at(x,z), terrain.caves.floor_at(x,z))
	var neighbours := [_bits(x+1,z),_bits(x-1,z),solid >> 1,solid << 1,_bits(x,z+1),_bits(x,z-1)]
	var faces := PackedInt64Array()
	for adjacent: int in neighbours:
		faces.append(solid & ~adjacent)
	var col := Vector2i(x,z)
	var packets: Array = reusable.get("packets",{}).get(col,[])
	for packet: Dictionary in packets:
		if faces == packet.faces:
			positions.append_array(packet.positions)
			normals.append_array(packet.normals)
			uv.append_array(packet.uv)
			atlas_tiles.append_array(packet.tiles)
			face_count += int(packet.positions.size()) / 6
			cut_faces += int(packet.cuts)
			packet_hits += 1
			return
	var start := positions.size()
	var previous_cuts := cut_faces
	for face in DIRECTIONS.size():
		var exposed := faces[face]
		var y := DATA.BEDROCK
		while exposed:
			if exposed & 1:
				var voxel := Vector3i(x,y,z)
				var neighbor: Vector3i = voxel + DIRECTIONS[face]
				if neighbor.y >= DATA.BEDROCK and int(hidden.get(Vector2i(neighbor.x,neighbor.z),0)) & (1 << (neighbor.y-DATA.BEDROCK)):
					cut_faces += 1
				var tile: int = terrain.top_tile(x,z) if y == top-1 and face == 2 else 4
				if face == 2 and y+1 == terrain.caves.floor_at(x,z) and top > y+3:
					tile = 6 # Existing gravel atlas for the natural cave bed.
				var base_uv := Vector2(z,y) if face<2 else (Vector2(x,z) if face<4 else Vector2(x,y))
				positions.append_array(Transform3D(Basis.IDENTITY,Vector3(voxel))*face_points[face])
				normals.append_array(face_normals[face])
				uv.append_array(Transform2D(0.0,base_uv)*face_uv[face])
				var tile_data := PackedVector2Array()
				tile_data.resize(6)
				tile_data.fill(Vector2(tile,-9999 if face in [2,3] else y+1))
				atlas_tiles.append_array(tile_data)
				face_count += 1
			exposed >>= 1
			y += 1

	# Keep two recent surface patterns per column. Matching faces have the
	# same world coordinates, atlas coordinates and collision winding.
	if reusable.has("packets"):
		if packets.size() >= 2:
			packet_bytes_delta -= packets.pop_front().positions.size()*40
		packets.append({"faces":faces,"positions":positions.slice(start),"normals":normals.slice(start),
			"uv":uv.slice(start),"tiles":atlas_tiles.slice(start),"cuts":cut_faces-previous_cuts})
		packet_bytes_delta += (positions.size()-start)*40
		reusable.packets[col] = packets

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
