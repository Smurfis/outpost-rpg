extends Node3D
## Short-lived, world-space wake marks. One mesh, no collision or physics.
const LIFE := 0.8
var age := 0.0
var art: MeshInstance3D
static var shared_mesh: ArrayMesh
static var shared_material: StandardMaterial3D

static func spawn(parent: Node3D, at: Vector3, heading: float, contact: bool = false) -> void:
	if parent==null: return
	var mark := preload("res://scripts/vfx/rowboat_wake.gd").new() as Node3D
	parent.add_child(mark)
	mark.global_position=at
	mark.rotation.y=heading
	if contact: mark.scale=Vector3(1.4,1.0,1.4)

func _ready() -> void:
	if shared_mesh==null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Two broken chevrons, trailing toward local +Z.
		for side in [-1.0,1.0]:
			for row in range(2):
				var a := Vector3(side*(0.24+row*0.18),0,float(row)*0.26)
				var b := Vector3(side*(0.70+row*0.18),0,0.36+row*0.26)
				var offset := Vector3(0,0,0.055)
				for v in [a,b,b+offset,a,b+offset,a+offset]: st.add_vertex(v)
		shared_mesh=st.commit()
		shared_material=StandardMaterial3D.new()
		shared_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_material.cull_mode=BaseMaterial3D.CULL_DISABLED
		shared_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		shared_material.albedo_color=Color(0.76,0.94,1.0,0.8)
	art=MeshInstance3D.new()
	art.mesh=shared_mesh
	art.material_override=shared_material
	art.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(art)

func _process(delta: float) -> void:
	age+=delta
	if age>=LIFE:
		queue_free()
		return
	var progress := age/LIFE
	art.scale=Vector3(1.0+progress*0.65,1.0,1.0+progress*0.3)
	art.transparency=progress
