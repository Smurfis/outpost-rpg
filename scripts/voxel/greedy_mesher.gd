extends RefCounted
## Reusable atlas-safe greedy surface material for Fields and future biomes.
## UV encodes world tile-repeat coordinates; UV2.x encodes atlas tile index.
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
const SHADER = preload("res://scripts/voxel/greedy_atlas.gdshader")
static var _material: ShaderMaterial

static func material() -> ShaderMaterial:
	if _material != null:
		return _material
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.set_shader_parameter("atlas_texture", PIXELS.get_material().albedo_texture)
	result.set_shader_parameter("coast_texture", PIXELS.coast_texture())
	_material = result
	return result

static func tiled_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tile: int, axes: String) -> void:
	var points: Array[Vector3] = [a, b, c, d]
	for index in [0, 1, 2, 0, 2, 3]:
		var at: Vector3 = points[index]
		var uv: Vector2 = Vector2(at.x, at.z)
		if axes == "x":
			uv = Vector2(at.z, at.y)
		elif axes == "z":
			uv = Vector2(at.x, at.y)
		st.set_uv(uv)
		st.set_uv2(Vector2(float(clampi(tile, 0, 19)), 0.0))
		st.add_vertex(at)
