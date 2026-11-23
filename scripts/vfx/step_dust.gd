extends Node3D
## One brief terrain-coloured, batched cube puff after a real voxel step.
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const COUNT := 10
const LIFE := 0.36
static var atlas_image: Image
static var coast_image: Image
var remaining := LIFE
var parts: MultiMesh
var offsets: Array[Vector3] = []
var velocities: Array[Vector3] = []
var tone := Color("9b977e")

static func puff(parent: Node3D, at: Vector3, direction: Vector3, tile: int) -> void:
	if parent == null:
		return
	var effect = load("res://scripts/vfx/step_dust.gd").new()
	effect.tone = tile_colour(tile).darkened(0.24)
	parent.add_child(effect)
	effect.global_position = at - direction.normalized() * 0.27

static func tile_colour(tile: int) -> Color:
	if tile >= 16 and tile <= 19:
		if coast_image == null:
			coast_image = PALETTE.coast_texture().get_image()
		return coast_image.get_pixel(((tile - 16) % 2) * 16 + 8, floori(float(tile - 16) / 2.0) * 16 + 8)
	if atlas_image == null:
		atlas_image = PALETTE.get_material().albedo_texture.get_image()
	var id := clampi(tile, 0, 15)
	return atlas_image.get_pixel((id % 4) * 16 + 8, floori(float(id) / 4.0) * 16 + 8)

func _ready() -> void:
	add_to_group("outpost_step_dust")
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cube.material = material
	parts = MultiMesh.new()
	parts.transform_format = MultiMesh.TRANSFORM_3D
	parts.use_colors = true
	parts.mesh = cube
	parts.instance_count = COUNT
	var cloud := MultiMeshInstance3D.new()
	cloud.multimesh = parts
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud)
	var random := RandomNumberGenerator.new()
	random.seed = Time.get_ticks_usec() + get_instance_id()
	for index in COUNT:
		var angle := TAU * float(index) / COUNT + random.randf_range(-0.2, 0.2)
		var offset := Vector3(cos(angle) * 0.12, 0.04, sin(angle) * 0.12)
		offsets.append(offset)
		velocities.append(Vector3(cos(angle), 0, sin(angle)) * random.randf_range(0.45, 1.2) + Vector3.UP * random.randf_range(0.35, 0.9))
		parts.set_instance_color(index, tone.lerp(Color.WHITE, random.randf_range(0.0, 0.16)))
		parts.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ONE * 0.11), offset))

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0:
		queue_free()
		return
	var size := 0.11 * remaining / LIFE
	for index in COUNT:
		offsets[index] += velocities[index] * delta
		velocities[index].y -= 3.0 * delta
		parts.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ONE * size), offsets[index]))
