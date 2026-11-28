extends "res://scripts/world/goblin_city_guard.gd"
const WORK = preload("res://scripts/world/goblin_village_work.gd")
var record: Dictionary
var route: Array
var job_clock := 0.0
var working := true

func _physics_process(delta: float) -> void:
	if not alive:
		super._physics_process(delta)
		return
	if hero==null: return
	working=not (_same_level() and hero.global_position.distance_to(global_position)<7.0)
	if not working:
		super._physics_process(delta)
		return
	_cancel_heavy_attack()
	var point := WORK.route_point(route,float(record.get("work",0.0)))
	var direction := Vector3(point.x-global_position.x,0,point.y-global_position.z)
	if direction.length()>0.12: direction=direction.normalized()
	else: direction=Vector3.ZERO
	velocity.x=direction.x*4.0
	velocity.z=direction.z*4.0
	velocity.y=-0.1 if is_on_floor() else velocity.y-18.0*delta
	move_and_slide()
	if direction.length_squared()>0.01:
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z),minf(1.0,delta*8.0))
	job_clock+=delta
	if avatar!=null:
		avatar.play_motion(direction.length()*3.0)
		if direction==Vector3.ZERO and job_clock>=1.2:
			var progress: float = float(record.get("work",0.0))/WORK.ROUND_SECONDS
			if progress>=0.4 and progress<=0.6: avatar.play_event("Attack")
			job_clock=0.0
