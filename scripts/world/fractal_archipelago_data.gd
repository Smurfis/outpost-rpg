extends RefCounted
## Oasis-inspired deterministic archipelago. Deliberately separate from the
## starter island so Outpost's existing terrain, camp and coastline stay intact.
const CAVES = preload("res://scripts/world/stepped_cave_tunnels.gd")
const SEA_LEVEL: float = -2.82
const BEDROCK: int = -7
const OCEAN_PLAY_HALF: int = 384
# Exploration islands lie across real swimmable water, beyond home +/-96.
var islands: Array[Dictionary] = [
	{"center": Vector2i(172, 26), "radius": 36.0, "strength": 0.7},
	{"center": Vector2i(-200, -58), "radius": 44.0, "strength": 1.15},
	{"center": Vector2i(18, 232), "radius": 46.0, "strength": 1.4},
]
var seed: int
var caves: RefCounted
var _fuzz: FastNoiseLite
var _fractal: FastNoiseLite
var _ridges: FastNoiseLite
var _height_cache: Dictionary = {}
var _margin_cache: Dictionary = {}

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
	caves = CAVES.new()
	caves.configure(self)

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
	if _height_cache.has(key):
		return int(_height_cache[key])
	var margin: float = margin_at(float(x) + 0.5, float(z) + 0.5)
	if margin <= 0.0:
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
	var height: int = maxi(-2, roundi(-2.0 + continent + hills + ridge))
	_height_cache[key] = height
	return height

func is_solid(x: int, y: int, z: int) -> bool:
	if y < BEDROCK or y >= height_at(x, z):
		return false
	var cave_floor: int = caves.floor_at(x, z)
	return cave_floor == CAVES.INVALID_FLOOR or y < cave_floor or y >= cave_floor + CAVES.CORRIDOR_HEIGHT

func top_tile(x: int, z: int) -> int:
	var margin: float = margin_at(float(x) + 0.5, float(z) + 0.5)
	if margin < 2.0:
		return 17 # Wet sand
	if margin < 5.0:
		return 16 # Dry sand
	if height_at(x, z) > 11:
		return 4 # Bare mountain rock
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
	var land: bool = height > BEDROCK
	return {"height": float(height) if land else SEA_LEVEL,
		"ground_height": float(height) if land else -5.0,
		"ground_tile": top_tile(x, z) if land else 4,
		"zone": "inland" if land else "water"}
