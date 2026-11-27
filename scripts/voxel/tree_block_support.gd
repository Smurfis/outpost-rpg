extends RefCounted
## Pure support solver for individually mineable procedural tree voxels.
## The caller must transactionally apply the returned removals, update
## collision/pick geometry and award timber. Leaves never support timber.
const TREE = preload("res://scripts/voxel/procedural_rooted_tree.gd")

static func cut(shape: Dictionary,ground: Dictionary,cell: Vector3i) -> Dictionary:
	var original: Dictionary = shape["cells"]
	var bark: int = shape["bark"]
	if not original.has(cell) or int(original[cell])!=bark: return {}
	var remaining: Dictionary = original.duplicate()
	remaining.erase(cell)
	var supported: Dictionary = {}
	var queue: Array[Vector3i] = []
	for p: Vector3i in remaining:
		if int(remaining[p])!=bark: continue
		var floor_y: int = ground.get(Vector2i(p.x,p.z),0)
		if p.y<=floor_y-1:
			supported[p]=true
			queue.append(p)
	var cursor := 0
	while cursor<queue.size():
		var p: Vector3i = queue[cursor]
		cursor+=1
		for d: Vector3i in TREE.DIRS:
			var q := p+d
			if remaining.get(q,-1)!=bark or supported.has(q): continue
			supported[q]=true
			queue.append(q)
	var detached: Array[Vector3i] = []
	for p: Vector3i in remaining:
		if int(remaining[p])==bark and not supported.has(p): detached.append(p)
	for p in detached: remaining.erase(p)
	# Leaf connectivity may follow retained wood but cannot reattach a branch.
	cursor=0
	while cursor<queue.size():
		var p: Vector3i = queue[cursor]
		cursor+=1
		for d: Vector3i in TREE.DIRS:
			var q := p+d
			if not remaining.has(q) or supported.has(q): continue
			supported[q]=true
			queue.append(q)
	var leaves: Array[Vector3i] = []
	for p: Vector3i in remaining:
		if not supported.has(p): leaves.append(p)
	for p in leaves: remaining.erase(p)
	return {"remaining":remaining,"cut":cell,"detached_wood":detached,"detached_leaves":leaves,"wood_units":1+detached.size()}
