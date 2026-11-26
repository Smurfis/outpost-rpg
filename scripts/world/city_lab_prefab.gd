extends RefCounted
## Bounded voxel selections and versioned, data-only prefab assets.
const MAX_SIDE := 24
const MAX_VOLUME := 13824
const MIN_Y := -2
const MAX_Y := 31
const SIZE := 88

func bounds(a: Vector3i, b: Vector3i) -> AABB:
	var lo := Vector3i(mini(a.x,b.x),mini(a.y,b.y),mini(a.z,b.z))
	var hi := Vector3i(maxi(a.x,b.x),maxi(a.y,b.y),maxi(a.z,b.z))
	return AABB(Vector3(lo),Vector3(hi-lo+Vector3i.ONE))

func inside(p: Vector3i) -> bool:
	return p.x >= 0 and p.z >= 0 and p.x < SIZE and p.z < SIZE and p.y >= MIN_Y and p.y <= MAX_Y

func valid_size(s: Vector3i) -> bool:
	return s.x > 0 and s.y > 0 and s.z > 0 and s.x <= MAX_SIDE and s.y <= MAX_SIDE and s.z <= MAX_SIDE

func selection(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var box := bounds(a,b)
	var lo := Vector3i(box.position)
	var size := Vector3i(box.size)
	if not valid_size(size) or not inside(lo) or not inside(lo+size-Vector3i.ONE): return result
	for z in range(size.z):
		for y in range(size.y):
			for x in range(size.x):
				result.append(lo+Vector3i(x,y,z))
	return result

func capture(blocks: Dictionary, a: Vector3i, b: Vector3i) -> Dictionary:
	var cells := selection(a,b)
	if cells.is_empty(): return {}
	var box := bounds(a,b)
	var origin := Vector3i(box.position)
	var size := Vector3i(box.size)
	var voxels: Array = []
	for p in cells:
		if blocks.has(p):
			var q := p-origin
			voxels.append([q.x,q.y,q.z,int(blocks[p])])
	if voxels.is_empty(): return {}
	return {"schema_version":1,"size":[size.x,size.y,size.z],"voxels":voxels}

func _integer(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and absf(float(v)) <= 1000000.0

func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("schema_version",0) != 1: return {}
	var s: Variant = value.get("size")
	var v: Variant = value.get("voxels")
	if not s is Array or s.size() != 3 or not v is Array or v.is_empty() or v.size() > MAX_VOLUME: return {}
	for item in s:
		if not _integer(item): return {}
	var size := Vector3i(int(s[0]),int(s[1]),int(s[2]))
	if not valid_size(size): return {}
	var cells: Dictionary = {}
	for row in v:
		if not row is Array or row.size() != 4: return {}
		for item in row:
			if not _integer(item): return {}
		var p := Vector3i(int(row[0]),int(row[1]),int(row[2]))
		var material := int(row[3])
		if p.x < 0 or p.y < 0 or p.z < 0 or p.x >= size.x or p.y >= size.y or p.z >= size.z or material < 0 or material > 6 or cells.has(p): return {}
		cells[p] = material
	return {"size":size,"cells":cells}

func stamp(prefab: Dictionary, at: Vector3i, turns: int) -> Dictionary:
	var parsed := decode(prefab)
	if parsed.is_empty(): return {}
	var size: Vector3i = parsed["size"]
	var result: Dictionary = {}
	var rotation := posmod(turns,4)
	var rotated_size := Vector3i(size.z,size.y,size.x) if rotation%2 == 1 else size
	if not inside(at) or not inside(at+rotated_size-Vector3i.ONE): return {}
	for p: Vector3i in parsed["cells"]:
		var q := p
		match rotation:
			1: q = Vector3i(size.z-1-p.z,p.y,p.x)
			2: q = Vector3i(size.x-1-p.x,p.y,size.z-1-p.z)
			3: q = Vector3i(p.z,p.y,size.x-1-p.x)
		result[at+q] = parsed["cells"][p]
	return result
