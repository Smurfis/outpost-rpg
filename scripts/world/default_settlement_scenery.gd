extends RefCounted
## All low countryside dressing for a chunk uses one shared-atlas mesh.
## No collisions, interaction targets, per-plant nodes or additional textures.
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")

static func build(plan, key: Vector2i, size: int) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for z in range(key.y,key.y+size):
		for x in range(key.x,key.x+size):
			var cell := Vector2i(x,z)
			if not plan.scenery.has(cell): continue
			var spec: Dictionary = plan.scenery[cell]
			var at := Vector3(x-key.x+0.5,float(spec["height"]),z-key.y+0.5)
			var variant: int = spec["variant"]
			match str(spec["kind"]):
				"crop":
					var height := 0.40+float(variant)*0.12
					var tint := Color(1.0,0.85,0.35) if variant==0 else Color(0.9,1.0,0.55)
					for offset in [-0.21,0.21]:
						PALETTE.box(surface,at+Vector3(float(offset),height*0.5,0),Vector3(0.15,height,0.15),9,9,3,tint)
						PALETTE.box(surface,at+Vector3(float(offset),height,0),Vector3(0.22,0.18,0.22),1,1,1,tint)
				"flowers":
					var tint := [Color(1.0,0.77,0.3),Color(1.0,0.55,0.8),Color(0.75,0.78,1.0)][variant] as Color
					PALETTE.box(surface,at+Vector3(0,0.12,0),Vector3(0.10,0.24,0.10),9,9)
					PALETTE.box(surface,at+Vector3(0,0.26,0),Vector3(0.22,0.13,0.22),14,14,14,tint)
				"waystone":
					PALETTE.box(surface,at+Vector3(0,0.12,0),Vector3(0.46,0.24,0.46),12,12)
					PALETTE.box(surface,at+Vector3(0,0.43,0),Vector3(0.27,0.42,0.27),4,12)
				_: continue
			count+=1
	if count==0: return null
	var node := PALETTE.as_instance(surface,"Countryside_%d_%d" % [key.x,key.y])
	node.position=Vector3(key.x,0,key.y)
	node.set_meta("scenery_count",count)
	return node
