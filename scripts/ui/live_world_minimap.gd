extends Control
## Live terrain minimap for the overworld; independent of the dungeon minimap.
## 48x48 sampled pixels are updated twice per second, never once per frame.
const RESOLUTION: int = 48
const MAP_RADIUS: float = 52.0
const RIM: Color = Color("c3944c")
const DEEP_RIM: Color = Color("372717")
var game: Node
var _image: Image
var _texture: ImageTexture
var _clock: float = 0.0
var _center: Vector3 = Vector3.ZERO

func setup(game_ref: Node) -> void:
	game = game_ref

func _ready() -> void:
	name = "LiveWorldMinimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	_image.fill(Color.TRANSPARENT)
	_texture = ImageTexture.create_from_image(_image)
	set_process(true)

func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	var player: Node3D = game.get("hero") as Node3D
	if player == null:
		return
	_clock += delta
	if _clock < 0.5:
		# Arrow still follows the character without resampling terrain.
		queue_redraw()
		return
	_clock = 0.0
	_center = player.global_position
	_refresh_pixels()
	queue_redraw()

func _refresh_pixels() -> void:
	var biome: Node = game.get_node_or_null("VoxelAtmosphere")
	for py in range(RESOLUTION):
		for px in range(RESOLUTION):
			var local := Vector2((float(px) + 0.5) / RESOLUTION * 2.0 - 1.0, (float(py) + 0.5) / RESOLUTION * 2.0 - 1.0)
			if local.length_squared() > 0.98:
				_image.set_pixel(px, py, Color.TRANSPARENT)
				continue
			var wx: float = _center.x + local.x * MAP_RADIUS
			var wz: float = _center.z + local.y * MAP_RADIUS
			var colour: Color = Color("688e3e")
			if biome != null:
				var half: float = float(biome.get("map_half"))
				if absf(wx) > half or absf(wz) > half:
					colour = Color("2d819d")
				else:
					var zone: String = str(biome.coast_zone_at(wx, wz))
					match zone:
						"water": colour = Color("287d99")
						"wet_sand": colour = Color("a69b70")
						"dry_sand": colour = Color("d8bd84")
						"grass_sand": colour = Color("9eac65")
						"coastal_soil": colour = Color("7e9360")
						_:
							var tile: int = int(biome._ground_tile(floori(wx), floori(wz)))
							match tile:
								1: colour = Color("8eae52")
								2: colour = Color("446f38")
								4: colour = Color("828487")
								5, 6: colour = Color("b49b6c")
								7: colour = Color("64794e")
								_: colour = Color("668f42")
			# Subtle repeatable terrain pixels, not random flickering.
			if (px * 17 + py * 31) % 13 == 0:
				colour = colour.lightened(0.08)
			_image.set_pixel(px, py, colour)
	_texture.update(_image)

func _draw() -> void:
	var d: float = minf(size.x, size.y)
	if d <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var r: float = d * 0.5 - 8.0
	draw_circle(center, r + 7.0, DEEP_RIM)
	draw_circle(center, r + 2.0, RIM)
	draw_circle(center, r, Color("192c29"))
	if _texture != null:
		draw_texture_rect(_texture, Rect2(center - Vector2.ONE * (r - 2.0), Vector2.ONE * (r - 2.0) * 2.0), false)
	var player: Node3D = game.get("hero") as Node3D if game != null else null
	if player != null:
		# Named crafting stations show as small gold map markers.
		var stations: Dictionary = game.get("stations")
		for id in stations:
			var station: Node3D = stations[id] as Node3D
			if not is_instance_valid(station):
				continue
			var offset := Vector2(station.global_position.x - player.global_position.x,
				station.global_position.z - player.global_position.z) * ((r - 2.0) / MAP_RADIUS)
			if offset.length() < r - 10.0:
				draw_circle(center + offset, 4.0, DEEP_RIM)
				draw_circle(center + offset, 2.6, Color("ffdc77"))
		# Rotation reflects visual facing, which uses -Z as local forward.
		var angle: float = 0.0
		var avatar: Node3D = player.get("visual") as Node3D
		if avatar != null:
			angle = -avatar.rotation.y
		var tip := center + Vector2(0, -12).rotated(angle)
		var left := center + Vector2(-7, 8).rotated(angle)
		var right := center + Vector2(7, 8).rotated(angle)
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color("ffdd8c"))
		draw_polyline(PackedVector2Array([tip, left, right, tip]), DEEP_RIM, 2.0)
	draw_arc(center, r + 3.0, 0.0, TAU, 96, RIM, 3.0, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-6, -r - 11), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("fff1c2"))
