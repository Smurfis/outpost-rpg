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

static func _cave_screen_pick(game: Node3D, screen: Vector2, remote: Variant,
		ray_origin: Vector3, ray_end: Vector3) -> Dictionary:
	# Only assist clicks while truly standing at the altitude of a carved
	# cave. Above-ground players cannot select through hidden mountain rock.
	if remote == null or remote.terrain == null:
		return {}
	var cave = remote.terrain.caves
	var hero: Vector3 = game.hero.global_position
	var hero_floor: int = cave.floor_at(floori(hero.x), floori(hero.z))
	if hero_floor == -99999 or absf(hero.y - float(hero_floor)) > 2.0:
		return {}
	# Pick-only areas give chests / interactables priority over ground and
	# avoid the invisible stone colliders that shader clipping leaves behind.
	var pick_ray := PhysicsRayQueryParameters3D.create(
		ray_origin, ray_end, PICK_LAYER, [game.hero.get_rid()])
	pick_ray.collide_with_areas = true
	var picked: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(pick_ray)
	if not picked.is_empty():
		var collider: Variant = picked.get("collider")
		if collider is CollisionObject3D:
			var object: Variant = collider.get_meta("world_target", null)
			if object is Node3D and is_instance_valid(object) and object.is_visible_in_tree():
				var at: Vector3 = object.global_position
				if at.distance_to(hero) < 12.0 and cave.has_cave(floori(at.x), floori(at.z)):
					picked["target"] = object
					return picked
	# For a click inside the cave, the camera ray can hit a solid outer
	# cliff even though the floor target is on screen. Choose the CLOSEST
	# projected carved-floor voxel, never a guessed point through rock.
	var closest: float = 25.0 # Pixels, enough for half a voxel at 19m zoom.
	var result: Dictionary = {}
	for x in range(floori(hero.x) - 8, floori(hero.x) + 9):
		for z in range(floori(hero.z) - 8, floori(hero.z) + 9):
			var floor_y: int = cave.floor_at(x, z)
			if floor_y == -99999:
				continue
			if not remote.terrain.is_solid(x, floor_y - 1, z) or remote.terrain.is_solid(x, floor_y + 1, z):
				continue
			var point := Vector3(float(x) + 0.5, float(floor_y) + 0.10, float(z) + 0.5)
			if game.camera.is_position_behind(point):
				continue
			var difference: float = game.camera.unproject_position(point).distance_to(screen)
			if difference < closest:
				closest = difference
				result = {"position": point, "normal": Vector3.UP, "target": null, "cave_pick": true}
	return result


static func resolve(game: Node3D, screen: Vector2) -> Dictionary:
	var origin: Vector3 = game.camera.project_ray_origin(screen)
	var direction: Vector3 = game.camera.project_ray_normal(screen)
	var end: Vector3 = origin + direction * game.camera.far
	var excluded: Array[RID] = [game.hero.get_rid()]
	var archipelago: Variant = null
	if game.terrain_surface != null:
		archipelago = game.terrain_surface.get("archipelago")
	var cave_fallback: Dictionary = _cave_screen_pick(game, screen, archipelago, origin, end)
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
		# When the camera's ray hits a front-facing solid island wall but
		# the click projects onto an actual carved cave floor, use that
		# nearby floor. Never skip collision in the movement planner.
		if not cave_fallback.is_empty() and collider.name.begins_with("IslandCollision_"):
			return cave_fallback
		return hit
	return cave_fallback
