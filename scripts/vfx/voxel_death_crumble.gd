extends Node3D
## Cube World-style creature collapse. One tinted MultiMesh draw call replaces
## the defeated visual; source vertices/UVs sample the *actual* imported
## creature rather than spawning an unrelated brown/grey explosion.
## CPU raycasting is bounded: max 168 cubes on PC, 72 on mobile, and only while
## falling. No per-cube nodes or RigidBody3D objects are allocated.
const GRID: float = 0.12
const BOX_SIZE: float = 0.105
const MAX_PC: int = 168
const MAX_MOBILE: int = 72
const MAX_SAMPLES: int = 9800
const LIFETIME: float = 4.4
const SHRINK_FROM: float = 3.2
const GRAVITY: float = 15.0
const REST_FRICTION: float = 11.0
const BOUNCE: float = 0.21
var elapsed: float = 0.0
var _positions: Array[Vector3] = []
var _velocities: Array[Vector3] = []
var _resting: Array[bool] = []
var _bounces: Array[int] = []
var _colours: Array[Color] = []
var _instance_mesh: MultiMesh
var _landings: int = 0

static func spawn(parent: Node3D, creature: Node3D, visible_rig: Node3D) -> Node3D:
	if parent == null or creature == null or visible_rig == null:
		return null
	var burst = load("res://scripts/vfx/voxel_death_crumble.gd").new()
	burst.name = "CreatureVoxelCrumble"
	burst.add_to_group("outpost_death_crumbles")
	parent.add_child(burst)
	burst.global_position = creature.global_position
	burst._build_from_rig(visible_rig, creature.global_position)
	# Gameplay collision, combat statistics, loot and respawn are owned by
	# the defeated actor, never by the cosmetic crumble.
	return burst

func cube_count() -> int:
	return _positions.size()

func landed_count() -> int:
	return _landings

func _build_from_rig(rig: Node3D, origin: Vector3) -> void:
	var limit: int = MAX_MOBILE if OS.has_feature("mobile") else MAX_PC
	var random := RandomNumberGenerator.new()
	random.seed = int(absf(origin.x * 977.0) + absf(origin.z * 2161.0) + Time.get_ticks_usec()) % 2147483647
	var selected: Array[Dictionary] = []
	var seen: Dictionary = {}
	var distinct: int = 0
	var candidates: int = 0
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		if candidates >= MAX_SAMPLES:
			break
		var source: MeshInstance3D = node as MeshInstance3D
		if source == null or source.mesh == null or not source.is_visible_in_tree():
			continue
		var mesh: Mesh = source.mesh
		for surface in range(mesh.get_surface_count()):
			if candidates >= MAX_SAMPLES:
				break
			if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var vertex_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			if vertices.is_empty():
				continue
			var material: Material = source.get_active_material(surface)
			var base_color: Color = Color("9099a4")
			var picture: Image = null
			if material is BaseMaterial3D:
				var standard: BaseMaterial3D = material as BaseMaterial3D
				base_color = standard.albedo_color
				if standard.albedo_texture != null:
					picture = standard.albedo_texture.get_image()
					if picture != null and picture.is_compressed():
						if picture.decompress() != OK:
							picture = null
			var triangle_count: int = int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
			# Uniformly stride large animated rigs. Reservoir sampling then
			# redistributes the capped cubes over all body parts/materials.
			var skip: int = maxi(1, ceili(float(triangle_count) / 2800.0))
			for triangle in range(0, triangle_count, skip):
				if candidates >= MAX_SAMPLES:
					break
				var a: int = indices[triangle * 3] if not indices.is_empty() else triangle * 3
				var b: int = indices[triangle * 3 + 1] if not indices.is_empty() else triangle * 3 + 1
				var c: int = indices[triangle * 3 + 2] if not indices.is_empty() else triangle * 3 + 2
				if a >= vertices.size() or b >= vertices.size() or c >= vertices.size():
					continue
				var va: Vector3 = vertices[a]
				var vb: Vector3 = vertices[b]
				var vc: Vector3 = vertices[c]
				var long_edge: float = maxf(va.distance_to(vb), maxf(vb.distance_to(vc), vc.distance_to(va)))
				var divisions: int = clampi(ceili(long_edge / GRID), 1, 5)
				for i in range(divisions + 1):
					for j in range(divisions + 1 - i):
						if candidates >= MAX_SAMPLES:
							break
						candidates += 1
						var w1: float = (float(i) + 0.18) / float(divisions + 0.54)
						var w2: float = (float(j) + 0.18) / float(divisions + 0.54)
						var w0: float = 1.0 - w1 - w2
						if w0 < 0.0:
							continue
						var at: Vector3 = source.to_global(va * w0 + vb * w1 + vc * w2)
						var relative: Vector3 = at - origin
						var grid_cell := Vector3i(roundi(relative.x / GRID),
							roundi(relative.y / GRID), roundi(relative.z / GRID))
						if seen.has(grid_cell):
							continue
						seen[grid_cell] = true
						distinct += 1
						var tint: Color = base_color
						if picture != null and not uvs.is_empty() and a < uvs.size() and b < uvs.size() and c < uvs.size():
							var uv: Vector2 = uvs[a] * w0 + uvs[b] * w1 + uvs[c] * w2
							var px: int = clampi(floori(posmod(uv.x, 1.0) * picture.get_width()), 0, picture.get_width() - 1)
							var py: int = clampi(floori(posmod(uv.y, 1.0) * picture.get_height()), 0, picture.get_height() - 1)
							tint *= picture.get_pixel(px, py)
						if not vertex_colors.is_empty() and a < vertex_colors.size() and b < vertex_colors.size() and c < vertex_colors.size():
							tint *= vertex_colors[a] * w0 + vertex_colors[b] * w1 + vertex_colors[c] * w2
						if tint.a < 0.2:
							continue
						var sample: Dictionary = {"at": relative, "color": Color(tint.r, tint.g, tint.b, 1.0)}
						if selected.size() < limit:
							selected.append(sample)
						else:
							var replacement: int = random.randi_range(0, distinct - 1)
							if replacement < limit:
								selected[replacement] = sample
	if selected.is_empty():
		# Keep the death feedback functional if a future animal mesh fails
		# to import. Normal Quaternius/voxel model sampling uses real colours.
		for y in range(2, 7):
			for x in range(-2, 3):
				selected.append({"at": Vector3(float(x) * GRID, float(y) * GRID, 0.0),
					"color": Color("8b9487")})
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cube.material = mat
	_instance_mesh = MultiMesh.new()
	_instance_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_instance_mesh.use_colors = true
	_instance_mesh.mesh = cube
	_instance_mesh.instance_count = selected.size()
	var draw := MultiMeshInstance3D.new()
	draw.name = "ScatteredVoxelCubes"
	draw.multimesh = _instance_mesh
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)
	for index in range(selected.size()):
		var sample: Dictionary = selected[index]
		var offset: Vector3 = sample["at"]
		_positions.append(offset)
		_colours.append(sample["color"])
		var outward: Vector3 = Vector3(offset.x, 0.0, offset.z)
		if outward.length_squared() < 0.01:
			outward = Vector3(random.randf_range(-1.0, 1.0), 0.0, random.randf_range(-1.0, 1.0))
		outward = outward.normalized() * random.randf_range(0.5, 2.0)
		_velocities.append(outward + Vector3(0.0, random.randf_range(1.25, 2.9), 0.0))
		_resting.append(false)
		_bounces.append(0)
		_instance_mesh.set_instance_color(index, _colours[index])
		_instance_mesh.set_instance_transform(index,
			Transform3D(Basis().scaled(Vector3.ONE * BOX_SIZE), offset))

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return
	if _instance_mesh == null:
		return
	var fade: float = clampf((LIFETIME - elapsed) / (LIFETIME - SHRINK_FROM), 0.0, 1.0) if elapsed > SHRINK_FROM else 1.0
	var size: float = BOX_SIZE * maxf(0.001, fade)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var dt: float = minf(delta, 0.045)
	for i in range(_positions.size()):
		var current: Vector3 = _positions[i]
		var velocity: Vector3 = _velocities[i]
		if not _resting[i]:
			velocity.y -= GRAVITY * dt
			var next: Vector3 = current + velocity * dt
			# Cast in world coordinates, colliding only with terrain layer 1.
			# Bounce is subtle. Once slow, retain friction and never roll away.
			var query := PhysicsRayQueryParameters3D.create(
				global_position + current + Vector3.UP * 0.08,
				global_position + next - Vector3.UP * 0.055, 1)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				var normal: Vector3 = hit.get("normal", Vector3.UP)
				next = (hit.get("position", global_position + next) as Vector3) - global_position + normal * 0.06
				if normal.y > 0.6:
					_landings += 1
					_bounces[i] += 1
					velocity.x *= 0.42
					velocity.z *= 0.42
					velocity.y = absf(velocity.y) * BOUNCE if _bounces[i] < 2 else 0.0
					if velocity.y < 0.55:
						velocity = Vector3.ZERO
						_resting[i] = true
				else:
					velocity = velocity.slide(normal) * 0.30
			_positions[i] = next
			_velocities[i] = velocity
		else:
			_velocities[i].x = move_toward(velocity.x, 0.0, REST_FRICTION * dt)
			_velocities[i].z = move_toward(velocity.z, 0.0, REST_FRICTION * dt)
		_instance_mesh.set_instance_transform(i,
			Transform3D(Basis().scaled(Vector3.ONE * size), _positions[i]))
