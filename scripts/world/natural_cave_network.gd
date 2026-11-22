extends RefCounted
## A bounded proposal on the second island. Publish its air spans only after
## the route, overlap, roof and surface checks pass for the whole network.
var floors := {}
var ceilings := {} # Exclusive world Y of the carved air column.
var regions: Array[Dictionary] = []
var chambers: Array[Vector2i] = []
var mouth: Vector2i
var approach: Vector2i
var lip: Vector2i
var rim: Vector2i
var shaft_bottom: Vector2i
var shaft_landing: Vector2i
var guard_cell: Vector2i
var ore_cell: Vector2i
var shaft := {}
var apron := {}

func generate(terrain, protected: Dictionary, placement = null) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.seed ^ 0x73c9ab
	var center: Vector2i = terrain.islands[1].center
	for attempt in 48:
		floors.clear()
		ceilings.clear()
		regions.clear()
		chambers.clear()
		shaft.clear()
		apron.clear()
		var sign_z := 1 if rng.randi_range(0, 1) == 0 else -1
		var outwards := Vector2i(0, sign_z)
		var hub := center + Vector2i(rng.randi_range(-8, 8), sign_z * rng.randi_range(13, 18))
		var length := rng.randi_range(12, 16)
		mouth = hub + outwards * length
		approach = mouth + outwards
		var start_y: int = terrain.height_at(mouth.x, mouth.y)
		if start_y < 1 or absi(terrain.height_at(approach.x, approach.y) - start_y) > 1:
			continue
		var depth := maxi(-1, start_y - 3)
		var bend := rng.randi_range(-1, 1)
		var passage := {}
		for i in range(-1, length + 1):
			var c := mouth - outwards * i
			if i >= 4 and i < length - 3:
				c.x += bend
			var floor_y := maxi(depth, start_y - maxi(0, i) / 3)
			if i == -1:
				floor_y = terrain.height_at(approach.x, approach.y)
			for dx in (3 if i in [2,3,4] else 2):
				var column := c + Vector2i.RIGHT * dx
				_carve(column, floor_y, 3 + int(dx == 1), passage)
				if i <= 5:
					apron[column] = true
			if passage.size() >= 12 or i == length:
				_region(passage, c)
				passage = {}
		_room(hub, depth, 3, 3, rng)
		for direction in [-1, 1]:
			var stretch := rng.randi_range(10, 13)
			var turn := rng.randi_range(-1, 1)
			var room_y := depth + int(direction)
			passage = {}
			for i in range(3, stretch + 1):
				var c := hub + Vector2i(direction * i, turn if i >= 5 else 0)
				for width in 2:
					_carve(c + outwards * width, depth if i < 6 else room_y, 3, passage)
				if passage.size() >= 14 or i == stretch:
					_region(passage, c)
					passage = {}
			var end := hub + Vector2i(direction * stretch, turn)
			_room(end, room_y, rng.randi_range(3, 4), rng.randi_range(2, 3), rng)
		if not _sinkhole(terrain, chambers[2], outwards):
			continue
		if not _fits(terrain):
			continue
		# Never relocate a seeded layout around a later player modification.
		for cell: Vector2i in floors:
			if protected.has(cell) or (placement != null and not placement.available(Vector3(cell.x+0.5, floors[cell], cell.y+0.5), 0.75)):
				return false
		guard_cell = chambers[1]
		ore_cell = chambers[2] + Vector2i.RIGHT * 2
		terrain.caves.floors.merge(floors)
		return true
	return false

func _carve(cell: Vector2i, floor_y: int, clearance: int, region: Dictionary) -> void:
	floors[cell] = mini(floor_y, floors.get(cell, floor_y))
	ceilings[cell] = maxi(floor_y + clearance, ceilings.get(cell, floor_y))
	region[cell] = true

func _region(cells: Dictionary, anchor: Vector2i) -> void:
	if not cells.is_empty():
		regions.append({"cells": cells, "anchor": anchor})

func _room(center: Vector2i, floor_y: int, rx: int, rz: int, rng: RandomNumberGenerator) -> void:
	var room := {}
	for x in range(-rx, rx + 1):
		for z in range(-rz, rz + 1):
			var radius := Vector2(float(x)/rx, float(z)/rz).length_squared()
			if radius <= 0.86 or (radius <= 1.14 and rng.randf() < 0.6):
				_carve(center + Vector2i(x,z), floor_y, 3 + roundi(2 * maxf(0, 1-radius)), room)
	_region(room, center)
	chambers.append(center)

func _sinkhole(terrain, center: Vector2i, outward: Vector2i) -> bool:
	var base: int = floors[center]
	var stairs := {}
	var steps: Array[Vector2i] = []
	for i in range(2, 9):
		steps.append(center + outward*i)
	for i in range(1, 5):
		steps.append(center + outward*8 + Vector2i.RIGHT*i)
	for i in range(7, 4, -1):
		steps.append(center + outward*i + Vector2i.RIGHT*4)
	lip = steps.back()
	shaft_landing = steps[9]
	rim = lip - outward
	var high: int = terrain.height_at(rim.x, rim.y)
	var rise := high-base
	if rise < 4 or rise > steps.size()-3 or absi(terrain.height_at(lip.x,lip.y)-high)>1:
		return false
	for i in steps.size():
		var c := steps[i]
		var y := base + maxi(0, rise - (steps.size()-1-i))
		var across := outward if i in [7,8,9] else Vector2i.RIGHT
		for width in 2:
			var tile := c + across*width
			_carve(tile, y, 3, stairs)
			if i >= 3:
				shaft[tile] = true
				ceilings[tile] = maxi(y+3, terrain.height_at(tile.x,tile.y))
	shaft_bottom = center + outward*5 + Vector2i.RIGHT*2
	# Open a narrow, chipped central throat beside the rising ledges.
	for offset in [Vector2i.ZERO, outward, outward*2, outward+Vector2i.RIGHT]:
		var c: Vector2i = shaft_bottom + offset
		_carve(c, base, 3, stairs)
		shaft[c] = true
		ceilings[c] = maxi(base+3, terrain.height_at(c.x,c.y))
	_carve(rim, high, 3, stairs)
	shaft[rim] = true
	_region(stairs, shaft_bottom)
	return true

func _fits(terrain) -> bool:
	for c: Vector2i in floors:
		var top: int = terrain.height_at(c.x, c.y)
		var floor_y: int = floors[c]
		if floor_y > top+1 or floor_y < terrain.BEDROCK+2:
			return false
		for d in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			if terrain.caves.floors.has(c+d):
				return false
		if not apron.has(c) and not shaft.has(c):
			if top < floor_y + 4:
				return false
			ceilings[c] = mini(ceilings[c], top-1)
	# Reject isolated ledges, including an unusable exit at the top of a shaft.
	var queue: Array[Vector2i] = [approach]
	var reached := {approach:true}
	var index := 0
	while index < queue.size():
		var c := queue[index]
		index += 1
		for offset: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next := c + offset
			if floors.has(next) and not reached.has(next) and absi(floors[c]-floors[next]) <= 1:
				reached[next] = true
				queue.append(next)
	return reached.size() == floors.size()
