extends CharacterBody3D
signal combat_state_changed(active: bool)
var in_combat: bool = false
var combat_remaining: float = 0.0

func enter_combat() -> void:
	combat_remaining = 6.0
	if not in_combat:
		in_combat = true
		combat_state_changed.emit(true)

func update_combat(delta: float) -> void:
	combat_remaining = maxf(0.0, combat_remaining - delta)
	if in_combat and combat_remaining <= 0.0:
		in_combat = false
		combat_state_changed.emit(false)
## Outpost v0.5: modular original OBJ adventurer with animated limbs and equipment.
const MODEL_ROOT: String = "res://assets/models/"
const VOXEL_CHARACTER = preload("res://scripts/voxel/voxel_character.gd")
const PIXEL_FEEDBACK = preload("res://scripts/vfx/pixel_feedback.gd")
const SWIM_SPLASH = preload("res://scripts/vfx/swimming_splashes.gd")
const WHIRLWIND_TRAIL = preload("res://scripts/vfx/whirlwind_sword_trail.gd")
const WATER_SURFACE_Y: float = -2.82

var game
var hud
var camera: Camera3D
var health: float = 100.0
var knockback_velocity: Vector3 = Vector3.ZERO
var elapsed: float = 0.0
var last_hit: float = -100.0

var visual: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var shield_mesh: MeshInstance3D
var torch_mesh: MeshInstance3D
var torch_light: OmniLight3D
var torch_flame: Node3D
var cloak_pivot: Node3D
var sword_mesh: MeshInstance3D
var tool_mesh: MeshInstance3D
var held_tool_id: String = ""
var weapon_grip: Node3D
var combat_phase: float = 0.0
var gather_phase: float = 0.0
var whirlwind_remaining: float = 0.0
var whirlwind_elapsed: float = 0.0
var whirlwind_start_heading: float = 0.0
var whirlwind_grip_pose: Vector3 = Vector3.ZERO
const WHIRLWIND_SPIN_DURATION: float = 0.90
var walking_phase: float = 0.0
var swimming: bool = false
var swim_stroke_phase: float = 0.0
var swim_splash_elapsed: float = 0.0
var swim_preview_seconds: float = 0.0
var walk_amount: float = 0.0
# Collision reaches the next solid tile immediately, but the visible model
# catches up over subsequent frames instead of popping one voxel at a time.
var visual_step_offset: Vector3 = Vector3.ZERO
var step_hop_remaining: float = 0.0
const STEP_HOP_DURATION: float = 0.28
var last_gather: String = ""
var gm_speed_multiplier: float = 1.0 # Temporary Alpha GM console; runtime only.
var remote_ledge_stall_frames: int = 0 # Only recovers low voxel-edge snags on generated islands.
@export var auto_step_enabled: bool = true
@export_range(0.1, 1.5, 0.05) var max_auto_step_height: float = 1.05
@export_range(0.1, 2.0, 0.05) var max_resource_hop_height: float = 1.9
const STEP_LANDING_TOLERANCE: float = 0.06
const STEP_CAPSULE_PROBE: float = 0.46 # Move the sample past the capsule front edge.
# Dungeon portal interaction state: manually operated by default.
var interaction_target: Vector3 = Vector3.ZERO
var interaction_moving: bool = false
var interaction_locked: bool = false
var station_waypoints: PackedVector3Array = PackedVector3Array()
var path_navigation: bool = false

func move_to_interaction(target: Vector3) -> void:
	path_navigation = false
	station_waypoints.clear()
	interaction_target = target
	interaction_moving = true

func move_along_station_path(path: PackedVector3Array) -> void:
	path_navigation = true
	station_waypoints = path.duplicate()
	if station_waypoints.is_empty():
		stop_interaction_move()
		return
	interaction_target = station_waypoints[0]
	interaction_moving = true

func stop_interaction_move() -> void:
	interaction_moving = false
	path_navigation = false
	station_waypoints.clear()

func setup(game_ref: Node, hud_ref: CanvasLayer, camera_ref: Camera3D) -> void:
	game = game_ref
	hud = hud_ref
	camera = camera_ref
	# Descend a one-voxel terrace without bouncing or requiring a jump press.
	floor_snap_length = 1.15 if bool(game.get("voxel_art_enabled")) else 0.1
	name = "Adventurer"
	collision_layer = 1
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	visual = Node3D.new()
	visual.name = "VisualRig"
	add_child(visual)
	# Smaller, rounder silhouette without changing collision or save data.
	if bool(game.get("voxel_art_enabled")):
		visual.scale = Vector3(0.88, 0.85, 0.88)
	_model("adventurer_torso", visual, Vector3.ZERO)
	var head: MeshInstance3D = _model("adventurer_head", visual, Vector3(0, 1.89, -0.035))
	if bool(game.get("voxel_art_enabled")):
		head.scale = Vector3.ONE * 1.34 # Slightly oversized Cube World-like face; collision stays unchanged.
	left_arm = _pivot("LeftArm", Vector3(-0.54, 1.51, 0.02))
	right_arm = _pivot("RightArm", Vector3(0.54, 1.51, 0.02))
	left_leg = _pivot("LeftLeg", Vector3(-0.205, 0.78, 0.0))
	right_leg = _pivot("RightLeg", Vector3(0.205, 0.78, 0.0))
	_model("adventurer_arm", left_arm, Vector3.ZERO)
	_model("adventurer_arm", right_arm, Vector3.ZERO)
	_model("adventurer_leg", left_leg, Vector3.ZERO)
	_model("adventurer_leg", right_leg, Vector3.ZERO)
	# Attach equipment to the wrist instead of letting a blade point vertically
	# through the adventurer's upper arm. The blade's OBJ/voxel local +Y points
	# from the hilt to the tip, so rotate it toward the ground and slightly forward.
	weapon_grip = Node3D.new()
	weapon_grip.name = "WeaponGrip"
	weapon_grip.position = Vector3(0.03, -0.60, -0.11)
	right_arm.add_child(weapon_grip)
	sword_mesh = _model("steel_sword", weapon_grip, Vector3.ZERO)
	shield_mesh = _model("kite_shield", left_arm, Vector3(-0.07, -0.46, -0.29))
	shield_mesh.visible = false
	_build_torch()
	cloak_pivot = _pivot("Cloak", Vector3(0, 1.50, 0.27))
	_model("cloth_cloak", cloak_pivot, Vector3.ZERO)
	cloak_pivot.visible = false
	set_weapon("training_blade")

func _pivot(id: String, location: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = id
	pivot.position = location
	visual.add_child(pivot)
	return pivot

func _model(id: String, parent: Node3D, position_at: Vector3) -> MeshInstance3D:
	var model: MeshInstance3D
	if game != null and bool(game.get("voxel_art_enabled")):
		model = VOXEL_CHARACTER.create_part(id)
	if model == null:
		model = MeshInstance3D.new()
		model.mesh = load(MODEL_ROOT + id + ".obj") as Mesh
	model.name = id
	model.position = position_at
	parent.add_child(model)
	return model

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.16
	mat.roughness = 0.72
	return mat

func set_weapon(id: String) -> void:
	if sword_mesh == null:
		return
	# The neutral sword hangs diagonally beside the right thigh. The longer
	# spear points forward, rather than vertically through the right arm.
	# This is cosmetic: item stats, hitboxes and save IDs are unchanged.
	if weapon_grip != null:
		weapon_grip.rotation = Vector3(PI + (0.85 if id == "spear" else 0.64), 0.05, 0.29)
	var pixel_mode: bool = game != null and bool(game.get("voxel_art_enabled"))
	if pixel_mode:
		# The voxel character shares a nearest-filtered atlas with the world.
		# Never tint the pixel sword with the old smooth OBJ override material.
		var visual_id: String = "iron_blade" if id == "iron_blade" else "steel_spear" if id == "spear" else "steel_sword"
		var replacement: MeshInstance3D = VOXEL_CHARACTER.create_part(visual_id)
		if replacement != null:
			sword_mesh.mesh = replacement.mesh
			sword_mesh.material_override = replacement.material_override
		sword_mesh.scale = Vector3(0.85, 0.84, 0.85) if id == "iron_blade" else Vector3(0.81, 0.78, 0.81) if id == "spear" else Vector3(0.76, 0.76, 0.76)
	elif id == "iron_blade":
		sword_mesh.scale = Vector3(0.90, 0.84, 0.90)
		sword_mesh.material_override = _material(Color("b7d7e2"))
	elif id == "spear":
		sword_mesh.scale = Vector3(0.78, 0.72, 0.78)
		sword_mesh.material_override = _material(Color("d2b782"))
	else:
		sword_mesh.scale = Vector3(0.76, 0.76, 0.76)
		sword_mesh.material_override = _material(Color("b2b6a9"))

## The quick-tool selection controls the *visible* wrist-held mesh.
## The weapon slot, damage, and harvesting stats still belong to game.gd.
## Reuse the current mesh when refreshing equipment to avoid GPU churn.
func set_held_tool(tool_id: String) -> void:
	if sword_mesh == null or weapon_grip == null:
		return
	var is_gather_tool: bool = tool_id == "axe" or tool_id == "pickaxe"
	if is_gather_tool:
		# Point the head down/forward from the right wrist, clear of the torso.
		weapon_grip.rotation = Vector3(PI + 0.52, -0.08, 0.19)
	else:
		weapon_grip.rotation = Vector3(PI + (0.85 if tool_id == "spear" else 0.64), 0.05, 0.29)
	if is_gather_tool and held_tool_id == tool_id and is_instance_valid(tool_mesh):
		sword_mesh.visible = false
		return
	if tool_mesh != null and is_instance_valid(tool_mesh):
		weapon_grip.remove_child(tool_mesh)
		tool_mesh.queue_free()
	tool_mesh = null
	held_tool_id = ""
	sword_mesh.visible = true
	if not is_gather_tool:
		return
	var pixel_mode: bool = game != null and bool(game.get("voxel_art_enabled"))
	var replacement: MeshInstance3D = null
	if pixel_mode:
		replacement = VOXEL_CHARACTER.create_part("hand_" + tool_id)
	else:
		# Real original OBJ models also work in the non-voxel fallback mode.
		var model_path: String = MODEL_ROOT + "hand_" + tool_id + ".obj"
		if ResourceLoader.exists(model_path):
			var mesh: Mesh = load(model_path) as Mesh
			if mesh != null:
				replacement = MeshInstance3D.new()
				replacement.mesh = mesh
	if replacement == null:
		# Missing imported art must never leave the player weaponless.
		return
	tool_mesh = replacement
	tool_mesh.name = "Held" + tool_id.capitalize()
	tool_mesh.position = Vector3(0.0, -0.02, -0.05)
	tool_mesh.scale = Vector3.ONE * (0.88 if tool_id == "axe" else 0.84)
	weapon_grip.add_child(tool_mesh)
	held_tool_id = tool_id
	sword_mesh.visible = false

func set_spear(equipped: bool) -> void:
	set_weapon("spear" if equipped else "training_blade")

func set_shield(equipped: bool) -> void:
	if shield_mesh != null:
		shield_mesh.visible = equipped

func _build_torch() -> void:
	torch_mesh = VOXEL_CHARACTER.create_part("torch")
	if torch_mesh == null:
		torch_mesh = MeshInstance3D.new()
		var stick := BoxMesh.new()
		stick.size = Vector3(0.20, 0.93, 0.22)
		torch_mesh.mesh = stick
		torch_mesh.material_override = _material(Color("90603a"))
	torch_mesh.name = "OffhandTorch"
	torch_mesh.position = Vector3(-0.07, -0.45, -0.28)
	left_arm.add_child(torch_mesh)
	var ember := MeshInstance3D.new()
	ember.name = "TorchEmber"
	var ember_mesh := BoxMesh.new()
	ember_mesh.size = Vector3(0.36, 0.33, 0.34)
	ember.mesh = ember_mesh
	ember.position = Vector3(0, 0.75, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffb85f")
	material.emission_enabled = true
	material.emission = Color("ff9f36")
	material.emission_energy_multiplier = 1.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.material_override = material
	torch_mesh.add_child(ember)
	torch_light = OmniLight3D.new()
	torch_light.name = "OffhandTorchLight"
	torch_light.position = Vector3(0, 0.78, 0)
	torch_light.light_color = Color("ffd095")
	torch_light.light_energy = 1.8
	torch_light.omni_range = 8.0
	torch_light.omni_attenuation = 1.2
	torch_light.shadow_enabled = false
	torch_mesh.add_child(torch_light)
	# Use the packaged PyroLux flame on the existing wrist-attached torch.
	# Keep the old emissive cube + light as a fallback for source checkouts.
	var preset_path: String = "res://addons/pyrolux_fx/presets/3d/fire_torch.tscn"
	if ResourceLoader.exists(preset_path):
		var flame_scene: PackedScene = load(preset_path) as PackedScene
		if flame_scene != null:
			torch_flame = flame_scene.instantiate() as Node3D
			if torch_flame != null:
				torch_flame.name = "PyroLuxTorchFlame"
				torch_flame.position = Vector3(0, 0.79, 0)
				torch_flame.scale = Vector3.ONE * 0.70
				torch_mesh.add_child(torch_flame)
				ember.visible = false
				torch_light.visible = false
	set_torch(false)

func set_torch(equipped: bool) -> void:
	if torch_mesh != null:
		torch_mesh.visible = equipped
	if torch_light != null:
		torch_light.visible = equipped and torch_flame == null
	if torch_flame != null:
		torch_flame.visible = equipped

func set_cloak(equipped: bool) -> void:
	if cloak_pivot != null:
		cloak_pivot.visible = equipped

func swing() -> void:
	enter_combat()
	# Set visible forward strike immediately; Android can render a frame before
	# the physics callback updates the arm rotation.
	combat_phase = 0.86
	if right_arm != null:
		right_arm.rotation.x = 1.75 * sin(combat_phase * PI)
		right_arm.rotation.z = -0.31 * sin(combat_phase * PI)

func play_whirlwind() -> void:
	enter_combat()
	if visual == null or sword_mesh == null or weapon_grip == null:
		return
	whirlwind_elapsed = 0.0
	whirlwind_remaining = WHIRLWIND_SPIN_DURATION
	whirlwind_start_heading = visual.rotation.y
	whirlwind_grip_pose = weapon_grip.rotation
	combat_phase = 0.0
	gather_phase = 0.0
	# Raise the blade out from the hip before tracing the circle.
	weapon_grip.rotation = Vector3(0.15, 0.0, 0.28)
	var trail: MeshInstance3D = WHIRLWIND_TRAIL.new() as MeshInstance3D
	add_child(trail)
	trail.begin(sword_mesh, WHIRLWIND_SPIN_DURATION)

## Weapon-hit sparks start at the actual animated blade/tool tip, not at
## the player's feet. Reuse the existing tiny voxel burst for Android.
func show_weapon_hit_effect(_target_position: Vector3) -> void:
	if game == null or sword_mesh == null:
		return
	var held: MeshInstance3D = sword_mesh
	if not sword_mesh.visible and is_instance_valid(tool_mesh):
		held = tool_mesh
	var tip_y: float = 1.70 if game.current_weapon_id() == "spear" and held == sword_mesh else 1.42
	var tip: Vector3 = held.to_global(Vector3(0.0, tip_y, 0.0))
	PIXEL_FEEDBACK.emit_feedback(game, tip, 0.0, Color("f04450"))

func gather_swing(kind: String) -> void:
	last_gather = kind
	gather_phase = 1.0

func preview_swimming_fx() -> void:
	# Preview can be invoked on dry land from Controls. No teleport or saved
	# state change: 3.5 seconds of stroke pose and real batched water particles.
	swim_preview_seconds = 3.5
	swim_stroke_phase = 0.0
	swim_splash_elapsed = 0.0
	_emit_swim_splash(true)


func _emit_swim_splash(preview: bool = false) -> void:
	if get_parent() == null:
		return
	var location: Vector3 = global_position + Vector3(0.0, 0.48 if preview else (WATER_SURFACE_Y - global_position.y + 0.06), 0.0)
	SWIM_SPLASH.splash(get_parent() as Node3D, location)


func _detect_surface_swimming() -> bool:
	# Use actual coastal land sampling, not all areas with a low world Y:
	# the private dungeon is never mistaken for a swimmable sea.
	if game == null or not bool(game.get("chunk_streaming_enabled")):
		return false
	# The ocean extends well beyond the procedural island. Its real floor
	# and far perimeter are built in game.gd; water buoyancy never shuts off
	# at the original x/z=96 terrain-streaming boundary.
	if absf(global_position.x) >= 384.0 or absf(global_position.z) >= 384.0:
		return false
	var terrain: Node = game.get_node_or_null("VoxelAtmosphere")
	if terrain == null or not bool(terrain.get("stream_enabled")):
		return false
	# Never switch buoyancy off just because the player was pushed below the
	# expected five-metre water band. That produced infinite falling if a
	# streamed collision tile arrived late, or a knockback crossed the band.
	var land: bool = bool(terrain.is_land_at(global_position.x, global_position.z))
	if land:
		# The first island beach voxel is submerged at Y=-3. Keep buoyancy
		# through that shallow landing tile until the swimmer has climbed up
		# to the dry one-block shoreline. Otherwise buoyancy cuts out while
		# the avatar is still below the first step and the character sinks.
		var remote: Variant = terrain.get("archipelago")
		if remote != null and remote.is_land_at(global_position.x, global_position.z):
			var beach_y: float = remote.height_at(floori(global_position.x), floori(global_position.z))
			return beach_y < WATER_SURFACE_Y and global_position.y < WATER_SURFACE_Y + 0.6
	return not land and global_position.y < WATER_SURFACE_Y + 0.6


func _remote_shore_float_target(direction: Vector3) -> float:
	# Swim up *onto* the next shallow voxel before horizontal collision
	# reaches its vertical face. Otherwise the swimmer stays at Y=-3.6,
	# pinned against an otherwise traversable Y=-3 or Y=-2 beach.
	var default_depth: float = WATER_SURFACE_Y - 0.78
	if direction.length_squared() < 0.02:
		return default_depth
	var terrain: Node = game.get_node_or_null("VoxelAtmosphere")
	if terrain == null:
		return default_depth
	var remote: Variant = terrain.get("archipelago")
	if remote == null or remote.terrain == null:
		return default_depth
	var ahead: Vector3 = global_position + direction.normalized() * 1.25
	if not remote.is_land_at(ahead.x, ahead.z):
		return default_depth
	var target_y: float = remote.height_at(floori(ahead.x), floori(ahead.z))
	var rise: float = target_y - global_position.y
	# Allow ONLY one normal voxel step. Never swim vertically up a cliff,
	# wall or mountain; the coast's actual terraced terrain must be used.
	if rise < -0.30 or rise > max_auto_step_height + 0.30:
		return default_depth
	return maxf(default_depth, target_y + 0.16)


func _rescue_remote_ledge_snag(direction: Vector3, requested_motion: Vector3, delta: float) -> void:
	# On generated voxel cliffs, Godot occasionally classifies the vertical
	# boundary as an upward-facing *floor* normal (e.g. [-.25, .97, 0]).
	# is_on_wall() stays false, disabling the normal auto-step solver.
	# After repeated zero progress, clear only a genuinely safe <=1m edge.
	if swimming or not is_on_floor() or direction.length_squared() < 0.02:
		remote_ledge_stall_frames = 0
		return
	var terrain: Node = game.get_node_or_null("VoxelAtmosphere")
	if terrain == null:
		remote_ledge_stall_frames = 0
		return
	var remote: Variant = terrain.get("archipelago")
	if remote == null or remote.terrain == null or not remote.terrain.near_island(global_position, 6.0):
		remote_ledge_stall_frames = 0
		return
	var intended: float = requested_motion.length()
	var progressed: float = (global_position - (global_position - requested_motion)).length()
	# A collision-aware progress measurement is passed through a temporary
	# node metadata value by the caller below.
	progressed = float(get_meta("_remote_progress", intended))
	if intended < 0.015 or progressed > intended * 0.20:
		remote_ledge_stall_frames = 0
		return
	remote_ledge_stall_frames += 1
	if remote_ledge_stall_frames < 5:
		return
	remote_ledge_stall_frames = 0
	var forward: Vector3 = direction.normalized() * 0.30
	var landing: Vector3 = global_position + forward
	var top: float = remote.height_at(floori(landing.x), floori(landing.z))
	var rise: float = top - global_position.y
	if rise < -0.40 or rise > max_auto_step_height:
		return
	# Raise a few centimetres above the coplanar voxel edge, not the next
	# full block. Recheck both vertical and lateral collision at the new Y.
	var upward: Vector3 = Vector3.UP * maxf(0.17, rise + 0.08)
	var original: Transform3D = global_transform
	if test_move(original, upward):
		return
	if test_move(original.translated(upward), forward):
		return
	# Real landing collision required: never nudge across unloaded terrain
	# or let a character step out into the surrounding ocean.
	var from: Vector3 = global_position + upward + forward + Vector3.UP
	var to: Vector3 = from - Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if floor_hit.is_empty() or (floor_hit.get("normal", Vector3.ZERO) as Vector3).y < 0.70:
		return
	global_position += upward + forward
	velocity.y = 0.0
	visual_step_offset -= upward + forward
	visual_step_offset = visual_step_offset.limit_length(1.0)


func _physics_process(delta: float) -> void:
	update_combat(delta)
	elapsed += delta
	var modal_open: bool = game.controls.modal_open() if game.controls != null else (game.menu != null and game.menu.visible) or interaction_locked
	swimming = _detect_surface_swimming()
	swim_preview_seconds = maxf(0.0, swim_preview_seconds - delta)
	var control: Vector2 = Input.get_vector("outpost_left", "outpost_right", "outpost_up", "outpost_down")
	if modal_open:
		control = Vector2.ZERO
	elif hud != null and hud.move_vector.length() > 0.12:
		control = hud.move_vector
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var direction: Vector3 = (right * control.x - forward * control.y).normalized()
	if interaction_moving and not modal_open:
		if control.length() > 0.15:
			stop_interaction_move()
			if game.controls != null:
				game.controls.cancel()
			if game.has_method("cancel_station_walk"):
				game.cancel_station_walk()
		else:
			# Advance through A* cells at close range; legacy dungeon portals
			# still use their original interaction_target / 2.4m arrival rule.
			while station_waypoints.size() > 0:
				var node: Vector3 = station_waypoints[0]
				if Vector2(node.x - global_position.x, node.z - global_position.z).length() > 0.25:
					break
				station_waypoints.remove_at(0)
			if station_waypoints.size() > 0:
				interaction_target = station_waypoints[0]
			var towards: Vector3 = interaction_target - global_position
			towards.y = 0.0
			if station_waypoints.is_empty() and towards.length() <= (0.25 if path_navigation else 2.4):
				stop_interaction_move()
				direction = Vector3.ZERO
			else:
				direction = towards.normalized()
	var speed: float = 6.0 if str(game.equipment.get("back", "")) == "cloak" else 5.1
	# Changing to a smaller bag can leave legacy inventories temporarily
	# overloaded. Slow the character, but never silently destroy saved items.
	if game.has_method("bag_load") and game.bag_load() > game.bag_capacity():
		speed *= 0.48
	if gather_phase > 0.0:
		speed *= 0.42
	speed *= gm_speed_multiplier
	# Separate short hit impulse from player steering. It decays rapidly,
	# feels like voxel-sandbox combat, and cannot keep moving the character.
	velocity.x = direction.x * speed + knockback_velocity.x
	velocity.z = direction.z * speed + knockback_velocity.z
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 13.0)
	var grounded_before_motion: bool = is_on_floor()
	if swimming:
		# In water, stay inside the swimmable band even if the character
		# entered fast, or an asynchronous coastal chunk had no collision yet.
		var float_target: float = _remote_shore_float_target(direction)
		if global_position.y < WATER_SURFACE_Y - 6.0:
			# Recovery stays at the SAME ocean coordinates rather than
			# teleporting to camp or waiting for minutes of slow upward speed.
			global_position.y = float_target
			velocity.y = 0.0
		else:
			velocity.y = clampf((float_target - global_position.y) * 5.5, -2.4, 4.5)
	else:
		velocity.y = -0.1 if grounded_before_motion else velocity.y - 18.0 * delta
	var motion_from: Vector3 = global_position
	move_and_slide()
	if auto_step_enabled and not modal_open and ((grounded_before_motion and velocity.y <= 0.0) or swimming) and is_on_wall() and direction.length_squared() > 0.02:
		_try_auto_step(direction * speed * delta)
	# The usual wall step misses rounded capsule/floor contacts on adjacent
	# voxels. Detect actual forward displacement to avoid false wall climbing.
	if auto_step_enabled and not modal_open and not swimming:
		var advance: float = maxf(0.0, (global_position - motion_from).dot(direction))
		set_meta("_remote_progress", advance)
		_rescue_remote_ledge_snag(direction, direction * speed * delta, delta)
		remove_meta("_remote_progress")
	# Interpolate the avatar rig separately from the physics capsule. The
	# capsule must not tunnel through a ledge and the camera stays independent.
	visual_step_offset = visual_step_offset.lerp(Vector3.ZERO, 1.0 - exp(-11.0 * delta))
	step_hop_remaining = maxf(0.0, step_hop_remaining - delta)
	var hop: float = 0.0
	if step_hop_remaining > 0.0:
		hop = sin((1.0 - step_hop_remaining / STEP_HOP_DURATION) * PI) * 0.20
	walk_amount = move_toward(walk_amount, direction.length(), delta * 8.0)
	if direction.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 12.0, 1.0))
		walking_phase += delta * 10.6
	visual.position = visual_step_offset + Vector3.UP * (absf(sin(walking_phase)) * 0.06 * walk_amount + hop)
	var step: float = sin(walking_phase) * 0.58 * walk_amount
	left_leg.rotation.x = step
	right_leg.rotation.x = -step
	left_arm.rotation.x = -step * 0.55
	right_arm.rotation.x = step * 0.55
	# Small tuck in midair; attack/gather takes precedence below.
	if not is_on_floor():
		left_leg.rotation.x = 0.28
		right_leg.rotation.x = -0.28
		left_arm.rotation.x = -0.20
		right_arm.rotation.x = -0.20
	combat_phase = maxf(0.0, combat_phase - delta * 2.8)
	gather_phase = maxf(0.0, gather_phase - delta * 2.3)
	if combat_phase > 0.0:
		# Positive X carries the downward arm toward local -Z (the character's
		# forward direction). Negative used to throw the blade behind the back.
		right_arm.rotation.x = 1.75 * sin(combat_phase * PI)
		right_arm.rotation.z = -0.31 * sin(combat_phase * PI)
	elif gather_phase > 0.0:
		# Tool swings are animated even before a real tool is owned.
		right_arm.rotation.x = -1.95 * sin(gather_phase * PI)
		left_arm.rotation.x = -0.42 * sin(gather_phase * PI)
		visual.rotation.z = 0.065 * sin(gather_phase * PI)
	else:
		visual.rotation.z = lerpf(visual.rotation.z, 0.0, minf(1.0, delta * 12.0))
	# Combat once left the wrist rolled inward permanently until another attack.
	# Restore the relaxed, slightly outward arm pose after every swing or harvest.
	if combat_phase <= 0.0:
		right_arm.rotation.z = lerpf(right_arm.rotation.z, 0.12, minf(1.0, delta * 11.0))
	cloak_pivot.rotation.x = 0.07 * sin(walking_phase * 0.6) * walk_amount
	if swimming or swim_preview_seconds > 0.0:
		# Readable alternating swim strokes and flutter kick on the same
		# joint rig used by walking, so tools and equipment remain attached.
		swim_stroke_phase += delta * (8.4 if direction.length() > 0.05 else 4.3)
		var stroke: float = sin(swim_stroke_phase)
		left_arm.rotation.x = -0.85 + 0.73 * stroke
		right_arm.rotation.x = -0.85 - 0.73 * stroke
		left_leg.rotation.x = -0.40 * stroke
		right_leg.rotation.x = 0.40 * stroke
		visual.rotation.z = 0.045 * sin(swim_stroke_phase * 0.5)
		swim_splash_elapsed += delta
		if swim_splash_elapsed >= (0.26 if swimming and direction.length() > 0.05 else 0.43):
			swim_splash_elapsed = 0.0
			_emit_swim_splash(not swimming)
	else:
		swim_splash_elapsed = 0.0
	if whirlwind_remaining > 0.0:
		# Only the visible rig rotates. The real physics capsule remains
		# stable, so this spin cannot alter steering or clip through terrain.
		whirlwind_elapsed = minf(WHIRLWIND_SPIN_DURATION, whirlwind_elapsed + delta)
		whirlwind_remaining = maxf(0.0, WHIRLWIND_SPIN_DURATION - whirlwind_elapsed)
		var spin_t: float = whirlwind_elapsed / WHIRLWIND_SPIN_DURATION
		visual.rotation.y = whirlwind_start_heading + TAU * 2.0 * spin_t
		right_arm.rotation.x = -0.36
		right_arm.rotation.z = -0.94
		left_arm.rotation.z = 0.30
		if whirlwind_remaining <= 0.0 and weapon_grip != null:
			weapon_grip.rotation = whirlwind_grip_pose
	# In LAN dungeons only the host owns health; local auto-healing must
	# never revive knocked-out characters or desync peer health snapshots.
	if elapsed - last_hit > 6.0 and not (game.coop != null and game.coop.in_party_dungeon()):
		health = minf(100.0, health + delta * 2.0)

func _try_auto_step(horizontal_motion: Vector3) -> bool:
	# The Fields biome needs one-block ledge climbing, NOT a wall-climb exploit.
	# Do not step during an active dungeon run or while airborne.
	var manager: Node = game.get_node_or_null("Dungeons") if game != null else null
	if manager != null and manager.get("active_instance") != null:
		return false
	if horizontal_motion.length_squared() < 0.0001 or not bool(game.get("voxel_art_enabled")):
		return false
	# Only an ore/rock/clay obstacle grants the larger automatic hop.
	# Terrain, walls and trees retain the existing one-voxel step limit.
	var resource_obstacle: Object = null
	for index in range(get_slide_collision_count()):
		var obstacle: Object = get_slide_collision(index).get_collider()
		if obstacle is Node and obstacle.is_in_group("auto_hop_resources"):
			resource_obstacle = obstacle
			break
	var step_limit: float = maxf(max_auto_step_height, max_resource_hop_height) if resource_obstacle != null else max_auto_step_height
	var up: Vector3 = Vector3.UP * (step_limit + STEP_LANDING_TOLERANCE)
	var original: Transform3D = global_transform
	if test_move(original, up):
		return false # Low ceiling or other obstacle directly above the player.
	var raised: Transform3D = original.translated(up)
	# A 0.38-radius capsule contacts the wall BEFORE its centre reaches the
	# top tile. Extend the safe probe past that radius, or normal joystick
	# movement would never find the landing surface.
	var probe_motion: Vector3 = horizontal_motion + horizontal_motion.normalized() * STEP_CAPSULE_PROBE
	if test_move(raised, probe_motion):
		return false # The elevated path is blocked by a full-height wall.
	var candidate: Vector3 = original.origin + probe_motion
	var start: Vector3 = candidate + Vector3.UP * (step_limit + 0.28)
	var end: Vector3 = candidate - Vector3.UP * 0.25
	var query := PhysicsRayQueryParameters3D.create(start, end, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if normal.dot(Vector3.UP) < 0.75:
		return false
	var rise: float = float((hit["position"] as Vector3).y - original.origin.y)
	if rise <= 0.045 or rise > step_limit:
		return false
	if rise > max_auto_step_height and hit.get("collider") != resource_obstacle:
		return false # A nearby tall wall cannot borrow the ore's hop allowance.
	# Revalidate horizontally at the final elevation before moving the body.
	var landing: Transform3D = original.translated(Vector3.UP * (rise + STEP_LANDING_TOLERANCE))
	if test_move(landing, probe_motion):
		return false
	var previous: Vector3 = global_position
	global_position = candidate + Vector3.UP * (rise + STEP_LANDING_TOLERANCE)
	velocity.y = 0.0
	apply_floor_snap()
	# Preserve prior render-space pose; bridge the movement over several
	# frames. Smaller half-height ledges get a brief stepping hop.
	visual_step_offset += previous - global_position
	visual_step_offset = visual_step_offset.limit_length(1.65)
	if rise >= 0.24 and rise <= 0.68:
		step_hop_remaining = STEP_HOP_DURATION
	return true

func apply_knockback(source: Vector3, force: float = 6.0) -> void:
	var push: Vector3 = global_position - source
	push.y = 0.0
	if push.length_squared() < 0.001:
		push = Vector3(0.0, 0.0, 1.0)
	knockback_velocity = (push.normalized() * clampf(force, 0.0, 9.5))
	stop_interaction_move()

func take_hit(amount: float, source: Vector3 = Vector3.ZERO) -> void:
	if source != Vector3.ZERO:
		apply_knockback(source, 6.3)
	var protection: float = 0.6 if str(game.equipment.get("offhand", "")) == "shield" else 1.0
	if int(game.inventory.get("cloak", 0)) > 0:
		protection *= 0.9
	var actual: float = amount * protection
	if actual > 0.0:
		enter_combat()
	# Station crafting is interrupted when combat damages the player, rather
	# than leaving a modal trapping them while enemies keep attacking.
	if actual > 0.0 and game.menu != null and game.menu.visible and game.menu.current_page == "craft":
		game.menu.close_page()
		game.hud.toast("Crafting Station interrupted by damage!")
	if actual > 0.0 and game.has_method("cancel_station_walk"):
		game.cancel_station_walk()
	health = maxf(0.0, health - actual)
	last_hit = elapsed
	var defeated: bool = health <= 0.0
	PIXEL_FEEDBACK.emit_feedback(game, global_position + Vector3.UP * 0.9, actual, Color("ff736b"), defeated)
	if defeated:
		knockback_velocity = Vector3.ZERO
		health = 100.0
		global_position = Vector3(0, 0.35, 0)
		game.hud.toast("Defeated! Respawned at outpost; items kept.")

