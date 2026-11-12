extends Node3D
## Low-cost, map-only silhouettes of unexplored remote islands.
## No collision, resources or cave markers are exposed by this preview.
## The silhouettes match the same seeded coastline sampler as live terrain.
const GRID: int = 2
const MAP_LAYER: int = 1 << 1 # World map only; minimap culls this layer.
const SEA_TINT := Color("1a3440")
const LAND_TINT := Color("252b31")
const COAST_TINT := Color("414b52")
const SEA_Y: float = -3.35
const LAND_Y: float = -3.02
var island_mesh: MeshInstance3D
var ocean_mesh: MeshInstance3D
var island_count: int = 0
var land_cells: int = 0

func setup(biome: Node) -> void:
	if biome == null or biome.get("archipelago") == null:
		return
	var source: Node = biome.archipelago
	if source == null or source.terrain == null:
		return
	var data = source.terrain
	island_count = data.islands.size()
	var map_half: int = int(biome.get("map_world_half"))
	# A single ocean quad provides readable contrast against the blacked-out
	# islands while keeping the map's deep-water colour muted.
	var sea := SurfaceTool.new()
	sea.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(sea, -float(map_half), float(map_half), -float(map_half),
		float(map_half), SEA_Y, SEA_TINT)
	ocean_mesh = _make_mesh(sea, "UnchartedOcean")
	# Only sample the three island bounds, not every tile of the 768x768 sea.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for island in data.islands:
		var centre: Vector2i = island["center"]
		var radius: int = ceili(float(island["radius"]) + 5.0)
		var left: int = floori(float(centre.x - radius) / GRID) * GRID
		var right: int = ceili(float(centre.x + radius) / GRID) * GRID
		var top: int = floori(float(centre.y - radius) / GRID) * GRID
		var bottom: int = ceili(float(centre.y + radius) / GRID) * GRID
		for x in range(left, right, GRID):
			for z in range(top, bottom, GRID):
				var coast: float = data.margin_at(float(x) + GRID * 0.5,
					float(z) + GRID * 0.5)
				if coast <= 0.0:
					continue
				var tint: Color = COAST_TINT if coast <= 2.8 else LAND_TINT
				_add_quad(st, float(x), float(x + GRID), float(z),
					float(z + GRID), LAND_Y, tint)
				land_cells += 1
	if land_cells > 0:
		island_mesh = _make_mesh(st, "UnchartedIslandShadows")

func _add_quad(st: SurfaceTool, x0: float, x1: float,
		z0: float, z1: float, y: float, tint: Color) -> void:
	st.set_color(tint)
	st.set_uv(Vector2.ZERO)
	for at in [
		Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1),
		Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x1, y, z0),
	]:
		st.add_vertex(at)

func _make_mesh(st: SurfaceTool, label: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = st.commit()
	mesh.layers = MAP_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)
	return mesh
