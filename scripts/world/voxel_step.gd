extends RefCounted
## Per-creature voxel step solver. The physics body is moved only after its
## raised capsule, horizontal probe and landing normal all pass collision.
## The caller separately eases its visible model to avoid visible teleporting.
static func try_step(body: CharacterBody3D, horizontal_motion: Vector3, max_height: float) -> float:
	if max_height <= 0.0 or horizontal_motion.length_squared() < 0.000001:
		return 0.0
	var original: Transform3D = body.global_transform
	var rise_probe: Vector3 = Vector3.UP * (max_height + 0.06)
	if body.test_move(original, rise_probe):
		return 0.0
	var forward: Vector3 = horizontal_motion + horizontal_motion.normalized() * 0.48
	if body.test_move(original.translated(rise_probe), forward):
		return 0.0
	var landing_pos: Vector3 = original.origin + forward
	var from: Vector3 = landing_pos + Vector3.UP * (max_height + 0.24)
	var to: Vector3 = landing_pos - Vector3.UP * 0.22
	var query := PhysicsRayQueryParameters3D.create(from, to, body.collision_mask, [body.get_rid()])
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	if (hit.get("normal", Vector3.ZERO) as Vector3).dot(Vector3.UP) < 0.78:
		return 0.0
	var rise: float = float((hit["position"] as Vector3).y - original.origin.y)
	if rise < 0.06 or rise > max_height:
		return 0.0
	var raised: Transform3D = original.translated(Vector3.UP * (rise + 0.06))
	if body.test_move(raised, forward):
		return 0.0
	body.global_position = landing_pos + Vector3.UP * (rise + 0.06)
	body.velocity.y = 0.0
	body.apply_floor_snap()
	return rise
