extends RefCounted
## Bounded dungeon layout experiment. Modules are 15x5x15 so the middle
## doorway is invariant under quarter-turns. Layout and voxel realization separate.
const Prefab = preload("res://scripts/world/city_lab_prefab.gd")
const SIDE := 15
const MID := 7
const HEIGHT := 5
const MAX_MODULES := 128
const DIRS: Array[Vector2i] = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const SHAPES := [
	["straight",[0,2],5],["left",[0,3],4],["right",[0,1],4],
	["tee",[0,1,3],3],["cross",[0,1,2,3],1],
	["chamber",[0,2],3],["dead_end",[0],1]]
var library: Dictionary = {}
var modules: Dictionary = {}
var links: Dictionary = {}
var external: Dictionary = {}
var rng := RandomNumberGenerator.new()
var codec := Prefab.new()

func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < SIDE and p.y < SIDE

func _edge(d: int) -> Vector2i:
	return Vector2i(MID,MID)+DIRS[d]*MID

func _rotate(p: Vector3i, turns: int) -> Vector3i:
	match posmod(turns,4):
		1: return Vector3i(SIDE-1-p.z,p.y,p.x)
		2: return Vector3i(SIDE-1-p.x,p.y,SIDE-1-p.z)
		3: return Vector3i(p.z,p.y,SIDE-1-p.x)
	return p

func _clear(cells: Dictionary, p: Vector2i) -> bool:
	if not _inside(p): return false
	if not cells.has(Vector3i(p.x,0,p.y)): return false
	for y in range(1,4):
		if cells.has(Vector3i(p.x,y,p.y)): return false
	return true

func _reachable(cells: Dictionary) -> Dictionary:
	var center := Vector2i(MID,MID)
	if not _clear(cells,center): return {}
	var seen: Dictionary = {}
	seen[center] = true
	var queue: Array[Vector2i] = [center]
	var index := 0
	while index < queue.size():
		var p: Vector2i = queue[index]
		index += 1
		for d in DIRS:
			var q := p+d
			if not seen.has(q) and _clear(cells,q):
				seen[q] = true
				queue.append(q)
	return seen

func register_asset(asset: Variant) -> bool:
	# Same voxel JSON format as Creator capture, plus explicit typed connectors.
	if not asset is Dictionary or asset.get("schema_version",0) != 1: return false
	var id: String = str(asset.get("id",""))
	if id.is_empty() or id.length() > 100 or library.has(id): return false
	var weight: Variant = asset.get("weight")
	if not codec._integer(weight) or int(weight)<1 or int(weight)>100: return false
	var decoded := codec.decode(asset.get("prefab"))
	if decoded.is_empty() or decoded["size"] != Vector3i(SIDE,HEIGHT,SIDE): return false
	var sockets: Variant = asset.get("sockets")
	if not sockets is Array or sockets.is_empty() or sockets.size()>4: return false
	var cells: Dictionary = decoded["cells"]
	var reachable := _reachable(cells)
	if reachable.is_empty(): return false
	var directions: Dictionary = {}
	for s in sockets:
		if not s is Dictionary or not codec._integer(s.get("direction")): return false
		var d := int(s["direction"])
		var kind: String = str(s.get("type",""))
		if d<0 or d>3 or kind.is_empty() or kind.length()>100 or directions.has(d): return false
		directions[d] = kind
	# Every declared doorway must have a 3x3 clear aperture, floor and access
	# to the center. Every undeclared edge must have no walkable opening.
	for d in range(4):
		var edge := _edge(d)
		var across := DIRS[(d+1)%4]
		for offset in range(-MID,MID+1):
			var p := edge+across*offset
			var expected: bool = directions.has(d) and absi(offset)<=1
			if expected:
				if not reachable.has(p): return false
			elif _clear(cells,p): return false
	library[id] = {"weight":int(weight),"cells":cells,"sockets":directions}
	return true

func _builtin(id: String, dirs: Array, weight: int, wide: bool = false) -> Dictionary:
	var open: Dictionary = {}
	var radius := 4 if wide else 1
	for z in range(MID-radius,MID+radius+1):
		for x in range(MID-radius,MID+radius+1): open[Vector2i(x,z)] = true
	for d in dirs:
		var forward: Vector2i = DIRS[d]
		var across: Vector2i = DIRS[(d+1)%4]
		for step in range(MID+1):
			for offset in range(-1,2):
				open[Vector2i(MID,MID)+forward*step+across*offset] = true
	var voxels: Array = []
	for z in range(SIDE):
		for x in range(SIDE):
			voxels.append([x,0,z,3])
			var p := Vector2i(x,z)
			if open.has(p): continue
			# Fill non-passage cells so no inaccessible decorative void can
			# accidentally become a second navigable space.
			for y in range(1,HEIGHT): voxels.append([x,y,z,2])
	var sockets: Array = []
	for d in dirs: sockets.append({"direction":d,"type":"stone_corridor"})
	return {"schema_version":1,"id":id,"weight":weight,"prefab":{"schema_version":1,"size":[SIDE,HEIGHT,SIDE],"voxels":voxels},"sockets":sockets}

func load_defaults() -> bool:
	library.clear()
	for shape in SHAPES:
		if not register_asset(_builtin(shape[0],shape[1],shape[2],shape[0]=="chamber")): return false
	return true

func _sockets(id: String, turns: int) -> Dictionary:
	var result: Dictionary = {}
	for d in library[id]["sockets"]:
		result[posmod(int(d)+turns,4)] = library[id]["sockets"][d]
	return result

func _place(p: Vector2i, id: String, turns: int) -> void:
	modules[p] = {"id":id,"turns":turns,"sockets":_sockets(id,turns)}
	links[p] = {}

func _connect(a: Vector2i, d: int, b: Vector2i) -> void:
	links[a][d] = b
	links[b][(d+2)%4] = a

func generate(seed_value: int, count: int) -> bool:
	modules.clear()
	links.clear()
	external.clear()
	if count<1 or count>MAX_MODULES: return false
	if library.is_empty() and not load_defaults(): return false
	if not library.has("cross"): return false
	rng.seed = seed_value
	_place(Vector2i.ZERO,"cross",0)
	while modules.size()<count:
		var frontier: Array = []
		for p: Vector2i in modules:
			for d in modules[p]["sockets"]:
				var q := p+DIRS[d]
				if not modules.has(q): frontier.append([p,d,q])
		if frontier.is_empty(): return false
		var f: Array = frontier[rng.randi_range(0,frontier.size()-1)]
		var a: Vector2i = f[0]
		var direction: int = f[1]
		var at: Vector2i = f[2]
		var target: String = modules[a]["sockets"][direction]
		var candidates: Array = []
		var total := 0
		for id in library:
			# Reserve terminal rooms for the final placements to avoid exhausting the frontier.
			if library[id]["sockets"].size()<2 and modules.size()<count-1: continue
			for turns in range(4):
				var sockets := _sockets(id,turns)
				if sockets.get((direction+2)%4,"") != target: continue
				var weight: int = library[id]["weight"]
				candidates.append([id,turns,weight])
				total += weight
		if candidates.is_empty(): return false
		var roll := rng.randi_range(1,total)
		for c in candidates:
			roll -= int(c[2])
			if roll <= 0:
				_place(at,c[0],c[1])
				break
		_connect(a,direction,at)
		# Compatible neighbouring open ports may close a loop.
		for d in modules[at]["sockets"]:
			var q := at+DIRS[d]
			if not modules.has(q) or links[at].has(d): continue
			if modules[q]["sockets"].get((d+2)%4,"") == modules[at]["sockets"][d]:
				_connect(at,d,q)
	return validate()

func validate() -> bool:
	if not modules.has(Vector2i.ZERO): return false
	var seen: Dictionary = {Vector2i.ZERO:true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var index := 0
	while index<queue.size():
		var p: Vector2i = queue[index]
		index += 1
		for d in links[p]:
			var q: Vector2i = links[p][d]
			if q != p+DIRS[d] or not modules.has(q): return false
			if links[q].get((d+2)%4) != p: return false
			if not modules[p]["sockets"].has(d) or modules[p]["sockets"][d] != modules[q]["sockets"].get((d+2)%4,""): return false
			if not seen.has(q):
				seen[q] = true
				queue.append(q)
	return seen.size()==modules.size()

func materialize(p: Vector2i) -> Dictionary:
	# Called for an individual module; layout never needs its voxel payload copied.
	if not modules.has(p): return {}
	var data: Dictionary = modules[p]
	var result: Dictionary = {}
	for v: Vector3i in library[data["id"]]["cells"]:
		result[_rotate(v,data["turns"])] = library[data["id"]]["cells"][v]
	# Close every unmatched connector with actual wall voxels.
	for d in data["sockets"]:
		if links[p].has(d) or external.get(p,{}).has(d): continue
		var edge := _edge(d)
		var across: Vector2i = DIRS[(d+1)%4]
		for offset in range(-1,2):
			var q := edge+across*offset
			for y in range(1,HEIGHT): result[Vector3i(q.x,y,q.y)] = 2
	return result
