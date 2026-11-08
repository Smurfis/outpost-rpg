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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	_image.fill(Color.TRANSPARENT)
	_texture = ImageTexture.create_from_image(_image)

func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	# Use the existing topological dungeon map until a unified map feature.
	var manager: Node = game.get_node_or_null("Dungeons")
	var in_dungeon: bool = manager != null and manager.get("active_instance") != null
	if visible == in_dungeon:
		visible = not in_dungeon
	if in_dungeon:
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

func _refresh_pixels() -> void:
	var biome: Node = game.get_node_or_null("VoxelAtmosphere")
	var half_extent: float = float(biome.get("map_half")) if biome != null else 0.0
	for py in range(RESOLUTION):
		var last_elevation: float = -0.055
		for px in range(RESOLUTION):
			# World-aligned: rotation happens via a single cheap canvas transform.
			var local := Vector2((float(px) + 0.5) / float(RESOLUTION) * 2.0 - 1.0,
				(float(py) + 0.5) / float(RESOLUTION) * 2.0 - 1.0)
			if local.length_squared() >= 0.96:
				_image.set_pixel(px, py, Color.TRANSPARENT)
				continue
			var wx: float = _center.x + local.x * MAP_RADIUS
			var wz: float = _center.z + local.y * MAP_RADIUS
			var colour: Color = Color("648641")
			var zone: String = ""
			if biome != null:
				if absf(wx) >= half_extent or absf(wz) >= half_extent:
					colour = Color("266983")
				else:
					zone = str(biome.coast_zone_at(wx, wz))
					match zone:
						"water": colour = Color("276f8c")
						"wet_sand": colour = Color("b0a57f")
						"dry_sand": colour = Color("dec994")
						"grass_sand": colour = Color("a8b47a")
						"coastal_soil": colour = Color("829b68")
						_:
							var tile: int = int(biome._ground_tile(floori(wx), floori(wz)))
							match tile:
								1: colour = Color("9bbd60")
								2: colour = Color("426f3e")
								3: colour = Color("94734f")
								4: colour = Color("858c91")
								5: colour = Color("c2a574")
								6: colour = Color("aa9774")
								7: colour = Color("55764c")
								_: colour = Color("739a4e")
			# Actual voxel elevation gives the miniature terrain subtle relief.
			# Reuse a height per two horizontal pixels to limit noise sampling.
			if biome != null and zone == "inland":
				if px % 2 == 0:
					last_elevation = float(biome._tile_height(floori(wx), floori(wz)))
					_relief_samples += 1
				if last_elevation > 0.45:
					colour = colour.lightened(clampf(last_elevation * 0.055, 0.0, 0.17))
				elif last_elevation < -0.55:
					colour = colour.darkened(clampf(-last_elevation * 0.055, 0.0, 0.15))
			# Cleaner, less noisy cartography: retained terrain/biome colour
			# categories, but fewer decorative speckles than the old map.
			var ink: int = posmod(floori(wx) * 31 + floori(wz) * 43, 101)
			if ink == 0:
				colour = colour.lightened(0.07)
			elif ink == 49:
				colour = colour.darkened(0.05)
			_image.set_pixel(px, py, colour)
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
