extends Node3D
## Small original voxel bubbles/ripples: one batched draw call per short splash.
## No alpha planes, heavy GPU particles, external assets or Android shaders.
const PARTICLES: int = 15
const LIFE: float = 0.75
var time_left: float = LIFE
var multimesh: MultiMesh
var offsets: Array[Vector3] = []
var velocities: Array[Vector3] = []

static func splash(parent: Node3D, at: Vector3) -> Node3D:
	if parent == null:
		return null
	var emitter := load("res://scripts/vfx/swimming_splashes.gd").new() as Node3D
	emitter.name = "SwimmingRippleBurst"
	emitter.add_to_group("outpost_swim_particles")
	parent.add_child(emitter)
	emitter.global_position = at
	return emitter

func _ready() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cube.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cube
	multimesh.instance_count = PARTICLES
	var emitter := MultiMeshInstance3D.new()
	emitter.name = "WaterPixelParticles"
	emitter.multimesh = multimesh
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	var random := RandomNumberGenerator.new()
	random.seed = (Time.get_ticks_usec() + get_instance_id()) % 2147483647
	for i in range(PARTICLES):
		var angle: float = TAU * float(i) / float(PARTICLES) + random.randf_range(-0.2, 0.2)
		var radius: float = random.randf_range(0.10, 0.52)
		var offset := Vector3(cos(angle) * radius, random.randf_range(-0.02, 0.10), sin(angle) * radius)
		var outward := Vector3(cos(angle), 0.0, sin(angle)) * random.randf_range(0.35, 1.35)
		offsets.append(offset)
		velocities.append(outward + Vector3.UP * random.randf_range(0.6, 1.8))
		multimesh.set_instance_color(i, Color("#8ee5f7").lerp(Color("#e3fcff"), random.randf_range(0.0, 0.65)))
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.095), offset))

func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	var progress: float = 1.0 - time_left / LIFE
	var size: float = 0.095 * maxf(0.05, 1.0 - progress)
	for i in range(offsets.size()):
		offsets[i] += velocities[i] * delta
		velocities[i].y -= 3.2 * delta
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), offsets[i]))
