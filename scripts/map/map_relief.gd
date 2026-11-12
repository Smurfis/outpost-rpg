extends Node3D
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const SURFACE = preload("res://scripts/map/map_surface.gdshader")
## Map-only geometry: no gameplay scene, collision, animation, AI or VFX.
const MAX_MESHES: int = 256 # Entire current 16x16 chunk island; bounded for future worlds.
const CHUNK: int = 12
var service: Node
var meshes: Dictionary = {}
var mesh_versions: Dictionary = {}
var queue: Array[Vector2i] = []
var material: ShaderMaterial
var focus := Vector3.ZERO
var seen_revision: int = -1
var build_count: int = 0

func setup(source: Node) -> void:
	service = source
	material = ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("atlas_texture", PALETTE.get_material().albedo_texture)
	material.set_shader_parameter("coast_texture", PALETTE.coast_texture())

func schedule(at: Vector3) -> void:
	focus = at
	var wanted: Dictionary = {}
	for cell in service.discovered:
		var key := Vector2i(floori(float(cell.x * service.CELL) / CHUNK), floori(float(cell.y * service.CELL) / CHUNK))
		wanted[key] = true
	var keys: Array = wanted.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a.x * CHUNK - at.x, a.y * CHUNK - at.z).length_squared() < Vector2(b.x * CHUNK - at.x, b.y * CHUNK - at.z).length_squared())
	keys = keys.slice(0, MAX_MESHES)
	for key in meshes.keys():
		if not keys.has(key):
			meshes[key].queue_free()
			meshes.erase(key)
			mesh_versions.erase(key)
	queue.clear()
	for key in keys:
		if not meshes.has(key) or mesh_versions.get(key, -1) != service.chunk_versions.get(key, 0):
			queue.append(key)
	seen_revision = service.revision

func tick() -> bool:
	material.set_shader_parameter("player_position", service.game.hero.global_position)
	if queue.is_empty():
		return false
	var key: Vector2i = queue[0]
	service.cache.request_chunk(key)
	service.cache.step(48)
	if not service.cache.chunks.has(key):
		return false
	queue.pop_front()
	build(key)
	return true

func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color, tile: int = -1, light: float = 1.0) -> void:
	st.set_color(tint)
	st.set_uv2(Vector2(tile, light))
	for vertex in [a, b, c, a, c, d]:
		st.set_uv(Vector2(vertex.x, vertex.z) if is_equal_approx(a.y, b.y) and is_equal_approx(b.y, c.y) else Vector2(vertex.x + vertex.z, vertex.y))
		st.add_vertex(vertex)

func box(st: SurfaceTool, at: Vector3, dimensions: Vector3, tint: Color) -> void:
	var a := at - dimensions * 0.5
	var b := at + dimensions * 0.5
	quad(st, Vector3(a.x,b.y,a.z), Vector3(a.x,b.y,b.z), Vector3(b.x,b.y,b.z), Vector3(b.x,b.y,a.z), tint)
	quad(st, Vector3(a.x,a.y,a.z), Vector3(a.x,b.y,a.z), Vector3(b.x,b.y,a.z), Vector3(b.x,a.y,a.z), tint.darkened(0.22))
	quad(st, Vector3(a.x,a.y,b.z), Vector3(a.x,b.y,b.z), Vector3(b.x,b.y,b.z), Vector3(b.x,a.y,b.z), tint.darkened(0.35))
	quad(st, Vector3(a.x,a.y,a.z), Vector3(a.x,b.y,a.z), Vector3(a.x,b.y,b.z), Vector3(a.x,a.y,b.z), tint.darkened(0.30))
	quad(st, Vector3(b.x,a.y,a.z), Vector3(b.x,b.y,a.z), Vector3(b.x,b.y,b.z), Vector3(b.x,a.y,b.z), tint.darkened(0.15))

func build(key: Vector2i) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for x in range(key.x * CHUNK, (key.x + 1) * CHUNK, 2):
		for z in range(key.y * CHUNK, (key.y + 1) * CHUNK, 2):
			if service.visibility_at(Vector3(x + 1, 0, z + 1)) == 0:
				continue
			var cell: Dictionary = service.cache.cell_at(x, z)
			if cell.is_empty():
				continue
			var tint := Color("719a51")
			match str(cell.zone):
				"water": tint = Color("286f84")
				"wet_sand": tint = Color("aba282")
				"dry_sand": tint = Color("ddc696")
				"grass_sand": tint = Color("91a96a")
				"coastal_soil": tint = Color("78975c")
			if int(cell.ground_tile) in [5, 6] and cell.zone == "inland":
				tint = Color("a58a60")
			var h: float = cell.height
			quad(st, Vector3(x,h,z), Vector3(x,h,z+2), Vector3(x+2,h,z+2), Vector3(x+2,h,z), tint, -2 if cell.zone == "water" else int(cell.ground_tile))
			count += 1
			if cell.zone == "water":
				continue
			for direction in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
				var neighbour: Dictionary = service.cache.cell_at(x + direction.x, z + direction.y)
				if neighbour.is_empty():
					neighbour = service.biome.map_cell_at(x + direction.x, z + direction.y)
				var low: float = float(neighbour.get("height", h))
				if low >= h:
					continue
				if direction.x != 0:
					var edge: float = x + (2 if direction.x > 0 else 0)
					quad(st, Vector3(edge,low,z),Vector3(edge,h,z),Vector3(edge,h,z+2),Vector3(edge,low,z+2),Color("8b6546"), 16 if cell.zone in ["dry_sand", "wet_sand"] else 3, 0.65)
				else:
					var edge: float = z + (2 if direction.y > 0 else 0)
					quad(st, Vector3(x,low,edge),Vector3(x,h,edge),Vector3(x+2,h,edge),Vector3(x+2,low,edge),Color("8b6546"), 16 if cell.zone in ["dry_sand", "wet_sand"] else 3, 0.78)
	for entry in service.scenery.values():
		var at: Vector3 = entry.position
		if Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK)) != key:
			continue
		var dimensions: Vector3 = entry.size
		if entry.kind == "wood":
			box(st, at + Vector3.UP * dimensions.y * 0.35, Vector3(0.45, dimensions.y * 0.7, 0.45), Color("795b3b"))
			box(st, at + Vector3.UP * dimensions.y * 0.7, Vector3(dimensions.x * 0.8, dimensions.y * 0.45, dimensions.z * 0.8), Color("659653"))
			box(st, at + Vector3.UP * dimensions.y * 0.93, Vector3(dimensions.x * 0.5, dimensions.y * 0.14, dimensions.z * 0.5), Color("84ad62"))
		else:
			box(st, at + Vector3.UP * dimensions.y * 0.5, dimensions, Color("ac795d") if entry.kind == "clay" else Color("7f8990"))
	for entry in service.known.values():
		var at: Vector3 = entry.position
		if entry.category != "stations" or Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK)) != key:
			continue
		box(st, at + Vector3.UP * 0.55, Vector3(1.4,1.1,1.0), Color("ae8154"))
	if meshes.has(key):
		meshes[key].queue_free()
		meshes.erase(key)
	if count > 0:
		var instance := MeshInstance3D.new()
		instance.mesh = st.commit()
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		meshes[key] = instance
		mesh_versions[key] = service.chunk_versions.get(key, 0)
	build_count += 1
