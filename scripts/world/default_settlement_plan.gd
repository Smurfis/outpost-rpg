extends RefCounted
## Built-in settlement blueprint for a bounded exploration island.
## Terrain heights are authoritative; no cave or terrain columns are edited.
const DIRS: Array[Vector2i] = [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
const MAX_BUILDINGS := 6
const KINDS := ["watchtower","smithy","storehouse","house","inn","guardhouse"]
const FOOTPRINTS: Array[Vector2i] = [Vector2i(7,7),Vector2i(7,7),Vector2i(5,7),Vector2i(5,5),Vector2i(7,5),Vector2i(5,5)]
var island_index := 2
var site_id := "settlement"
var profile := "market_town"
var roles: Array = KINDS.duplicate()
var footprints: Array[Vector2i] = FOOTPRINTS.duplicate()
var landmarks: Array[Dictionary] = []
var west_route: Array[Vector2i] = []
var eastern_landing := Vector2i.MAX
var eastern_route: Array[Vector2i] = []
var plaza: Dictionary = {}
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

func generate(source, index: int = 2) -> bool:
	if index not in [1,2]: return false
	island_index = index
	site_id = "settlement" if index==2 else "waystation"
	profile = "market_town" if index==2 else "frontier_waystation"
	roles = KINDS.duplicate() if index==2 else ["guardhouse","storehouse","house"]
	footprints.clear()
	if index==2:
		footprints.append_array(FOOTPRINTS)
	else:
		footprints.append(Vector2i(5,5))
		footprints.append(Vector2i(5,7))
		footprints.append(Vector2i(5,5))
	landmarks.clear()
	west_route.clear()
	eastern_landing = Vector2i.MAX
	eastern_route.clear()
	roads.clear()
	plaza.clear()
	cave_approach = Vector2i.MAX
	cave_route.clear()
	buildings.clear()
	reserved.clear()
	_heights.clear()
	_ids.clear()
	_graph.clear()
	var center: Vector2i = source.islands[island_index]["center"]
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
		west_route = route
		_record_road(route)
		found = true
		break
	if not found: return false
	var candidates: Array[Vector2i] = []
	for z in range(hub.y-28,hub.y+29,2):
		for x in range(hub.x-28,hub.x+29,2):
			candidates.append(Vector2i(x,z))
	var rng := RandomNumberGenerator.new()
	rng.seed = source.seed ^ 0x51c17 ^ (0 if island_index==2 else 0x192a)
	# Stable per-seed tie breaks without relying on dictionary iteration.
	var tie: Dictionary = {}
	for p in candidates: tie[p] = rng.randf()
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return float(a.distance_squared_to(hub))+float(tie[a])*30.0 < float(b.distance_squared_to(hub))+float(tie[b])*30.0)
	for role_index in range(roles.size()):
		if not _place_building(candidates,role_index): break

	# Reserve a modest public square around the hub without altering slopes.
	for dz in range(-2,3):
		for dx in range(-2,3):
			var p := hub+Vector2i(dx,dz)
			if not _heights.has(p) or reserved.has(p): continue
			if absf(float(_heights[p]-_heights[hub]))>1.0: continue
			var route := _route(hub,p)
			if route.is_empty() or route.size()>7: continue
			plaza[p] = true
			_record_road(route)
	# Connect another existing POI without modifying the cave's own cells.
	# The endpoint is a safe exterior staging tile, not a tunnel floor.
	if source.caves.entrances.size()>island_index:
		var entrance: Vector3 = source.caves.entrances[island_index]
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
	# Connect the existing eastern coastal access corridor after mandatory
	# building reservations. This is a real safe dry approach, not a dock.
	var east: Array[Vector2i] = []
	for p: Vector2i in _ids:
		if p.x>center.x and absi(p.y-center.y)<=2 and source.margin_at(p.x+0.5,p.y+0.5)<5.0:
			east.append(p)
	east.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return a.x>b.x if a.x!=b.x else a.y<b.y)
	for p in east:
		var route := _route(hub,p)
		if route.is_empty(): continue
		eastern_landing = p
		eastern_route = route
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
	_build_landmarks(source)
	var valid: bool = buildings.size()>=2 and _validate_network(source)
	# The immutable result is enough for streamed terrain, map and buildings;
	# discard the temporary search graph and per-cell planning tables.
	_graph.clear()
	_ids.clear()
	_heights.clear()
	return valid

func _place_building(candidates: Array[Vector2i],index: int) -> bool:
	for at in candidates:
		var size: Vector2i = footprints[index]
		var rect := Rect2i(at,size)
		var hi := -999
		var lo := 999
		var valid := true
		for z in range(at.y,rect.end.y):
			for x in range(at.x,rect.end.x):
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
			var half := Vector2i((size.x-1)/2,(size.y-1)/2)
			var edge := at+half+Vector2i(d.x*half.x,d.y*half.y)
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
		for z in range(at.y,rect.end.y):
			for x in range(at.x,rect.end.x): reserved[Vector2i(x,z)] = true
		buildings.append({"id":"%s_%s" % [site_id,roles[index]],"kind":roles[index],"rect":rect,"floor":floor_y,"door":door,"direction":direction,"route":best})
		return true
	return false

func _add_landmark(source, suffix: String, label: String, role: String, p: Vector2i) -> void:
	landmarks.append({"id":"%s:%s" % [site_id,suffix],"label":label,"role":role,
		"position":Vector3(p.x+0.5,source.height_at(p.x,p.y),p.y+0.5),"cell":p})

func _build_landmarks(source) -> void:
	_add_landmark(source,"hub","Market Town" if island_index==2 else "Frontier Waystation","settlement",hub)
	_add_landmark(source,"west","Western Landing","landing",landing)
	if not eastern_route.is_empty():
		_add_landmark(source,"east","Eastern Landing","landing",eastern_landing)
	if not cave_route.is_empty():
		_add_landmark(source,"cave","Cavern Approach","cave_approach",cave_approach)
	for item in buildings:
		var p: Vector2i = item["door"]+item["direction"]
		_add_landmark(source,str(item["kind"]),str(item["kind"]).capitalize(),"architecture",p)

func _validate_network(source) -> bool:
	# A road is not merely a material: every published destination must be
	# connected by safe cardinal steps from the settlement hub.
	if not roads.has(hub): return false
	var visited: Dictionary = {}
	visited[hub]=true
	var queue: Array[Vector2i] = [hub]
	var cursor := 0
	while cursor<queue.size():
		var p: Vector2i = queue[cursor]
		cursor+=1
		for d in DIRS:
			var q := p+d
			if visited.has(q) or not roads.has(q) or reserved.has(q): continue
			if absi(source.height_at(p.x,p.y)-source.height_at(q.x,q.y))>1: continue
			visited[q]=true
			queue.append(q)
	for item in landmarks:
		if not visited.has(item["cell"]): return false
	return true

func is_road(x: int,z: int) -> bool:
	return roads.has(Vector2i(x,z))

func building_at(cell: Vector2i) -> Dictionary:
	for item in buildings:
		if item["rect"].has_point(cell): return item
	return {}
