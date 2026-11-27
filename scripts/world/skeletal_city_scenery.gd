extends RefCounted
## Bounded original voxel art, one batched mesh per populated chunk.
## Decorative ribs and crystals stay along chamber edges, never on centreline.
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")

static func build(plan,key: Vector2i,size: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for p: Vector2i in plan.scenery:
		if not Rect2i(key,Vector2i.ONE*size).has_point(p): continue
		var spec: Dictionary = plan.scenery[p]
		var at := Vector3(p.x-key.x+0.5,float(spec["height"]),p.y-key.y+0.5)
		match str(spec["kind"]):
			"crystal":
				PALETTE.box(st,at+Vector3(0,0.18,0),Vector3(0.9,0.36,0.9),12,4)
				for i in range(3):
					var h := 0.65+float(i)*0.34
					var offset := Vector3(float(i-1)*0.23,h*0.5+0.3,float(i%2)*0.18)
					PALETTE.box(st,at+offset,Vector3(0.26,h,0.28),13,13,13,Color("#9bdaff"))
					PALETTE.box(st,at+offset+Vector3.UP*(h*0.5+0.08),Vector3(0.15,0.16,0.16),13,13)
			"rib":
				var side := -1.0 if p.y<plan.heart.y else 1.0
				for i in range(6):
					var inward := floorf(float(i)*0.55)*0.32
					PALETTE.box(st,at+Vector3(0,0.4+float(i)*0.55,-side*inward),Vector3(0.46,0.68,0.54),12,12,12,Color("#d7cbb0"))
			"bones":
				PALETTE.box(st,at+Vector3(0,0.12,0),Vector3(0.76,0.22,0.18),12,12,12,Color("#e1d6b9"))
				PALETTE.box(st,at+Vector3(0.19,0.24,0.23),Vector3(0.42,0.36,0.38),12,12,12,Color("#d7cbb0"))
				for side in [-1.0,1.0]:
					PALETTE.box(st,at+Vector3(0.19+float(side)*0.1,0.28,0.035),Vector3(0.07,0.09,0.025),15,15)
		count+=1
	if count==0: return null
	var art := PALETTE.as_instance(st,"SkeletalCavern_%d_%d" % [key.x,key.y])
	art.position=Vector3(key.x,0,key.y)
	return art
