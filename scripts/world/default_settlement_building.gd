extends Node3D
## Built-in roofed architecture, separate visibility and movement collision.
## A building is a small immutable prefab, not one node per voxel.
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const DIRS: Array[Vector3i] = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.UP,Vector3i.DOWN,Vector3i.BACK,Vector3i.FORWARD]
var spec: Dictionary
var parts: Dictionary = {}
var voxels: Dictionary = {}
var groups: Dictionary = {}
var view_mask := -1
var quad_count := 0
var exposed_count := 0

func _put(p: Vector3i, tile: int, group: int) -> void:
	voxels[p] = tile
	groups[p] = group

func build(item: Dictionary, source) -> void:
	spec = item
	var rect: Rect2i = item["rect"]
	var floor_y: int = item["floor"]
	var door: Vector2i = item["door"]
	var direction: Vector2i = item["direction"]
	var wall_h := 5 if item["kind"]=="watchtower" else 3
	var wall_tile := 12 if item["kind"] in ["watchtower","smithy"] else 11
	var roof_tile := 4 if item["kind"] in ["watchtower","smithy"] else 8
	position = Vector3(rect.position.x,floor_y,rect.position.y)
	for z in range(rect.size.y):
		for x in range(rect.size.x):
			var cell := rect.position+Vector2i(x,z)
			var depth: int = source.height_at(cell.x,cell.y)-floor_y
			for y in range(depth,0): _put(Vector3i(x,y,z),12,0)
			var wall_group := 0
			if x==0: wall_group=1
			elif x==rect.size.x-1: wall_group=2
			elif z==0: wall_group=3
			elif z==rect.size.y-1: wall_group=4
			if wall_group>0:
				var is_door: bool = (cell.x-door.x)*direction.x+(cell.y-door.y)*direction.y==0 and cell.distance_squared_to(door)<=1
				for y in range(wall_h):
					if is_door and y<3: continue
					_put(Vector3i(x,y,z),wall_tile,wall_group)
			# Roof is a distinct visual group; collision remains solid.
			_put(Vector3i(x,wall_h,z),roof_tile,5)
	# Raised parapet on the watchtower; simple pitched stepped roofs on homes.
	if item["kind"]=="watchtower":
		for x in range(7):
			for z in range(7):
				if (x in [0,6] or z in [0,6]) and (x+z)%2==0:
					_put(Vector3i(x,wall_h+1,z),12,5)
	else:
		for inset in range(1,3):
			for z in range(7):
				for x in range(inset,7-inset):
					_put(Vector3i(x,wall_h+inset,z),roof_tile,5)
	_build_groups()

func _plane(p: Vector3i, face: int) -> int:
	if face<2: return p.x
	if face<4: return p.y
	return p.z

func _uv(p: Vector3i, face: int) -> Vector2i:
	if face<2: return Vector2i(p.z,p.y)
	if face<4: return Vector2i(p.x,p.z)
	return Vector2i(p.x,p.y)

func _point(face: int, plane: int, u: int, v: int) -> Vector3:
	var f := plane+1 if face%2==0 else plane
	if face<2: return Vector3(f,v,u)
	if face<4: return Vector3(u,f,v)
	return Vector3(u,v,f)

func _build_groups() -> void:
	# Merge only same material, direction, plane and cutaway group.
	# Keep inter-group faces so hiding a wall exposes its neighbour's cap.
	var masks: Dictionary = {}
	for p: Vector3i in voxels:
		for face in range(6):
			var q := p+DIRS[face]
			if voxels.has(q) and groups[q]==groups[p]: continue
			var key := Vector4i(groups[p],face,_plane(p,face),voxels[p])
			if not masks.has(key): masks[key]={}
			masks[key][_uv(p,face)] = true
			exposed_count += 1
	var surfaces: Dictionary = {}
	for key: Vector4i in masks:
		if not surfaces.has(key.x):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[key.x] = surface
		var mask: Dictionary = masks[key]
		var cells: Array = mask.keys()
		cells.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.y<b.y if a.y!=b.y else a.x<b.x)
		for cell: Vector2i in cells:
			if not mask.has(cell): continue
			var w := 1
			while mask.has(cell+Vector2i(w,0)): w+=1
			var h := 1
			while true:
				var complete := true
				for dx in range(w):
					if not mask.has(cell+Vector2i(dx,h)):
						complete=false
						break
				if not complete: break
				h+=1
			for dz in range(h):
				for dx in range(w): mask.erase(cell+Vector2i(dx,dz))
			var a := _point(key.y,key.z,cell.x,cell.y)
			var b := _point(key.y,key.z,cell.x+w,cell.y)
			var c := _point(key.y,key.z,cell.x+w,cell.y+h)
			var d := _point(key.y,key.z,cell.x,cell.y+h)
			if (b-a).cross(c-a).dot(Vector3(DIRS[key.y]))>0:
				var swap := b
				b=d
				d=swap
			var axes := "x" if key.y<2 else ("top" if key.y<4 else "z")
			GREEDY.tiled_quad(surfaces[key.x],a,b,c,d,key.w,axes)
			quad_count+=1
	for group in surfaces:
		var mesh := MeshInstance3D.new()
		mesh.name = "SettlementPart_%d" % group
		mesh.mesh = PALETTE.create_mesh(surfaces[group])
		mesh.material_override = GREEDY.material()
		add_child(mesh)
		var body := StaticBody3D.new()
		body.name = "SettlementCollision_%d" % group
		body.collision_layer = 1
		body.collision_mask = 1
		var collider := CollisionShape3D.new()
		var shape: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
		shape.backface_collision = true
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
		parts[group] = {"mesh":mesh,"body":body}

func update_view(hero: Vector3, eye: Vector3) -> void:
	var rect: Rect2i = spec["rect"]
	var cell := Vector2i(floori(hero.x),floori(hero.z))
	var floor_y: int = spec["floor"]
	var inside: bool = rect.has_point(cell) and hero.y>=float(floor_y)-0.2 and hero.y<float(floor_y)+2.5
	var hidden := 0
	if inside:
		hidden |= 1<<5
		var toward := Vector2(eye.x-hero.x,eye.z-hero.z).normalized()
		if toward.x < -0.25: hidden |= 1<<1
		if toward.x > 0.25: hidden |= 1<<2
		if toward.y < -0.25: hidden |= 1<<3
		if toward.y > 0.25: hidden |= 1<<4
	if hidden==view_mask: return
	view_mask=hidden
	for group in parts:
		var hide_part: bool = (hidden & (1<<int(group)))!=0
		parts[group]["mesh"].visible = not hide_part
		# Existing WorldPicker already honors this flag. Movement layer stays 1.
		parts[group]["body"].set_meta("building_cutaway_hidden",hide_part)
