extends RefCounted
## Single shared, nearest-filtered pixel atlas. Prefer checked-in source PNG, with
## deterministic generated fallback for local tools and recovery.
const TILE_PIXELS: int = 16
const GRID: int = 4
const PIXELS: int = TILE_PIXELS * GRID
const ART_ATLAS_PATH: String = "res://assets/voxel/outpost_visual_atlas_16px.svg"
const COAST_ATLAS_PATH: String = "res://assets/voxel/coastal_terrain_16px.svg"
static var _shared_coast_atlas: Texture2D

# Coastal terrain 2x2 atlas (16 px per cell), distinct from the legacy
# material atlas used by trees/resources/props.
# 16 dry sand | 17 wet sand | 18 grass to sand | 19 coastal soil
static func coast_texture() -> Texture2D:
	if _shared_coast_atlas != null:
		return _shared_coast_atlas
	var tex: Texture2D = null
	if ResourceLoader.exists(COAST_ATLAS_PATH):
		tex = load(COAST_ATLAS_PATH) as Texture2D
	if tex == null or tex.get_size() != Vector2(32.0, 32.0):
		# Keep Android playable if a designer intentionally replaces
		# or temporarily removes the external art during migration.
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var palette: Array[Color] = [
			Color("dfc18a"), Color("ae976f"),
			Color("b1ba6d"), Color("7c8254")
		]
		for cell in range(4):
			for yy in range(16):
				for xx in range(16):
					var tint: Color = palette[cell]
					var pattern: int = posmod(xx * 79 + yy * 43 + cell * 61 + xx * yy, 17)
					if pattern < 3:
						tint = tint.darkened(0.12)
					elif pattern > 13:
						tint = tint.lightened(0.13)
					img.set_pixel((cell % 2) * 16 + xx, (cell / 2) * 16 + yy, tint)
		tex = ImageTexture.create_from_image(img)
	_shared_coast_atlas = tex
	return tex
static var _shared_material: StandardMaterial3D

# 0 grass | 1 light grass | 2 deep grass | 3 soil
# 4 stone | 5 path | 6 gravel | 7 moss
# 8 bark | 9 leaves | 10 dark leaves | 11 planks
# 12 masonry | 13 magic crystal | 14 berries | 15 coal
static func get_material() -> StandardMaterial3D:
	if _shared_material != null:
		return _shared_material
	var tex: Texture2D
	if ResourceLoader.exists(ART_ATLAS_PATH):
		tex = load(ART_ATLAS_PATH) as Texture2D
	if tex != null and (tex.get_width() != PIXELS or tex.get_height() != PIXELS):
		push_warning("Voxel atlas must be 64x64 pixels; using procedural fallback.")
		tex = null
	if tex == null:
		var bases: Array[Color] = [
			Color("74a852"), Color("96bd60"), Color("4b814a"), Color("8b6546"),
			Color("8d8990"), Color("b79c6b"), Color("a4a098"), Color("668958"),
			Color("785339"), Color("6ca34d"), Color("386e49"), Color("ae8051"),
			Color("a29b91"), Color("9882ce"), Color("c05061"), Color("353f52")
		]
		var image := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
		for tile in range(16):
			for y in range(TILE_PIXELS):
				for x in range(TILE_PIXELS):
					var hash_value: int = posmod((x + 3) * 71 + (y + 5) * 137 + tile * 173 + x * y * 29, 31)
					var base: Color = bases[tile]
					var ink: Color = base
					if hash_value < 5:
						ink = base.darkened(0.23)
					elif hash_value < 11:
						ink = base.lightened(0.17)
					elif hash_value > 27:
						ink = base.darkened(0.12)
					if tile == 3 and (y == 5 or y == 11) and x % 4 != 0:
						ink = base.darkened(0.18)
					elif tile == 4 and (x == 7 or y == 10) and hash_value < 13:
						ink = base.darkened(0.2)
					elif tile == 8 and x % 6 == 0:
						ink = base.darkened(0.22)
					elif tile == 11 and y in [4, 10]:
						ink = base.darkened(0.3)
					elif tile == 12 and (y == 7 or (x == 8 and y < 7) or (x == 4 and y > 7)):
						ink = base.darkened(0.3)
					elif tile == 13 and (x + y) % 6 == 0:
						ink = base.lightened(0.5)
					image.set_pixel((tile % GRID) * TILE_PIXELS + x, (tile / GRID) * TILE_PIXELS + y, ink)
		tex = ImageTexture.create_from_image(image)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Vertex tints allow pink, gold and jade foliage in a single batched mesh,
	# without multiplying material/texture objects or Android draw calls.
	mat.vertex_color_use_as_albedo = true
	_shared_material = mat
	return mat

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tile: int, tint: Color = Color.WHITE) -> void:
	var t: int = clampi(tile, 0, 15)
	# Half-texel UV inset prevents a tile pulling pixels from its neighbours.
	var u0: float = float((t % GRID) * TILE_PIXELS) + 0.5
	var v0: float = float((t / GRID) * TILE_PIXELS) + 0.5
	var u1: float = u0 + float(TILE_PIXELS - 1)
	var v1: float = v0 + float(TILE_PIXELS - 1)
	var uv: Array[Vector2] = [
		Vector2(u0, v1) / float(PIXELS),
		Vector2(u1, v1) / float(PIXELS),
		Vector2(u1, v0) / float(PIXELS),
		Vector2(u0, v0) / float(PIXELS)
	]
	var points: Array[Vector3] = [a, b, c, d]
	for index in [0, 1, 2, 0, 2, 3]:
		st.set_color(tint)
		st.set_uv(uv[index])
		st.add_vertex(points[index])

static func box(st: SurfaceTool, center: Vector3, full_size: Vector3, top_tile: int, side_tile: int, bottom_tile: int = 3, tint: Color = Color.WHITE) -> void:
	var l: float = center.x - full_size.x * 0.5
	var r: float = center.x + full_size.x * 0.5
	var b: float = center.y - full_size.y * 0.5
	var t: float = center.y + full_size.y * 0.5
	var n: float = center.z - full_size.z * 0.5
	var f: float = center.z + full_size.z * 0.5
	quad(st, Vector3(l, t, n), Vector3(l, t, f), Vector3(r, t, f), Vector3(r, t, n), top_tile, tint)
	quad(st, Vector3(l, b, f), Vector3(l, b, n), Vector3(r, b, n), Vector3(r, b, f), bottom_tile, tint)
	quad(st, Vector3(l, b, f), Vector3(r, b, f), Vector3(r, t, f), Vector3(l, t, f), side_tile, tint)
	quad(st, Vector3(r, b, f), Vector3(r, b, n), Vector3(r, t, n), Vector3(r, t, f), side_tile, tint)
	quad(st, Vector3(r, b, n), Vector3(l, b, n), Vector3(l, t, n), Vector3(r, t, n), side_tile, tint)
	quad(st, Vector3(l, b, n), Vector3(l, b, f), Vector3(l, t, f), Vector3(l, t, n), side_tile, tint)

# Deterministic cluster-based seasonal tint: sunny lime, cherry blossom,
# deep green and magical lavender. Combined with existing coloured atlas
# cells, this avoids extra texture memory and Android draw calls.
static func foliage_variant_at(x: float, z: float, seed: int = 64012) -> int:
	var cx: int = floori(x / 14.0)
	var cz: int = floori(z / 14.0)
	return posmod(cx * 71 + cz * 101 + seed * 13 + cx * cz * 7, 11)

# Draw variant crowns from already-loaded atlas cells, not just a
# multiplication of dark green pixels: cherry/purple foliage must stay vivid.
# No new textures; all variants still use the same 64x64 atlas.
static func foliage_tile_at(x: float, z: float, seed: int = 64012) -> int:
	var kind: int = foliage_variant_at(x, z, seed)
	if kind in [0, 1, 2, 3]:
		return 14 # Original vibrant berry-red tile doubles as pink blossom.
	if kind in [4, 5]:
		return 1 # Sunlit lime tile.
	if kind == 6:
		return 13 # Violet floral tile.
	if kind == 7:
		return 7 # Teal-moss tile.
	return 9 # Evergreen leaves.

static func foliage_tint_at(x: float, z: float, seed: int = 64012) -> Color:
	var kind: int = foliage_variant_at(x, z, seed)
	if kind in [0, 1, 2, 3]:
		return Color(1.0, 0.82, 1.0) # Cherry blossom red-pink.
	if kind in [4, 5]:
		return Color(1.0, 1.0, 0.52) # Sunlit chartreuse.
	if kind == 6:
		return Color(1.0, 0.79, 1.0) # Violet floral crown.
	if kind == 7:
		return Color(0.52, 0.95, 1.0) # Cool jade canopy.
	return Color.WHITE # Forest green, preserving the original source art.

static func create_mesh(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

static func as_instance(st: SurfaceTool, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = create_mesh(st)
	node.material_override = get_material()
	return node
