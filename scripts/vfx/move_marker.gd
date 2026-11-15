extends MeshInstance3D
## A thin open gold ring: no disk, decal background or opaque centre.
var age: float = 0.0
const LIFETIME: float = 0.55

func _ready() -> void:
	name = "GoldMoveMarker"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.44
	ring.outer_radius = 0.48
	ring.rings = 4
	ring.ring_segments = 32
	mesh = ring
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gold.albedo_color = Color(0.83, 0.66, 0.32, 0.7)
	material_override = gold
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	age += delta
	var fraction: float = clampf(age / LIFETIME, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(0.55, 1.8, fraction)
	material_override.albedo_color.a = 0.7 * (1.0 - fraction)
	if age >= LIFETIME:
		queue_free()
