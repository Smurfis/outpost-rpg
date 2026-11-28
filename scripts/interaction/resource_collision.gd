extends StaticBody3D
## Simple solids: one box for rocks, a trunk and raised canopy per tree.
## The physics capsule handles movement; no per-frame mesh height checks.
var visual_dimensions := Vector3.ONE

func configure(resource: Node3D, height: float, width: float) -> void:
	name = "ResourceCollision"
	collision_layer = 1
	collision_mask = 0
	if resource.get("kind") in ["stone", "iron", "coal", "clay"]:
		add_to_group("auto_hop_resources")
	var boxes: Array[AABB] = []
	_collect_bounds(resource, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return
	var bounds: AABB = boxes[0]
	for index in range(1, boxes.size()):
		bounds = bounds.merge(boxes[index])
	var bottom: float = minf(0.0, bounds.position.y)
	var dimensions := Vector3(bounds.size.x, bounds.end.y - bottom, bounds.size.z)
	if height > 0.0:
		dimensions.y = height
	if width > 0.0:
		dimensions.x = width
		dimensions.z = width
	visual_dimensions = dimensions
	if resource.get("kind") == "wood":
		var rooted: Variant = resource.get("rooted_tree")
		if rooted is Dictionary and not rooted.is_empty():
			_configure_rooted_tree(rooted)
			return
		# Bundles keep separate trunks instead of one invisible wall beneath
		# the combined foliage. Canopy remains solid when approached above.
		for child in resource.get_children():
			if not child is MeshInstance3D or child.mesh == null:
				continue
			var crown: AABB = child.transform * child.get_aabb()
			var base: float = minf(child.position.y, crown.position.y)
			var tree_height: float = crown.end.y - base
			if height > 0:
				tree_height *= height / maxf(bounds.end.y - bottom, 0.05)
			var clearance: float = minf(resource.tree_canopy_clearance, tree_height * 0.8)
			var crown_width := Vector2(crown.size.x, crown.size.z)
			if width > 0:
				crown_width *= width / maxf(bounds.size.x, bounds.size.z)
			_add_box(Vector3(crown.get_center().x, base + clearance + (tree_height - clearance) * 0.5, crown.get_center().z), Vector3(crown_width.x, tree_height - clearance, crown_width.y), "TreeCanopy")
			var trunk: float = resource.tree_trunk_width
			_add_box(Vector3(child.position.x, base + clearance * 0.5, child.position.z), Vector3(trunk * absf(child.scale.x), clearance + 0.05, trunk * absf(child.scale.z)), "TreeTrunk")
		return
	_add_box(Vector3(bounds.get_center().x, bottom + dimensions.y * 0.5, bounds.get_center().z), dimensions, "ResourceBox")

func _configure_rooted_tree(shape: Dictionary) -> void:
	# One trunk plus a buttress and at most twelve merged root columns.
	# Upper canopy remains a coarse solid, separate from walkable ground.
	var trunk: float = shape["trunk_width"]
	var cells: Dictionary = shape["cells"]
	var crown_min := Vector3.INF
	var crown_max := -Vector3.INF
	for p: Vector3i in cells:
		if int(cells[p])<4: continue
		var at := Vector3(p)*0.5-Vector3(0.25,0,0.25)
		crown_min=crown_min.min(at)
		crown_max=crown_max.max(at+Vector3.ONE*0.5)
	var clearance := maxf(1.85,crown_min.y)
	_add_box(Vector3(0,clearance*0.5,0),Vector3(trunk,clearance,trunk),"TreeTrunk")
	_add_box(Vector3(0,0.25,0),Vector3(1.5,0.5,1.5),"TreeButtress")
	var columns: Dictionary = {}
	for p: Vector3i in shape["roots"]:
		var key := Vector2i(p.x,p.z)
		var span: Vector2i = columns.get(key,Vector2i(p.y,p.y))
		columns[key]=Vector2i(mini(span.x,p.y),maxi(span.y,p.y))
	for key: Vector2i in columns:
		var span: Vector2i = columns[key]
		var low := float(span.x)*0.5
		var high := float(span.y+1)*0.5
		_add_box(Vector3(key.x*0.5,(low+high)*0.5,key.y*0.5),Vector3(0.5,high-low,0.5),"TreeRoot_%d_%d" % [key.x,key.y])
	if crown_min.is_finite() and crown_max.is_finite():
		_add_box((crown_min+crown_max)*0.5,crown_max-crown_min,"TreeCanopy")

func _add_box(at: Vector3, dimensions: Vector3, label: String) -> void:
	var box := BoxShape3D.new()
	box.size = dimensions.max(Vector3.ONE * 0.05)
	var collider := CollisionShape3D.new()
	collider.name = label
	collider.shape = box
	collider.position = at
	add_child(collider)

func _collect_bounds(node: Node3D, local: Transform3D, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(local * node.get_aabb())
	for child in node.get_children():
		if child is Node3D and not child is CollisionObject3D:
			_collect_bounds(child, local * child.transform, boxes)
