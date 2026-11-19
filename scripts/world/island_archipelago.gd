extends Node3D
## Feature-branch-only remote island streamer. Never mutates the original
## Outpost chunks or its coastline. The far-ocean horizon supplies the water.
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
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
const CHAMBER = preload("res://scripts/world/chamber_visibility.gd")
const SECTION_PICK := 1 << 18
var section_active := false
var section_excluded: Array[RID] = []
var _regions: Array[Dictionary] = []
var _owners := {}
var _lights: Array[Vector3] = []
var _region := 0
var side_chamber

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
	if _regions.is_empty() and cell.distance_squared_to(center) < 64 * 64:
		_identify_regions(center)
	var next_region: int = _owners.get(cell,-1)
	var inside: bool = next_region >= 0 and absf(pos.y-terrain.caves.floor_at(cell.x,cell.y)) < 2.1 and pos.y < terrain.height_at(cell.x,cell.y)-1
	var sector := posmod(roundi(atan2(eye.z,eye.x)*8/TAU),8)
	if not inside:
		if section_active:
			_restore_section()
		if cell.distance_squared_to(center) < 64 * 64:
			_prewarm(cell,sector)
		elif not _regions.is_empty() and cell.distance_squared_to(center) > 80 * 80:
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

func setup(world_seed: int) -> void:
	if terrain != null:
		_clear_stream()
		if _chamber_light != null:
			_chamber_light.queue_free()
			_chamber_light = null
	terrain = DATA.new(world_seed)
	side_chamber = null
	if OS.get_environment("OUTPOST_TEST_SIDE_CHAMBER") == "1":
		var addition = preload("res://scripts/world/test_side_chamber.gd").new()
		if addition.install(terrain):
			side_chamber = addition
		else:
			push_warning("No roofed site for the test side chamber in this seed")
	name = "FractalArchipelago"
	# Never mutate GREEDY's global material: other Fields chunks must not cut
	# holes when the remote island camera enters a tunnel or a deep ravine.
	_cutaway_material = GREEDY.material().duplicate() as ShaderMaterial
	_cutaway_material.set_shader_parameter("island_cutaway_enabled", false)
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = HERO_OUTLINE

func _process(delta: float) -> void:
	if terrain == null:
		return
	var game: Node = get_parent().get_parent()
	if game == null:
		return
	var hero: Node3D = game.get("hero")
	if hero == null:
		return
	var position: Vector3 = hero.global_position
	if not terrain.near_island(position):
		if section_active:
			_restore_section()
		if _cutaway_material != null:
			_cutaway_material.set_shader_parameter("island_cutaway_enabled", false)
		_set_hero_outline(hero, false)
		if not _loaded.is_empty():
			_clear_stream()
		return
	_queue_near(position)
	_build_pending()
	_update_cutaway(game, position, delta)
	_update_hero_visibility(game, hero)

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
			node.queue_free()
	_loaded.erase(key)

func _emit_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tile: int, axes: String) -> void:
	GREEDY.tiled_quad(st, a, b, c, d, tile, axes)

func _build_chunk(key: Vector2i) -> void:
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
			columns.append(terrain.solid_column(key.x+dx,key.y+dz))
	for x in range(key.x, key.x + CHUNK):
		for z in range(key.y, key.y + CHUNK):
			var top: int = terrain.height_at(x, z)
			var cave_here: bool = terrain.caves.has_cave(x, z)
			if cave_here:
				top = maxi(top, terrain.caves.floor_at(x, z)) # Include guaranteed stone step foundations.
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
				var tile: int = terrain.top_tile(x, z) if y == top - 1 else 4
				if up & bit:
					var cutaway: bool = cave_here and y + 1 == top and terrain.caves.floor_at(x, z) < top - 1
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
		add_child(ground)
		members.append(ground)
		meshed.append(ground)
		# The shadow-only mesh is shared, not duplicated geometry. Keep it on
		# Android as well so enabling the shadow budget works for loaded chunks.
		var shadow_ground := MeshInstance3D.new()
		shadow_ground.name = "IslandShadow_%d_%d" % [key.x, key.y]
		shadow_ground.mesh = ground.mesh
		shadow_ground.material_override = GREEDY.material()
		shadow_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(shadow_ground)
		members.append(shadow_ground)
	if roof_faces > 0:
		var lid := MeshInstance3D.new()
		lid.name = "CaveCutaway_%d_%d" % [key.x, key.y]
		lid.mesh = PALETTE.create_mesh(roof)
		lid.material_override = _cutaway_material
		add_child(lid)
		members.append(lid)
		meshed.append(lid)
		_roof_nodes.append(lid)
		# The visible material clips the roof; an unchanged shadow-only copy
		# keeps the cavern from being flooded by sunlight through that hole.
		var shadow_roof := MeshInstance3D.new()
		shadow_roof.name = "CaveShadow_%d_%d" % [key.x, key.y]
		shadow_roof.mesh = lid.mesh
		shadow_roof.material_override = GREEDY.material()
		shadow_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(shadow_roof)
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
		add_child(body)
		members.append(body)
	# The cavern chest uses the existing persistent loot contract.
	var game: Node = get_parent().get_parent()
	for index in range(terrain.caves.chests.size()):
		var at: Vector3 = terrain.caves.chests[index]
		if at.x < key.x or at.x >= key.x + CHUNK or at.z < key.y or at.z >= key.y + CHUNK:
			continue
		var chest := WORLD_OBJECT.new()
		chest.name = "IslandCaveChest_%d" % index
		chest.position = at + Vector3(0.0, 0.08, 0.0)
		add_child(chest)
		chest.setup(game, "island_cave_%d_%d" % [terrain.seed, index],
			"Cavern cache", "chest", PROPS.crate(), {"stone": 3, "iron": 1})
		members.append(chest)
	_loaded[key] = members
	if not terrain.caves.entrances.is_empty():
		var mine: Vector3 = terrain.caves.entrances[0]
		if _cell_at(mine) == key:
			var manager := game.get_node_or_null("Dungeons") if game != null else null
			if manager != null and manager.has_method("register_world_site"):
				manager.register_world_site(MINE_SITE_ID, terrain.seed, Vector3i(floori(mine.x), floori(mine.y), floori(mine.z)), "island_%d_%d" % [key.x, key.y])
