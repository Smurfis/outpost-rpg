extends "res://scripts/interaction/world_object.gd"
## Stationary, animated civilian. Stable interaction volume; no expensive
## navigation or combat simulation for this first guide replacement.
const HUMANOID = preload("res://scripts/creatures/cube_world_visual.gd")
var avatar: Node3D
var greeted := false
var attention := 0.0
var patrol: Array[Vector3] = []
var patrol_index := 0
var patrol_direction := 1
var dwell := 2.0

func configure_guide(ref: Node) -> bool:
	return configure_civilian(ref,"camp_guide","Outpost guide","human_male_2")

func configure_civilian(ref: Node,id: String,caption: String,kind: String) -> bool:
	var rig := HUMANOID.new()
	rig.name="AnimatedCivilian"
	if not rig.configure(kind,0.72):
		rig.free()
		return false
	avatar=rig
	set_meta("animated_npc",true)
	set_meta("nameplate_height",2.15)
	setup(ref,id,caption,"npc",rig)
	return true

func _process(delta: float) -> void:
	if not is_instance_valid(avatar) or not is_instance_valid(game) or not is_instance_valid(game.hero): return
	var offset: Vector3=game.hero.global_position-global_position
	var distance:=offset.length()
	var active:=distance<18.0
	# Animation overhead is only incurred close to the player.
	if avatar.animator!=null:
		avatar.animator.active=active
	if not active:
		greeted=false
		return
	attention=maxf(0.0,attention-delta)
	if distance>7.0: greeted=false
	if distance<4.5 and absf(offset.y)<1.5 and not greeted:
		greeted=true
		attention=2.0
		avatar.play_event("Wave","Yes")
	if (distance<4.5 or attention>0.0) and Vector2(offset.x,offset.z).length()>0.1:
		avatar.rotation.y=lerp_angle(avatar.rotation.y,atan2(-offset.x,-offset.z),1.0-exp(-8.0*delta))
	if attention<=0.0 and distance>4.5 and patrol.size()>1:
		dwell=maxf(0.0,dwell-delta)
		if dwell<=0.0:
			var goal: Vector3=patrol[patrol_index]
			var offset_to_goal:=goal-global_position
			if offset_to_goal.length()<0.06:
				if patrol_index==patrol.size()-1: patrol_direction=-1
				elif patrol_index==0: patrol_direction=1
				patrol_index+=patrol_direction
				dwell=1.5 if patrol_index==0 or patrol_index==patrol.size()-1 else 0.0
			else:
				global_position=global_position.move_toward(goal,delta*1.5)
				avatar.rotation.y=lerp_angle(avatar.rotation.y,atan2(-offset_to_goal.x,-offset_to_goal.z),1.0-exp(-8.0*delta))
				avatar.play_motion(1.5)
				return
	avatar.play_motion(0.0)

func interact(hero: Node3D) -> void:
	if not game.target_in_range(self): return
	attention=3.0
	greeted=true
	if is_instance_valid(avatar):
		avatar.play_event("Yes","Wave")
	super.interact(hero)
