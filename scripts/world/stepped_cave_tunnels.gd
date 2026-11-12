extends RefCounted
## Connected, grid-carved caves for remote islands. Each horizontal tile is a
## one-voxel step at most; the corridor is 2 wide and 3 high for the player.
## Noise shapes the surrounding rock, never the guaranteed traversable route.
const INVALID_FLOOR: int = -99999
const CORRIDOR_WIDTH: int = 2
const CORRIDOR_HEIGHT: int = 3
const DESCENT_SPACING: int = 4
var floors: Dictionary = {} # Vector2i -> absolute walkable y
var routes: Array = []
var entrances: Array[Vector3] = []
var chests: Array[Vector3] = []

func configure(terrain) -> void:
	floors.clear()
	routes.clear()
	entrances.clear()
	chests.clear()
	for island in terrain.islands:
		var center: Vector2i = island["center"]
		var radius: float = island["radius"]
		# Put the entrance on the inland shoulder, NOT the beach. The old
		# 0.80 radius point sometimes had terrain Y=-1 but the forced
		# cave floor Y=+1, forming a 2-block wall in the access path.
		var start := Vector2i(center.x + roundi(radius * 0.55), center.y)
		var first_height: int = maxi(1, terrain.height_at(start.x, start.y))
		var route: Array = []
		var steps: int = mini(38, roundi(radius * 0.96))
		for step in range(steps):
			# Westward inward motion with bounded 1-tile lateral changes.
			var bend: int = roundi(sin(float(step) * 0.22) * 2.0)
			var cell := Vector2i(start.x - step, start.y + bend)
			var floor_y: int = maxi(0, first_height - int(step / DESCENT_SPACING))
			route.append(Vector3i(cell.x, floor_y, cell.y))
			for width in range(CORRIDOR_WIDTH):
				var column := cell + Vector2i(0, width)
				floors[column] = mini(int(floors.get(column, floor_y)), floor_y)
		routes.append(route)
		if route.is_empty():
			continue
		var entry: Vector3i = route[0]
		entrances.append(Vector3(float(entry.x) + 0.5, float(entry.y), float(entry.z) + 0.5))
		var end: Vector3i = route[route.size() - 1]
		# One small, flat chamber at the route's end, reachable by walking.
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var column := Vector2i(end.x + dx, end.z + dz)
				floors[column] = mini(int(floors.get(column, end.y)), end.y)
		chests.append(Vector3(float(end.x) + 0.5, float(end.y), float(end.z) + 0.5))

func floor_at(x: int, z: int) -> int:
	return int(floors.get(Vector2i(x, z), INVALID_FLOOR))

func has_cave(x: int, z: int) -> bool:
	return floors.has(Vector2i(x, z))

func route_has_safe_steps(route: Array) -> bool:
	for i in range(1, route.size()):
		var a: Vector3i = route[i - 1]
		var b: Vector3i = route[i]
		if absi(a.y - b.y) > 1 or absi(a.x - b.x) + absi(a.z - b.z) > 2:
			return false
	return true
