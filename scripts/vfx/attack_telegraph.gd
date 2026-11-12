extends MeshInstance3D
## Red, world-space floor warning for a committed enemy heavy attack.
## The visual shape and the damage test share the same dimensions.
## One short-lived unshaded mesh: no shader, collision or mobile GPU particles.
const ARC_STEPS: int = 20
var shape_kind: String = "cone"
var reach: float = 4.0
var half_angle: float = deg_to_rad(43.0)
var half_width: float = 0.67
var duration: float = 1.0
var elapsed: float = 0.0
var surface: ImmediateMesh

func configure(kind: String, facing: Vector3, attack_reach: float, warn_seconds: float) -> void:
	shape_kind = "line" if kind == "line" else "cone"
	reach = maxf(0.2, attack_reach)
	duration = maxf(0.15, warn_seconds)
	var horizontal: Vector3 = Vector3(facing.x, 0.0, facing.z).normalized()
	if horizontal.length_squared() < 0.01:
		horizontal = Vector3.FORWARD
	rotation.y = atan2(-horizontal.x, -horizontal.z)
	name = "AttackTelegraph_" + shape_kind
	add_to_group("outpost_attack_telegraphs")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface = ImmediateMesh.new()
	mesh = surface
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material_override = material
	surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	if shape_kind == "line":
		_draw_line()
	else:
		_draw_cone()
	surface.surface_end()
	set_process(true)

func _process(delta: float) -> void:
	elapsed = minf(duration, elapsed + maxf(0.0, delta))
	# The warning intensifies as the committed attack approaches.
	transparency = 0.22 * (1.0 - elapsed / duration)

func contains_position(point: Vector3) -> bool:
	if absf(point.y - global_position.y) > 1.7:
		return false
	var local: Vector3 = to_local(point)
	var forward: float = -local.z
	if forward < 0.0 or forward > reach:
		return false
	if shape_kind == "line":
		return absf(local.x) <= half_width
	return absf(atan2(local.x, forward)) <= half_angle

func _draw_line() -> void:
	var fill := Color(0.94, 0.07, 0.08, 0.39)
	var edge := Color(1.0, 0.22, 0.17, 0.94)
	_quad(Vector3(-half_width, 0, 0), Vector3(half_width, 0, 0),
		Vector3(half_width, 0, -reach), Vector3(-half_width, 0, -reach), fill)
	var rim: float = 0.12
	_quad(Vector3(-half_width, 0.006, 0), Vector3(-half_width + rim, 0.006, 0),
		Vector3(-half_width + rim, 0.006, -reach), Vector3(-half_width, 0.006, -reach), edge)
	_quad(Vector3(half_width - rim, 0.006, 0), Vector3(half_width, 0.006, 0),
		Vector3(half_width, 0.006, -reach), Vector3(half_width - rim, 0.006, -reach), edge)
	_quad(Vector3(-half_width, 0.006, -reach + rim), Vector3(half_width, 0.006, -reach + rim),
		Vector3(half_width, 0.006, -reach), Vector3(-half_width, 0.006, -reach), edge)

func _draw_cone() -> void:
	var fill := Color(0.94, 0.07, 0.08, 0.37)
	var edge := Color(1.0, 0.20, 0.17, 0.94)
	var inner: float = maxf(0.0, reach - 0.13)
	for i in range(ARC_STEPS):
		var a: float = lerpf(-half_angle, half_angle, float(i) / ARC_STEPS)
		var b: float = lerpf(-half_angle, half_angle, float(i + 1) / ARC_STEPS)
		var outer_a: Vector3 = _radial(a, reach, 0.0)
		var outer_b: Vector3 = _radial(b, reach, 0.0)
		_triangle(Vector3.ZERO, outer_a, outer_b, fill)
		_quad(_radial(a, inner, 0.007), _radial(b, inner, 0.007),
			_radial(b, reach, 0.007), _radial(a, reach, 0.007), edge)
	for angle in [-half_angle, half_angle]:
		var side: Vector3 = _radial(angle, reach, 0.009)
		var inner_side: Vector3 = _radial(angle, maxf(0.0, reach - 0.12), 0.009)
		_quad(Vector3.ZERO, side, inner_side, Vector3.ZERO, edge)

func _radial(angle: float, radius: float, height: float) -> Vector3:
	return Vector3(sin(angle) * radius, height, -cos(angle) * radius)

func _triangle(a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	for point in [a, b, c]:
		surface.surface_set_color(tint)
		surface.surface_add_vertex(point)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
	_triangle(a, b, c, tint)
	_triangle(a, c, d, tint)
