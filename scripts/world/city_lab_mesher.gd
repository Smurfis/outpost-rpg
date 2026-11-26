extends RefCounted
## Greedy meshing per 16-cube section. Occupancy queries cross section boundaries.
const SECTION := 16
const NORMALS: Array[Vector3i] = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.UP,Vector3i.DOWN,Vector3i.BACK,Vector3i.FORWARD]
const PALETTE: Array[Color] = [Color("#71855c"),Color("#a99b82"),Color("#777d83"),Color("#4d5158"),Color("#997452"),Color("#4c754c"),Color("#8e3c3e")]

func section_of(p: Vector3i) -> Vector3i:
	# Local bounded coordinates only; floor division handles negative Y.
	return Vector3i(floori(p.x/16.0),floori(p.y/16.0),floori(p.z/16.0))

func bucket(blocks: Dictionary) -> Dictionary:
	var sections: Dictionary = {}
	for p: Vector3i in blocks:
		var key := section_of(p)
		if not sections.has(key): sections[key] = []
		sections[key].append(p)
	return sections

func _plane(p: Vector3i, face: int) -> int:
	if face < 2: return p.x
	if face < 4: return p.y
	return p.z

func _uv(p: Vector3i, face: int) -> Vector2i:
	if face < 2: return Vector2i(p.z,p.y)
	if face < 4: return Vector2i(p.x,p.z)
	return Vector2i(p.x,p.y)

func _point(face: int, plane: int, u: int, v: int) -> Vector3:
	var f := plane+1 if face%2 == 0 else plane
	if face < 2: return Vector3(f,v,u)
	if face < 4: return Vector3(u,f,v)
	return Vector3(u,v,f)

func rectangles(blocks: Dictionary, cells: Array, key: Vector3i) -> Dictionary:
	var origin := key*SECTION
	var masks: Dictionary = {}
	var exposed := 0
	for p: Vector3i in cells:
		var local := p-origin
		for face in range(6):
			if blocks.has(p+NORMALS[face]): continue
			var group := Vector3i(face,_plane(local,face),int(blocks[p]))
			if not masks.has(group): masks[group] = {}
			masks[group][_uv(local,face)] = true
			exposed += 1
	var quads: Array = []
	for group: Vector3i in masks:
		var mask: Dictionary = masks[group]
		for v in range(SECTION):
			for u in range(SECTION):
				if not mask.has(Vector2i(u,v)): continue
				var w := 1
				while mask.has(Vector2i(u+w,v)): w += 1
				var h := 1
				while v+h < SECTION:
					var full := true
					for x in range(u,u+w):
						if not mask.has(Vector2i(x,v+h)):
							full = false
							break
					if not full: break
					h += 1
				for y in range(v,v+h):
					for x in range(u,u+w): mask.erase(Vector2i(x,y))
				quads.append([group,u,v,w,h])
	return {"quads":quads,"exposed":exposed}

func build_mesh(result: Dictionary) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for quad in result["quads"]:
		var group: Vector3i = quad[0]
		var u: int = quad[1]
		var v: int = quad[2]
		var w: int = quad[3]
		var h: int = quad[4]
		var points: Array[Vector3] = [
			_point(group.x,group.y,u,v),_point(group.x,group.y,u+w,v),
			_point(group.x,group.y,u+w,v+h),_point(group.x,group.y,u,v+h)]
		var normal := Vector3(NORMALS[group.x])
		# Godot uses clockwise front faces.
		var order := [0,1,2,0,2,3]
		if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0:
			order = [0,2,1,0,3,2]
		for index in order:
			surface.set_normal(normal)
			surface.set_color(PALETTE[group.z])
			surface.add_vertex(points[index])
	return surface.commit()
