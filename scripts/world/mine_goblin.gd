extends "res://scripts/dungeons/dungeon_guardian.gd"
const CAVE_PATH = preload("res://scripts/navigation/fractal_cave_path.gd")
signal slain
var terrain
var last_from := Vector2i.MAX
var last_to := Vector2i.MAX
var waypoints := PackedVector3Array()

func _underground() -> bool:
	var p := hero.global_position
	var cell := Vector2i(floori(p.x),floori(p.z))
	var floor_y: int = terrain.caves.floor_at(cell.x,cell.y)
	return absf(p.y-floor_y)<1.75 and p.y+1 < terrain.height_at(cell.x,cell.y)

func melee_visible() -> bool:
	if not _underground() or absf(hero.global_position.y-global_position.y)>1.6:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,hero.global_position+Vector3.UP,1,[get_rid(),hero.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func pursuit_direction(to_player: Vector3) -> Vector3:
	if not _underground():
		return Vector3.ZERO
	var from := Vector2i(floori(global_position.x),floori(global_position.z))
	var to := Vector2i(floori(hero.global_position.x),floori(hero.global_position.z))
	if from != last_from or to != last_to:
		last_from = from
		last_to = to
		waypoints = CAVE_PATH._branch_path(terrain.caves,from,to,hero.global_position)
	if waypoints.is_empty():
		return Vector3.ZERO
	var step := waypoints[0]-global_position
	step.y = 0
	return step.normalized() if from != to else to_player.normalized()

func receive_damage(amount: float) -> void:
	var was_alive := alive
	super.receive_damage(amount)
	if was_alive and not alive:
		slain.emit()

func _exit_tree() -> void:
	_cancel_heavy_attack()
