extends RefCounted
## Connected, grid-carved caves for remote islands. Each horizontal tile is a
## one-voxel step at most; the corridor is 2 wide and 3 high for the player.
## Noise shapes the surrounding rock, never the guaranteed traversable route.
const INVALID_FLOOR: int = -99999
const CORRIDOR_WIDTH: int = 2
const CORRIDOR_HEIGHT: int = 3
const DESCENT_SPACING: int = 4
var floors: Dictionary = {} # Vector2i -> absolute walkable y
var natural

func install_natural(terrain, protected: Dictionary, placement = null) -> bool:
	if natural != null:
		return true
	var proposal = preload("res://scripts/world/natural_cave_network.gd").new()
	if not proposal.generate(terrain, protected, placement):
		return false
	natural = proposal
	return true

func ceiling_at(x: int, z: int, floor_y: int) -> int:
	if natural != null:
		return natural.ceilings.get(Vector2i(x,z), floor_y + CORRIDOR_HEIGHT)
	return floor_y + CORRIDOR_HEIGHT
var routes: Array = []
# Generated on the first island only when running the procedural trial.
var branches: Array[Dictionary] = []
var mine_end_room := {}
var entrances: Array[Vector3] = []
var chests: Array[Vector3] = []

func configure(terrain) -> void:
	mine_end_room.clear()
	branches.clear()
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

	if OS.get_environment("OUTPOST_TEST_PROCEDURAL_CAVE") == "1" and OS.get_environment("OUTPOST_TEST_SIDE_CHAMBER") != "1":
		_generate_branches(terrain,terrain.seed ^ 0x4b17)

func carve_mine(terrain, layout_seed: int) -> bool:
	var end: Vector3i = routes[0].back()
	# Enlarge the original end chamber only where the mountain provides a roof.
	for dx in range(-3,4):
		for dz in range(-3,4):
			var cell := Vector2i(end.x+dx,end.z+dz)
			if terrain.height_at(cell.x,cell.y) <= end.y+CORRIDOR_HEIGHT:
				mine_end_room.clear()
				return false
			mine_end_room[cell] = end.y
	var original := floors.duplicate()
	floors.merge(mine_end_room,true)
	_generate_branches(terrain,layout_seed)
	if branches.is_empty():
		floors = original
		mine_end_room.clear()
		return false
	return true

func _generate_branches(terrain, layout_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var route: Array = routes[0]
	var wanted := rng.randi_range(3,4)
	for attempt in 240:
		var index := rng.randi_range(9,route.size()-8)
		var tile: Vector3i = route[index]
		var adjacent: Vector3i = route[index-1]
		if adjacent.z != tile.z or adjacent.y != tile.y:
			continue
		var direction := 1 if rng.randi_range(0,1) else -1
		var mouth := Vector2i(tile.x,tile.z + (1 if direction > 0 else 0))
		var length := rng.randi_range(4,8)
		var half_width := rng.randi_range(1,3)
		var half_depth := rng.randi_range(1,2)
		var rise := rng.randi_range(0,1)
		var center := mouth + Vector2i(0,direction*(length+half_depth+1))
		var passage := {}
		var room := {}
		for step in range(1,length+1):
			for width in 2:
				passage[mouth + Vector2i(width,direction*step)] = tile.y + (rise if step >= 3 else 0)
		for dx in range(-half_width,half_width+1):
			for dz in range(-half_depth,half_depth+1):
				room[center+Vector2i(dx,dz)] = tile.y+rise
		var proposal := passage.duplicate()
		proposal.merge(room)
		if not _enclosed_branch(terrain,proposal,mouth,direction):
			continue
		floors.merge(proposal)
		branches.append({"room":room,"passage":passage,"center":center,"junction":mouth,
			"threshold":mouth+Vector2i(0,direction*length),"size":Vector2i(2*half_width+1,2*half_depth+1)})
		if branches.size() == wanted:
			break
	if branches.size() < 2:
		# A seed without enough roofed sites keeps its original cave intact.
		for branch in branches:
			for cells: Dictionary in [branch.room,branch.passage]:
				for cell: Vector2i in cells:
					floors.erase(cell)
		branches.clear()

func _enclosed_branch(terrain, proposal: Dictionary, mouth: Vector2i, direction: int) -> bool:
	for cell: Vector2i in proposal:
		var roof: int = proposal[cell]+CORRIDOR_HEIGHT
		if floors.has(cell) or terrain.height_at(cell.x,cell.y) <= roof:
			return false
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var n: Vector2i = cell+offset
			if proposal.has(n) or n == mouth or n == mouth+Vector2i.RIGHT:
				continue
			if floors.has(n) or terrain.height_at(n.x,n.y) <= roof:
				return false
	# Both lanes join a level, roofed stretch of the original tunnel.
	return terrain.height_at(mouth.x,mouth.y) > int(proposal[mouth+Vector2i(0,direction)])+CORRIDOR_HEIGHT

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
