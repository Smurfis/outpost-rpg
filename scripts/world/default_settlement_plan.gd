extends RefCounted
## Built-in settlement blueprint for the third exploration island.
## Terrain heights are authoritative; no cave or terrain columns are edited.
const DIRS: Array[Vector2i] = [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
const LOT := 7
const MAX_BUILDINGS := 4
const KINDS := ["watchtower","smithy","storehouse","house"]
var roads: Dictionary = {}
var buildings: Array[Dictionary] = []
var reserved: Dictionary = {}
var hub := Vector2i.ZERO
var landing := Vector2i.ZERO
var cave_approach := Vector2i.MAX
var cave_route: Array[Vector2i] = []
var _heights: Dictionary = {}
var _ids: Dictionary = {}
var _graph := AStar2D.new()

func _safe(source, p: Vector2i) -> bool:
	if source.margin_at(p.x+0.5,p.y+0.5)<2.0: return false
	if source.height_at(p.x,p.y)<-2: return false
	for dz in range(-1,2):
		for dx in range(-1,2):
			if source.caves.has_cave(p.x+dx,p.y+dz): return false
	return true

func _nearest(anchor: Vector2i) -> Vector2i:
	var result := Vector2i.MAX
	var best := INF
	for p: Vector2i in _ids:
		if _graph.is_point_disabled(_ids[p]): continue
		var cost := float(p.distance_squared_to(anchor))
		if cost<best:
			best = cost
			result = p
	return result

func _route(a: Vector2i,b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _ids.has(a) or not _ids.has(b): return result
	for id in _graph.get_id_path(_ids[a],_ids[b]):
		result.append(Vector2i(_graph.get_point_position(id)))
	return result

func _disable(rect: Rect2i, disabled: bool) -> void:
	for z in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var p := Vector2i(x,z)
			if _ids.has(p): _graph.set_point_disabled(_ids[p],disabled)

func _record_road(route: Array[Vector2i]) -> void:
	for p in route: roads[p] = true

func generate(source) -> bool:
	roads.clear()
	cave_approach = Vector2i.MAX
	cave_route.clear()
	buildings.clear()
	reserved.clear()
	_heights.clear()
	_ids.clear()
	_graph.clear()
	var center: Vector2i = source.islands[2]["center"]
	# Restrict planning to one bounded island, and preserve its cave corridor.
	for z in range(center.y-44,center.y+45):
		for x in range(center.x-44,center.x+45):
			var p := Vector2i(x,z)
			if not _safe(source,p): continue
			var h: int = source.height_at(x,z)
			_heights[p] = h
			var id := _graph.get_available_point_id()
			_ids[p] = id
			_graph.add_point(id,Vector2(p))
	for p: Vector2i in _ids:
		var roughness := 0.0
		for d in DIRS:
			if _heights.has(p+d): roughness += absf(float(_heights[p]-_heights[p+d]))
		_graph.set_point_weight_scale(_ids[p],1.0+roughness*0.35)
		for d in [Vector2i.RIGHT,Vector2i.DOWN]:
			var q: Vector2i = p+d
			if _ids.has(q) and absi(int(_heights[p]) - int(_heights[q]))<=1:
				_graph.connect_points(_ids[p],_ids[q])
	hub = _nearest(center+Vector2i(-12,-15))
	if hub==Vector2i.MAX: return false
	# Prefer the nearest reachable shallow western coast, not an arbitrary
	# straight line across the hills. Retain the existing island cave route.
	var shore: Array[Vector2i] = []
	for p: Vector2i in _ids:
		if p.x<center.x and source.margin_at(p.x+0.5,p.y+0.5)<5.0: shore.append(p)
	shore.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		var da := a.distance_squared_to(hub)
		var db := b.distance_squared_to(hub)
		return da<db if da!=db else (a.x<b.x if a.x!=b.x else a.y<b.y))
	var found := false
	for p in shore:
		var route := _route(hub,p)
		if route.is_empty(): continue
		landing = p
		_record_road(route)
		found = true
		break
	if not found: return false
	var candidates: Array[Vector2i] = []
	for z in range(hub.y-20,hub.y+21,2):
		for x in range(hub.x-20,hub.x+21,2):
			candidates.append(Vector2i(x,z))
	var rng := RandomNumberGenerator.new()
	rng.seed = source.seed ^ 0x51c17
	# Stable per-seed tie breaks without relying on dictionary iteration.
	var tie: Dictionary = {}
	for p in candidates: tie[p] = rng.randf()
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return float(a.distance_squared_to(hub))+float(tie[a])*30.0 < float(b.distance_squared_to(hub))+float(tie[b])*30.0)
	for at in candidates:
		if buildings.size()>=MAX_BUILDINGS: break
		var rect := Rect2i(at,Vector2i(LOT,LOT))
		var hi := -999
		var lo := 999
		var valid := true
		for z in range(at.y,at.y+LOT):
			for x in range(at.x,at.x+LOT):
				var p := Vector2i(x,z)
				if not _heights.has(p) or reserved.has(p) or roads.has(p) or p==hub:
					valid = false
					continue
				hi = maxi(hi,_heights[p])
				lo = mini(lo,_heights[p])
		if not valid or hi-lo>2: continue
		# Building floor is a single flat, accessible layer on a shallow
		# foundation. Door must meet the outside terrain by <= one step.
		var floor_y := hi+1
		_disable(rect,true)
		var best: Array[Vector2i] = []
		var door := Vector2i.ZERO
		var direction := Vector2i.ZERO
		for d in DIRS:
			var edge := at+Vector2i(3,3)+d*3
			var outside := edge+d
			if not _heights.has(outside) or reserved.has(outside) or absi(floor_y-int(_heights[outside]))>1: continue
			var side := Vector2i(-d.y,d.x)
			var wide := true
			for offset in [-1,1]:
				var q: Vector2i = outside+side*int(offset)
				if not _heights.has(q) or reserved.has(q) or absi(floor_y-int(_heights[q]))>1: wide = false
			if not wide: continue
			var route := _route(hub,outside)
			if route.is_empty(): continue
			if best.is_empty() or route.size()<best.size():
				best = route
				door = edge
				direction = d
		if best.is_empty():
			_disable(rect,false)
			continue
		_record_road(best)
		var side := Vector2i(-direction.y,direction.x)
		for offset in range(-1,2): roads[door+direction+side*offset] = true
		for z in range(at.y,at.y+LOT):
			for x in range(at.x,at.x+LOT): reserved[Vector2i(x,z)] = true
		buildings.append({"id":"settlement_%s" % KINDS[buildings.size()],"kind":KINDS[buildings.size()],"rect":rect,"floor":floor_y,"door":door,"direction":direction,"route":best})
	# Connect another existing POI without modifying the cave's own cells.
	# The endpoint is a safe exterior staging tile, not a tunnel floor.
	if source.caves.entrances.size()>2:
		var entrance: Vector3 = source.caves.entrances[2]
		var anchor := Vector2i(floori(entrance.x),floori(entrance.z))
		var approaches: Array[Vector2i] = []
		for p: Vector2i in _ids:
			if p.distance_squared_to(anchor)<=64 and absf(float(_heights[p])-entrance.y)<=2.0:
				approaches.append(p)
		approaches.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
			var da := a.distance_squared_to(anchor)
			var db := b.distance_squared_to(anchor)
			return da<db if da!=db else (a.x<b.x if a.x!=b.x else a.y<b.y))
		for p in approaches:
			var route := _route(hub,p)
			if route.is_empty(): continue
			cave_approach = p
			cave_route = route
			_record_road(route)
			break
	# Expand narrow centerlines by one tile on gentle slopes. The road remains
	# a terrain material, not another set of mesh nodes or colliders.
	var centerlines: Array = roads.keys()
	for p: Vector2i in centerlines:
		for d in DIRS:
			var q := p+d
			if _heights.has(q) and not reserved.has(q) and absi(int(_heights[p])-int(_heights[q]))<=1:
				roads[q] = true
	# The immutable result is enough for streamed terrain, map and buildings;
	# discard the temporary search graph and per-cell planning tables.
	_graph.clear()
	_ids.clear()
	_heights.clear()
	return buildings.size()>=2

func is_road(x: int,z: int) -> bool:
	return roads.has(Vector2i(x,z))

func building_at(cell: Vector2i) -> Dictionary:
	for item in buildings:
		if item["rect"].has_point(cell): return item
	return {}
