extends RefCounted
## Pure, local city blueprint. No scene nodes, global floats or save mutations.
const Region = preload("res://scripts/world/city_lab_region.gd")
const PREFABS = "res://data/city_lab/prefabs.json"
const LOT: int = 8
const LOTS: int = 11
const SIZE: int = LOT * LOTS
const TYPES: Array[String] = ["house", "ruin", "garden", "tower", "market"]
const DIRS: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
var region := Region.new()
var prefabs: Dictionary = {}
var entrances: Dictionary = {}
var blocks: Dictionary = {}
var blocked: Dictionary = {}
var districts: Dictionary = {}
var roads: Dictionary = {}
var rooms: Array[Rect2i] = []
var rng := RandomNumberGenerator.new()
var start := Vector2i(44, 2)
var goal := Vector2i(44, 44)

func height_at(p: Vector2i) -> int:
	return region.height_at(p)

func _load_prefabs() -> bool:
	prefabs.clear()
	var root: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFABS))
	if not root is Dictionary or root.get("schema_version",0) != 1: return false
	if not root.get("prefabs") is Array: return false
	for item in root["prefabs"]:
		if not item is Dictionary: return false
		var kind: String = str(item.get("kind",""))
		if not TYPES.has(kind) or prefabs.has(kind): return false
		if int(item.get("weight",0)) < 1 or int(item.get("weight",0)) > 100: return false
		if int(item.get("height",0)) < 1 or int(item.get("height",0)) > 8: return false
		if int(item.get("material",-1)) < 0 or int(item.get("material",-1)) > 6: return false
		if not item.get("sockets") is Array or item["sockets"].is_empty(): return false
		for side in item["sockets"]:
			if not ["north","east","south","west"].has(side): return false
		prefabs[kind] = item
	return prefabs.size() == TYPES.size()

func _socket_directions(p: Vector2i, kind: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var names := ["east","west","south","north"]
	for i in range(DIRS.size()):
		if prefabs[kind]["sockets"].has(names[i]) and _road(p+DIRS[i]):
			result.append(DIRS[i])
	return result

func _weighted(options: Array) -> String:
	var total := 0
	for kind in options: total += int(prefabs[kind]["weight"])
	var roll := rng.randi_range(1,total)
	for kind in options:
		roll -= int(prefabs[kind]["weight"])
		if roll <= 0: return kind
	return options.back()

func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < SIZE and p.y < SIZE

func _keep(p: Vector2i) -> bool:
	return p.x >= 4 and p.x <= 6 and p.y >= 4 and p.y <= 6

func _road(p: Vector2i) -> bool:
	return region.road_lots.has(p)

func _compatible(a: String, b: String) -> bool:
	# Symmetric thematic adjacency constraints, applied by propagation.
	if a == "tower" and b == "tower": return false
	if a == "market" and b == "market": return false
	if (a == "house" and b == "ruin") or (a == "ruin" and b == "house"): return false
	return true

func _solve(seed_value: int) -> bool:
	for attempt in range(12):
		rng.seed = seed_value + attempt * 1009
		var domains: Dictionary = {}
		var cells: Array[Vector2i] = []
		for z in range(LOTS):
			for x in range(LOTS):
				var p := Vector2i(x,z)
				if _keep(p): domains[p] = ["keep"]
				elif _road(p): domains[p] = ["road"]
				else:
					var options: Array[String] = TYPES.duplicate()
					for kind in TYPES:
						if bool(prefabs[kind].get("road_required",false)) and _socket_directions(p,kind).is_empty():
							options.erase(kind)
					if x > 1 and x < 9 and z > 1 and z < 9: options.erase("tower")
					domains[p] = options
				cells.append(p)
		if not _propagate(domains, cells.duplicate()): continue
		var failed := false
		while true:
			var best: Array[Vector2i] = []
			var entropy := 999
			for p in cells:
				var n: int = domains[p].size()
				if n <= 1: continue
				if n < entropy:
					entropy = n
					best.clear()
				if n == entropy: best.append(p)
			if best.is_empty(): break
			var chosen: Vector2i = best[rng.randi_range(0,best.size()-1)]
			var options: Array = domains[chosen]
			domains[chosen] = [_weighted(options)]
			var queue: Array[Vector2i] = [chosen]
			if not _propagate(domains, queue):
				failed = true
				break
		if not failed:
			districts.clear()
			for p in cells: districts[p] = domains[p][0]
			return true
	return false

func _propagate(domains: Dictionary, queue: Array) -> bool:
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		for d in DIRS:
			var q: Vector2i = p+d
			if not domains.has(q): continue
			var old: Array = domains[q]
			var allowed: Array = []
			for candidate in old:
				for neighbor in domains[p]:
					if _compatible(candidate, neighbor):
						allowed.append(candidate)
						break
			if allowed.is_empty(): return false
			if allowed.size() != old.size():
				domains[q] = allowed
				queue.append(q)
	return true

func _wall(p: Vector2i, h: int, material: int = 2) -> void:
	if not _inside(p): return
	var base := height_at(p)
	for y in range(base+1, base+h+1):
		blocks[Vector3i(p.x,y,p.y)] = material
	blocked[p] = true

func _line(a: Vector2i, b: Vector2i, door: Vector2i, h: int, material: int = 2) -> void:
	var p := a
	var step := Vector2i(signi(b.x-a.x),signi(b.y-a.y))
	while true:
		if p != door: _wall(p,h,material)
		if p == b: break
		p += step

func _building(p: Vector2i, kind: String) -> void:
	var base := p*LOT
	var a := base+Vector2i(1,1)
	var b := base+Vector2i(6,6)
	if kind == "garden":
		for x in [2,5]:
			for z in [2,5]:
				var at := base+Vector2i(x,z)
				_wall(at,1,4)
				blocks[Vector3i(at.x,height_at(at)+2,at.y)] = 5
		return
	if kind == "market":
		for x in [2,5]:
			_wall(base+Vector2i(x,2),2,4)
			_wall(base+Vector2i(x,5),2,4)
		for x in range(2,6):
			for z in range(2,6):
				var at := base+Vector2i(x,z)
				blocks[Vector3i(at.x,height_at(at)+3,at.y)] = 6
		return
	var h: int = int(prefabs[kind]["height"])
	var mat: int = int(prefabs[kind]["material"])
	_line(a,Vector2i(b.x,a.y),Vector2i(base.x+3,a.y),h,mat)
	_line(Vector2i(a.x,b.y),b,Vector2i(base.x+3,b.y),h,mat)
	_line(a,Vector2i(a.x,b.y),Vector2i(a.x,base.y+3),h,mat)
	_line(Vector2i(b.x,a.y),b,Vector2i(b.x,base.y+3),h,mat)
	if kind == "ruin":
		# Open ruined corner; preserve public walkways.
		for y in range(height_at(a)+1,height_at(a)+h+1):
			blocks.erase(Vector3i(a.x,y,a.y))
		blocked.erase(a)
	if kind == "tower":
		for q in [a,Vector2i(a.x,b.y),Vector2i(b.x,a.y),b]:
			_wall(q,h+1,3)

func _bsp(rect: Rect2i, depth: int) -> void:
	if depth <= 0 or (rect.size.x < 10 and rect.size.y < 10):
		rooms.append(rect)
		return
	var split_x: bool = rect.size.x >= rect.size.y
	if split_x and rect.size.x >= 10:
		var x := rect.position.x + rng.randi_range(4,rect.size.x-5)
		var door := Vector2i(x,rect.position.y+rect.size.y/2)
		_line(Vector2i(x,rect.position.y),Vector2i(x,rect.end.y-1),door,3,2)
		_bsp(Rect2i(rect.position,Vector2i(x-rect.position.x,rect.size.y)),depth-1)
		_bsp(Rect2i(Vector2i(x+1,rect.position.y),Vector2i(rect.end.x-x-1,rect.size.y)),depth-1)
	elif rect.size.y >= 10:
		var z := rect.position.y + rng.randi_range(4,rect.size.y-5)
		var door := Vector2i(rect.position.x+rect.size.x/2,z)
		_line(Vector2i(rect.position.x,z),Vector2i(rect.end.x-1,z),door,3,2)
		_bsp(Rect2i(rect.position,Vector2i(rect.size.x,z-rect.position.y)),depth-1)
		_bsp(Rect2i(Vector2i(rect.position.x,z+1),Vector2i(rect.size.x,rect.end.y-z-1)),depth-1)
	else:
		rooms.append(rect)

func _open(p: Vector2i) -> void:
	for y in range(height_at(p)+1,height_at(p)+12):
		blocks.erase(Vector3i(p.x,y,p.y))
	blocked.erase(p)

func generate(seed_value: int, region_x: int = 0, region_z: int = 0) -> bool:
	if not _load_prefabs(): return false
	region.configure(seed_value,region_x,region_z)
	entrances.clear()
	blocks.clear()
	blocked.clear()
	roads.clear()
	rooms.clear()
	var digest := ("%d:%d:%d:districts:v1" % [seed_value,region_x,region_z]).sha256_buffer()
	var local_seed: int = int(digest[0]) | (int(digest[1]) << 8) | (int(digest[2]) << 16) | (int(digest[3]) << 24)
	if not _solve(local_seed): return false
	for z in range(SIZE):
		for x in range(SIZE):
			var p := Vector2i(x,z)
			var lot := Vector2i(floori(x / float(LOT)),floori(z / float(LOT)))
			var is_road: bool = districts[lot] == "road"
			if is_road: roads[p] = true
			for y in range(-2,height_at(p)+1):
				blocks[Vector3i(x,y,z)] = (1 if is_road else 0) if y == height_at(p) else 3
	for p in districts:
		var kind: String = districts[p]
		if kind != "road" and kind != "keep":
			_building(p,kind)
			var sockets := _socket_directions(p,kind)
			if not sockets.is_empty():
				var d: Vector2i = sockets[0]
				var base: Vector2i = p*LOT
				var door := base+Vector2i(3,3)
				if d.x != 0: door.x = base.x+(6 if d.x>0 else 1)
				else: door.y = base.y+(6 if d.y>0 else 1)
				_open(door)
				entrances[p] = door
	# Perimeter with two broad entrances.
	for i in range(SIZE):
		if absi(i-44)>2:
			_wall(Vector2i(i,0),4)
			_wall(Vector2i(i,SIZE-1),4)
			_wall(Vector2i(0,i),4)
			_wall(Vector2i(SIZE-1,i),4)
	for p in [Vector2i(1,1),Vector2i(86,1),Vector2i(1,86),Vector2i(86,86)]:
		for dx in range(-1,2):
			for dz in range(-1,2): _wall(p+Vector2i(dx,dz),7)
	# Central fortified district: BSP room layout, then guarantee public routes.
	_line(Vector2i(33,33),Vector2i(54,33),Vector2i(44,33),6)
	_line(Vector2i(33,54),Vector2i(54,54),Vector2i(44,54),6)
	_line(Vector2i(33,33),Vector2i(33,54),Vector2i(33,44),6)
	_line(Vector2i(54,33),Vector2i(54,54),Vector2i(54,44),6)
	_bsp(Rect2i(34,34,20,20),3)
	# Reserved processional cross, plus guaranteed door into every BSP leaf.
	for i in range(33,55):
		_open(Vector2i(44,i))
		_open(Vector2i(i,44))
	for room in rooms:
		var center: Vector2i = room.position + room.size/2
		var p := center
		while p.x != 44:
			_open(p)
			p.x += signi(44-p.x)
		_open(p)
	return validate()

func walkable(p: Vector2i) -> bool:
	if not _inside(p): return false
	var h := height_at(p)
	return blocks.has(Vector3i(p.x,h,p.y)) and not blocks.has(Vector3i(p.x,h+1,p.y)) and not blocks.has(Vector3i(p.x,h+2,p.y))

func validate() -> bool:
	if not walkable(start) or not walkable(goal): return false
	var seen: Dictionary = {start:true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var p: Vector2i = queue[index]
		index += 1
		for d in DIRS:
			var q := p+d
			if walkable(q) and not seen.has(q) and absi(height_at(q)-height_at(p)) <= 1:
				seen[q] = true
				queue.append(q)
	if not seen.has(goal): return false
	for p in roads:
		if walkable(p) and not seen.has(p): return false
	for room in rooms:
		if not seen.has(room.position+room.size/2): return false
	for p in entrances.values():
		if not seen.has(p): return false
	return true
