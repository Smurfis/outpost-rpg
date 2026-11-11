extends Control
## Outpost overworld minimap: camera-relative GPU display of cached world-aligned pixels.
## Camera orbit must NEVER trigger a CPU terrain resample; all artwork is original.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const RESOLUTION: int = 64
const MAP_RADIUS: float = 46.0
const MIN_SAMPLE_INTERVAL: float = 0.24
const IDLE_REFRESH_INTERVAL: float = 2.0
const MOVEMENT_REFRESH_DISTANCE: float = 1.4
const RIM: Color = Color("cba668")
const DARK_WOOD: Color = Color("382719")
const INNER_WOOD: Color = Color("765033")
var game: Node
var _image: Image
var _texture: ImageTexture
var _clock: float = 0.0
var _center: Vector3 = Vector3.ZERO # Last texture sample, NOT the player marker.
var _sample_angle: float = 0.0 # Latest camera orbit; changes without texture updates.
var _has_sample: bool = false
var _refresh_count: int = 0
var _relief_samples: int = 0 # Height-call counter for Android performance QA.

func setup(game_ref: Node) -> void:
	game = game_ref

func _ready() -> void:
	name = "LiveWorldMinimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	_image.fill(Color.TRANSPARENT)
	_texture = ImageTexture.create_from_image(_image)

func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	# One circular map is shared between the overworld and dungeon. Never
	# resample world terrain while the hero is inside a private dungeon.
	var manager: Node = game.get_node_or_null("Dungeons")
	var dungeon: Node3D = manager.get("active_instance") as Node3D if manager != null else null
	if not visible:
		visible = true
	if dungeon != null and is_instance_valid(dungeon):
		_sample_angle = float(game.get("camera_angle"))
		queue_redraw()
		return
	var player: Node3D = game.get("hero") as Node3D
	if player == null:
		return
	_clock += delta
	_sample_angle = float(game.get("camera_angle"))
	var position_now: Vector3 = player.global_position
	var ground_shift := Vector2(position_now.x - _center.x, position_now.z - _center.z)
	var distance_sq: float = ground_shift.length_squared()
	# Cache the same world-aligned pixels while dragging the camera. Even a
	# 360-degree orbit changes only the draw transform, not expensive biome noise.
	# A small shift is smoothly offset at draw time to centre the player.
	if not _has_sample or distance_sq >= 16.0 or (
		_clock >= MIN_SAMPLE_INTERVAL and distance_sq >= MOVEMENT_REFRESH_DISTANCE * MOVEMENT_REFRESH_DISTANCE
	) or _clock >= IDLE_REFRESH_INTERVAL:
		_clock = 0.0
		_center = position_now
		_has_sample = true
		_refresh_pixels()
	queue_redraw()

func _map_to_world(screen_local: Vector2) -> Vector2:
	var c: float = cos(_sample_angle)
	var s: float = sin(_sample_angle)
	return Vector2(screen_local.x * c + screen_local.y * s, -screen_local.x * s + screen_local.y * c)

func _world_to_map(world_delta: Vector2) -> Vector2:
	var c: float = cos(_sample_angle)
	var s: float = sin(_sample_angle)
	return Vector2(world_delta.x * c - world_delta.y * s, world_delta.x * s + world_delta.y * c)

static func terrain_colour(zone: String) -> Color:
	# One consistent colour per *actual coast classification*, never a
	# random tint based on terrain tile hash or player-relative grid pixel.
	match zone:
		"water": return Color("28677b")
		"wet_sand": return Color("aba282")
		"dry_sand": return Color("ddc696")
		"grass_sand": return Color("91a96a")
		"coastal_soil": return Color("78975c")
		_: return Color("719a51")  # All inland grass is the SAME green.

func _refresh_pixels() -> void:
	var biome: Node = game.get_node_or_null("VoxelAtmosphere")
	var half_extent: float = float(biome.get("map_half")) if biome != null else 0.0
	for py in range(RESOLUTION):
		for px in range(RESOLUTION):
			# World-aligned, camera rotation applied in _draw().
			var local := Vector2((float(px) + 0.5) / float(RESOLUTION) * 2.0 - 1.0,
				(float(py) + 0.5) / float(RESOLUTION) * 2.0 - 1.0)
			if local.length_squared() >= 0.96:
				_image.set_pixel(px, py, Color.TRANSPARENT)
				continue
			var wx: float = _center.x + local.x * MAP_RADIUS
			var wz: float = _center.z + local.y * MAP_RADIUS
			var region: String = "inland"
			if biome != null:
				if absf(wx) >= half_extent or absf(wz) >= half_extent:
					region = "water"
				else:
					region = str(biome.coast_zone_at(wx, wz))
			# No per-pixel noise, no per-voxel green variants, no elevation
			# tinting. These re-sampled details created checkerboard flashes
			# on recentering. Actual tree and station markers still render
			# separately in world space, not inside the texture.
			_image.set_pixel(px, py, terrain_colour(region))
	_texture.update(_image)
	_refresh_count += 1

func _draw() -> void:
	if game == null:
		return
	var diameter: float = minf(size.x, size.y)
	if diameter <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var radius: float = diameter * 0.5 - 7.0
	var interior: float = radius - 5.0
	# Slim bronze + carved-wood bezel matches the new compact map footer.
	# Same world-locked sample and camera-relative rotation: visual pass only.
	draw_circle(center + Vector2(0.0, 1.0), radius + 4.0, Color("1e1712"))
	draw_circle(center, radius + 2.0, DARK_WOOD)
	draw_circle(center, radius, INNER_WOOD)
	draw_circle(center, radius - 2.0, RIM)
	draw_circle(center, radius - 4.0, Color("182c2b"))
	var manager: Node = game.get_node_or_null("Dungeons")
	var dungeon: Node3D = manager.get("active_instance") as Node3D if manager != null else null
	if dungeon != null and is_instance_valid(dungeon):
		_draw_dungeon_rooms(dungeon, center, interior, radius)
		return
	var player: Node3D = game.get("hero") as Node3D
	if _texture != null:
		var display_offset := Vector2.ZERO
		if player != null:
			var delta := Vector2(player.global_position.x - _center.x, player.global_position.z - _center.z)
			display_offset = -_world_to_map(delta) * (interior / MAP_RADIUS)
		# GPU/canvas rotation makes camera drag free of terrain-noise resampling.
		draw_set_transform(center + display_offset, _sample_angle, Vector2.ONE)
		draw_texture_rect(_texture, Rect2(Vector2(-interior, -interior), Vector2.ONE * interior * 2.0), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Four carved compass ticks and a subtler eight-point inner tick ring.
	for index in range(8):
		var a: float = float(index) * TAU / 8.0 - PI * 0.5
		var direction := Vector2(cos(a), sin(a))
		var end: float = radius + 2.0
		var start: float = radius - (5.0 if index % 2 == 0 else 2.0)
		draw_line(center + direction * start, center + direction * end,
			Color("f2d599") if index % 2 == 0 else Color("a8804b"), 2.0)
	if player != null:
		var stations: Dictionary = game.get("stations")
		for station_id in stations:
			var station: Node3D = stations[station_id] as Node3D
			if not is_instance_valid(station):
				continue
			var diff := Vector2(station.global_position.x - player.global_position.x,
				station.global_position.z - player.global_position.z)
			var offset: Vector2 = _world_to_map(diff) * (interior / MAP_RADIUS)
			if offset.length_squared() < (interior - 7.0) * (interior - 7.0):
				var marker: Color = Color("f3a66a") if station_id == "forge" else Color("f0cf7b")
				draw_circle(center + offset, 5.0, DARK_WOOD)
				draw_circle(center + offset, 3.1, marker)
				draw_circle(center + offset + Vector2(-1.0, -1.0), 1.1, Color("fff2c7"))
		# Only real world trees are marked; this pass does not invent
		# stream-chunk positions or add costly terrain samples on camera orbit.
		for thing in game.get_children():
			if not (thing is MeshInstance3D) or not str(thing.name).begins_with("VoxelTree"):
				continue
			var tree: MeshInstance3D = thing as MeshInstance3D
			var relative := Vector2(tree.global_position.x - player.global_position.x, tree.global_position.z - player.global_position.z)
			var offset: Vector2 = _world_to_map(relative) * (interior / MAP_RADIUS)
			if offset.length_squared() >= (interior - 7.0) * (interior - 7.0):
				continue
			var variety: int = PIXELS.foliage_variant_at(tree.global_position.x, tree.global_position.z, 64012)
			var tree_colour: Color = Color("e68bb6") if variety <= 3 else Color("d1dc54") if variety <= 5 else Color("ab86d9") if variety == 6 else Color("59b2aa") if variety == 7 else Color("78b75a")
			draw_circle(center + offset, 3.3, DARK_WOOD)
			draw_circle(center + offset, 2.1, tree_colour)
		# Fixed centre; arrow heading is relative to camera and world map.
		var yaw: float = _sample_angle
		var avatar: Node3D = player.get("visual") as Node3D
		if avatar != null:
			yaw -= avatar.rotation.y
		var tip: Vector2 = center + Vector2(0.0, -13.0).rotated(yaw)
		var left: Vector2 = center + Vector2(-7.0, 9.0).rotated(yaw)
		var right: Vector2 = center + Vector2(7.0, 9.0).rotated(yaw)
		draw_colored_polygon(PackedVector2Array([tip, left, right]), DARK_WOOD)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -10).rotated(yaw),
			center + Vector2(-5, 6).rotated(yaw),
			center + Vector2(5, 6).rotated(yaw)
		]), Color("ffe6a3"))
	draw_arc(center, radius - 4.0, 0.0, TAU, 72, Color("d8ad68", 0.80), 1.4, true)
	# N is geographic north, which turns around the circular rim as the
	# camera rotates; this is distinct from the player's directional arrow.
	var north: Vector2 = _world_to_map(Vector2(0.0, -1.0))
	draw_string(ThemeDB.fallback_font, center + north * (radius - 13.0) + Vector2(-5.0, 5.0),
		"N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff3cc"))

## Same circular HUD slot, border and camera-relative orientation as the
## overworld map; not a second draggable, screen-blocking dungeon overlay.
## Entire topology fits inside the ring, with exact player position as a dot.
func _draw_dungeon_rooms(dungeon: Node3D, center: Vector2, interior: float, radius: float) -> void:
	var rooms: Array = dungeon.layout.get("rooms", [])
	if rooms.is_empty():
		return
	var smallest := Vector2(INF, INF)
	var largest := Vector2(-INF, -INF)
	for room in rooms:
		var grid: Vector2i = room["grid"]
		var pos := Vector2(float(grid.x), float(grid.y))
		smallest = smallest.min(pos)
		largest = largest.max(pos)
	var middle: Vector2 = (smallest + largest) * 0.5
	var farthest: float = 0.5
	for room in rooms:
		var grid: Vector2i = room["grid"]
		farthest = maxf(farthest, (Vector2(float(grid.x), float(grid.y)) - middle).length())
	var scale_by: float = minf(27.0, (interior - 15.0) / farthest)
	var points: Dictionary = {}
	for room in rooms:
		var grid: Vector2i = room["grid"]
		var relative := (Vector2(float(grid.x), float(grid.y)) - middle) * scale_by
		points[int(room["id"])] = center + _world_to_map(relative)
	for link in dungeon.layout.get("edges", []):
		draw_line(points[link.x], points[link.y], Color("73969b"), 5.0, true)
		draw_line(points[link.x], points[link.y], Color("b1c2b2"), 2.0, true)
	for room in rooms:
		var id: int = int(room["id"])
		var colour: Color = Color("a9b7ae")
		match str(room.get("role", "normal")):
			"start": colour = Color("83bdd5")
			"stairs": colour = Color("f6c974")
			"boss": colour = Color("ed7d68")
			"treasure": colour = Color("9bdcb0")
		var at: Vector2 = points[id]
		draw_circle(at, 7.0, DARK_WOOD)
		draw_rect(Rect2(at - Vector2.ONE * 4.6, Vector2.ONE * 9.2), colour, true)
	var hero: Node3D = dungeon.hero as Node3D
	if hero != null and is_instance_valid(hero):
		var delta: Vector3 = hero.global_position - dungeon.global_position
		var hero_grid := Vector2(delta.x, delta.z) / float(dungeon.STEP)
		var map_pos: Vector2 = center + _world_to_map((hero_grid - middle) * scale_by)
		draw_circle(map_pos, 6.8, Color("241d1a"))
		draw_circle(map_pos, 4.7, Color("fff1a5"))
	draw_arc(center, radius - 4.0, 0.0, TAU, 72, Color("d8ad68", 0.80), 1.4, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-22, radius - 15.0),
		"F%d/%d" % [int(dungeon.current_floor), int(dungeon.floor_count)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffe6a3"))
