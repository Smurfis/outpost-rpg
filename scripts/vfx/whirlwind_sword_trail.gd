extends MeshInstance3D
## Original Outpost sword-ribbon VFX. Tracks actual moving blade points during a
## two-turn character spin; a short translucent golden trail follows the sword.
## No particles, downloaded art, per-frame mesh resources, or gameplay hitboxes.
const MAX_SAMPLES: int = 18
var _blade: Node3D
var _duration: float = 0.90
var _elapsed: float = 0.0
var _trail_mesh: ImmediateMesh
var _ribbon_material: StandardMaterial3D
var _bases: Array[Vector3] = []
var _tips: Array[Vector3] = []

func begin(blade: Node3D, duration: float = 0.90) -> void:
	_blade = blade
	_duration = maxf(0.2, duration)
	_elapsed = 0.0
	_bases.clear()
	_tips.clear()
	name = "WhirlwindSwordTrail"
	add_to_group("outpost_whirlwind_trails")
	_trail_mesh = ImmediateMesh.new()
	mesh = _trail_mesh
	_ribbon_material = StandardMaterial3D.new()
	_ribbon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ribbon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ribbon_material.vertex_color_use_as_albedo = true
	_ribbon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ribbon_material.no_depth_test = false
	material_override = _ribbon_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_process(true)

func _process(delta: float) -> void:
	if not is_instance_valid(_blade) or _trail_mesh == null:
		queue_free()
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed > _duration + 0.20:
		queue_free()
		return
	# The model's local +Y is hilt -> blade tip. Record points in this
	# mesh's local space, so a rotating player leaves a true world-space trail.
	if _elapsed <= _duration:
		_bases.append(to_local(_blade.to_global(Vector3(0.0, 0.22, 0.0))))
		_tips.append(to_local(_blade.to_global(Vector3(0.0, 1.08, 0.0))))
		if _tips.size() > MAX_SAMPLES:
			_tips.pop_front()
			_bases.pop_front()
	_draw_ribbon()

func _draw_ribbon() -> void:
	_trail_mesh.clear_surfaces()
	if _tips.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _ribbon_material)
	var n: int = _tips.size()
	var vanish: float = clampf((_duration + 0.20 - _elapsed) / 0.20, 0.0, 1.0)
	for i in range(n - 1):
		var age: float = float(i + 1) / float(n)
		var alpha: float = 0.72 * age * age * vanish
		var golden: Color = Color(1.0, 0.60 + 0.33 * age, 0.19 + 0.56 * age, alpha)
		var bright: Color = Color(1.0, 0.95, 0.67, alpha * 0.78)
		# Two triangles form a blade-length ribbon segment. The old edge
		# fades to clear; the leading edge follows the real spinning sword.
		_vertex(_bases[i], golden * Color(1, 1, 1, 0.45))
		_vertex(_tips[i], golden)
		_vertex(_tips[i + 1], bright)
		_vertex(_bases[i], golden * Color(1, 1, 1, 0.45))
		_vertex(_tips[i + 1], bright)
		_vertex(_bases[i + 1], bright * Color(1, 1, 1, 0.45))
	_trail_mesh.surface_end()

func _vertex(point: Vector3, tint: Color) -> void:
	_trail_mesh.surface_set_color(tint)
	_trail_mesh.surface_add_vertex(point)
