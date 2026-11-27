extends RefCounted
## Independent mountain necropolis: roofed gateway, broad stepped descent,
## central hall and seeded crypt districts. Single cave interval per column.
const CENTER := Vector2i(186,-170)
const RADIUS := 62.0
const INDEX := 4
const CITY_Y := -4
const ENTRY_Y := 8
var cycle := 0
var entrance := CENTER+Vector2i(38,0)
var hub := CENTER+Vector2i(42,0)
var heart := CENTER+Vector2i(-10,0)
var floors: Dictionary = {}
var ceilings: Dictionary = {}
var route: Array[Vector3i] = []
var regions: Array[Dictionary] = []
var scenery: Dictionary = {}

func generate(world_seed: int,iteration: int) -> void:
	cycle=iteration
	var rng := RandomNumberGenerator.new()
	rng.seed=world_seed ^ 0x5ce1e7 ^ (iteration*7919)
	floors.clear()
	ceilings.clear()
	route.clear()
	regions.clear()
	scenery.clear()
	var passage: Dictionary = {}
	for i in range(40):
		var cell := entrance-Vector2i(i,0)
		var y := maxi(CITY_Y,ENTRY_Y-floori(float(i)/3.0))
		var width := 4 if i<8 else 2
		var clearance := 8 if i<8 else 5
		route.append(Vector3i(cell.x,y,cell.y))
		for lane in range(-width,width+1):
			var p := cell+Vector2i(0,lane)
			_carve(p,y,clearance)
			passage[p]=true
		if i%5==4:
			regions.append({"cells":passage,"anchor":cell,"label":"Mountain gateway" if i<10 else "Grand descent"})
			passage={}
		if i%4==0:
			for side in [-1,1]:
				var p := cell+Vector2i(0,width*side)
				scenery[p]={"kind":"crystal","height":y}
	# The main chamber is a genuine wide cavern, not a corridor or sky trench.
	_room(Rect2i(CENTER+Vector2i(-22,-8),Vector2i(22,17)),"Hall of the Ancients",10)
	_room(Rect2i(CENTER+Vector2i(-12,-23),Vector2i(5,47)),"Processional avenue",7)
	# Four bounded crypt plots around the central spine. Seeded chamber sizes
	# and roles; reserved central spine guarantees reachability.
	var labels := ["Ossuary","Rune forge","Royal crypt","Crystal sanctum"]
	for i in range(3,0,-1):
		var j := rng.randi_range(0,i)
		var swap: String = labels[i]
		labels[i]=labels[j]
		labels[j]=swap
	for i in range(4):
		var w := rng.randi_range(8,11)
		var h := rng.randi_range(8,11)
		var left := i%2==0
		var north := i<2
		var rect := Rect2i(CENTER+Vector2i(-15-w if left else -4,-10-h if north else 11),Vector2i(w,h))
		_room(rect,labels[i],rng.randi_range(6,8))
		var mid := rect.get_center()
		var gate_x := CENTER.x-10
		var gate := Rect2i(Vector2i(mini(mid.x,gate_x),mid.y-2),Vector2i(absi(mid.x-gate_x)+1,5))
		_room(gate,"Crypt gate",5)
		for corner in [rect.position+Vector2i(1,1),rect.end-Vector2i(2,2)]:
			scenery[corner]={"kind":"bones","height":CITY_Y}
	# Paired carved bone ribs and crystal clusters at the great hall edges.
	for x in range(-20,-2,4):
		for z in [-7,7]:
			scenery[CENTER+Vector2i(x,z)]={"kind":"rib","height":CITY_Y}
	for offset in [Vector2i(-20,-5),Vector2i(-20,5),Vector2i(-3,-6),Vector2i(-3,6)]:
		scenery[CENTER+offset]={"kind":"crystal","height":CITY_Y}

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
	# Split large halls into bounded view sectors, with overlapping reveal
	# margins. This avoids a single expensive whole-city cutaway variant.
	for z in range(rect.position.y,rect.end.y,8):
		for x in range(rect.position.x,rect.end.x,8):
			var part: Dictionary = {}
			for zz in range(z,mini(z+8,rect.end.y)):
				for xx in range(x,mini(x+8,rect.end.x)):
					part[Vector2i(xx,zz)]=true
			var anchor := Vector2i(x+mini(3,rect.end.x-x-1),z+mini(3,rect.end.y-z-1))
			regions.append({"cells":part,"anchor":anchor,"label":label})

func contains(p: Vector2i) -> bool:
	return Vector2(p-CENTER).length()<=RADIUS+6.0

func height_override(p: Vector2i) -> int:
	var local := p-CENTER
	var distance := Vector2(local).length()
	if distance>54.0: return -99999
	# East-facing entrance carved through a solid facade, with a broad
	# external landing. No open roof cells above the staircase.
	if local.x>=39 and local.x<=48 and absi(local.y)<=5:
		return ENTRY_Y-maxi(0,floori(float(local.x-43)/2.0))
	var mountain := roundi(3.0+19.0*(1.0-smoothstep(14.0,53.0,distance)))
	if floors.has(p):
		mountain=maxi(mountain,int(ceilings[p])+4)
	return mountain

func validate() -> bool:
	if not floors.has(entrance) or not floors.has(heart): return false
	var queue: Array[Vector2i] = [entrance]
	var seen: Dictionary = {entrance:true}
	var cursor := 0
	while cursor<queue.size():
		var p: Vector2i = queue[cursor]
		cursor+=1
		for d: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var q := p+d
			if seen.has(q) or not floors.has(q): continue
			if absi(int(floors[p])-int(floors[q]))>1: continue
			seen[q]=true
			queue.append(q)
	return seen.size()==floors.size() and seen.has(heart)
