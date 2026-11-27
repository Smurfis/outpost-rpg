extends RefCounted
## Half-height physical treads on existing integer terrain. One mesh and
## one static body per populated chunk, not one rendered node per step.
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")

static func build(plan,key: Vector2i,size: int) -> Array:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name="RoadStepCollision"
	body.collision_layer=1
	body.collision_mask=0
	body.position=Vector3(key.x,0,key.y)
	var count := 0
	for z in range(key.y,key.y+size):
		for x in range(key.x,key.x+size):
			var cell := Vector2i(x,z)
			if not plan.road_steps.has(cell): continue
			var spec: Dictionary = plan.road_steps[cell]
			var d: Vector2i = spec["direction"]
			var at := Vector3(x-key.x+0.5+d.x*0.25,float(spec["height"])+0.25,z-key.y+0.5+d.y*0.25)
			var dimensions := Vector3(0.5 if d.x!=0 else 1.0,0.5,0.5 if d.y!=0 else 1.0)
			PALETTE.box(surface,at,dimensions,5,5,4)
			var shape := BoxShape3D.new()
			shape.size=dimensions
			var collider := CollisionShape3D.new()
			collider.shape=shape
			collider.position=at
			body.add_child(collider)
			count+=1
	if count==0:
		body.free()
		return []
	var mesh := PALETTE.as_instance(surface,"RoadHalfSteps")
	mesh.position=body.position
	body.set_meta("road_step_count",count)
	return [mesh,body]
