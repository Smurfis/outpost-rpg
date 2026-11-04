extends Node3D
## Original low-cost voxel damage feedback. One MultiMesh draw-call per burst,
## no imported textures, particle shaders, or Godot editor scene dependencies.
const SHARD_COUNT_HIT: int = 9
const SHARD_COUNT_DEATH: int = 26
const DURATION: float = 0.72
var _lifetime: float = 0.0
var _birth: float = 0.0
var _parts: MultiMesh
var _offsets: Array[Vector3] = []
var _velocity: Array[Vector3] = []
var _drift: float = 0.0
var _caption: Label3D
var _damage: int = 0
var _tone: Color = Color.WHITE
var _lethal: bool = false

static func emit_feedback(parent: Node3D, at: Vector3, damage: float, tone: Color = Color("ffe1a0"), lethal: bool = false) -> Node3D:
	if parent == null:
		return null
	var feedback = load("res://scripts/vfx/pixel_feedback.gd").new()
	feedback.name = "PixelBurst"
	feedback.add_to_group("outpost_pixel_feedback")
	feedback._damage = maxi(0, roundi(damage))
	feedback._tone = tone
	feedback._lethal = lethal
	parent.add_child(feedback)
	feedback.global_position = at
	return feedback

func _ready() -> void:
	name = "PixelBurst"
	_birth = DURATION + (0.18 if _lethal else 0.0)
	_lifetime = _birth
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	_parts = MultiMesh.new()
	_parts.transform_format = MultiMesh.TRANSFORM_3D
	_parts.use_colors = true
	_parts.mesh = mesh
	var count: int = SHARD_COUNT_DEATH if _lethal else SHARD_COUNT_HIT
	_parts.instance_count = count
	var cloud := MultiMeshInstance3D.new()
	cloud.name = "PixelFragments"
	cloud.multimesh = _parts
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud)
	var random := RandomNumberGenerator.new()
	random.seed = (Time.get_ticks_usec() + get_instance_id()) % 2147483647
	for i in range(count):
		var offset := Vector3(
			random.randf_range(-0.38, 0.38),
			random.randf_range(-0.13, 0.45),
			random.randf_range(-0.38, 0.38)
		)
		var velocity := Vector3(
			random.randf_range(-2.2, 2.2),
			random.randf_range(1.8, 4.6) if _lethal else random.randf_range(1.0, 2.8),
			random.randf_range(-2.2, 2.2)
		)
		_offsets.append(offset)
		_velocity.append(velocity)
		_parts.set_instance_color(i, _tone.lerp(Color.WHITE, random.randf_range(0.0, 0.5)))
		_parts.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.17), offset))
	if _damage > 0:
		_caption = Label3D.new()
		_caption.name = "DamageNumber"
		_caption.text = "-%d" % _damage
		_caption.position = Vector3(0, 0.8, 0)
		_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_caption.no_depth_test = false
		_caption.font_size = 54
		_caption.pixel_size = 0.006
		_caption.modulate = _tone
		_caption.outline_modulate = Color("241a24")
		_caption.outline_size = 12
		add_child(_caption)

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	var t: float = _birth - _lifetime
	var shrink: float = maxf(0.04, 1.0 - t / _birth)
	for i in range(_offsets.size()):
		_offsets[i] += _velocity[i] * delta
		_velocity[i].y -= 7.0 * delta
		_parts.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.17 * shrink), _offsets[i]))
	if _caption != null:
		_caption.position.y = 0.80 + t * 1.15
		var fade: Color = _tone
		fade.a = minf(1.0, _lifetime * 3.2)
		_caption.modulate = fade
