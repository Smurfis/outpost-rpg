extends RefCounted
## Fixed-size local region address; never turn global region coordinates into floats.
const SIZE := 88
const LOT := 8
const LOTS := 11
const DIRS: Array[Vector2i] = [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
var heights: PackedInt32Array = PackedInt32Array()
var road_lots: Dictionary = {}
var seed_value: int
var region_x: int
var region_z: int

func configure(world_seed: int, rx: int = 0, rz: int = 0) -> void:
	seed_value = world_seed
	region_x = rx
	region_z = rz
	var noise := FastNoiseLite.new()
	# Seed the bounded local noise field from exact decimal addresses.
	# A future regional border contract must share lattice samples across sites.
	var digest := ("%d:%d:%d:terrain:v1" % [world_seed,rx,rz]).sha256_buffer()
	var local_seed: int = int(digest[0]) | (int(digest[1]) << 8) | (int(digest[2]) << 16) | (int(digest[3]) << 24)
	noise.seed = local_seed - 4294967296 if local_seed > 2147483647 else local_seed
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	heights.resize(SIZE*SIZE)
	for z in range(SIZE):
		for x in range(SIZE):
			var slope: float = float(z)/18.0
			var natural: float = 4.0 + slope + noise.get_noise_2d(x,z)*5.0
			var distance: float = maxf(absf(x-44.0),absf(z-44.0))
			# Blend a central terrace into the hills, not the whole site.
			var blend: float = clampf((distance-11.0)/12.0,0.0,1.0)
			heights[z*SIZE+x] = roundi(lerpf(7.0,natural,blend))
	# Lower steep spikes until every cardinal edge is at most one block.
	# This deliberately favours walkability over cliff generation in the city lab.
	for pass_index in range(16):
		var changed := false
		for z in range(SIZE):
			for x in range(SIZE):
				var p := Vector2i(x,z)
				for d in DIRS:
					var q := p+d
					if q.x < 0 or q.y < 0 or q.x >= SIZE or q.y >= SIZE: continue
					var index := z*SIZE+x
					var limit := height_at(q)+1
					if heights[index] > limit:
						heights[index] = limit
						changed = true
		if not changed: break
	_plan_roads()

func height_at(p: Vector2i) -> int:
	return heights[p.y*SIZE+p.x]

func is_keep(p: Vector2i) -> bool:
	return p.x >= 4 and p.x <= 6 and p.y >= 4 and p.y <= 6

func _plan_roads() -> void:
	road_lots.clear()
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0,0,LOTS,LOTS)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for z in range(LOTS):
		for x in range(LOTS):
			var p := Vector2i(x,z)
			if is_keep(p):
				grid.set_point_solid(p,true)
				continue
			var lo := 999
			var hi := -999
			for dz in range(LOT):
				for dx in range(LOT):
					var h := height_at(p*LOT+Vector2i(dx,dz))
					lo = mini(lo,h)
					hi = maxi(hi,h)
			grid.set_point_weight_scale(p,1.0+float(hi-lo)*0.75)
	# Reserved ring joins all four keep gates; weighted A* adds approaches.
	for i in range(3,8):
		for p in [Vector2i(i,3),Vector2i(i,7),Vector2i(3,i),Vector2i(7,i)]:
			road_lots[p] = true
	var entrances: Array[Vector2i] = [Vector2i(5,0),Vector2i(5,10),Vector2i(0,5),Vector2i(10,5)]
	var targets: Array[Vector2i] = [Vector2i(5,3),Vector2i(5,7),Vector2i(3,5),Vector2i(7,5)]
	for i in range(entrances.size()):
		for p in grid.get_id_path(entrances[i],targets[i]):
			road_lots[p] = true

func road_mask(p: Vector2i) -> int:
	var mask := 0
	for i in range(DIRS.size()):
		if road_lots.has(p+DIRS[i]): mask |= 1 << i
	return mask
