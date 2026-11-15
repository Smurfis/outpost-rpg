extends RefCounted
## Deterministic, batched voxel-accent props for themed dungeon chambers.
## Decorative shapes stay in wall corners and side recesses, leaving the central
## 4x4 spawn/combat area and all four 2-unit doorways unobstructed.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const TILES_STONE: int = 12
const TILES_MOSS: int = 7
const TILES_WOOD: int = 8
const TILES_IRON: int = 4
const TILES_CRYSTAL: int = 13
const TILES_GOLD: int = 5

static func decorate(floor_root: Node3D, room: Dictionary, center: Vector3, rarity: int, rooms: Array = []) -> MeshInstance3D:
	var style: String = str(room.get("archetype", "gallery"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(room.get("decor_seed", 1))
	match style:
		"entry":
			_pillars(st, 0.66, 2.2, TILES_MOSS)
			# A gatehouse with four lamps and a distinct stone landing.
			for x in [-3.8, 3.8]:
				PIXELS.box(st, Vector3(x, 0.13, -4.4), Vector3(1.0, 0.26, 0.8), TILES_GOLD, TILES_STONE)
				PIXELS.box(st, Vector3(x, 1.30, -4.4), Vector3(0.22, 2.14, 0.22), TILES_WOOD, TILES_WOOD)
		"stairs":
			# The actual climbable staircase comes from FloorExit and turns
			# toward its doorway. Do not place conflicting fake steps.
			_pillars(st, 0.78, 2.55, TILES_IRON)
			for x in [-3.2, 3.2]:
				PIXELS.box(st, Vector3(x, 0.07, 0), Vector3(0.30, 0.14, 5.0), TILES_GOLD, TILES_STONE)
		"boss":
			_pillars(st, 0.98, 3.4, TILES_STONE)
			for x in [-4.2, 4.2]:
				for z in [-2.6, 2.6]:
					PIXELS.box(st, Vector3(x, 0.2, z), Vector3(0.7, 0.4, 0.7), TILES_IRON, TILES_STONE)
					PIXELS.box(st, Vector3(x, 0.95, z), Vector3(0.26, 1.3, 0.32), TILES_CRYSTAL, TILES_CRYSTAL)
		"treasure":
			_pillars(st, 0.67, 2.3, TILES_GOLD)
			for x in [-4.2, 4.2]:
				PIXELS.box(st, Vector3(x, 0.38, 2.7), Vector3(1.1, 0.75, 1.2), TILES_WOOD, TILES_WOOD)
				PIXELS.box(st, Vector3(x, 0.80, 2.7), Vector3(1.23, 0.12, 1.22), TILES_GOLD, TILES_IRON)
		"pillar_hall":
			_pillars(st, 0.93, 2.85, TILES_STONE)
			for x in [-4.1, 4.1]:
				PIXELS.box(st, Vector3(x, 0.055, 0.0), Vector3(0.45, 0.11, 2.9), TILES_GOLD, TILES_STONE)
		"collapsed_ruin":
			for x in [-4.2, 4.2]:
				for z in [-4.2, 4.2]:
					var h: float = rng.randf_range(0.50, 1.67)
					PIXELS.box(st, Vector3(x, h * 0.5, z), Vector3(0.84, h, 0.80), TILES_MOSS, TILES_STONE)
					PIXELS.box(st, Vector3(x + 0.25, 0.12, z - 0.32), Vector3(0.7, 0.24, 0.58), TILES_STONE, TILES_MOSS)
					PIXELS.box(st, Vector3(x - 0.28, 0.09, z + 0.21), Vector3(0.37, 0.18, 0.58), TILES_STONE, TILES_STONE)
		"old_armory":
			for x in [-4.25, 4.25]:
				PIXELS.box(st, Vector3(x, 0.83, -3.4), Vector3(0.4, 1.6, 1.8), TILES_WOOD, TILES_WOOD)
				for z in [-4.05, -3.45, -2.85]:
					PIXELS.box(st, Vector3(x + signf(x) * 0.26, 1.22, z), Vector3(0.15, 0.92, 0.12), TILES_IRON, TILES_GOLD)
			for z in [-4.0, 4.0]:
				PIXELS.box(st, Vector3(0, 0.18, z), Vector3(2.5, 0.35, 0.54), TILES_WOOD, TILES_WOOD)
		"fungal_grotto":
			for x in [-4.2, 4.2]:
				for z in [-4.0, 4.0]:
					for i in range(3):
						var px: float = x + float(i - 1) * 0.30
						var h: float = 0.28 + 0.13 * float(i)
						PIXELS.box(st, Vector3(px, h * 0.5, z), Vector3(0.16, h, 0.16), TILES_WOOD, TILES_WOOD)
						PIXELS.box(st, Vector3(px, h + 0.10, z), Vector3(0.58, 0.24, 0.55), TILES_CRYSTAL, TILES_MOSS)
			for z in [-3.25, 3.25]:
				PIXELS.box(st, Vector3(-3.9, 0.035, z), Vector3(0.48, 0.07, 1.8), TILES_MOSS, TILES_MOSS)
		"shrine":
			for x in [-4.2, 4.2]:
				for z in [-4.15, 4.15]:
					PIXELS.box(st, Vector3(x, 0.33, z), Vector3(0.94, 0.66, 0.9), TILES_STONE, TILES_MOSS)
					PIXELS.box(st, Vector3(x, 1.05, z), Vector3(0.32, 0.88, 0.34), TILES_CRYSTAL, TILES_CRYSTAL)
			for x in [-2.2, 2.2]:
				PIXELS.box(st, Vector3(x, 0.05, 4.12), Vector3(0.78, 0.10, 0.72), TILES_GOLD, TILES_STONE)
		"scorched_hall":
			for x in [-4.25, 4.25]:
				for z in [-4.2, 4.2]:
					PIXELS.box(st, Vector3(x, 0.40, z), Vector3(0.95, 0.80, 0.92), 15, TILES_STONE)
					PIXELS.box(st, Vector3(x, 1.05, z), Vector3(0.36, 0.50, 0.26), TILES_CRYSTAL, 15)
			for x in [-3.2, 3.2]:
				PIXELS.box(st, Vector3(x, 0.07, 1.6), Vector3(1.0, 0.14, 1.6), 15, 3)
		"gallery":
			for x in [-4.3, 4.3]:
				for z in [-3.9, 3.9]:
					PIXELS.box(st, Vector3(x, 0.63, z), Vector3(0.71, 1.26, 0.77), TILES_MOSS, TILES_STONE)
					PIXELS.box(st, Vector3(x, 1.34, z), Vector3(0.93, 0.18, 0.95), TILES_GOLD, TILES_STONE)
			for z in [-4.5, 4.5]:
				PIXELS.box(st, Vector3(0, 0.08, z), Vector3(3.0, 0.16, 0.30), TILES_GOLD, TILES_STONE)
		_:
			_pillars(st, 0.65, 1.6, TILES_STONE)
	_architecture(st, room, rooms)
	var art: MeshInstance3D = PIXELS.as_instance(st, "RoomDecor_%d_%s" % [int(room.get("id", 0)), style])
	art.position = center
	floor_root.add_child(art)
	return art

static func _pillars(st: SurfaceTool, width: float, height: float, top_tile: int) -> void:
	for x in [-4.25, 4.25]:
		for z in [-4.15, 4.15]:
			PIXELS.box(st, Vector3(x, height * 0.5, z), Vector3(width, height, width), top_tile, TILES_STONE)
			PIXELS.box(st, Vector3(x, height + 0.11, z), Vector3(width + 0.35, 0.22, width + 0.35), TILES_STONE, TILES_STONE)

## Thresholds, shallow bevels and broken stone trim give every doorway
## a readable architectural frame while keeping movement collision unchanged.
## Everything is combined into the room's existing single atlas mesh.
static func _architecture(st: SurfaceTool, room: Dictionary, rooms: Array) -> void:
	var border: int = TILES_MOSS if str(room.get("archetype", "")) in ["fungal_grotto", "collapsed_ruin"] else TILES_STONE
	for axis in [-5.68, 5.68]:
		PIXELS.box(st, Vector3(axis, 0.04, 0), Vector3(0.18, 0.08, 10.6), border, TILES_STONE)
		PIXELS.box(st, Vector3(0, 0.04, axis), Vector3(10.6, 0.08, 0.18), border, TILES_STONE)
	if rooms.is_empty():
		return
	var grid: Vector2i = room["grid"]
	for linked in room.get("links", []):
		var delta: Vector2i = rooms[int(linked)]["grid"] - grid
		var outward := Vector3(float(delta.x), 0, float(delta.y))
		var across := Vector3(0, 0, 1) if delta.x != 0 else Vector3(1, 0, 0)
		var doorway := outward * 5.86
		for side in [-1.0, 1.0]:
			var pillar: Vector3 = doorway + across * (side * 1.78)
			PIXELS.box(st, pillar + Vector3(0, 1.34, 0), Vector3(0.44, 2.55, 0.44), TILES_STONE, border)
			PIXELS.box(st, pillar + Vector3(0, 2.70, 0), Vector3(0.66, 0.24, 0.66), TILES_IRON, TILES_STONE)
		var header_size := Vector3(0.60, 0.32, 4.05) if delta.x != 0 else Vector3(4.05, 0.32, 0.60)
		PIXELS.box(st, doorway + Vector3(0, 2.88, 0), header_size, TILES_STONE, border)
		PIXELS.box(st, doorway + Vector3(0, 3.12, 0), header_size * Vector3(1.0, 0.45, 1.0), TILES_GOLD, TILES_STONE)
