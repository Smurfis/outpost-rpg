extends Node3D
## Feature-branch-only remote island streamer. Never mutates the original
## Outpost chunks or its coastline. The far-ocean horizon supplies the water.
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const SETTLEMENT_BUILDING = preload("res://scripts/world/default_settlement_building.gd")
const SETTLEMENT_SCENERY = preload("res://scripts/world/default_settlement_scenery.gd")
const REGIONAL_RESOURCE = preload("res://scripts/resource_node.gd")
const RESOURCE_PLACEMENT = preload("res://scripts/world/prop_placement.gd")
var settlement_nodes: Array[Node3D] = []
var regional_trees: Array[Node3D] = []
const CAVES = preload("res://scripts/world/stepped_cave_tunnels.gd")
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const PROPS = preload("res://scripts/voxel/voxel_props.gd")
const WORLD_OBJECT = preload("res://scripts/interaction/world_object.gd")
const MINE_SITE_ID := "fractal_goblin_mine_1"
const HERO_OUTLINE = preload("res://scripts/voxel/occluded_hero_outline.gdshader")
const CHUNK: int = 12
const BUILD_BUDGET: int = 2
const CAVE_OVERHEAD_BLOCK_RADIUS: int = 1 # Exactly 3x3 roof blocks, centred on the avatar.
const CAVE_HEAD_CLEARANCE: float = 1.25
const REVEAL_RADIUS: int = 16
const REVEAL_PATH_LIMIT: int = 18
const REVEAL_SIZE: int = REVEAL_RADIUS * 2 + 1
var terrain
var _loaded: Dictionary = {} # chunk origin -> meshes/collision/chest nodes
var _pending: Array[Vector2i] = []
var _center := Vector2i(99999, 99999)
var _roof_nodes: Array[MeshInstance3D] = []
var _cutaway_material: ShaderMaterial
var _cave_mode: bool = false
var _cutaway_focus: Vector3 = Vector3.ZERO
var _cutaway_eye: Vector3 = Vector3.ZERO
var _cutaway_radius: float = 1.5
var _outline_material: ShaderMaterial
var _outline_meshes: Array[MeshInstance3D] = []
var _outline_active: bool = false
var _reveal_origin := Vector2i.ZERO
var _reveal_cell := Vector2i(99999, 99999)
var _reveal_cells: Dictionary = {}
var _reveal_texture: ImageTexture
var _reveal_strength: float = 0.0

const SECTION = preload("res://scripts/world/island_section_mesh.gd")
const SKELETAL_SCENERY = preload("res://scripts/world/skeletal_city_scenery.gd")
const VILLAGE_WORK = preload("res://scripts/world/goblin_village_work.gd")
const VILLAGE_CHEST = preload("res://scripts/world/village_loot_chest.gd")
const GATHERER = preload("res://scripts/world/goblin_gatherer.gd")
var village_workers: Dictionary = {}
var village_chests: Dictionary = {}
var village_tick := 0.0
const REGIONAL_RIVAL = preload("res://scripts/world/regional_rival.gd")
const CITY_GUARD = preload("res://scripts/world/goblin_city_guard.gd")
const OCEAN_SHOAL = preload("res://scripts/world/ocean_fishing_shoal.gd")
var ocean_shoals: Dictionary = {}
var ocean_tick := 0.0
const CHAMBER = preload("res://scripts/world/chamber_visibility.gd")
const SECTION_PICK := 1 << 18
var section_active := false
var section_excluded: Array[RID] = []
var _regions: Array[Dictionary] = []
var _owners := {}
var _lights: Array[Vector3] = []
var _region := 0
var mine_pending := false
var mine_load_failed := false
var natural_population
var side_chamber
var mine
const MINE = preload("res://scripts/world/physical_mineshaft.gd")
const MINE_AUTO = preload("res://scripts/world/mine_auto_renewal.gd")
var mine_auto = MINE_AUTO.new()

func _add_region(cells: Dictionary, anchor: Vector2i) -> void:
	var index := _regions.size()
	var reveal := cells.duplicate()
	for c: Vector2i in cells:
		_owners[c] = index
		# Include the immediately adjoining walkable threshold in both views.
		if side_chamber != null or not terrain.caves.branches.is_empty():
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if terrain.caves.floors.has(c+d):
					reveal[c+d] = true
	_regions.append(reveal)
	_lights.append(Vector3(anchor.x-0.8,terrain.caves.floor_at(anchor.x,anchor.y)+2.6,anchor.y+1.5))

func _identify_regions(center: Vector2i) -> void:
	_identify_mine_regions(center)
	if mine != null:
		for index in range(1, mini(3,terrain.caves.routes.size())):
			_add_cache_cave_regions(terrain.caves.routes[index])
	var cave = terrain.caves.natural
	if cave != null:
		for region in cave.regions:
			_add_region(region.cells, region.anchor)
	if terrain.goblin_city!=null:
		for region in terrain.goblin_city.regions:
			_add_region(region.cells,region.anchor)
	if terrain.skeletal_city!=null:
		for region in terrain.skeletal_city.regions:
			_add_region(region.cells,region.anchor)

func _add_cache_cave_regions(route: Array) -> void:
	var end: Vector3i = route.back()
	var center := Vector2i(end.x, end.z)
	var room := {}
	for dx in range(-2,3):
		for dz in range(-2,3):
			var cell := center + Vector2i(dx,dz)
			if terrain.caves.floors.has(cell):
				room[cell] = true
	_add_region(room, center)
	var passage := {}
	for i in range(route.size()-1,-1,-1):
		var at: Vector3i = route[i]
		var width := 2 if terrain.expanded_preview and i<3 else 1 if terrain.expanded_preview and i<6 else 0
		for lane in range(-width,terrain.caves.CORRIDOR_WIDTH+width):
			var cell := Vector2i(at.x,at.z+lane)
			if terrain.caves.has_cave(cell.x,cell.y) and not _owners.has(cell):
				passage[cell] = true
		if passage.size() >= 18 or (i == 0 and not passage.is_empty()):
			_add_region(passage,Vector2i(at.x,at.z))
			passage = {}

func _identify_mine_regions(center: Vector2i) -> void:
	if mine != null:
		_add_region(terrain.caves.mine_end_room,center)
	else:
		_add_region(CHAMBER.identify(terrain.caves.floors,terrain.caves.floors,center,4).cells,center)
	if side_chamber != null:
		_add_region(side_chamber.room,side_chamber.center)
	elif terrain.caves.branches.is_empty():
		return
	for branch in terrain.caves.branches:
		_add_region(branch.room,branch.center)
		var cells: Array = branch.passage.keys()
		_add_region(branch.passage,cells[cells.size()/2])
	var passage := {}
	var route: Array = terrain.caves.routes[0]
	# Walk backwards from the end chamber. Limit the length of any visible
	# passage so a bend cannot open the whole mountainside.
	for i in range(route.size()-1,-1,-1):
		var at: Vector3i = route[i]
		for z in range(2):
			var c := Vector2i(at.x,at.z+z)
			if not _owners.has(c):
				passage[c] = true
			if side_chamber != null and c == side_chamber.junction:
				passage.merge(side_chamber.branch)
		if passage.size() >= 18 or i == 0:
			_add_region(passage,Vector2i(at.x,at.z))
			passage = {}

var _variants := {}
var _shown := {}
var _sector := -1
var section_builds := 0
var mask_usec := 0
var faces_usec := 0
var publish_usec := 0
var _chamber_light: OmniLight3D

func _restore_section() -> void:
	if _chamber_light != null:
		_chamber_light.hide()
	for key in _shown:
		for node in _loaded.get(key, []):
			if node.name.begins_with("IslandRock_") or node.name.begins_with("CaveCutaway_"):
				node.show()
		for replacement: Node3D in _shown[key]:
			replacement.get_child(0).collision_layer = 0
			replacement.hide()
	_shown.clear()
	section_excluded.clear()
	section_active = false
	_sector = -1

func _section_update(pos: Vector3, eye: Vector3) -> bool:
	var end: Vector3i = terrain.caves.routes[0].back()
	var center := Vector2i(end.x,end.z)
	var cell := Vector2i(floori(pos.x),floori(pos.z))
	var nearby := center
	if mine != null:
		for chest: Vector3 in terrain.caves.chests:
			var anchor := Vector2i(floori(chest.x),floori(chest.z))
			if cell.distance_squared_to(anchor) < cell.distance_squared_to(nearby):
				nearby = anchor
	if terrain.caves.natural != null and cell.distance_squared_to(terrain.caves.natural.mouth) < 64*64:
		nearby = terrain.caves.natural.mouth
	if terrain.goblin_city!=null and terrain.goblin_city.contains(cell):
		nearby=terrain.goblin_city.throne
	if terrain.skeletal_city!=null and terrain.skeletal_city.contains(cell):
		nearby=terrain.skeletal_city.heart
	if _regions.is_empty() and cell.distance_squared_to(nearby) < 64 * 64:
		_identify_regions(center)
	var next_region: int = _owners.get(cell,-1)
	var shaft_landing: bool = terrain.caves.natural != null and terrain.caves.natural.shaft.has(cell)
	var inside: bool = next_region >= 0 and absf(pos.y-terrain.caves.floor_at(cell.x,cell.y)) < 2.1 and (shaft_landing or pos.y < terrain.height_at(cell.x,cell.y)-1)
	var sector := posmod(roundi(atan2(eye.z,eye.x)*8/TAU),8)
	if not inside:
		if section_active:
			_restore_section()
		if cell.distance_squared_to(nearby) < 64 * 64:
			_prewarm(cell,sector)
		elif not _regions.is_empty() and cell.distance_squared_to(nearby) > 80 * 80:
			invalidate_section_geometry()
		return false
	var changed := sector != _sector or next_region != _region
	_region = next_region
	if changed:
		_restore_section()
		_sector = sector
	section_active = true
	if _chamber_light == null:
		_chamber_light = OmniLight3D.new()
		_chamber_light.position = Vector3(end.x-0.8,end.y+2.6,end.z+1.5)
		_chamber_light.light_color = Color("ffd8a3")
		_chamber_light.light_energy = 2.0
		_chamber_light.omni_range = 8.0
		add_child(_chamber_light)
	_chamber_light.position = _lights[_region]
	var skeletal: bool = terrain.skeletal_city!=null and terrain.skeletal_city.contains(cell)
	_chamber_light.light_color=Color("#9fcaff") if skeletal else Color("ffd8a3")
	_chamber_light.omni_range=13.0 if skeletal else 8.0
	_chamber_light.light_energy=3.0 if skeletal else 2.0
	_chamber_light.show()
	var variant := _variant(_region,sector)
	for key: Vector2i in variant.chunks:
		if _shown.has(key) or not _loaded.has(key):
			continue
		var replacements: Array[Node3D] = []
		for patch: Vector2i in variant.chunks[key]:
			if not variant.geometry.has(patch):
				_prepare_chunk(variant,patch,0)
			var replacement: MeshInstance3D = variant.geometry[patch].node
			replacement.get_child(0).collision_layer = SECTION_PICK
			replacement.show()
			replacements.append(replacement)
		_shown[key] = replacements
		for node in _loaded[key]:
			if node.name.begins_with("IslandRock_") or node.name.begins_with("CaveCutaway_"):
				node.hide()
			if node is StaticBody3D:
				section_excluded.append(node.get_rid())
	if not changed:
		_prewarm(cell,sector)
	return true

# World occupancy is immutable for the lifetime of this streamed island.
# Masks, geometry and picking bodies are discarded together on invalidation.
var section_cache_bytes := 0
var _prewarm_complete := false

var _section_spans := {}

# One variant is pinned for display. Spare slots retain recent views for
# reversals and re-entry. Limits apply to partial preparations as well.
const PATCH := CHUNK / 2 # Four independently reusable quarters per streamed chunk.
const MAX_VARIANTS := 18
const TARGET_GEOMETRY_BYTES := 12 * 1024 * 1024
var _shared_chunks := {}
# Retain a small second tier of completed visibility masks after evicting
# their expensive geometry. Both tiers are invalidated with terrain revision.
var _recent_masks := {}
const MAX_RECENT_MASKS := 32
var _face_pages := {}
var section_packet_hits := 0
var packet_cache_bytes := 0
const MAX_FACE_PAGES := 64
var section_reuses := 0
var section_evictions := 0
var section_peak_bytes := 0
var _clock := 0
var _portals := {}
var _plan: Array[Vector2i] = []
var _plan_cell := Vector2i.MAX
var _plan_sector := -1

func _variant(region: int, sector: int, deadline := 0) -> Dictionary:
	var id := Vector2i(region,sector)
	if not _variants.has(id):
		if _variants.size() >= MAX_VARIANTS:
			_evict_one()
		if _recent_masks.has(id):
			_variants[id] = _recent_masks[id]
			_recent_masks.erase(id)
		else:
			_variants[id] = {"hidden":{}, "chunks":{}, "geometry":{}, "jobs":{},
				"intervals":{}, "cells":_regions[region].keys(), "cursor":0,
				"columns":[], "projected":false, "ready":false, "used":0}
	var variant: Dictionary = _variants[id]
	_clock += 1
	variant.used = _clock
	if not variant.ready:
		var t := Time.get_ticks_usec()
		_advance_mask(variant,region,sector,deadline)
		mask_usec += Time.get_ticks_usec()-t
	return variant

func _advance_mask(v: Dictionary, region: int, sector: int, deadline: int) -> void:
	if not v.projected:
		var spans := _sector_spans(sector)
		while v.cursor < v.cells.size():
			var c: Vector2i = v.cells[v.cursor]
			var shift: int = terrain.caves.floor_at(c.x,c.y)-DATA.BEDROCK
			for offset: Vector2i in spans:
				var col := c+offset
				v.intervals[col] = int(v.intervals.get(col,0)) | (int(spans[offset]) << shift)
			v.cursor += 1
			if deadline and Time.get_ticks_usec() >= deadline:
				return
		v.columns = v.intervals.keys()
		v.cursor = 0
		v.projected = true
	while v.cursor < v.columns.size():
		var col: Vector2i = v.columns[v.cursor]
		v.cursor += 1
		var cap: int = terrain.height_at(col.x,col.y)
		var bits: int = int(v.intervals[col]) & ((1 << (cap-DATA.BEDROCK))-1)
		if not bits:
			if deadline and Time.get_ticks_usec() >= deadline:
				return
			continue
		var low := DATA.BEDROCK
		if terrain.caves.natural != null and terrain.caves.natural.floors.has(col):
			low = terrain.caves.natural.floors[col]
		if not terrain.caves.has_cave(col.x,col.y):
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var n: Vector2i = col+d
				if _regions[region].has(n):
					low = maxi(low,terrain.caves.floor_at(n.x,n.y)+1)
		var cut: int = bits & terrain.solid_column(col.x,col.y) & (-1 << (low-DATA.BEDROCK))
		if cut:
			v.hidden[col] = cut
			for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var n: Vector2i = col+offset
				var key := _cell_at(Vector3(n.x,0,n.y))
				if not v.chunks.has(key):
					v.chunks[key] = [key,key+Vector2i(PATCH,0),key+Vector2i(0,PATCH),key+Vector2i(PATCH,PATCH)]
		if deadline and Time.get_ticks_usec() >= deadline:
			return
	v.intervals.clear()
	v.columns.clear()
	v.cells.clear()
	v.ready = true

func _evict_one() -> bool:
	var victim := Vector2i(-1,-1)
	var lowest := INF
	for id: Vector2i in _variants:
		if (section_active and id == Vector2i(_region,_sector)) or _plan.has(id):
			continue
		var rank: float = _variants[id].used
		if id.x == _region:
			rank += 1.0e12
		elif _portals.get(_region,{}).has(id.x):
			rank += 1.0e9
		if rank < lowest:
			victim = id
			lowest = rank
	if victim.x < 0:
		return false
	_drop_variant(victim,true)
	section_evictions += 1
	return true

func _drop_variant(id: Vector2i, keep_mask := false) -> void:
	for key: Vector2i in _variants[id].geometry:
		var data: Dictionary = _variants[id].geometry[key]
		data.refs -= 1
		if data.refs == 0:
			_shared_chunks[key].erase(data.signature)
			if _shared_chunks[key].is_empty():
				_shared_chunks.erase(key)
			section_cache_bytes -= int(data.get("vertices",0))*52
			data.node.queue_free()
	if keep_mask and _variants[id].ready:
		if _recent_masks.size() >= MAX_RECENT_MASKS:
			_recent_masks.erase(_recent_masks.keys()[0])
		_variants[id].geometry.clear()
		_variants[id].jobs.clear()
		_recent_masks[id] = _variants[id]
	_variants.erase(id)

# A chunk only depends on its own removed solids and the one-column
# neighbour apron. Compare the complete bit pattern before sharing nodes.
func _signature(key: Vector2i, mask: Dictionary) -> PackedInt64Array:
	var sig := PackedInt64Array()
	for x in range(key.x-1,key.x+PATCH+1):
		for z in range(key.y-1,key.y+PATCH+1):
			sig.append(mask.get(Vector2i(x,z),0))
	return sig

func _sector_spans(sector: int) -> Dictionary:
	if _section_spans.has(sector):
		return _section_spans[sector]
	var spans := {}
	var run_per_rise := 26.25/20.0
	for half_step in range(64):
		var distance := half_step * 0.5
		var rise := floori(distance/run_per_rise)
		var samples := maxi(1,ceili(distance*TAU/8*2))
		for i in range(samples+1):
			var heading := (sector - 0.5 + float(i)/samples)*TAU/8
			var offset := Vector2i((Vector2.from_angle(heading)*distance).round())
			# Keep the full interior at the canonical angle. Between
			# cache directions reserve only the avatar's sight corridor,
			# so a whole additional room is never projected at each yaw.
			var central := absf(float(i)/samples-0.5)*distance < 1.0
			var band := 0b1111 if central else 0b0110
			spans[offset] = int(spans.get(offset,0)) | (band << rise)
	_section_spans[sector] = spans
	return spans

func _prepare_chunk(variant: Dictionary,key: Vector2i,deadline: int) -> void:
	if not variant.jobs.has(key):
		var signature := _signature(key,variant.hidden)
		var data: Dictionary = _shared_chunks.get(key,{}).get(signature,{})
		if not data.is_empty():
			data.refs += 1
			variant.geometry[key] = data
			section_reuses += 1
			return
		var job := SECTION.new()
		job.signature = signature
		job.begin(terrain,key,PATCH,variant.hidden)
		variant.jobs[key] = job
	var job = variant.jobs[key]
	var t := Time.get_ticks_usec()
	job.reusable = _face_page(key)
	var ready: bool = job.advance(deadline)
	faces_usec += Time.get_ticks_usec()-t
	section_packet_hits += int(job.packet_hits)
	job.packet_hits = 0
	# Pages are a separate bounded CPU cache. A paused job always looks up
	# the current page before resuming.
	packet_cache_bytes += int(job.packet_bytes_delta)
	job.reusable.bytes += int(job.packet_bytes_delta)
	job.packet_bytes_delta = 0
	job.reusable = {}
	if not ready:
		return
	# Start the indivisible GPU upload and collision cook with a fresh budget.
	if deadline and Time.get_ticks_usec() + 1100 >= deadline:
		return
	# Another view can finish the same patch while this job is paused.
	var previous: Dictionary = _shared_chunks.get(key,{}).get(job.signature,{})
	if not previous.is_empty():
		previous.refs += 1
		variant.geometry[key] = previous
		variant.jobs.erase(key)
		section_reuses += 1
		return
	t = Time.get_ticks_usec()
	var result: Dictionary = job.finish()
	if result.mesh != null:
		# Position, normal, UV, UV2 plus pick triangle positions, excluding
		# driver compression, BVH, allocation overhead and transient jobs.
		section_cache_bytes += int(result.vertices) * 52
	section_peak_bytes = maxi(section_peak_bytes,section_cache_bytes + packet_cache_bytes)
	result.refs = 1
	result.signature = job.signature
	if not _shared_chunks.has(key):
		_shared_chunks[key] = {}
	_shared_chunks[key][result.signature] = result
	_install_cached_node(result)
	variant.geometry[key] = result
	variant.jobs.erase(key)
	section_builds += 1
	while section_cache_bytes > TARGET_GEOMETRY_BYTES and _evict_one():
		pass # A large current room always wins over the soft byte target.
	publish_usec += Time.get_ticks_usec()-t

func _face_page(key: Vector2i) -> Dictionary:
	if not _face_pages.has(key):
		if _face_pages.size() >= MAX_FACE_PAGES:
			var victim: Vector2i = _face_pages.keys()[0]
			for other: Vector2i in _face_pages:
				if _face_pages[other].used < _face_pages[victim].used:
					victim = other
			packet_cache_bytes -= int(_face_pages[victim].bytes)
			_face_pages.erase(victim)
		_face_pages[key] = {"solid":{},"packets":{},"bytes":0,"used":0}
	_face_pages[key].used = _clock
	return _face_pages[key]

func _install_cached_node(data: Dictionary) -> void:
	var replacement := MeshInstance3D.new()
	replacement.mesh = data.mesh
	replacement.material_override = GREEDY.material()
	replacement.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pick := StaticBody3D.new()
	pick.collision_layer = 0
	pick.collision_mask = 0
	if data.has("shape"):
		var slot := CollisionShape3D.new()
		slot.shape = data.shape
		pick.add_child(slot)
	replacement.add_child(pick)
	replacement.hide()
	add_child(replacement)
	data.node = replacement

func _make_plan(cell: Vector2i, sector: int) -> void:
	_plan.clear()
	_plan_cell = cell
	_plan_sector = sector
	_prewarm_complete = false
	var region: int = _owners.get(cell,-1)
	if region < 0:
		# Outside: use the nearest entrance/region anchor on approach.
		var best := INF
		for i in _lights.size():
			var dist := Vector2(_lights[i].x,_lights[i].z).distance_squared_to(Vector2(cell))
			if dist < best:
				best = dist
				region = i
	if region < 0:
		return
	_plan.append(Vector2i(region,sector))
	if not _portals.has(region):
		var links := {}
		for c: Vector2i in _regions[region]:
			var other: int = _owners.get(c,region)
			if other != region:
				if not links.has(other):
					links[other] = []
				links[other].append(c)
		_portals[region] = links
	var nearby: Array[Vector2i] = []
	for other: int in _portals[region]:
		var distance := 65
		for portal: Vector2i in _portals[region][other]:
			distance = mini(distance,cell.distance_squared_to(portal))
		if distance <= 64:
			nearby.append(Vector2i(distance,other))
	nearby.sort()
	# At most two upcoming thresholds, ordered by walking proximity.
	for link in nearby.slice(0,2):
		_plan.append(Vector2i(link.y,sector))
	for delta in [1,-1]:
		_plan.append(Vector2i(region,posmod(sector+delta,8)))
		if not nearby.is_empty():
			_plan.append(Vector2i(nearby[0].y,posmod(sector+delta,8)))

func _prewarm(cell: Vector2i, sector: int) -> void:
	if cell != _plan_cell or sector != _plan_sector:
		_make_plan(cell,sector)
	if _prewarm_complete:
		return
	var deadline := Time.get_ticks_usec()+3750
	for id in _plan:
		var variant := _variant(id.x,id.y,deadline)
		if not variant.ready or Time.get_ticks_usec() >= deadline:
			return
		for key: Vector2i in variant.chunks:
			for patch: Vector2i in variant.chunks[key]:
				if not variant.geometry.has(patch):
					_prepare_chunk(variant,patch,deadline)
					if Time.get_ticks_usec() >= deadline or not variant.geometry.has(patch):
						return
	_prewarm_complete = true

func setup(world_seed: int, physical_mineshaft := true) -> void:
	if terrain != null:
		_clear_stream()
		if _chamber_light != null:
			_chamber_light.queue_free()
			_chamber_light = null
	natural_population = null
	mine_pending = false
	mine_load_failed = false
	terrain = DATA.new(world_seed)
	mine = null
	side_chamber = null
	if OS.get_environment("OUTPOST_TEST_SIDE_CHAMBER") == "1":
		var addition = preload("res://scripts/world/test_side_chamber.gd").new()
		if addition.install(terrain):
			side_chamber = addition
		else:
			push_warning("No roofed site for the test side chamber in this seed")
	elif physical_mineshaft and OS.get_environment("OUTPOST_TEST_PROCEDURAL_CAVE") != "1":
		mine_pending = true
		var game = get_parent().get_parent() if get_parent() != null else null
		if game == null or game.get("building") != null:
			finish_mine_loading(game)
	name = "FractalArchipelago"
	# Never mutate GREEDY's global material: other Fields chunks must not cut
	# holes when the remote island camera enters a tunnel or a deep ravine.
	_cutaway_material = GREEDY.material().duplicate() as ShaderMaterial
	_cutaway_material.set_shader_parameter("terrain_gradient_enabled",true)
	_cutaway_material.set_shader_parameter("island_cutaway_enabled", false)
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = HERO_OUTLINE

func finish_mine_loading(game) -> void:
	if not mine_pending:
		return
	mine_pending = false
	var candidate = MINE.new()
	var manager = game.get_node_or_null("Dungeons") if game != null else null
	if game != null and (manager == null or not manager.world_site_save_valid):
		mine_load_failed = true
		push_error("Physical mine unavailable: invalid dungeon save")
		return
	var id := "fractal_physical_goblin_mine_1_%d" % terrain.seed
	var site: Dictionary = manager.world_sites.sites.get(id, {}) if manager != null else {}
	if int(site.get("cycle", 0)) > 0:
		if not game.player_save_valid_for_mine:
			mine_load_failed = true
			push_error("Renewed mine unavailable: player construction save is missing or invalid")
			return
		var original = DATA.new(terrain.seed)
		var proposal = DATA.new(terrain.seed)
		if not original.caves.carve_mine(original, MINE.REGISTRY.cycle_seed(terrain.seed, id, 0, "initial")) or not proposal.caves.carve_mine(proposal, int(site.layout_seed)):
			mine_load_failed = true
			push_error("Cannot reconstruct the saved physical mine")
			return
		# Other registered sites may own terrain outside their visible entrance.
		var changed_chunks := {}
		for column: Vector2i in original.caves.floors:
			if original.caves.floors.get(column) != proposal.caves.floors.get(column):
				var key := _cell_at(Vector3(column.x, 0, column.y))
				changed_chunks["island_%d_%d" % [key.x, key.y]] = true
		for column: Vector2i in proposal.caves.floors:
			if original.caves.floors.get(column) != proposal.caves.floors.get(column):
				var key := _cell_at(Vector3(column.x, 0, column.y))
				changed_chunks["island_%d_%d" % [key.x, key.y]] = true
		for other_id in manager.world_sites.sites:
			if other_id == id:
				continue
			for chunk in manager.world_sites.sites[other_id].chunks:
				if changed_chunks.has(chunk):
					mine_load_failed = true
					push_error("Renewed mine overlaps another persistent site's chunks")
					return
		for block: Vector3i in game.building.blocks:
			var column := Vector2i(block.x, block.z)
			if original.caves.floors.get(column) != proposal.caves.floors.get(column):
				mine_load_failed = true
				push_error("Renewed mine conflicts with a saved player construction")
				return
	if site.get("cycle", 0) == 1 and site.get("state") == "ready_for_renewal" and site.get("reopened", false) and not site.has("cycle_history"):
		var previous := site.duplicate(true)
		site.cycle_history = {"0": site.room_state.duplicate(true)}
		site.room_state = {}
		site.boss_defeated = false
		site.state = "active"
		if not manager._save_clears():
			manager.world_sites.sites[id] = previous
			mine_load_failed = true
			push_error("Cannot migrate renewed mine progression")
			return
	if not candidate.configure(self, site):
		mine_load_failed = true
		push_error("Cannot reconstruct physical mine from saved site")
		return
	candidate.manager = manager
	mine = candidate

func run_mine_command(action: String) -> void:
	await get_tree().process_frame
	while Engine.is_in_physics_frame():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	if mine == null:
		return
	var result := "unavailable"
	match action:
		"report":
			if mine.trigger_reoccupation_for_test():
				result = "sealed"
		"ready":
			if mine.advance_for_test("ready_for_renewal"):
				result = "ready for renewal"
		"renew":
			result = advance_mine_renewal_for_test()
	get_parent().get_parent().chat.add_line("Mine",result)

func advance_mine_renewal_for_test() -> String:
	return preload("res://scripts/world/mine_renewal.gd").advance(self, get_parent().get_parent())

func install_natural(game) -> void:
	var protected := {}
	for block: Vector3i in game.building.blocks:
		protected[Vector2i(block.x, block.z)] = true
	var manager = game.get_node("Dungeons")
	if not manager.world_site_save_valid:
		return
	for site in manager.world_sites.sites.values():
		var gate := Vector2i(site.entrance[0],site.entrance[2])
		for x in range(-4,5):
			for z in range(-4,5):
				protected[gate + Vector2i(x,z)] = true
	if terrain.caves.install_natural(terrain, protected, game.prop_placement):
		natural_population = preload("res://scripts/world/natural_cave_population.gd").new()
		natural_population.configure(self)

var profile_stream := OS.get_environment("OUTPOST_PROFILE_MINE") == "1"
var stream_usec := 0

func _process(delta: float) -> void:
	if terrain == null or mine_pending or mine_load_failed:
		return
	var game: Node = get_parent().get_parent()
	if game == null:
		return
	var hero: Node3D = game.get("hero")
	if hero == null:
		return
	# The scheduler must keep gameplay time while the player is off-island.
	# It only checks the mine once per second and uses the existing journal.
	mine_auto.tick(self, game, delta)
	var position: Vector3 = hero.global_position
	if terrain.goblin_city!=null:
		village_tick+=delta
		if village_tick>=0.5:
			_update_village(game,village_tick)
			village_tick=0.0
		ocean_tick+=delta
		if ocean_tick>=0.5:
			ocean_tick=0.0
			_update_ocean_shoals(game,position)
	if not terrain.near_island(position):
		if section_active:
			_restore_section()
		if _cutaway_material != null:
			_cutaway_material.set_shader_parameter("island_cutaway_enabled", false)
		_set_hero_outline(hero, false)
		if not _loaded.is_empty():
			_clear_stream()
		return
	var started := Time.get_ticks_usec() if profile_stream else 0
	_queue_near(position)
	_build_pending()
	if profile_stream:
		stream_usec += Time.get_ticks_usec()-started
	if natural_population != null:
		natural_population.try_spawn(self,game)
	if mine != null:
		mine.visit(position)
	_update_cutaway(game, position, delta)
	_update_hero_visibility(game, hero)
	if game.camera != null:
		update_settlement_views(position,game.camera)

func update_settlement_views(position: Vector3,camera: Camera3D) -> void:
	var revealed: Dictionary = {}
	for building in settlement_nodes:
		if is_instance_valid(building) and building.contains_hero(position):
			revealed = building.spec
			break
	var toward := camera.global_transform.basis.z.normalized()
	var player_cell := Vector2i(floori(position.x),floori(position.z))
	var cave_floor: int = terrain.caves.floor_at(player_cell.x,player_cell.y)
	var below_city: bool = cave_floor!=CAVES.INVALID_FLOOR and absf(position.y-cave_floor)<2.1 and position.y<terrain.height_at(player_cell.x,player_cell.y)-1.0
	for building in settlement_nodes:
		if not is_instance_valid(building): continue
		var rect: Rect2i = building.spec["rect"]
		var floor_y: int = building.spec["floor"]
		building.visible=not (below_city and floor_y>position.y+1.0 and Vector2(rect.get_center()-player_cell).length()<80.0)
		building.update_view(position,camera.global_position,revealed,toward)
		if not building.visible:
			for part in building.parts.values(): part["body"].set_meta("building_cutaway_hidden",true)
		else:
			for part in building.parts.values(): part["body"].set_meta("building_cutaway_hidden",not part["mesh"].visible)
	for tree in regional_trees:
		if is_instance_valid(tree): tree.update_tree_cutaway(revealed,toward)

func _is_below_terrain(position: Vector3) -> bool:
	# Actual tunnel cells are definitive. A steep drop with high walls on
	# several sides is also treated as a crevice, even outside carved caves.
	var xi: int = floori(position.x)
	var zi: int = floori(position.z)
	var floor_y: int = terrain.caves.floor_at(xi, zi)
	if floor_y != CAVES.INVALID_FLOOR and position.y < float(terrain.height_at(xi, zi)) - 0.8:
		return true
	var elevated: int = 0
	for offset in [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(0, 3),
			Vector2i(-3, -3), Vector2i(3, 3)]:
		if float(terrain.height_at(xi + offset.x, zi + offset.y)) >= position.y + 3.5:
			elevated += 1
	return elevated >= 3

func _update_cutaway(game: Node, position: Vector3, delta: float = 1.0) -> void:
	if _cutaway_material == null:
		return
	var view: Camera3D = game.get("camera") as Camera3D
	if view == null:
		_cutaway_material.set_shader_parameter("island_cutaway_enabled", false)
		return
	if mine != null and mine.access.closed and mine.access.footprint.has(Vector2i(floori(position.x), floori(position.z))):
		if section_active:
			_restore_section()
		_cave_mode = false
		_reveal_strength = 0.0
		_cutaway_material.set_shader_parameter("island_cutaway_enabled", false)
		return
	_cave_mode = _is_below_terrain(position)
	if _section_update(position,view.global_basis.z):
		_cutaway_material.set_shader_parameter("island_cutaway_enabled",false)
		_reveal_strength = 0.0
		return
	var xi: int = floori(position.x)
	var zi: int = floori(position.z)
	var cave_floor: int = terrain.caves.floor_at(xi, zi)
	# Outdoor crevices use the highlighted avatar, not missing mountains.
	var inside_roofed_cave: bool = cave_floor != CAVES.INVALID_FLOOR and _cave_mode
	if inside_roofed_cave:
		_update_reveal_mask(Vector2i(xi, zi))
	_reveal_strength = move_toward(_reveal_strength, 1.0 if inside_roofed_cave else 0.0, maxf(delta, 0.0) * 4.0)
	_cutaway_focus = position + Vector3.UP * 0.95
	_cutaway_eye = view.global_position
	_cutaway_radius = 1.5 # Limit the hole to the 3x3 overhead voxel footprint.
	_cutaway_material.set_shader_parameter("island_cutaway_enabled", _reveal_strength > 0.0)
	_cutaway_material.set_shader_parameter("island_cave_mode", _reveal_strength > 0.0)
	_cutaway_material.set_shader_parameter("cave_reveal", _reveal_strength)
	_cutaway_material.set_shader_parameter("island_cutaway_focus", _cutaway_focus)
	_cutaway_material.set_shader_parameter("island_cutaway_eye", _cutaway_eye)
	_cutaway_material.set_shader_parameter("island_cutaway_radius", _cutaway_radius)
	for roof in _roof_nodes:
		if is_instance_valid(roof):
			roof.visible = true

func _update_reveal_mask(center: Vector2i) -> void:
	if center == _reveal_cell:
		return
	_reveal_cell = center
	_reveal_origin = center - Vector2i(REVEAL_RADIUS, REVEAL_RADIUS)
	_reveal_cells.clear()
	var pending: Array[Vector2i] = [center]
	var distances := {center: 0}
	var cursor := 0
	while cursor < pending.size():
		var cell: Vector2i = pending[cursor]
		cursor += 1
		var floor_y: int = terrain.caves.floor_at(cell.x, cell.y)
		if floor_y == CAVES.INVALID_FLOOR:
			continue
		_reveal_cells[cell] = true
		var distance: int = distances[cell]
		if distance >= REVEAL_PATH_LIMIT:
			continue
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if distances.has(next) or absi(next.x - center.x) > REVEAL_RADIUS or absi(next.y - center.y) > REVEAL_RADIUS:
				continue
			var next_floor: int = terrain.caves.floor_at(next.x, next.y)
			if next_floor == CAVES.INVALID_FLOOR or absi(next_floor - floor_y) > 1:
				continue
			distances[next] = distance + 1
			pending.append(next)
	var mask := Image.create(REVEAL_SIZE, REVEAL_SIZE, false, Image.FORMAT_R8)
	mask.fill(Color.BLACK)
	for cell in _reveal_cells:
		var pixel: Vector2i = cell - _reveal_origin
		mask.set_pixel(pixel.x, pixel.y, Color.WHITE)
	if _reveal_texture == null:
		_reveal_texture = ImageTexture.create_from_image(mask)
	else:
		_reveal_texture.update(mask)
	_cutaway_material.set_shader_parameter("cave_visibility_mask", _reveal_texture)
	_cutaway_material.set_shader_parameter("cave_mask_origin", Vector2(_reveal_origin))
	_cutaway_material.set_shader_parameter("cave_mask_size", float(REVEAL_SIZE))

func _is_cut_overhead_block(at: Vector3, normal: Vector3) -> bool:
	# Keep the pick-through rule identical to the voxel-snapped roof shader:
	# one block to either side of the player's current X/Z voxel, and only
	# horizontal faces higher than the hero's head. Never disable collision.
	if absf(normal.y) <= 0.88 or at.y <= _cutaway_focus.y + CAVE_HEAD_CLEARANCE:
		return false
	var block := Vector2i(floori(at.x - 0.001), floori(at.z - 0.001))
	return _reveal_cells.has(block)


func cutaway_hides_hit(hit: Dictionary) -> bool:
	# Ray picking passes ONLY the exact overhead roof cells hidden by the
	# shader. No body-wide exclusions; sidewalls and terrain floors remain.
	if _cutaway_material == null or _cutaway_material.get_shader_parameter("island_cutaway_enabled") != true:
		return false
	# During the dither transition some pixels are still opaque. Treat the
	# whole surface as solid for picking until the visual cut is complete.
	if _reveal_strength < 0.999:
		return false
	var collider: Variant = hit.get("collider")
	if not collider is CollisionObject3D or not collider.has_meta("island_roof_shape_index"):
		return false
	var at: Vector3 = hit.get("position", Vector3.ZERO)
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if int(hit.get("shape", -1)) == int(collider.get_meta("island_roof_shape_index")):
		return _is_cut_overhead_block(at, normal)
	if int(hit.get("shape", -1)) != 0:
		return false
	if absf(normal.y) > 0.88 or at.y <= _cutaway_focus.y + 0.25:
		return false
	var wall_normal := Vector2(normal.x, normal.z).normalized()
	var camera_dir := Vector2(_cutaway_eye.x - _cutaway_focus.x, _cutaway_eye.z - _cutaway_focus.z).normalized()
	var inner := Vector2i(floori(at.x + wall_normal.x * 0.12), floori(at.z + wall_normal.y * 0.12))
	return wall_normal.dot(camera_dir) > 0.25 and _reveal_cells.has(inner)

func _set_hero_outline(hero: Node3D, enabled: bool) -> void:
	if not hero is CollisionObject3D or _outline_material == null:
		return
	if _outline_meshes.is_empty():
		var rig: Variant = hero.get("visual")
		if not rig is Node3D:
			return
		for child in rig.find_children("*", "MeshInstance3D", true, false):
			if child is MeshInstance3D:
				_outline_meshes.append(child)
	if _outline_active == enabled:
		return
	_outline_active = enabled
	for mesh in _outline_meshes:
		if not is_instance_valid(mesh):
			continue
		if enabled:
			if mesh.material_overlay == null:
				mesh.material_overlay = _outline_material
		elif mesh.material_overlay == _outline_material:
			mesh.material_overlay = null


func _update_hero_visibility(game: Node, hero: Node3D) -> void:
	if section_active:
		_set_hero_outline(hero,false)
		return
	if not hero is CollisionObject3D:
		return
	var view: Camera3D = game.get("camera") as Camera3D
	if view == null:
		_set_hero_outline(hero, false)
		return
	var focus: Vector3 = hero.global_position + Vector3.UP * 0.98
	var origin: Vector3 = view.global_position
	var direction: Vector3 = (focus - origin).normalized()
	var end: Vector3 = focus
	var covered: bool = false
	# A clipped ceiling still has collision. Skip only cutaway roof hits,
	# then highlight the avatar if a genuinely visible wall occludes it.
	for attempt in range(18):
		var query := PhysicsRayQueryParameters3D.create(origin, end, 1, [hero.get_rid()])
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		if cutaway_hides_hit(hit) and hit.position.distance_to(end) > 1.5:
			origin = hit.position + direction * 0.11
			if origin.distance_to(end) < 0.3:
				break
			continue
		var collider: Variant = hit.get("collider")
		covered = collider is Node and str(collider.name).begins_with("IslandCollision_") and hit.position.distance_to(focus) > 1.15
		break
	_set_hero_outline(hero, covered)


func is_land_at(x: float, z: float) -> bool:
	return terrain != null and terrain.is_land_at(x, z)

func map_cell_at(x: int, z: int) -> Dictionary:
	return terrain.map_cell_at(x, z) if terrain != null else {}

func height_at(x: int, z: int) -> float:
	return float(terrain.height_at(x, z)) if terrain != null else -5.0

func loaded_chunk_count() -> int:
	return _loaded.size()

func _active_radius() -> int:
	return 3 if OS.has_feature("mobile") else 4

func _cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / float(CHUNK)) * CHUNK,
		floori(point.z / float(CHUNK)) * CHUNK)

func _queue_near(point: Vector3) -> void:
	if mine_pending or mine_load_failed:
		return
	var center: Vector2i = _cell_at(point)
	if center == _center:
		return
	_center = center
	var wanted: Dictionary = {}
	var candidates: Array[Vector2i] = []
	for dx in range(-_active_radius(), _active_radius() + 1):
		for dz in range(-_active_radius(), _active_radius() + 1):
			var cell: Vector2i = center + Vector2i(dx, dz) * CHUNK
			if not terrain.chunk_near_land(cell.x, cell.y, CHUNK):
				continue
			wanted[cell] = true
			if not _loaded.has(cell):
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	_pending = candidates
	for key in _loaded.keys():
		if not wanted.has(key):
			_unload(key)

func _build_pending() -> void:
	for _i in range(mini(BUILD_BUDGET, _pending.size())):
		var key: Vector2i = _pending.pop_front()
		if not _loaded.has(key):
			_build_chunk(key)

func invalidate_section_geometry() -> void:
	if section_active:
		_restore_section()
	_prewarm_complete = false
	for id: Vector2i in _variants.keys():
		_drop_variant(id)
	_plan.clear()
	_plan_cell = Vector2i.MAX
	_portals.clear()
	_face_pages.clear()
	_recent_masks.clear()
	packet_cache_bytes = 0
	_regions.clear()
	_owners.clear()
	_lights.clear()
	_region = 0

func _clear_stream() -> void:
	for worker in village_workers.values():
		if is_instance_valid(worker): worker.get_parent().queue_free()
	village_workers.clear()
	village_chests.clear()
	invalidate_section_geometry()
	_pending.clear()
	for key in _loaded.keys():
		_unload(key)
	_center = Vector2i(99999, 99999)

func _unload(key: Vector2i) -> void:
	if _shown.has(key):
		_restore_section()
	if terrain != null and not terrain.caves.entrances.is_empty() and _cell_at(terrain.caves.entrances[0]) == key:
		var game := get_parent().get_parent()
		var manager := game.get_node_or_null("Dungeons") if game != null else null
		if manager != null and manager.has_method("unregister_world_site"):
			manager.unregister_world_site(MINE_SITE_ID)
	var members: Array = _loaded.get(key, [])
	for node in members:
		if node != null and is_instance_valid(node):
			if node is MeshInstance3D:
				_roof_nodes.erase(node)
			if node in settlement_nodes: settlement_nodes.erase(node)
			if node in regional_trees: regional_trees.erase(node)
			node.queue_free()
	_loaded.erase(key)

func _emit_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tile: int, axes: String) -> void:
	GREEDY.tiled_quad(st, a, b, c, d, tile, axes)

func _build_chunk(key: Vector2i) -> void:
	_install_chunk(key, _build_chunk_geometry(key, terrain))

func _build_chunk_geometry(key: Vector2i, source) -> Array:
	# Cull invisible interior voxels. The same world-coordinate occupancy
	# sample is used on chunk boundaries, so seams cannot expose rock faces.
	var surface := SurfaceTool.new()
	var roof := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var surface_faces: int = 0
	var roof_faces: int = 0
	# Each column's occupancy serves all six neighbour queries. Include the
	# apron so chunk boundaries use exactly the same source voxels.
	var stride := CHUNK+2
	var columns := PackedInt64Array()
	for dx in range(-1,CHUNK+1):
		for dz in range(-1,CHUNK+1):
			columns.append(source.solid_column(key.x+dx,key.y+dz))
	for x in range(key.x, key.x + CHUNK):
		for z in range(key.y, key.y + CHUNK):
			var top: int = source.height_at(x, z)
			var cave_here: bool = source.caves.has_cave(x, z)
			if cave_here:
				top = maxi(top, source.caves.floor_at(x, z)) # Include guaranteed stone step foundations.
			if top <= DATA.BEDROCK:
				continue
			var index := (x-key.x+1)*stride+z-key.y+1
			var solid := columns[index]
			var east := solid & ~columns[index+stride]
			var west := solid & ~columns[index-stride]
			var south := solid & ~columns[index+1]
			var north := solid & ~columns[index-1]
			var up := solid & ~(solid >> 1)
			var down := solid & ~(solid << 1)
			var exposed := east | west | south | north | up | down
			for y in range(DATA.BEDROCK, top):
				var bit := 1 << (y-DATA.BEDROCK)
				if not (exposed & bit):
					continue
				var xf: float = float(x)
				var yf: float = float(y)
				var zf: float = float(z)
				var tile: int = source.top_tile(x, z) if y == top - 1 else 4
				if up & bit:
					if source.skeletal_city!=null and source.skeletal_city.floors.has(Vector2i(x,z)) and y+1==source.skeletal_city.floors[Vector2i(x,z)]:
						tile=12 if posmod(x+z,4)!=0 else 13
					var cutaway: bool = cave_here and y + 1 == top and source.caves.floor_at(x, z) < top - 1
					var st: SurfaceTool = roof if cutaway else surface
					_emit_face(st, Vector3(xf, yf + 1, zf), Vector3(xf, yf + 1, zf + 1),
						Vector3(xf + 1, yf + 1, zf + 1), Vector3(xf + 1, yf + 1, zf), tile, "top")
					if cutaway:
						roof_faces += 1
					else:
						surface_faces += 1
				if down & bit:
					var st: SurfaceTool = roof if cave_here else surface
					_emit_face(st, Vector3(xf, yf, zf + 1), Vector3(xf, yf, zf),
						Vector3(xf + 1, yf, zf), Vector3(xf + 1, yf, zf + 1), 4, "top")
					if cave_here:
						roof_faces += 1
					else:
						surface_faces += 1
				if east & bit:
					_emit_face(surface, Vector3(xf + 1, yf, zf + 1), Vector3(xf + 1, yf, zf),
						Vector3(xf + 1, yf + 1, zf), Vector3(xf + 1, yf + 1, zf + 1), 4, "x")
					surface_faces += 1
				if west & bit:
					_emit_face(surface, Vector3(xf, yf, zf), Vector3(xf, yf, zf + 1),
						Vector3(xf, yf + 1, zf + 1), Vector3(xf, yf + 1, zf), 4, "x")
					surface_faces += 1
				if south & bit:
					_emit_face(surface, Vector3(xf, yf, zf + 1), Vector3(xf + 1, yf, zf + 1),
						Vector3(xf + 1, yf + 1, zf + 1), Vector3(xf, yf + 1, zf + 1), 4, "z")
					surface_faces += 1
				if north & bit:
					_emit_face(surface, Vector3(xf + 1, yf, zf), Vector3(xf, yf, zf),
						Vector3(xf, yf + 1, zf), Vector3(xf + 1, yf + 1, zf), 4, "z")
					surface_faces += 1
	var members: Array = []
	var meshed: Array[MeshInstance3D] = []
	if surface_faces > 0:
		var ground := MeshInstance3D.new()
		ground.name = "IslandRock_%d_%d" % [key.x, key.y]
		ground.mesh = PALETTE.create_mesh(surface)
		ground.material_override = _cutaway_material
		# The uncut shadow-only instance below already casts these triangles.
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		members.append(ground)
		meshed.append(ground)
		# The shadow-only mesh is shared, not duplicated geometry. Keep it on
		# Android as well so enabling the shadow budget works for loaded chunks.
		var shadow_ground := MeshInstance3D.new()
		shadow_ground.name = "IslandShadow_%d_%d" % [key.x, key.y]
		shadow_ground.mesh = ground.mesh
		shadow_ground.material_override = GREEDY.material()
		shadow_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		members.append(shadow_ground)
	if roof_faces > 0:
		var lid := MeshInstance3D.new()
		lid.name = "CaveCutaway_%d_%d" % [key.x, key.y]
		lid.mesh = PALETTE.create_mesh(roof)
		lid.material_override = _cutaway_material
		lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		members.append(lid)
		meshed.append(lid)
		# The visible material clips the roof; an unchanged shadow-only copy
		# keeps the cavern from being flooded by sunlight through that hole.
		var shadow_roof := MeshInstance3D.new()
		shadow_roof.name = "CaveShadow_%d_%d" % [key.x, key.y]
		shadow_roof.mesh = lid.mesh
		shadow_roof.material_override = GREEDY.material()
		shadow_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		members.append(shadow_roof)
	if not meshed.is_empty():
		var body := StaticBody3D.new()
		body.name = "IslandCollision_%d_%d" % [key.x, key.y]
		body.collision_layer = 1
		body.collision_mask = 1
		var shape_index: int = 0
		for mesh in meshed:
			if mesh.name.begins_with("CaveCutaway_"):
				body.set_meta("island_roof_shape_index", shape_index)
			var collider := CollisionShape3D.new()
			var collision_mesh: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
			# Match the established Outpost terrain collision contract.
			# Without double-sided triangles the avatar can collide with
			# cliff edges but miss the adjoining top face and fall/stall.
			collision_mesh.backface_collision = true
			collider.shape = collision_mesh
			body.add_child(collider)
			shape_index += 1
		members.append(body)
	return members

func _install_chunk(key: Vector2i, members: Array) -> void:
	for member in members:
		if member.name.begins_with("CaveCutaway_"):
			_roof_nodes.append(member)
		add_child(member)
	# The cavern chest uses the existing persistent loot contract.
	var game: Node = get_parent().get_parent()
	for index in range(terrain.caves.chests.size()):
		var at: Vector3 = terrain.caves.chests[index]
		if at.x < key.x or at.x >= key.x + CHUNK or at.z < key.y or at.z >= key.y + CHUNK:
			continue
		if index == 0 and mine != null:
			continue
		var chest := WORLD_OBJECT.new()
		chest.name = "IslandCaveChest_%d" % index
		chest.position = at + Vector3(0.0, 0.08, 0.0)
		add_child(chest)
		chest.setup(game, "island_cave_%d_%d" % [terrain.seed, index],
			"Cavern cache", "chest", PROPS.crate(), {"stone": 3, "iron": 1})
		members.append(chest)
	var settlement_index: int = terrain.settlement_index_at(key.x,key.y,float(CHUNK))
	if settlement_index>=0:
		var plan = terrain.settlement_plan(settlement_index)
		if plan != null:
			for item in plan.buildings:
				var rect: Rect2i = item["rect"]
				if _cell_at(Vector3(rect.position.x,0,rect.position.y)) != key: continue
				var building := SETTLEMENT_BUILDING.new()
				building.name = str(item["id"])
				add_child(building)
				building.build(item,terrain)
				members.append(building)
				settlement_nodes.append(building)
			var scenery := SETTLEMENT_SCENERY.build(plan,key,CHUNK)
			if scenery != null:
				add_child(scenery)
				members.append(scenery)
			_install_gathering(plan,key,game,members)
			if terrain.expanded_preview: _install_civilians(plan,key,game,members)
	_install_goblin_city(key,game,members)
	_install_skeletal_inhabitants(key,game,members)
	if terrain.skeletal_city!=null:
		var decoration := SKELETAL_SCENERY.build(terrain.skeletal_city,key,CHUNK)
		if decoration!=null:
			add_child(decoration)
			members.append(decoration)
	_install_cave_ore(key,game,members)
	_loaded[key] = members
	if natural_population != null:
		natural_population.populate(self,game,key,members)
	if mine != null:
		mine.populate(key,game,members)
	elif side_chamber != null or OS.get_environment("OUTPOST_TEST_PROCEDURAL_CAVE") == "1":
		var mine: Vector3 = terrain.caves.entrances[0]
		if _cell_at(mine) == key:
			var manager := game.get_node_or_null("Dungeons") if game != null else null
			if manager != null and manager.has_method("register_world_site"):
				manager.register_world_site(MINE_SITE_ID, terrain.seed, Vector3i(floori(mine.x), floori(mine.y), floori(mine.z)), "island_%d_%d" % [key.x, key.y])

func _install_gathering(plan,key: Vector2i,game: Node,members: Array) -> void:
	if game==null or not game.has_method("gather"): return
	for spec in plan.gathering.nodes:
		var at: Vector3 = spec["position"]
		if _cell_at(at)!=key: continue
		var cell: Vector2i = spec["cell"]
		if spec["habitat"]=="cavern":
			if terrain.caves.floor_at(cell.x,cell.y)!=floori(at.y): continue
		elif terrain.caves.has_cave(cell.x,cell.y): continue
		var radius := float(spec.get("radius",RESOURCE_PLACEMENT.radius_for(spec["kind"])))
		if not game.prop_placement.available(at,radius): continue
		var resource := REGIONAL_RESOURCE.new()
		add_child(resource)
		resource.global_position=at
		resource.setup(spec["kind"],1,spec.get("tree",{}))
		if not resource.rooted_tree.is_empty(): regional_trees.append(resource)
		resource.configure_regional(str(terrain.seed)+":"+str(spec["id"]),int(spec["tier"]),str(spec["habitat"]),game)
		if spec["habitat"]=="rocky_outcrop": resource.set_meta("special_resource_node",true)
		game.prop_placement.reserve(at,radius,resource)
		members.append(resource)

func _install_cave_ore(key: Vector2i,game: Node,members: Array) -> void:
	if game==null or not game.has_method("gather"): return
	for cell: Vector3i in terrain.ore_slots:
		var at := Vector3(cell)+Vector3(0.5,0,0.5)
		if _cell_at(at)!=key: continue
		var record: Dictionary = terrain.ore_slots[cell]
		var resource := REGIONAL_RESOURCE.new()
		add_child(resource)
		resource.global_position=at
		resource.setup(record["kind"],1,{},true)
		resource.configure_regional("%d:wall_ore:%d:%d:%d" % [terrain.seed,cell.x,cell.y,cell.z],int(record["tier"]),"cave_wall",game)
		members.append(resource)

func _install_goblin_city(key: Vector2i,game: Node,members: Array) -> void:
	var city = terrain.goblin_city
	if city==null or game==null: return
	for item in city.buildings:
		var rect: Rect2i = item["rect"]
		if _cell_at(Vector3(rect.position.x,0,rect.position.y))!=key: continue
		var building := SETTLEMENT_BUILDING.new()
		building.name=str(item["id"])
		add_child(building)
		building.build(item,terrain)
		members.append(building)
		settlement_nodes.append(building)
	for spec in city.gatherers:
		var source: Vector2i = spec["source"]
		var side := -1 if source.x<city.hub.x else 1
		var cell := source+Vector2i(side,0)
		var at := Vector3(cell.x+0.5,terrain.height_at(cell.x,cell.y)+0.05,cell.y+0.5)
		if _cell_at(at)!=key: continue
		var pile := PROPS.rock("stone") if side>0 else PROPS.crate()
		pile.name="GoblinCollectionPile"
		pile.position=at
		add_child(pile)
		members.append(pile)
	for cache in city.caches:
		var cell: Vector2i = cache["cell"]
		var at := Vector3(cell.x+0.5,float(cache["height"])+0.08,cell.y+0.5)
		if _cell_at(at)!=key: continue
		var id := "goblin_cache:%d:%s" % [terrain.seed,cache["id"]]
		if game.opened_world_objects.get(id,cache["loot"]).is_empty(): continue
		_spawn_village_chest(game,id,"Goblin stash",at,cache["loot"],"",members)
	for record in city.guards:
		var cell: Vector2i = record["cell"]
		var y: int = city.floors[cell] if record["underground"] else terrain.height_at(cell.x,cell.y)
		var at := Vector3(cell.x+0.5,y+0.08,cell.y+0.5)
		if _cell_at(at)!=key: continue
		var group := Node3D.new()
		add_child(group)
		members.append(group)
		var guard := CITY_GUARD.new()
		guard.terrain=terrain
		guard.underground_guard=record["underground"]
		guard.home=at
		group.add_child(guard)
		guard.setup(game.hero,null,1,at,"goblin")
		guard.bind_rival(game,"rival:%d:goblin:%s" % [terrain.seed,record["id"]],"goblin","Goblin city guard",1)
		_spawn_retinue(game,guard,group,city)

func regenerate_city_for_preview(hero: Node3D) -> bool:
	if terrain==null or terrain.goblin_city==null or mine_pending or mine_load_failed: return false
	# Never replace geometry around the player or another island's dungeon.
	if terrain.goblin_city.contains(Vector2i(floori(hero.global_position.x),floori(hero.global_position.z))): return false
	if not terrain.regenerate_goblin_city(): return false
	for worker in village_workers.values():
		if is_instance_valid(worker): worker.get_parent().queue_free()
	village_workers.clear()
	village_chests.clear()
	invalidate_section_geometry()
	for key: Vector2i in _loaded.keys():
		if terrain.goblin_city.contains(key+Vector2i(CHUNK/2,CHUNK/2)): _unload(key)
	_center=Vector2i(99999,99999)
	return true

func _update_ocean_shoals(game: Node,hero_at: Vector3) -> void:
	var wanted: Dictionary = {}
	for index in range(terrain.islands.size()):
		var island: Dictionary = terrain.islands[index]
		var center: Vector2i = island["center"]
		for sector in range(12):
			var angle := TAU*float(sector)/12.0+float(posmod(terrain.seed+index*17,100))*0.005
			var offset := Vector2.from_angle(angle)*(float(island["radius"])+8.0)
			var at := Vector3(center.x+offset.x,DATA.SEA_LEVEL+0.055,center.y+offset.y)
			if at.distance_squared_to(hero_at)>32.0*32.0: continue
			var clear_water := true
			for d in [Vector2.ZERO,Vector2(2,0),Vector2(-2,0),Vector2(0,2),Vector2(0,-2)]:
				if terrain.is_land_at(at.x+d.x,at.z+d.y): clear_water=false
			if not clear_water: continue
			var id := Vector2i(index,sector)
			wanted[id]=true
			if ocean_shoals.has(id): continue
			var value := posmod(terrain.seed+index*371+sector*193,100)
			var rank := 4 if value>=98 else 3 if value>=90 else 2 if value>=75 else 1 if value>=50 else 0
			var shoal := OCEAN_SHOAL.new()
			add_child(shoal)
			shoal.global_position=at
			shoal.configure(game,terrain.seed+index*371+sector*193,rank)
			ocean_shoals[id]=shoal
	for id in ocean_shoals.keys():
		if not wanted.has(id):
			if is_instance_valid(ocean_shoals[id]): ocean_shoals[id].queue_free()
			ocean_shoals.erase(id)

func regenerate_skeletal_city_for_preview(hero: Node3D) -> bool:
	if terrain==null or terrain.skeletal_city==null or mine_pending or mine_load_failed: return false
	if terrain.skeletal_city.contains(Vector2i(floori(hero.global_position.x),floori(hero.global_position.z))): return false
	if not terrain.regenerate_skeletal_city(): return false
	invalidate_section_geometry()
	for key: Vector2i in _loaded.keys():
		if terrain.skeletal_city.contains(key+Vector2i(CHUNK/2,CHUNK/2)): _unload(key)
	_center=Vector2i(99999,99999)
	return true

func _install_skeletal_inhabitants(key: Vector2i,game: Node,members: Array) -> void:
	var city = terrain.skeletal_city
	if city==null or game==null: return
	for cache in city.caches:
		var cell: Vector2i = cache["cell"]
		var at := Vector3(cell.x+0.5,float(cache["height"])+0.08,cell.y+0.5)
		if _cell_at(at)!=key: continue
		var id := "skeletal_cache:%d:%s" % [terrain.seed,cache["id"]]
		if game.opened_world_objects.get(id,cache["loot"]).is_empty(): continue
		_spawn_village_chest(game,id,"Ancient crypt cache",at,cache["loot"],"",members)
	for record in city.inhabitants:
		var cell: Vector2i = record["cell"]
		if not city.floors.has(cell): continue
		var at := Vector3(cell.x+0.5,float(city.floors[cell])+0.08,cell.y+0.5)
		if _cell_at(at)!=key: continue
		var group := Node3D.new()
		add_child(group)
		members.append(group)
		var guard := CITY_GUARD.new()
		guard.terrain=terrain
		guard.skeletal_guard=true
		guard.underground_guard=true
		guard.home=at
		group.add_child(guard)
		guard.setup(game.hero,null,int(record["tier"]),at,"skeleton")
		guard.bind_rival(game,"rival:%d:skeleton:%s" % [terrain.seed,record["id"]],"skeleton",str(record["name"]),int(record["tier"]))
		_spawn_retinue(game,guard,group,city)

func _spawn_village_chest(game: Node,id: String,label: String,at: Vector3,stock: Dictionary,work_id: String,members: Array) -> Node3D:
	var chest := VILLAGE_CHEST.new()
	chest.work_id=work_id
	chest.position=at
	add_child(chest)
	chest.setup(game,id,label,"chest",PROPS.crate(),stock)
	members.append(chest)
	return chest

func _update_village(game: Node,seconds: float) -> void:
	var city = terrain.goblin_city
	if city==null or game.hero==null: return
	var save_needed := false
	for i in range(city.gatherers.size()):
		var spec: Dictionary = city.gatherers[i]
		var id := "goblin_work:%d:%s" % [terrain.seed,spec["id"]]
		if not game.village_work.has(id): game.village_work[id]=VILLAGE_WORK.sanitize({})
		var record: Dictionary = game.village_work[id]
		var worker = village_workers.get(id)
		if not is_instance_valid(worker) or worker.is_queued_for_deletion(): worker=null
		var scheduled := VILLAGE_WORK.route_point(spec["path"],float(record["work"]))
		var near_route: bool = worker!=null and Vector2(worker.global_position.x,worker.global_position.z).distance_to(scheduled)<1.15
		# Visible workers must catch up to their assigned route before the
		# work clock progresses; unloaded workers use bounded simulation.
		if worker==null or not worker.alive or (worker.working and near_route):
			if VILLAGE_WORK.advance(record,minf(seconds,1.0),terrain.seed,i): save_needed=true
		var yard: Vector2i = spec["yard"]
		var point := VILLAGE_WORK.route_point(spec["path"],float(record["work"]))
		var at := Vector3(point.x,terrain.height_at(floori(point.x),floori(point.y))+0.08,point.y)
		var active_chunk := _cell_at(at)
		if worker!=null and (not _loaded.has(_cell_at(worker.global_position)) or not _loaded.has(active_chunk)):
			worker.get_parent().queue_free()
			village_workers.erase(id)
			worker=null
		if worker==null and float(record["rest"])<=0.0 and _loaded.has(active_chunk):
			var group := Node3D.new()
			add_child(group)
			worker=GATHERER.new()
			worker.terrain=terrain
			worker.underground_guard=false
			worker.home=Vector3(yard.x+0.5,10.08,yard.y+0.5)
			worker.record=record
			worker.route=spec["path"]
			group.add_child(worker)
			worker.setup(game.hero,null,0,at,"goblin")
			worker.bind_rival(game,"rival:%d:goblin:%s" % [terrain.seed,spec["id"]],"goblin","Goblin Gatherer",0)
			_spawn_retinue(game,worker,group,city)
			worker.slain.connect(_worker_slain.bind(game,id))
			worker.tree_exited.connect(group.queue_free,CONNECT_ONE_SHOT)
			village_workers[id]=worker
		var chest_cell: Vector2i = spec["chest"]
		var chest_at := Vector3(chest_cell.x+0.5,terrain.height_at(chest_cell.x,chest_cell.y)+0.08,chest_cell.y+0.5)
		var chest_key := _cell_at(chest_at)
		var chest = village_chests.get(id)
		if not record["stock"].is_empty() and _loaded.has(chest_key) and (not is_instance_valid(chest) or chest.is_queued_for_deletion()):
			village_chests[id]=_spawn_village_chest(game,id,"Gatherer's stockpile",chest_at,record["stock"],id,_loaded[chest_key])
	if save_needed: game._save()

func _worker_slain(game: Node,id: String) -> void:
	if not game.village_work.has(id): return
	VILLAGE_WORK.defeat(game.village_work[id])
	game._save()

func _spawn_retinue(game: Node,leader,group: Node3D,city) -> void:
	var count: int = REGIONAL_RIVAL.follower_count(int(leader.rival_record["rank"]))
	if count==0: return
	var start := Vector2i(floori(leader.global_position.x),floori(leader.global_position.z))
	var y: int = floori(leader.global_position.y)
	var candidates: Array[Vector2i] = []
	# Prefer nearby same-elevation floor cells; reject intact walls,
	# building footprints, cliffs and positions outside loaded terrain.
	for radius in range(2,6):
		for dz in range(-radius,radius+1):
			for dx in range(-radius,radius+1):
				if maxi(absi(dx),absi(dz))!=radius: continue
				var p := start+Vector2i(dx,dz)
				if leader.underground_guard:
					if int(city.floors.get(p,-99999))!=y: continue
					if terrain.is_solid(p.x,y,p.y) or terrain.is_solid(p.x,y+1,p.y): continue
				else:
					if terrain.height_at(p.x,p.y)!=y or not city.building_at(p).is_empty(): continue
				candidates.append(p)
	for p in candidates:
		if count<=0: break
		var at := Vector3(p.x+0.5,y+0.08,p.y+0.5)
		# A nearby adjacent chunk will be built by the same stream queue.
		# Keep followers within the leader's streamed chunk to avoid falling.
		if _cell_at(at)!=_cell_at(leader.global_position): continue
		var follower := CITY_GUARD.new()
		follower.terrain=terrain
		follower.skeletal_guard=leader.skeletal_guard
		follower.underground_guard=leader.underground_guard
		follower.home=at
		follower.rival_follower=true
		group.add_child(follower)
		follower.setup(game.hero,null,0,at,leader.rival_kind)
		follower.display_name="Retinue of "+leader.display_name
		count-=1

func _install_civilians(plan,key: Vector2i,game: Node,members: Array) -> void:
	if game==null: return
	var roles: Dictionary = {
		"expedition_coordinator":["Expedition coordinator","Ask me about the islands and their caverns."],
		"farmer":["Farmer","We grow supplies for the settlement."],
		"merchant":["Merchant","This market is where the town gathers to trade."],
		"banker":["Banker","The town vault will offer secure storage."],
		"guild_contact":["Guild representative","Adventurers gather here before expeditions."],
		"blacksmith":["Blacksmith","Bring ore to a forge to craft equipment."],
		"innkeeper":["Innkeeper","Rest here before your next expedition."],
		"quartermaster":["Quartermaster","Our stores support the settlement."],
		"guard":["Town guard","Stay on the roads when travelling outside town."],
		"explorer":["Cave explorer","The cave entrance lies beneath the rocky hillside."],
		"coastal_contact":["Harbour contact","The coastal trail connects to the main square."],
		"resident":["Resident","Welcome to our settlement."]
	}
	var variants: Array[String] = ["human_male_1","human_female_1","human_male_2","human_female_2"]
	for spec in plan.quest_anchors:
		var at: Vector3 = spec["position"]
		if _cell_at(at)!=key: continue
		var actor=preload("res://scripts/world/animated_camp_guide.gd").new()
		var info: Array = roles.get(spec["role"],["Resident","Welcome, traveller."])
		var kind: String = variants[posmod(hash(str(spec["id"])),variants.size())]
		actor.name="Civilian_"+str(spec["id"]).replace(":","_")
		add_child(actor)
		actor.position=at+Vector3.UP*0.04
		if not actor.configure_civilian(game,str(spec["id"]),str(info[0]),kind):
			actor.queue_free()
			continue
		actor.message=str(info[1])
		members.append(actor)
