extends RefCounted
## Isolated northern test territory. No quest, loot or persistent mine state.
## Single-floor cave columns, rather than pretending to support stacked
## spiral tunnels. The surface and dungeon are two real elevations.
const CENTER := Vector2i(0,-207)
const RADIUS := 58.0
const INDEX := 3
const CITY_Y := -3
var cycle := 0
var floors: Dictionary = {}
var ceilings: Dictionary = {}
var regions: Array[Dictionary] = []
var route: Array[Vector3i] = []
var buildings: Array[Dictionary] = []
var roads: Dictionary = {}
var guards: Array[Dictionary] = []
var caches: Array[Dictionary] = []
var gatherers: Array[Dictionary] = []
var hub := CENTER+Vector2i(0,5)
var entrance := CENTER+Vector2i(36,0)
var throne := CENTER+Vector2i(-17,0)
var city_seed := 0

func generate(world_seed: int,iteration: int) -> void:
	cycle=iteration
	city_seed=world_seed ^ 0x71b923 ^ (iteration*7919)
	var rng := RandomNumberGenerator.new()
	rng.seed=city_seed
	floors.clear()
	ceilings.clear()
	regions.clear()
	route.clear()
	buildings.clear()
	roads.clear()
	guards.clear()
	caches.clear()
	gatherers.clear()
	# Three-wide roofed descent from the eastern shoulder into the city.
	for step in range(27):
		var p := entrance-Vector2i(step,0)
		var y := maxi(CITY_Y,3-floori(float(step)/4.0))
		route.append(Vector3i(p.x,y,p.y))
		for lane in range(-1,2):
			_carve(p+Vector2i(0,lane),y,4)
		if step%6==5 or step==26:
			var cells: Dictionary = {}
			for n in range(maxi(0,step-5),step+1):
				for lane in range(-1,2): cells[entrance-Vector2i(n,0)+Vector2i(0,lane)]=true
			regions.append({"cells":cells,"anchor":p})
	# Central boulevard and transept. District blocks split around reserved
	# streets; seed controls room dimensions and role order.
	var main := Rect2i(CENTER+Vector2i(-13,-2),Vector2i(25,5))
	_room(main,"Grand avenue",5)
	_room(Rect2i(CENTER+Vector2i(-2,-17),Vector2i(5,35)),"Crossroads",5)
	_room(Rect2i(CENTER+Vector2i(-21,-6),Vector2i(11,13)),"Throne hall",7)
	var roles := ["War barracks","Forge district","Treasury","Bone shrine"]
	for i in range(3,0,-1):
		var j := rng.randi_range(0,i)
		var swap: String = roles[i]
		roles[i]=roles[j]
		roles[j]=swap
	for i in range(4):
		var left := i%2==0
		var north := i<2
		var w := rng.randi_range(8,10)
		var h := rng.randi_range(8,11)
		var x := -12 if left else 5
		var z := -h-4 if north else 4
		var rect := Rect2i(CENTER+Vector2i(x,z),Vector2i(w,h))
		_room(rect,roles[i],rng.randi_range(5,6))
		# Three-wide doorway from the room into the reserved north/south street.
		var mid := rect.get_center()
		var end_x := CENTER.x-2 if left else CENTER.x+2
		var connector: Dictionary = {}
		for px in range(mini(mid.x,end_x),maxi(mid.x,end_x)+1):
			for dz in range(-1,2):
				var p := Vector2i(px,mid.y+dz)
				_carve(p,CITY_Y,4)
				connector[p]=true
		regions.append({"cells":connector,"anchor":Vector2i(end_x,mid.y),"label":"District gate"})
		guards.append({"id":"district_%d" % i,"cell":mid,"underground":true})
	guards.append({"id":"throne","cell":throne,"underground":true})
	# Surface stronghold with ten roofed stone/timber structures and a keep.
	# All footprints fit the level terrace, streets stay free.
	var slots: Array[Vector2i] = [Vector2i(-21,-20),Vector2i(-13,-20),Vector2i(8,-20),Vector2i(18,-20),
		Vector2i(-21,-8),Vector2i(18,-8),Vector2i(-21,10),Vector2i(-13,10),Vector2i(8,10),Vector2i(18,10)]
	for i in range(slots.size()):
		var kind: String = ["watchtower","guardhouse","smithy","storehouse","house","guardhouse"][rng.randi_range(0,5)]
		if i in [0,3,6,9]: kind="watchtower"
		_build("district_%d" % i,kind,Rect2i(CENTER+slots[i],Vector2i(7,7)),Vector2i(0,1 if i<6 else -1))
	_build("keep","watchtower",Rect2i(CENTER+Vector2i(-5,-19),Vector2i(11,11)),Vector2i.DOWN)
	var infill: Array[Vector2i] = [Vector2i(-12,-7),Vector2i(8,-7),Vector2i(-21,0),Vector2i(18,0),Vector2i(-7,17),Vector2i(3,17)]
	for i in range(infill.size()):
		_build("infill_%d" % i,["house","storehouse","house","smithy","guardhouse","house"][i],Rect2i(CENTER+infill[i],Vector2i(5,5)),Vector2i.DOWN if i<4 else Vector2i.UP)
	for z in range(-25,24):
		for x in range(-27,29):
			var p := CENTER+Vector2i(x,z)
			if absi(x)<=2 or absi(z-5)<=2 or absi(z+10)<=1 or x in [-24,25]:
				if building_at(p).is_empty(): roads[p]=true
	for x in range(28,43):
		for z in range(4,7): roads[CENTER+Vector2i(x,z)]=true
	for z in range(0,5): roads[CENTER+Vector2i(42,z)]=true
	for x in range(36,43): roads[CENTER+Vector2i(x,0)]=true
	for item in buildings:
		var at: Vector2i = item["door"]+item["direction"]
		var path := _surface_route(at)
		item["route"]=path
		for p in path: roads[p]=true
	for i in [0,2,4,7,10,12,15]:
		var item: Dictionary = buildings[i]
		var rect: Rect2i = item["rect"]
		var cell := rect.get_center()+Vector2i(1,0)
		caches.append({"id":"building_%d" % i,"cell":cell,"height":int(item["floor"]),"loot":{"wood":rng.randi_range(3,7),"stone":rng.randi_range(2,5),"fiber":rng.randi_range(1,4)}})
	# Two workers have fixed storage yards and distinct collection walks.
	for i in range(2):
		var side := -1 if i==0 else 1
		var yard := CENTER+Vector2i(side*12,6)
		var source := CENTER+Vector2i(side*25,-10)
		var to_hub := _surface_route(yard)
		to_hub.reverse()
		var outward := _surface_route(source)
		if to_hub.is_empty() or outward.is_empty(): continue
		to_hub.append_array(outward.slice(1))
		for p in to_hub: roads[p]=true
		gatherers.append({"id":"worker_%d" % i,"yard":yard,"source":source,"path":to_hub,"chest":yard+Vector2i(0,1)})
	for offset in [Vector2i(-9,5),Vector2i(9,5),Vector2i(0,-4),Vector2i(0,18),Vector2i(-16,7),Vector2i(16,7)]:
		guards.append({"id":"surface_%d_%d" % [offset.x,offset.y],"cell":CENTER+offset,"underground":false})

func _surface_route(goal: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [hub]
	var parents: Dictionary = {hub:hub}
	var cursor := 0
	while cursor<queue.size() and not parents.has(goal):
		var p: Vector2i = queue[cursor]
		cursor+=1
		for d: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
			var q := p+d
			var local := q-CENTER
			if parents.has(q) or absi(local.x)>27 or absi(local.y)>24 or not building_at(q).is_empty(): continue
			parents[q]=p
			queue.append(q)
	var route_cells: Array[Vector2i] = []
	if not parents.has(goal): return route_cells
	var cursor_cell := goal
	while cursor_cell!=hub:
		route_cells.append(cursor_cell)
		cursor_cell=parents[cursor_cell]
	route_cells.append(hub)
	route_cells.reverse()
	return route_cells

func _build(id: String,kind: String,rect: Rect2i,d: Vector2i) -> void:
	var door := rect.get_center()+Vector2i(d.x*floori(rect.size.x/2.0),d.y*floori(rect.size.y/2.0))
	buildings.append({"id":"goblin_city_"+id,"kind":kind,"rect":rect,"floor":11,"door":door,"direction":d,"route":[]})

func _carve(p: Vector2i,y: int,clearance: int) -> void:
	floors[p]=mini(int(floors.get(p,y)),y)
	ceilings[p]=maxi(int(ceilings.get(p,y+clearance)),y+clearance)

func _room(rect: Rect2i,label: String,clearance: int) -> void:
	var cells: Dictionary = {}
	for z in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var p := Vector2i(x,z)
			_carve(p,CITY_Y,clearance)
			cells[p]=true
	regions.append({"cells":cells,"anchor":rect.get_center(),"label":label})

func building_at(p: Vector2i) -> Dictionary:
	for item in buildings:
		if item["rect"].has_point(p): return item
	return {}

func height_override(p: Vector2i) -> int:
	var local := p-CENTER
	var edge := maxi(absi(local.x),absi(local.y))
	# Deliberate broad stone terrace, then one-block shoulders. Tunnel mouth
	# opens on the eastern side; subsequent cells have a thick roof.
	if local.x>=31 and local.x<=40 and absi(local.y)<=2:
		if local.x>=36: return 3-floori(float(maxi(0,local.x-36))/2.0)
		return maxi(8,int(ceilings.get(p,7))+2)
	if local.x>=28 and local.x<=43 and local.y>=3 and local.y<=7:
		return maxi(2,10-floori(float(local.x-28)*0.6))
	if Vector2(local).length()>51.0: return -99999
	if edge<=28: return 10
	if edge<=44: return 10-ceili(float(edge-28)/2.0)
	return -99999

func contains(p: Vector2i) -> bool:
	return Vector2(p-CENTER).length()<=RADIUS+6.0

func validate() -> bool:
	if floors.is_empty() or not floors.has(throne) or gatherers.size()!=2: return false
	for worker in gatherers:
		for p: Vector2i in worker["path"]:
			if not building_at(p).is_empty(): return false
		if not building_at(worker["chest"]).is_empty(): return false
	for i in range(buildings.size()):
		var a: Rect2i = buildings[i]["rect"]
		if buildings[i]["route"].is_empty(): return false
		for j in range(i+1,buildings.size()):
			var b: Rect2i = buildings[j]["rect"]
			if a.intersects(b): return false
	var start := entrance
	var visited := {start:true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor<queue.size():
		var p: Vector2i = queue[cursor]
		cursor+=1
		for d: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
			var q := p+d
			if visited.has(q) or not floors.has(q) or absi(int(floors[p])-int(floors[q]))>1: continue
			visited[q]=true
			queue.append(q)
	return visited.size()==floors.size() and visited.has(throne)
