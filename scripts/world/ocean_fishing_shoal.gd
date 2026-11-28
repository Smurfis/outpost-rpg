extends Node3D
## Small deterministic school. One MultiMesh draw, bounded local boid simulation.
const PICKER = preload("res://scripts/interaction/world_picker.gd")
const PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
const COUNT := 8
const OCEAN = preload("res://scripts/world/ocean_surface.gd")
var game: Node
var rank := 0
var points: Array[Vector2] = []
var velocities: Array[Vector2] = []
var school: MultiMesh
var ring: MeshInstance3D
var elapsed := 0.0
var bite_at := -1.0
var cooldown := 0.0
var rng := RandomNumberGenerator.new()

func configure(ref: Node, seed_value: int, rarity: int) -> void:
	game=ref
	rank=clampi(rarity,0,4)
	rng.seed=seed_value
	set_meta("world_action","Fish")
	set_meta("display_name",["Common","Uncommon","Rare","Epic","Legendary"][rank]+" fishing shoal")
	ring=MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius=1.15
	torus.outer_radius=1.22
	torus.rings=24
	torus.ring_segments=8
	ring.mesh=torus
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=[Color("#d1d5d4"),Color("#70d381"),Color("#75b8ff"),Color("#c98af4"),Color("#ffce68")][rank]
	ring.material_override=material
	add_child(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	PALETTE.box(st,Vector3.ZERO,Vector3(0.42,0.20,0.75),4,4,4,Color("#8ad6d3"))
	PALETTE.box(st,Vector3(0,0,0.48),Vector3(0.12,0.32,0.22),4,4,4,Color("#78acae"))
	var art := PALETTE.as_instance(st,"FishTemplate")
	var instance := MultiMeshInstance3D.new()
	school=MultiMesh.new()
	school.transform_format=MultiMesh.TRANSFORM_3D
	school.mesh=art.mesh
	art.free()
	school.instance_count=COUNT
	instance.multimesh=school
	add_child(instance)
	for i in range(COUNT):
		var angle := TAU*float(i)/COUNT
		points.append(Vector2.from_angle(angle)*rng.randf_range(0.35,1.1))
		velocities.append(Vector2.from_angle(angle+PI/2)*0.7)
	PICKER.attach(self,"inspect")
	set_process(true)

func _process(delta: float) -> void:
	if game==null or game.hero==null: return
	if global_position.distance_squared_to(game.hero.global_position)>30.0*30.0: return
	ring.position.y=OCEAN.surface_y(global_position)-global_position.y+0.065
	elapsed+=minf(delta,0.1)
	cooldown=maxf(0.0,cooldown-delta)
	if bite_at>=0 and elapsed>bite_at+1.1:
		bite_at=-1
		game.hud.toast("The fish got away.")
	if bite_at>=0 and elapsed>=bite_at:
		ring.scale=Vector3.ONE*(1.0+0.25*sin(elapsed*10.0))
	else: ring.scale=Vector3.ONE
	var next: Array[Vector2] = []
	for i in range(COUNT):
		var p: Vector2 = points[i]
		var alignment := Vector2.ZERO
		var cohesion := Vector2.ZERO
		var separation := Vector2.ZERO
		var neighbors := 0
		for j in range(COUNT):
			if j==i: continue
			var diff: Vector2 = points[j]-p
			if diff.length_squared()<2.5:
				alignment+=velocities[j]
				cohesion+=diff
				neighbors+=1
			if diff.length_squared()<0.2:
				separation-=diff/maxf(0.04,diff.length_squared())
		var force := -p*0.35+Vector2(-p.y,p.x)*0.45+separation*0.4
		if neighbors>0:
			force+=(alignment/float(neighbors)-velocities[i])*0.5+cohesion/float(neighbors)*0.25
		var v: Vector2 = (velocities[i]+force*delta).limit_length(1.4)
		next.append(v)
	for i in range(COUNT):
		velocities[i]=next[i]
		points[i]=(points[i]+next[i]*delta).limit_length(1.6)
		var p: Vector2 = points[i]
		var v: Vector2 = velocities[i]
		var at := global_position+Vector3(p.x,0,p.y)
		var depth := OCEAN.surface_y(at)-global_position.y-0.4+sin(elapsed*2.0+i)*0.08
		school.set_instance_transform(i,Transform3D(Basis(Vector3.UP,atan2(v.x,v.y)+PI),Vector3(p.x,depth,p.y)))

func interact(_hero: Node3D) -> void:
	if not game.target_in_range(self): return
	if str(game.equipment.get("tool_fishing",""))!="shrimp_net":
		game.hud.toast("Equip a fishing net first.")
		return
	if cooldown>0: return
	if bite_at<0:
		bite_at=elapsed+rng.randf_range(1.0,2.5)
		game.hud.toast("Cast! Watch the ring, then tap Interact at the bite.")
		return
	if elapsed<bite_at:
		bite_at=-1
		game.hud.toast("Too early.")
		return
	if elapsed<=bite_at+1.1:
		var count: int = game.grant_item("shrimp",1+rank)
		game.hud.toast("Caught %d shrimp." % count)
		cooldown=8.0
	bite_at=-1
