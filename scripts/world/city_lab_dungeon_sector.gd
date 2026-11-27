extends RefCounted
## Each 5x5 sector is independently reproducible, with four fixed shared
## stone-corridor gateways and a seeded spanning tree. No global float positions.
const Dungeon = preload("res://scripts/world/city_lab_dungeon_connectors.gd")
const Pack = preload("res://scripts/world/city_lab_dungeon_pack.gd")
const WIDTH := 5
const MID := 2
const SIDE := WIDTH*Dungeon.SIDE
const KIND := "stone_corridor"
const DIRS = Dungeon.DIRS
var solver := Dungeon.new()
var rng := RandomNumberGenerator.new()
var pack_id := "outpost:default"
var loop_percent := 22

func gate(d: int) -> Vector2i:
	return Vector2i(MID,MID)+DIRS[d]*MID

func _inside(p: Vector2i) -> bool:
	return p.x>=0 and p.y>=0 and p.x<WIDTH and p.y<WIDTH

func _add(graph: Dictionary,a: Vector2i,d: int) -> void:
	var b := a+DIRS[d]
	graph[a][d] = true
	graph[b][(d+2)%4] = true

func generate(world_seed: int, sx: int, sz: int, custom: Variant = null) -> bool:
	if not solver.load_defaults(): return false
	pack_id = "outpost:default"
	loop_percent = 22
	if custom != null:
		if custom is Dictionary and custom.get("format","") == Pack.FORMAT:
			var pack := Pack.new().normalize(custom)
			if pack.is_empty(): return false
			pack_id = pack["id"]
			loop_percent = pack["loop_percent"]
			for asset in pack["modules"]:
				if not solver.register_asset(asset): return false
		elif not solver.register_asset(custom):
			return false
	solver.modules.clear()
	solver.links.clear()
	solver.external.clear()
	var bytes := ("%d:%d:%d:dungeon_sector_v1" % [world_seed,sx,sz]).sha256_buffer()
	rng.seed = int(bytes[0]) | (int(bytes[1])<<8) | (int(bytes[2])<<16) | (int(bytes[3])<<24)
	var graph: Dictionary = {}
	for z in range(WIDTH):
		for x in range(WIDTH): graph[Vector2i(x,z)] = {}
	var center := Vector2i(MID,MID)
	var visited: Dictionary = {}
	visited[center] = true
	var stack: Array[Vector2i] = [center]
	while not stack.is_empty():
		var p: Vector2i = stack.back()
		var options: Array[int] = []
		for d in range(4):
			var q := p+DIRS[d]
			if _inside(q) and not visited.has(q): options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var d: int = options[rng.randi_range(0,options.size()-1)]
		var q := p+DIRS[d]
		_add(graph,p,d)
		visited[q] = true
		stack.append(q)
	# Optional loops, drawn in fixed row-major order.
	for z in range(WIDTH):
		for x in range(WIDTH):
			var p := Vector2i(x,z)
			for d in [1,2]:
				if _inside(p+DIRS[d]) and not graph[p].has(d) and rng.randf()<float(loop_percent)/100.0:
					_add(graph,p,d)
	for d in range(4):
		var p := gate(d)
		solver.external[p] = {d:KIND}
	# Select an exact socket mask, after topology is known. The built-in pool
	# includes every nonzero four-bit mask via rotation.
	for z in range(WIDTH):
		for x in range(WIDTH):
			var p := Vector2i(x,z)
			var required: Dictionary = graph[p].duplicate()
			for d in solver.external.get(p,{}): required[d] = true
			var choices: Array = []
			var total := 0
			for id in solver.library:
				for rotation in range(4):
					var ports := solver._sockets(id,rotation)
					if ports.size()!=required.size(): continue
					var compatible := true
					for d in required:
						if ports.get(d,"")!=KIND: compatible=false
					if not compatible: continue
					var weight: int = solver.library[id]["weight"]
					choices.append([id,rotation,weight])
					total += weight
			if choices.is_empty(): return false
			var roll := rng.randi_range(1,total)
			for c in choices:
				roll -= int(c[2])
				if roll<=0:
					solver._place(p,c[0],c[1])
					break
	for p in graph:
		for d in graph[p]:
			solver._connect(p,d,p+DIRS[d])
	return solver.validate()

func materialize() -> Dictionary:
	var result: Dictionary = {}
	for p: Vector2i in solver.modules:
		var origin := Vector3i(p.x*Dungeon.SIDE,0,p.y*Dungeon.SIDE)
		var cells := solver.materialize(p)
		for v: Vector3i in cells: result[origin+v] = cells[v]
	return result

func gate_cell(d: int) -> Vector2i:
	return gate(d)*Dungeon.SIDE+solver._edge(d)

func entry_cell(d: int) -> Vector2i:
	# One step inside the opposite gateway so a transition doesn't retrigger.
	return gate_cell(d)-DIRS[d]
