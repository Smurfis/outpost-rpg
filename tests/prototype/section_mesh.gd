extends RefCounted
## One immutable voxel volume. Only the visual occupancy changes.
const ATLAS = preload("res://scripts/voxel/greedy_mesher.gd")
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const DIRS := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
# The winding matches the island renderer. Coordinates address voxel corners.
const QUADS := [[5,1,3,7], [0,4,6,2], [2,6,7,3], [4,0,1,5], [4,5,7,6], [1,0,2,3]]
const CORNERS := [Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3(1,1,0),
	Vector3.BACK,Vector3(1,0,1),Vector3(0,1,1),Vector3.ONE]
var solids := {}
var rooms: Array[Dictionary] = []
var cache := {}
var meshes_built := 0

func _init() -> void:
	for x in range(19):
		for z in range(10):
			for y in range(-2, 5):
				var edge := x in [0,9,18] or z in [0,9]
				var door := x == 9 and z == 5 and y >= 0 and y < 3
				if y < 0 or y == 4 or (edge and not door):
					solids[Vector3i(x,y,z)] = 6 if y == -1 else 4
	# Two parts of the architecture survive the section through the shell.
	for y in range(4):
		solids[Vector3i(6,y,2)] = 12
	for x in range(13,17):
		solids[Vector3i(x,0,2)] = 12
	# Flood walkable columns independently on either side of the doorway.
	for seed_cell in [Vector2i(3,5), Vector2i(12,5)]:
		var cells := {}
		var queue: Array[Vector2i] = [seed_cell]
		cells[seed_cell] = true
		var i := 0
		while i < queue.size():
			var cell := queue[i]
			i += 1
			for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var n: Vector2i = cell + dir
				if n == Vector2i(9,5) or cells.has(n):
					continue
				if solids.has(Vector3i(n.x,1,n.y)) or not solids.has(Vector3i(n.x,-1,n.y)):
					continue
				cells[n] = true
				queue.append(n)
		rooms.append(cells)

func room_at(at: Vector3, previous: int) -> int:
	var cell := Vector2i(floori(at.x),floori(at.z))
	for i in rooms.size():
		if rooms[i].has(cell):
			return i
	return previous if cell == Vector2i(9,5) else -1

func geometry(room: int, side: Vector2i) -> Dictionary:
	var key := Vector3i(room,side.x,side.y) if room >= 0 else Vector3i(-1,0,0)
	if cache.has(key):
		return cache[key]
	var hidden := {}
	if room >= 0:
		var cells := rooms[room]
		# Include the ceiling above interior columns such as the pillar.
		var bounds := Rect2i(cells.keys()[0],Vector2i.ONE)
		for cell: Vector2i in cells:
			bounds = bounds.merge(Rect2i(cell,Vector2i.ONE))
		for voxel: Vector3i in solids:
			var col := Vector2i(voxel.x,voxel.z)
			if voxel.y == 4 and bounds.grow(1).has_point(col) and voxel.x != 9:
				hidden[voxel] = true
			elif voxel.y >= 0 and voxel.x != 9 and bounds.grow(1).has_point(col):
				var outward := col - col.clamp(bounds.position,bounds.end-Vector2i.ONE)
				if outward.x * side.x > 0 or outward.y * side.y > 0:
					hidden[voxel] = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var new_faces := 0
	for voxel: Vector3i in solids:
		if hidden.has(voxel):
			continue
		for f in DIRS.size():
			var adjacent: Vector3i = voxel + DIRS[f]
			if solids.has(adjacent) and not hidden.has(adjacent):
				continue
			if hidden.has(adjacent):
				new_faces += 1
			var tile: int = solids[voxel]
			if voxel.y == 4 and f == 2:
				tile = 0
			elif voxel.y == -1 and f != 2:
				tile = 4
			var q: Array = QUADS[f]
			var p := Vector3(voxel)
			ATLAS.tiled_quad(st,p+CORNERS[q[0]],p+CORNERS[q[1]],p+CORNERS[q[2]],p+CORNERS[q[3]],tile,["x","x","top","top","z","z"][f])
	var mesh := PALETTE.create_mesh(st)
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	cache[key] = {"mesh":mesh,"shape":shape,"new_faces":new_faces}
	meshes_built += 1
	return cache[key]
