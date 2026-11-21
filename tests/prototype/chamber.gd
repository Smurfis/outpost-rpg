extends Node3D
const Volume = preload("section_mesh.gd")
const Player = preload("res://scripts/player.gd")
const Atlas = preload("res://scripts/voxel/greedy_mesher.gd")
const voxel_art_enabled := true
const PICK_LAYER := 1 << 18
var volume := Volume.new()
var hero := Player.new()
var camera := Camera3D.new()
var shell := MeshInstance3D.new()
var pick_shape := CollisionShape3D.new()
var active := false
var room := -1
var state := Vector3i(-99,0,0)
var section_faces := 0
var heading := -45.0

func body_for(shape_node: CollisionShape3D, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.add_child(shape_node)
	add_child(body)

func _ready() -> void:
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.0
	camera.current = true
	var whole := volume.geometry(-1,Vector2i.ZERO)
	var physical := CollisionShape3D.new()
	physical.shape = whole.shape
	body_for(physical,1)
	body_for(pick_shape,PICK_LAYER)
	shell.material_override = Atlas.material()
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var shadow := MeshInstance3D.new()
	shadow.mesh = whole.mesh
	shadow.material_override = Atlas.material()
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(shadow)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("30383e")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("e4e8ed")
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-34,0)
	sun.shadow_enabled = true
	add_child(sun)
	for x in [4,13]:
		var light := OmniLight3D.new()
		light.position = Vector3(x+0.5,2.8,4.4)
		light.light_color = Color("ffd39c")
		light.light_energy = 1.6
		light.omni_range = 9
		light.shadow_enabled = true
		add_child(light)
	add_child(hero)
	hero.setup(self,null,camera)
	hero.set_physics_process(false)
	hero.set_shield(true)
	hero.visual.rotation.y = PI
	pose(Vector3(4.5,0,5.5),-45.0,false)

func pose(at: Vector3, degrees: float, opened: bool) -> void:
	heading = degrees
	hero.position = at
	active = opened
	var angle := deg_to_rad(degrees)
	var focus := at + Vector3.UP * 1.15
	camera.position = focus + Vector3(sin(angle)*14,13,cos(angle)*14)
	camera.look_at(focus)
	refresh()

func _process(_delta: float) -> void:
	refresh()

# Controls belong only to this standalone inspection scene.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: pose(hero.position, heading, not active)
			KEY_LEFT: pose(hero.position, heading - 90, active)
			KEY_RIGHT: pose(hero.position, heading + 90, active)
			KEY_TAB: pose(Vector3(11.5 if room == 0 else 4.5, 0, 5.5), heading, active)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Section pick ", pick(event.position).get("position", "outside"))

func refresh() -> void:
	room = volume.room_at(hero.position,room)
	var eye := camera.global_basis.z
	var side := Vector2i(signi(roundi(eye.x*10)),signi(roundi(eye.z*10)))
	var key := Vector3i(room,side.x,side.y) if active and room >= 0 else Vector3i(-1,0,0)
	if state == key:
		return
	state = key
	var result := volume.geometry(key.x,side)
	shell.mesh = result.mesh
	pick_shape.shape = result.shape
	section_faces = result.new_faces

func pick(screen: Vector2, layer := PICK_LAYER) -> Dictionary:
	var eye := camera.project_ray_origin(screen)
	var ray := PhysicsRayQueryParameters3D.create(eye,eye+camera.project_ray_normal(screen)*100,layer,[hero.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray)

