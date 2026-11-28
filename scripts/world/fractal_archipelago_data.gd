extends RefCounted
## Oasis-inspired deterministic archipelago. Deliberately separate from the
## starter island so Outpost's existing terrain, camp and coastline stay intact.
const CAVES = preload("res://scripts/world/stepped_cave_tunnels.gd")
const SETTLEMENT = preload("res://scripts/world/default_settlement_plan.gd")
const GOBLIN_CITY = preload("res://scripts/world/goblin_city_plan.gd")
const SKELETAL_CITY = preload("res://scripts/world/skeletal_city_plan.gd")
var skeletal_city: RefCounted
var goblin_city: RefCounted
var _settlements: Dictionary = {}
var _settlement_attempted: Dictionary = {}
const SEA_LEVEL: float = -2.82
const BEDROCK: int = -7
const OCEAN_PLAY_HALF: int = 384
# Exploration islands lie across real swimmable water, beyond home +/-96.
var islands: Array[Dictionary] = [
	{"center": Vector2i(172, 62), "radius": 36.0, "strength": 0.7,"biome":"rocky_highlands","name":"Goblin Mineshaft","sea":"rocky_shoals"},
	{"center": Vector2i(-200, -58), "radius": 44.0, "strength": 1.15,"biome":"temperate_woodland","name":"Frontier Waystation","sea":"kelp_coast"},
	{"center": Vector2i(18, 232), "radius": 46.0, "strength": 1.4,"biome":"warm_meadow","name":"Market Town","sea":"sandbanks"},
]
var expanded_preview := false
var seed: int
var caves
var _fuzz: FastNoiseLite
var _fractal: FastNoiseLite
var _ridges: FastNoiseLite
var _height_cache: Dictionary = {}
var _margin_cache: Dictionary = {}
var _cave_cover: Dictionary = {}
var _cove_apron: Dictionary = {}
var ore_slots: Dictionary = {} # Exact wall voxel -> regenerating material
var _ore_column_masks: Dictionary = {}

func _init(world_seed: int = 64012) -> void:
	seed = world_seed
	_fuzz = FastNoiseLite.new()
	_fuzz.seed = seed + 17
	_fuzz.noise_type = FastNoiseLite.TYPE_PERLIN
	_fuzz.frequency = 0.035
	_fuzz.fractal_type = FastNoiseLite.FRACTAL_FBM
	_fuzz.fractal_octaves = 3
	_fractal = FastNoiseLite.new()
	_fractal.seed = seed + 113
	_fractal.noise_type = FastNoiseLite.TYPE_PERLIN
	_fractal.frequency = 0.032
	_fractal.fractal_type = FastNoiseLite.FRACTAL_FBM
	_fractal.fractal_octaves = 6 # Original Oasis detail layering
	_fractal.fractal_lacunarity = 3.0
	_fractal.fractal_gain = 0.4
	_ridges = FastNoiseLite.new()
	_ridges.seed = seed + 701
	_ridges.noise_type = FastNoiseLite.TYPE_PERLIN
	_ridges.frequency = 0.039
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 4
	if str(ProjectSettings.get_setting("application/config/build_channel",""))=="world-preview" or OS.get_environment("OUTPOST_TEST_GOBLIN_CITY")=="1":
		expanded_preview=true
		# Keep original cave placement radii while extending settlement land.
		islands[1]["cave_radius"]=44.0
		islands[2]["cave_radius"]=46.0
		goblin_city=GOBLIN_CITY.new()
		goblin_city.generate(seed,0)
		islands.append({"center":GOBLIN_CITY.CENTER,"radius":GOBLIN_CITY.RADIUS,"strength":1.4,"biome":"goblin_badlands","name":"Goblin Territory","sea":"cold_reef"})
		# Compute original routes before applying any settlement terrain edits.
		expanded_preview=false
	caves = CAVES.new()
	caves.configure(self)
	if goblin_city!=null:
		expanded_preview=true
		islands[1]["radius"]=56.0
		islands[2]["radius"]=64.0
		_height_cache.clear()
		_margin_cache.clear()
		_install_city_caves()
		skeletal_city=SKELETAL_CITY.new()
		skeletal_city.generate(seed,0)
		islands.append({"center":SKELETAL_CITY.CENTER,"radius":SKELETAL_CITY.RADIUS,"strength":1.6,"biome":"dwarven_mountain","name":"Skeletal City","sea":"cold_reef"})
		_install_skeletal_caves()
	if expanded_preview:
		_shape_preview_coves()
	else:
		_cover_remote_caves()
	_plan_cave_ore()

# Preserve the original non-preview coastal route contract. Preview alone
# replaces the exposed approach with a lateral roofed entrance.
func _cover_remote_caves() -> void:
	for index in [1,2]:
		var route: Array = caves.routes[index]
		if route.is_empty(): continue
		var mouth: Vector3i = route.front()
		for i in range(5,route.size()):
			var step: Vector3i = route[i]
			for lane in range(CAVES.CORRIDOR_WIDTH):
				_cover_column(Vector2i(step.x,step.z+lane),mouth,false,false)
		var end: Vector3i = route.back()
		for dz in range(-2,3):
			for dx in range(-2,3):
				_cover_column(Vector2i(end.x+dx,end.z+dz),mouth,false,false)

# Sculpt a real mountain facade into the existing Perlin terrain. Both
# remote cave routes retain their original floor/chest coordinates. Widen
# the mouth sideways; taper ceiling and width as the player walks inside.
func _shape_preview_coves() -> void:
	for index in [1,2]:
		var route: Array = caves.routes[index]
		if route.is_empty(): continue
		var mouth: Vector3i = route.front()
		for i in range(mini(9,route.size())):
			var step: Vector3i = route[i]
			var width := 2 if i<3 else 1 if i<6 else 0
			for lane in range(-width,CAVES.CORRIDOR_WIDTH+width):
				var cell := Vector2i(step.x,step.z+lane)
				var floor_y: int = mini(int(caves.floors.get(cell,step.y)),step.y)
				caves.floors[cell]=floor_y
				# Raised central arch, lower shoulders; irregular taper.
				var edge: bool = lane==-width or lane==CAVES.CORRIDOR_WIDTH+width-1
				caves.extra_ceilings[cell]=floor_y+(6 if i<3 and not edge else 4 if i<6 else 3)
		for step: Vector3i in route:
			for lane in range(-2,4):
				var cell := Vector2i(step.x,step.z+lane)
				if caves.has_cave(cell.x,cell.y):
					_cover_column(cell,mouth,true,step.x>=mouth.x-8)
		var end: Vector3i = route.back()
		for dz in range(-2,3):
			for dx in range(-2,3):
				_cover_column(Vector2i(end.x+dx,end.z+dz),mouth,true,false)
		_grade_preview_approach(mouth,index)

func _grade_preview_approach(mouth: Vector3i,index: int) -> void:
	# A six-wide exterior landing connects to the actual shore, not a
	# global straight trench that continues through the entire island.
	var center: Vector2i = islands[index]["center"]
	var limit := center.x+ceili(float(islands[index]["radius"]))+8
	var last_land := mouth.x+1
	for x in range(mouth.x+1,limit):
		if margin_at(x+0.5,mouth.z+0.5)<=0.0: break
		last_land=x
	var length := maxi(1,last_land-mouth.x)
	for step in range(1,length+1):
		var x := mouth.x+step
		var travel := float(step-1)/float(maxi(1,length-1))
		var target := roundi(lerpf(float(mouth.y),-3.0,travel))
		for lane in range(-7,9):
			var z := mouth.z+lane
			if margin_at(x+0.5,z+0.5)<=0.0: continue
			var cell := Vector2i(x,z)
			var side := maxf(0.0,absf(float(lane)-0.5)-2.5)
			var weight := 1.0-smoothstep(0.0,5.0,side)
			var original := height_at(x,z)
			_cove_apron[cell]=roundi(lerpf(float(original),float(target),weight))

func _cover_column(cell: Vector2i,mouth: Vector3i,cove: bool,entrance: bool) -> void:
	var floor_y: int = caves.floor_at(cell.x,cell.y)
	if floor_y==CAVES.INVALID_FLOOR: return
	var roof: int = caves.ceiling_at(cell.x,cell.y,floor_y)+2
	var radius := 5 if cove and entrance else 3
	for dz in range(-radius,radius+1):
		for dx in range(-radius,radius+1):
			var q := cell+Vector2i(dx,dz)
			# Keep the front face open horizontally, never open to the sky.
			if cove and q.x>mouth.x: continue
			if not cove and q.x>mouth.x-5 and caves.has_cave(q.x,q.y): continue
			if margin_at(q.x+0.5,q.y+0.5)<=0: continue
			var distance := maxi(absi(dx),absi(dz))
			var required := roof-ceili(float(distance)*0.75) if cove and entrance else roof-distance
			_cave_cover[q]=maxi(int(_cave_cover.get(q,BEDROCK)),required)

func _plan_cave_ore() -> void:
	# Reserve actual solid wall voxels in the remote end chambers. Base
	# terrain mesh omits these cells; a separately streamed one-metre block
	# occupies each socket until mined. No excavation of support or roof.
	for index in [1,2]:
		var end: Vector3i = caves.routes[index].back()
		var candidates: Array[Vector3i] = []
		for dz in range(-2,3):
			for dx in range(-2,3):
				var inner := Vector2i(end.x+dx,end.z+dz)
				if caves.floor_at(inner.x,inner.y)!=end.y: continue
				for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
					var wall: Vector2i = inner+direction
					if caves.has_cave(wall.x,wall.y): continue
					var back: Vector2i = wall+direction
					var y := end.y+1
					if not is_solid(wall.x,y,wall.y) or not is_solid(back.x,y,back.y): continue
					if height_at(wall.x,wall.y)<y+2: continue
					var cell := Vector3i(wall.x,y,wall.y)
					if not candidates.has(cell): candidates.append(cell)
		candidates.sort_custom(func(a: Vector3i,b: Vector3i) -> bool:
			var ha := posmod(a.x*73856093+a.z*19349663+seed,2147483647)
			var hb := posmod(b.x*73856093+b.z*19349663+seed,2147483647)
			return ha<hb if ha!=hb else (a.x<b.x if a.x!=b.x else a.z<b.z))
		var placed := 0
		for cell in candidates:
			if placed>=6: break
			var adjacent := false
			for old: Vector3i in ore_slots:
				if old.distance_squared_to(cell)<=1: adjacent=true
			if adjacent: continue
			var kind: String = ["iron","coal","stone"][placed%3]
			ore_slots[cell]={"kind":kind,"tier":2 if kind=="stone" else 3,"island":index}
			var column := Vector2i(cell.x,cell.z)
			_ore_column_masks[column]=int(_ore_column_masks.get(column,0)) | (1 << (cell.y-BEDROCK))
			placed+=1

func _install_city_caves() -> void:
	# The old route list, entrance and chest indexes stay intact. The
	# experimental island has no ordinary reward chest or mine registry.
	for p: Vector2i in goblin_city.floors:
		caves.floors[p]=goblin_city.floors[p]
		caves.extra_ceilings[p]=goblin_city.ceilings[p]
	caves.routes.append(goblin_city.route)
	var start: Vector3i = goblin_city.route.front()
	caves.entrances.append(Vector3(start)+Vector3(0.5,0,0.5))

func regenerate_goblin_city() -> bool:
	if goblin_city==null: return false
	var next := GOBLIN_CITY.new()
	next.generate(seed,goblin_city.cycle+1)
	if not next.validate(): return false
	for p: Vector2i in goblin_city.floors:
		caves.floors.erase(p)
		caves.extra_ceilings.erase(p)
	goblin_city=next
	for p: Vector2i in next.floors:
		caves.floors[p]=next.floors[p]
		caves.extra_ceilings[p]=next.ceilings[p]
	caves.routes[GOBLIN_CITY.INDEX]=next.route
	var entry: Vector3i = next.route.front()
	caves.entrances[GOBLIN_CITY.INDEX]=Vector3(entry)+Vector3(0.5,0,0.5)
	return true

func _install_skeletal_caves() -> void:
	for p: Vector2i in skeletal_city.floors:
		caves.floors[p]=skeletal_city.floors[p]
		caves.extra_ceilings[p]=skeletal_city.ceilings[p]
	caves.routes.append(skeletal_city.route)
	var entry: Vector3i = skeletal_city.route.front()
	caves.entrances.append(Vector3(entry)+Vector3(0.5,0,0.5))

func regenerate_skeletal_city() -> bool:
	if skeletal_city==null: return false
	var next := SKELETAL_CITY.new()
	next.generate(seed,skeletal_city.cycle+1)
	if not next.validate(): return false
	for p: Vector2i in skeletal_city.floors:
		caves.floors.erase(p)
		caves.extra_ceilings.erase(p)
	skeletal_city=next
	for p: Vector2i in next.floors:
		caves.floors[p]=next.floors[p]
		caves.extra_ceilings[p]=next.ceilings[p]
	caves.routes[SKELETAL_CITY.INDEX]=next.route
	var entry: Vector3i = next.route.front()
	caves.entrances[SKELETAL_CITY.INDEX]=Vector3(entry)+Vector3(0.5,0,0.5)
	return true

func margin_at(x: float, z: float) -> float:
	var key := Vector2i(floori(x), floori(z))
	if _margin_cache.has(key):
		return float(_margin_cache[key])
	var warp_x: float = _fuzz.get_noise_2d(x + 331.0, z - 811.0) * 3.5
	var warp_z: float = _fuzz.get_noise_2d(x - 917.0, z + 177.0) * 3.5
	var best: float = -100000.0
	for island in islands:
		var center: Vector2i = island["center"]
		var delta := Vector2(x + warp_x - float(center.x), z + warp_z - float(center.y))
		var coast: float = float(island["radius"]) - delta.length()
		best = maxf(best, coast)
	_margin_cache[key] = best
	return best

func is_land_at(x: float, z: float) -> bool:
	return margin_at(x, z) > 0.0

func height_at(x: int, z: int) -> int:
	var key := Vector2i(x, z)
	if _cove_apron.has(key): return int(_cove_apron[key])
	if skeletal_city!=null:
		var skeletal_height: int = skeletal_city.height_override(key)
		if skeletal_height!=-99999 and margin_at(x+0.5,z+0.5)>0.0: return skeletal_height
	if goblin_city!=null:
		var override: int = goblin_city.height_override(key)
		if override!=-99999: return override
	if _height_cache.has(key):
		return maxi(int(_height_cache[key]),int(_cave_cover.get(key,BEDROCK)))
	var margin: float = margin_at(float(x) + 0.5, float(z) + 0.5)
	if margin <= 0.0:
		# A submerged shelf gives each preview island a visible sea front.
		# It stays below sea level and does not change the dry land mask.
		if goblin_city!=null and margin>-9.0:
			return -4-floori(-margin/3.0)
		return BEDROCK
	var strength: float = 1.0
	for island in islands:
		var center: Vector2i = island["center"]
		if Vector2(x - center.x, z - center.y).length() < float(island["radius"]) + 5.0:
			strength = float(island["strength"])
			break
	# The continental mask rises out of the ocean, then fBm forms hills and
	# ridged noise grows rocky elevations progressively farther inland.
	var continent: float = minf(margin, 20.0) * 0.32
	var hills: float = _fractal.get_noise_2d(float(x), float(z)) * 3.0
	var ridge_sample: float = (_ridges.get_noise_2d(float(x), float(z)) + 1.0) * 0.5
	var ridge: float = ridge_sample * 12.0 * strength * smoothstep(7.0, 23.0, margin)
	# A swimmer's feet sit at sea level - 0.78. The previous minimum
	# coastal top was -2, creating a 1.6m wall at the first dry cell while
	# the player only auto-steps 1.05m. Start with a shallow submerged -3
	# landing tile, then ascend in regular one-block terraces.
	var raw_height: float = -2.0 + continent + hills + ridge
	var coastal_steps: float = floorf(maxf(margin, 0.0) / 2.4)
	var accessible_shore: float = -3.0 + coastal_steps
	var blend: float = smoothstep(11.0, 25.0, margin)
	var height: int = roundi(lerpf(accessible_shore, raw_height, blend))
	# Broad continuous town terraces, with a gradual one-block transition
	# into the surrounding hills. Road surfaces are actual terrain, not props.
	if expanded_preview:
		for index in [1,2]:
			var center: Vector2i = islands[index]["center"]
			var town := center+Vector2i(-12,-15)
			var distance := Vector2(key-town).length()
			var flat := 21.0 if index==2 else 15.0
			if margin>8.0 and distance<flat+12.0:
				var weight := (1.0-smoothstep(flat,flat+12.0,distance))*smoothstep(8.0,15.0,margin)
				height=roundi(lerpf(float(height),5.0,weight))
				break
	# A broad eastward access route guarantees a traversable walk from
	# the ocean to each island's small cave entrance and its inland slopes.
	# Pure coastline terraces remain in this corridor; no random ridge
	# can insert a two-block wall in the landing approach.
	for island in islands:
		var center: Vector2i = island["center"]
		var dx: float = float(x) + 0.5 - float(center.x)
		var dz: float = float(z) + 0.5 - float(center.y)
		# Preview west/south use their local graded mouth approach instead.
		if expanded_preview and islands.find(island) in [1,2]: continue
		if dx >= -3.0 and absf(dz) <= 2.5 and dx <= float(island["radius"]) + 5.0:
			height = roundi(accessible_shore)
			break
	_height_cache[key] = height
	return maxi(height,int(_cave_cover.get(key,BEDROCK)))

func is_solid(x: int, y: int, z: int) -> bool:
	if y < BEDROCK or ore_slots.has(Vector3i(x,y,z)):
		return false
	var cave_floor: int = caves.floor_at(x, z)
	if cave_floor != CAVES.INVALID_FLOOR:
		# Support even a rare low spot along the tunnel: never allow
		# Perlin valleys to remove the stairs beneath the player's feet.
		if y < cave_floor:
			return true
		if y < caves.ceiling_at(x, z, cave_floor):
			return false
	return y < height_at(x, z)

# Column form of is_solid for the two meshers. Foundations reach the cave
# floor even when the local surface is lower. Bits start at BEDROCK.
func solid_column(x: int, z: int) -> int:
	var floor_y: int = caves.floor_at(x,z)
	var top := maxi(height_at(x,z),floor_y)
	assert(top-BEDROCK < 63)
	var solid := (1 << (top-BEDROCK))-1
	if floor_y != CAVES.INVALID_FLOOR:
		var clearance: int = caves.ceiling_at(x, z, floor_y) - floor_y
		solid &= ~(((1 << clearance)-1) << (floor_y-BEDROCK))
	return solid & ~int(_ore_column_masks.get(Vector2i(x,z),0))

func settlement_index_at(x: float,z: float,padding: float = 0.0) -> int:
	for index in [1,2]:
		var c: Vector2i = islands[index]["center"]
		var extent: float = float(islands[index]["radius"]) if expanded_preview else 44.0
		if absf(x-c.x)<=extent+padding and absf(z-c.y)<=extent+padding: return index
	return -1

func near_settlement(x: float,z: float,padding: float = 0.0) -> bool:
	if goblin_city!=null and Vector2(x-GOBLIN_CITY.CENTER.x,z-GOBLIN_CITY.CENTER.y).length()<=GOBLIN_CITY.RADIUS+padding: return true
	return settlement_index_at(x,z,padding)>=0

func settlement_plan(index: int = 2):
	# One immutable regional blueprint per settlement, independent of visit order.
	# The Goblin Mineshaft island never pays settlement planning costs.
	if index not in [1,2]: return null
	if not _settlement_attempted.has(index):
		_settlement_attempted[index] = true
		var proposal := SETTLEMENT.new()
		if proposal.generate(self,index): _settlements[index] = proposal
	return _settlements.get(index)

func settlement_at(x: int,z: int) -> Dictionary:
	if goblin_city!=null and goblin_city.contains(Vector2i(x,z)):
		return goblin_city.building_at(Vector2i(x,z))
	var plan = settlement_plan(settlement_index_at(x,z))
	return plan.building_at(Vector2i(x,z)) if plan != null else {}

func biome_at(x: float,z: float) -> String:
	var best := -INF
	var result := "open_ocean"
	for island in islands:
		var c: Vector2i = island["center"]
		var m: float = float(island["radius"])-Vector2(x-c.x,z-c.y).length()
		if m>best:
			best=m
			result=str(island["biome"]) if m>=0.0 else (str(island["sea"]) if m>=-18.0 else "open_ocean")
	return result

func top_tile(x: int, z: int) -> int:
	if goblin_city!=null and goblin_city.roads.has(Vector2i(x,z)): return 6
	var index := settlement_index_at(x,z)
	if index>=0:
		var plan = settlement_plan(index)
		if plan != null:
			if plan.plaza.has(Vector2i(x,z)): return 6
			if plan.is_road(x,z): return 5
			if plan.field_tiles.has(Vector2i(x,z)): return 3
	var margin: float = margin_at(float(x) + 0.5, float(z) + 0.5)
	if margin < 2.0:
		return 17 # Wet sand
	if margin < 5.0:
		return 16 # Dry sand
	if height_at(x, z) > 11:
		return 4 # Bare mountain rock
	if goblin_city!=null and goblin_city.contains(Vector2i(x,z)): return 4 if height_at(x,z)>8 else 3
	if str(ProjectSettings.get_setting("application/config/build_channel",""))=="world-preview" or OS.get_environment("OUTPOST_TEST_GOBLIN_CITY")=="1":
		match biome_at(x+0.5,z+0.5):
			"rocky_highlands": return 7 if height_at(x,z)<7 else 4
			"temperate_woodland": return 2
			"warm_meadow": return 1
			"dwarven_mountain": return 4
	return 0 # Grass

func chunk_near_land(chunk_x: int, chunk_z: int, chunk_size: int) -> bool:
	var center := Vector2(float(chunk_x) + float(chunk_size) * 0.5,
		float(chunk_z) + float(chunk_size) * 0.5)
	for island in islands:
		var at: Vector2i = island["center"]
		if center.distance_to(Vector2(at.x, at.y)) <= float(island["radius"]) + float(chunk_size):
			return true
	return false

func near_island(point: Vector3, padding: float = 70.0) -> bool:
	for island in islands:
		var c: Vector2i = island["center"]
		if Vector2(point.x - c.x, point.z - c.y).length() < float(island["radius"]) + padding:
			return true
	return false

func map_cell_at(x: int, z: int) -> Dictionary:
	var height: int = height_at(x, z)
	var land: bool = height > BEDROCK and (goblin_city==null or is_land_at(x+0.5,z+0.5))
	return {"height": float(height) if land else SEA_LEVEL,
		"ground_height": float(height) if land or (goblin_city!=null and height>BEDROCK) else -5.0,
		"ground_tile": top_tile(x, z) if land else 4,
		"zone": "inland" if land else "water","biome":biome_at(x+0.5,z+0.5)}
