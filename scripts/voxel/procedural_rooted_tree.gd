extends RefCounted
## Seeded half-block trees with one foliage-atlas surface. Local coordinates
## stay independent of world addresses and ground contour is sampled per root.
const FOLIAGE = preload("res://scripts/voxel/foliage_renderer.gd")
const UNIT := 0.5
const DIRS: Array[Vector3i] = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.UP,Vector3i.DOWN,Vector3i.BACK,Vector3i.FORWARD]
const ROOT_DIRS: Array[Vector2i] = [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
const LEAVES := [4,5,6,7,8,9,10]

static func describe(source,cell: Vector2i) -> Dictionary:
	var digest := ("%d:%d:%d:rooted_tree_v1" % [source.seed,cell.x,cell.y]).sha256_buffer()
	var seed_value := int(digest[0]) | (int(digest[1])<<8) | (int(digest[2])<<16) | (int(digest[3])<<24)
	var ground: Dictionary = {}
	var base: int = source.height_at(cell.x,cell.y)
	for z in range(-3,4):
		for x in range(-3,4):
			var q := cell+Vector2i(floori(0.5+x*UNIT),floori(0.5+z*UNIT))
			ground[Vector2i(x,z)] = clampi((source.height_at(q.x,q.y)-base)*2,-2,2)
	return {"seed":seed_value,"species":FOLIAGE.species_at(cell.x,cell.y,source.seed),"ground":ground}

static func _fill(cells: Dictionary,at: Vector3i,size: Vector3i,tile: int,replace: bool = true) -> void:
	for y in range(at.y,at.y+size.y):
		for z in range(at.z,at.z+size.z):
			for x in range(at.x,at.x+size.x):
				var p := Vector3i(x,y,z)
				if replace or not cells.has(p): cells[p]=tile

static func _lobe(cells: Dictionary,center: Vector3i,radii: Vector3i,tile: int) -> void:
	for y in range(-radii.y,radii.y+1):
		for z in range(-radii.z,radii.z+1):
			for x in range(-radii.x,radii.x+1):
				if pow(float(x)/radii.x,2)+pow(float(y)/radii.y,2)+pow(float(z)/radii.z,2)>1.05: continue
				var p := center+Vector3i(x,y,z)
				if not cells.has(p): cells[p]=tile

static func generate(spec: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed=int(spec["seed"])
	var species: int = clampi(int(spec["species"]),0,6)
	var bark := FOLIAGE.BIRCH_BARK if species==FOLIAGE.BIRCH else FOLIAGE.PINE_BARK if species==FOLIAGE.PINE else FOLIAGE.MOSSY_BARK if species==FOLIAGE.TWILIGHT else FOLIAGE.OAK_BARK
	var leaf: int = LEAVES[species]
	var cells: Dictionary = {}
	var roots: Array[Vector3i] = []
	var h := rng.randi_range(9,12) if species!=FOLIAGE.PINE else rng.randi_range(12,16)
	var wide := species!=FOLIAGE.BIRCH and species!=FOLIAGE.PINE
	var half := 1 if wide else 0
	# Broad buttress base, taper into a continuous central trunk.
	_fill(cells,Vector3i(-1,-1,-1),Vector3i(3,3,3),bark)
	_fill(cells,Vector3i(-half,0,-half),Vector3i(half*2+1,h-3,half*2+1),bark)
	_fill(cells,Vector3i(0,h-3,0),Vector3i(1,4,1),bark)
	var terrain: Dictionary = spec["ground"]
	for direction in ROOT_DIRS:
		var length := rng.randi_range(2,3)
		var previous := 1
		for step in range(1,length+1):
			var p := direction*step
			var grade: int = terrain.get(p,0)
			var top := maxi(grade+1,previous-1)
			if step==length: top=grade+1
			for y in range(grade-1,top+1):
				var v := Vector3i(p.x,y,p.y)
				cells[v]=bark
				roots.append(v)
			previous=top
	# Seeded branch azimuth, length, vertical stagger and crown lobes.
	if species==FOLIAGE.PINE:
		for tier in range(5):
			var radius := 5-tier
			var y := h-5+tier*2
			_lobe(cells,Vector3i(0,y,0),Vector3i(radius,2,radius),leaf)
		_lobe(cells,Vector3i(0,h+5,0),Vector3i(1,2,1),leaf)
	else:
		for d in ROOT_DIRS:
			var length := rng.randi_range(2,3)
			var y := h-3+rng.randi_range(0,2)
			for step in range(1,length+1):
				var p := Vector3i(d.x*step,y+int(step/3),d.y*step)
				cells[p]=bark
				if step==1:
					cells[Vector3i(0,y,0)]=bark
				if step==3:
					cells[p-Vector3i.UP]=bark
			var crown := Vector3i(d.x*length,y+2,d.y*length)
			var radius := rng.randi_range(2,3) if wide else 2
			_lobe(cells,crown,Vector3i(radius,2,radius),leaf)
		_lobe(cells,Vector3i(0,h+2,0),Vector3i(4 if wide else 3,3,4 if wide else 3),leaf)
	return {"cells":cells,"roots":roots,"bark":bark,"trunk_width":float(half*2+1)*UNIT,"height":h*UNIT,"species":species}

static func _plane(p: Vector3i,face: int) -> int:
	if face<2: return p.x
	if face<4: return p.y
	return p.z

static func _uv(p: Vector3i,face: int) -> Vector2i:
	if face<2: return Vector2i(p.z,p.y)
	if face<4: return Vector2i(p.x,p.z)
	return Vector2i(p.x,p.y)

static func _point(face: int,plane: int,u: int,v: int) -> Vector3:
	var f := plane+1 if face%2==0 else plane
	var p := Vector3(f,v,u) if face<2 else (Vector3(u,f,v) if face<4 else Vector3(u,v,f))
	return p*UNIT-Vector3(UNIT*0.5,0,UNIT*0.5)

static func mesh_for(shape: Dictionary) -> MeshInstance3D:
	var cells: Dictionary = shape["cells"]
	var masks: Dictionary = {}
	var exposed := 0
	for p: Vector3i in cells:
		for face in range(6):
			if cells.has(p+DIRS[face]): continue
			var tile: int = cells[p]
			var key := Vector3i(face,_plane(p,face),tile)
			if not masks.has(key): masks[key]={}
			masks[key][_uv(p,face)]=true
			exposed+=1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	for key: Vector3i in masks:
		var mask: Dictionary = masks[key]
		var coordinates: Array = mask.keys()
		coordinates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.y<b.y if a.y!=b.y else a.x<b.x)
		for p: Vector2i in coordinates:
			if not mask.has(p): continue
			var width := 1
			while mask.has(p+Vector2i(width,0)): width+=1
			var height := 1
			while true:
				var full := true
				for dx in range(width):
					if not mask.has(p+Vector2i(dx,height)):
						full=false
						break
				if not full: break
				height+=1
			for dz in range(height):
				for dx in range(width): mask.erase(p+Vector2i(dx,dz))
			var a := _point(key.x,key.y,p.x,p.y)
			var b := _point(key.x,key.y,p.x+width,p.y)
			var c := _point(key.x,key.y,p.x+width,p.y+height)
			var d := _point(key.x,key.y,p.x,p.y+height)
			if (b-a).cross(c-a).dot(Vector3(DIRS[key.x]))>0:
				var swap := b
				b=d
				d=swap
			FOLIAGE._quad(st,a,b,c,d,key.z,[0.82,0.75,1.0,0.64,0.94,0.87][key.x])
			quads+=1
	var node := FOLIAGE.batched(st,"ProceduralRootedTree")
	node.set_meta("tree_quads",quads)
	node.set_meta("tree_exposed_faces",exposed)
	node.set_meta("tree_voxels",cells.size())
	return node
