extends StaticBody3D
## One inexpensive solid per harvestable. No per-frame height checks or
## triangle collision meshes; the physics capsule handles jumping/landing.

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
	var box := BoxShape3D.new()
	box.size = dimensions.max(Vector3.ONE * 0.05)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position = Vector3(bounds.get_center().x, bottom + box.size.y * 0.5, bounds.get_center().z)
	add_child(collider)

func _collect_bounds(node: Node3D, local: Transform3D, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(local * node.get_aabb())
	for child in node.get_children():
		if child is Node3D and not child is CollisionObject3D:
			_collect_bounds(child, local * child.transform, boxes)
