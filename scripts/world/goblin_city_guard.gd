extends "res://scripts/world/mine_goblin.gd"
## Preview-only encounter. No persistent loot, dungeon clear or quest credit.
var underground_guard := true
var skeletal_guard := false
var home := Vector3.ZERO

func _same_level() -> bool:
	if hero==null: return false
	var p: Vector3 = hero.global_position
	var city = terrain.skeletal_city if skeletal_guard else terrain.goblin_city
	if city==null or not city.contains(Vector2i(floori(p.x),floori(p.z))): return false
	var cell := Vector2i(floori(p.x),floori(p.z))
	var in_cave: bool = city.floors.has(cell) and absf(p.y-float(city.floors.get(cell,-99999)))<1.75 and p.y<terrain.height_at(cell.x,cell.y)-1.0
	return in_cave==underground_guard and absf(p.y-global_position.y)<2.0

func melee_visible() -> bool:
	if not _same_level(): return false
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,hero.global_position+Vector3.UP,1,[get_rid(),hero.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func pursuit_direction(to_player: Vector3) -> Vector3:
	if not _same_level() or global_position.distance_to(home)>12.0: return Vector3.ZERO
	if underground_guard: return super.pursuit_direction(to_player)
	return to_player.normalized()
