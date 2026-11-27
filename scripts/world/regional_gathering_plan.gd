extends RefCounted
## Deterministic gathering pockets on existing connected terrain.
const PLACEMENT = preload("res://scripts/world/prop_placement.gd")
const DIRS: Array[Vector2i] = [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
var nodes: Array[Dictionary] = []
var access: Dictionary = {}

func _free(plan,p: Vector2i) -> bool:
	if not plan._heights.has(p) or int(plan._heights[p])<0 or plan.reserved.has(p) or plan.field_tiles.has(p): return false
	for anchor in plan.quest_anchors:
		if anchor["cell"]==p: return false
	return true

func _fits(plan,p: Vector2i,kind: String) -> bool:
	var radius := PLACEMENT.radius_for(kind)
	for dz in range(-3,4):
		for dx in range(-3,4):
			var q := p+Vector2i(dx,dz)
			if float(p.distance_squared_to(q))>pow(radius+0.6,2): continue
			if not _free(plan,q) or plan.roads.has(q) or plan.scenery.has(q) or access.has(q): return false
			if absi(int(plan._heights[p])-int(plan._heights[q]))>1: return false
	for node in nodes:
		var old: Vector2i = node["cell"]
		if p.distance_to(old)<radius+PLACEMENT.radius_for(node["kind"])+0.5: return false
	return true

func _clear_walk(plan,p: Vector2i) -> bool:
	if not _free(plan,p): return false
	for node in nodes:
		var at: Vector2i = node["cell"]
		if at.distance_to(p)<PLACEMENT.radius_for(node["kind"])+0.45: return false
	return true

func _approach(plan,p: Vector2i,kind: String) -> Array[Vector2i]:
	var distance := 2 if kind=="wood" else 1
	for d in DIRS:
		var stand := p+d*distance
		if not _clear_walk(plan,stand): continue
		if absi(int(plan._heights[stand])-int(plan._heights[p]))>1: continue
		var queue: Array[Vector2i] = [stand]
		var paths: Dictionary = {}
		paths[stand]=[stand]
		var cursor := 0
		while cursor<queue.size():
			var at: Vector2i = queue[cursor]
			cursor+=1
			var path: Array = paths[at]
			if plan.roads.has(at):
				var result: Array[Vector2i] = []
				result.assign(path)
				return result
			if path.size()>=9: continue
			for step in DIRS:
				var q := at+step
				if paths.has(q) or not _clear_walk(plan,q): continue
				if q.distance_to(p)<PLACEMENT.radius_for(kind)+0.2: continue
				if absi(int(plan._heights[at])-int(plan._heights[q]))>1: continue
				var next := path.duplicate()
				next.append(q)
				paths[q]=next
				queue.append(q)
	return []

func generate(source,plan) -> void:
	nodes.clear()
	access.clear()
	var cells: Array = plan._heights.keys()
	for profile in [{"habitat":"woodland","tier":1,"kinds":["wood","wood","wood","fiber","berries","herbs"]},{"habitat":"rocky_outcrop","tier":2,"kinds":["stone","coal","iron","stone"]}]:
		var habitat: String = profile["habitat"]
		var tier: int = profile["tier"]
		var center := Vector2i.MAX
		for kind in profile["kinds"]:
			var origin: Vector2i = plan.hub if center==Vector2i.MAX else center
			var candidates: Array = cells.duplicate()
			candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
				var da := a.distance_squared_to(origin)
				var db := b.distance_squared_to(origin)
				return da<db if da!=db else (a.x<b.x if a.x!=b.x else a.y<b.y))
			for p: Vector2i in candidates:
				if center!=Vector2i.MAX and p.distance_squared_to(center)>196: continue
				if not _fits(plan,p,kind): continue
				var route := _approach(plan,p,kind)
				if route.is_empty(): continue
				if center==Vector2i.MAX: center=p
				for q in route: access[q]=true
				nodes.append({"id":"%s:%s:%d:%d" % [plan.site_id,kind,p.x,p.y],"site":plan.site_id+":"+habitat,
					"habitat":habitat,"tier":tier,"kind":kind,"cell":p,"position":Vector3(p.x+0.5,source.height_at(p.x,p.y)+0.055,p.y+0.5),"approach":route})
				break
	# Nonblocking cave fungi at the edge of the existing end chamber.
	# Do not insert solid ore into narrow passages or the chest interaction lane.
	var index: int = plan.island_index
	if source.caves.chests.size()<=index: return
	var chest: Vector3 = source.caves.chests[index]
	var at := Vector2i(floori(chest.x),floori(chest.z))
	for offset in [Vector2i(-2,-2),Vector2i(2,2),Vector2i(-2,2),Vector2i(2,-2)]:
		var p: Vector2i = at+offset
		var floor_y: int = source.caves.floor_at(p.x,p.y)
		if floor_y!=int(chest.y) or source.height_at(p.x,p.y)<floor_y+4: continue
		nodes.append({"id":"%s:cave_fungi:%d:%d" % [plan.site_id,p.x,p.y],"site":plan.site_id+":cavern",
			"habitat":"cavern","tier":3,"kind":"mushrooms","cell":p,"position":Vector3(p.x+0.5,floor_y+0.055,p.y+0.5),"approach":[]})
		break
