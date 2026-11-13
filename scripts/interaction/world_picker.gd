extends RefCounted
## Pick-only geometry uses a separate layer; it never changes player collisions.
const PICK_LAYER: int = 16

static func attach(target: Node3D, kind: String) -> void:
	target.set_meta("world_kind", kind)
	target.add_to_group("world_interactables")
	var area := Area3D.new()
	area.name = "WorldPickGeometry"
	area.collision_layer = PICK_LAYER
	area.collision_mask = 0
	area.input_ray_pickable = false # The shared input router owns click/tap ordering.
	area.set_meta("world_target", target)
	target.add_child(area)
	_add_shapes(target, target, area)

static func _add_shapes(node: Node3D, target: Node3D, area: Area3D) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var shape := CollisionShape3D.new()
		shape.shape = node.mesh.create_trimesh_shape()
		if shape.shape is ConcavePolygonShape3D:
			shape.shape.backface_collision = true
		area.add_child(shape)
		shape.transform = target.global_transform.affine_inverse() * node.global_transform
	for child in node.get_children():
		if child is Node3D and child != area and not child is CollisionObject3D:
			_add_shapes(child, target, area)

static func resolve(game: Node3D, screen: Vector2) -> Dictionary:
	var origin: Vector3 = game.camera.project_ray_origin(screen)
	var direction: Vector3 = game.camera.project_ray_normal(screen)
	var end: Vector3 = origin + direction * game.camera.far
	var excluded: Array[RID] = [game.hero.get_rid()]
	var archipelago: Variant = null
	if game.terrain_surface != null:
		archipelago = game.terrain_surface.get("archipelago")
	# Gameplay colliders stay solid when a roof is culled visually.
	# Continue the *same* click ray past only the clipped roof triangles;
	# never exclude the whole island body, which also owns the cave floor.
	for _attempt in range(48):
		var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 2 | 8 | PICK_LAYER, excluded)
		query.collide_with_areas = true
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		if archipelago != null and archipelago.has_method("cutaway_hides_hit") and archipelago.cutaway_hides_hit(hit):
			origin = (hit.position as Vector3) + direction * 0.13
			if origin.distance_to(end) < 0.2:
				return {}
			continue
		var collider: Node3D = hit.collider
		var target: Node3D = collider.get_meta("world_target", collider)
		if not target.is_visible_in_tree() or (target.is_in_group("resources") and not target.active):
			excluded.append(collider.get_rid())
			continue
		while target != null and target != game:
			if target.has_meta("world_kind") or target.is_in_group("enemies"):
				hit["target"] = target
				return hit
			target = target.get_parent() as Node3D
		hit["target"] = null
		return hit
	return {}
