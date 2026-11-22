extends RefCounted
## Immutable footprint of the current mine. Seals are streamed props.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
var footprint := {}
var roofed := {}
var seal_chunks := {}
var closed := false
var height: int

func configure(island, entrance: Vector3, terrain) -> void:
	height = terrain.caves.CORRIDOR_HEIGHT
	var queue: Array[Vector2i] = [Vector2i(floori(entrance.x), floori(entrance.z))]
	footprint[queue[0]] = int(entrance.y)
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		var floor_y: int = footprint[cell]
		if terrain.is_solid(cell.x, floor_y + height, cell.y):
			roofed[cell] = floor_y
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var other := cell + step
			if not footprint.has(other) and terrain.caves.has_cave(other.x, other.y):
				footprint[other] = terrain.caves.floor_at(other.x, other.y)
				queue.append(other)
	for cell: Vector2i in roofed:
		var ceiling: int = roofed[cell] + height
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var other := cell + step
			if roofed.has(other):
				continue
			# Both an unroofed passage and a low hillside can expose cave air.
			if footprint.has(other) or terrain.height_at(other.x, other.y) < ceiling:
				var key: Vector2i = island._cell_at(Vector3(cell.x, 0, cell.y))
				if not seal_chunks.has(key):
					seal_chunks[key] = []
				seal_chunks[key].append(cell)
				break

func blocks_destination(pos: Vector3) -> bool:
	var cell := Vector2i(floori(pos.x), floori(pos.z))
	return closed and roofed.has(cell) and pos.y < float(roofed[cell]) + height

func clear_of_player(pos: Vector3) -> bool:
	# A one-cell margin includes the capsule and either side of a chunk seam.
	var center := Vector2i(floori(pos.x), floori(pos.z))
	for x in range(center.x - 1, center.x + 2):
		for z in range(center.y - 1, center.y + 2):
			var cell := Vector2i(x, z)
			if footprint.has(cell) and pos.y < float(footprint[cell]) + height + 1:
				return false
	return true

func populate(key: Vector2i, island, members: Array) -> void:
	if not closed or not seal_chunks.has(key):
		return
	var body := StaticBody3D.new()
	body.name = "MineBulkhead"
	body.position = Vector3(key.x, 0, key.y)
	var timber := SurfaceTool.new()
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := BoxShape3D.new()
	box.size = Vector3(1, height, 1)
	for cell: Vector2i in seal_chunks[key]:
		var base := Vector3(cell.x - key.x + 0.5, roofed[cell], cell.y - key.y + 0.5)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = base + Vector3.UP * height * 0.5
		body.add_child(shape)
		for plank in height * 2:
			PIXELS.box(timber, base + Vector3.UP * (0.25 + plank * 0.5), Vector3(1, 0.5, 1), 11, 8)
	body.add_child(PIXELS.as_instance(timber, "Sealed mine timbers"))
	island.add_child(body)
	members.append(body)
