extends Node3D
## Native 3D Five Star Interactive ident. All meshes are generated locally.
## No GIF, external image, asset download, or runtime network dependency.
const STAR_COUNT := 5
const FLIGHT_SECONDS := 6.0
const STAR_RING_RADIUS := 2.65
const RING_Y := 0.25

var _stars: Array[MeshInstance3D] = []
var _trails: Array[ImmediateMesh] = []
var _portal: Node3D
var _voxel_batches: Dictionary = {}
var _time: float = 0.0

func _ready() -> void:
	_build_camera_and_lighting()
	_build_voxel_outpost()
	_build_portal()
	_build_stars()
	seek(0.0)

func get_star_count() -> int:
	return _stars.size()

func get_portal_progress() -> float:
	return clampf((_time - 3.5) / 1.8, 0.0, 1.0)

func seek(seconds: float) -> void:
	_time = maxf(0.0, seconds)
	var reveal: float = _smooth(3.5, 5.3, _time)
	_portal.visible = reveal > 0.0
	_portal.scale = Vector3.ONE * maxf(0.001, reveal)
	_portal.rotation.z = 0.018 * sin(_time * 0.60) * reveal
	for i in range(STAR_COUNT):
		var star: MeshInstance3D = _stars[i]
		var delay: float = float(i) * 0.16
		var fly_t: float = clampf((_time - delay) / (FLIGHT_SECONDS - delay), 0.0, 1.0)
		star.position = _flight_position(i, fly_t)
		star.rotation = Vector3(0.18 * (1.0 - fly_t), 0.9 * (1.0 - fly_t), (1.0 - fly_t) * (2.0 + float(i) * 0.55))
		star.scale = Vector3.ONE * (0.82 + 0.10 * _smooth(0.0, 1.0, fly_t))
		_update_trail(i, fly_t)

func _build_camera_and_lighting() -> void:
	var camera := Camera3D.new()
	camera.name = "IdentCamera"
	camera.position = Vector3(0.0, 0.50, 11.5)
	camera.fov = 49.0
	camera.near = 0.05
	camera.far = 110.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.25, 0.0), Vector3.UP)
	camera.current = true

	var sun := DirectionalLight3D.new()
	sun.name = "SunsetKey"
	sun.rotation_degrees = Vector3(-34.0, -28.0, -12.0)
	sun.light_color = Color("#ffd09a")
	sun.light_energy = 1.65
	sun.shadow_enabled = false
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "GoldenFill"
	fill.position = Vector3(-2.0, 3.5, 5.0)
	fill.light_color = Color("#ffe6b0")
	fill.light_energy = 2.1
	fill.omni_range = 20.0
	fill.shadow_enabled = false
	add_child(fill)

func _material(tint: Color, metallic: float = 0.0, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = metallic
	m.roughness = 0.48 if metallic > 0.0 else 0.86
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = energy
	return m

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material, label: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	return instance

func _box(kind: String, at: Vector3, size: Vector3) -> void:
	if not _voxel_batches.has(kind):
		_voxel_batches[kind] = []
	var group: Array = _voxel_batches[kind]
	group.append(Transform3D(Basis.IDENTITY.scaled(size), at))

func _build_voxel_outpost() -> void:
	var palette: Dictionary = {
		"rock": Color("#565064"),
		"rock_light": Color("#81727d"),
		"grass": Color("#678d45"),
		"dirt": Color("#836447"),
		"wood": Color("#654533"),
		"wood_light": Color("#ac7c4a"),
		"roof": Color("#403746"),
		"banner": Color("#a14443"),
		"gold": Color("#e7b75c"),
		"window": Color("#ffc36a"),
		"leaves": Color("#385a43"),
		"leaves_light": Color("#4b7b4d"),
		"mountain": Color("#786780")
	}

	# Tiny layered voxel valley behind the medallion.
	for x in range(-11, 12):
		var xf: float = float(x) * 0.28
		var back_h: int = maxi(0, 3 - absi(x) / 4)
		for h in range(back_h):
			_box("mountain", Vector3(xf, -2.1 + float(h) * 0.28, -2.8),
				Vector3(0.29, 0.28, 0.34))

	# Cliff with a jagged underside, flat habitable upper edge.
	for x in range(-8, 9):
		var xf: float = float(x) * 0.29
		var depth: int = maxi(2, 6 - absi(x) / 3)
		for z in range(3):
			for h in range(depth):
				var yf: float = -2.35 + float(h) * 0.30
				_box("rock" if (x + z + h) % 3 else "rock_light",
					Vector3(xf, yf, -0.85 - float(z) * 0.29),
					Vector3(0.29, 0.30, 0.29))
			_box("dirt", Vector3(xf, -0.70, -0.85 - float(z) * 0.29),
				Vector3(0.29, 0.22, 0.29))
			_box("grass", Vector3(xf, -0.55, -0.85 - float(z) * 0.29),
				Vector3(0.30, 0.10, 0.30))

	# A small, clearly medieval timber watchtower, not science fiction.
	for side in [-1, 1]:
		var xf: float = float(side) * 0.43
		for zside in [-1, 1]:
			var zf: float = -0.74 + float(zside) * 0.29
			_box("wood", Vector3(xf, 0.44, zf), Vector3(0.15, 1.92, 0.15))
	_box("wood_light", Vector3(0.0, 0.38, -0.73), Vector3(1.15, 0.19, 0.95))
	_box("wood_light", Vector3(0.0, 1.20, -0.73), Vector3(1.40, 0.18, 1.20))
	for x in [-0.49, 0.49]:
		_box("wood", Vector3(x, 1.56, -0.73), Vector3(0.16, 0.72, 0.15))
	_box("roof", Vector3(0.0, 1.98, -0.73), Vector3(1.72, 0.22, 1.46))
	_box("roof", Vector3(0.0, 2.20, -0.73), Vector3(1.22, 0.20, 1.08))
	_box("roof", Vector3(0.0, 2.40, -0.73), Vector3(0.56, 0.18, 0.70))
	_box("window", Vector3(-0.20, 0.76, -0.18), Vector3(0.22, 0.38, 0.08))
	_box("window", Vector3(0.20, 0.76, -0.18), Vector3(0.22, 0.38, 0.08))
	_box("wood", Vector3(0.0, 2.71, -0.70), Vector3(0.07, 0.68, 0.06))
	_box("banner", Vector3(0.29, 2.85, -0.68), Vector3(0.56, 0.28, 0.04))
	_box("gold", Vector3(0.33, 2.84, -0.63), Vector3(0.12, 0.08, 0.03))

	# Two crimson hanging banners, torches and grassy voxel trees.
	for side in [-1, 1]:
		var x: float = float(side) * 1.08
		_box("wood", Vector3(x, 0.43, -0.40), Vector3(0.10, 1.85, 0.10))
		_box("banner", Vector3(x, 0.85, -0.28), Vector3(0.42, 0.67, 0.09))
		_box("gold", Vector3(x, 0.88, -0.21), Vector3(0.12, 0.16, 0.04))
		_box("wood", Vector3(x * 1.3, -0.22, -0.13), Vector3(0.10, 0.55, 0.10))
		_box("window", Vector3(x * 1.3, 0.10, -0.13), Vector3(0.17, 0.20, 0.15))
	for x in [-1.90, 1.94]:
		_box("wood", Vector3(x, -0.14, -0.63), Vector3(0.14, 0.85, 0.14))
		for h in range(3):
			var radius: float = 0.54 - float(h) * 0.12
			_box("leaves" if h % 2 == 0 else "leaves_light",
				Vector3(x, 0.15 + float(h) * 0.26, -0.63),
				Vector3(radius * 2.0, 0.29, radius * 1.75))

	# Merge hundreds of little cubes into a handful of draw calls for Android.
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	for kind in _voxel_batches.keys():
		var key: String = str(kind)
		var instances: Array = _voxel_batches[kind]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = unit_box
		batch.instance_count = instances.size()
		for idx in range(instances.size()):
			batch.set_instance_transform(idx, instances[idx])
		var node := MultiMeshInstance3D.new()
		node.name = "Voxel_" + key
		node.multimesh = batch
		node.material_override = _material(palette[key], 0.0, 0.65 if key == "window" else 0.0)
		add_child(node)

func _build_portal() -> void:
	_portal = Node3D.new()
	_portal.name = "GoldenPortal"
	_portal.position.y = RING_Y
	add_child(_portal)
	_add_ring(2.59, 0.20, Color("#d49539"), 0.0, "OuterBronze")
	_add_ring(2.42, 0.085, Color("#fff1ad"), 0.11, "GoldHighlight")
	_add_ring(2.76, 0.045, Color("#d98931"), -0.10, "OuterFiligree")
	for i in range(20):
		var a: float = float(i) * TAU / 20.0
		var block := BoxMesh.new()
		block.size = Vector3(0.08, 0.22, 0.09)
		var tick := _mesh(_portal, block,
			Vector3(cos(a) * 2.58, sin(a) * 2.58, 0.11),
			_material(Color("#ffe2a1"), 0.65), "RingNotch")
		tick.rotation.z = a - PI * 0.5

func _add_ring(radius: float, width: float, tint: Color, depth: float, label: String) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - width * 0.5
	torus.outer_radius = radius + width * 0.5
	torus.rings = 80
	torus.ring_segments = 8
	var ring := _mesh(_portal, torus, Vector3(0.0, 0.0, depth),
		_material(tint, 0.76, 0.25), label)
	ring.rotation.x = PI * 0.5

func _star_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector2] = []
	for i in range(10):
		var a: float = float(i) * TAU / 10.0 - PI * 0.5
		var radius: float = 0.42 if i % 2 == 0 else 0.20
		points.append(Vector2(cos(a), sin(a)) * radius)
	for i in range(10):
		var j: int = (i + 1) % 10
		var p: Vector2 = points[i]
		var q: Vector2 = points[j]
		# Raised centre makes each front triangle a polished gold facet.
		_tri(tool, Vector3(0.0, 0.0, 0.18),
			Vector3(p.x, p.y, 0.08), Vector3(q.x, q.y, 0.08))
		_tri(tool, Vector3(0.0, 0.0, -0.14),
			Vector3(q.x, q.y, -0.12), Vector3(p.x, p.y, -0.12))
		_tri(tool, Vector3(p.x, p.y, 0.08),
			Vector3(p.x, p.y, -0.12), Vector3(q.x, q.y, 0.08))
		_tri(tool, Vector3(q.x, q.y, 0.08),
			Vector3(p.x, p.y, -0.12), Vector3(q.x, q.y, -0.12))
	tool.generate_normals()
	return tool.commit()

func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)

func _build_stars() -> void:
	var gold := _material(Color("#ffd16b"), 0.72, 0.30)
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.vertex_color_use_as_albedo = true
	glow.no_depth_test = true
	glow.emission_enabled = true
	glow.emission = Color("#ffc36b")
	glow.emission_energy_multiplier = 1.25
	var mesh: ArrayMesh = _star_mesh()
	for i in range(STAR_COUNT):
		var star := _mesh(self, mesh, Vector3.ZERO, gold, "FlyingStar_%d" % (i + 1))
		_stars.append(star)
		var trail := ImmediateMesh.new()
		var trail_node := _mesh(self, trail, Vector3.ZERO, glow, "StarTrail_%d" % (i + 1))
		trail_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trails.append(trail)

func _final_position(i: int) -> Vector3:
	var a: float = -PI * 0.5 + float(i) * TAU / float(STAR_COUNT)
	return Vector3(cos(a) * STAR_RING_RADIUS, RING_Y + sin(a) * STAR_RING_RADIUS, 0.62)

func _flight_position(i: int, progress: float) -> Vector3:
	var p0 := Vector3(-7.0 + float(i) * 2.95, 5.3 + float(i % 2), -11.0)
	var near_pass := Vector3(-2.6 + float(i) * 1.22, 1.35 + float(i % 3) * 0.35, 8.0)
	var end: Vector3 = _final_position(i)
	if progress < 0.63:
		var t: float = _smooth(0.0, 0.63, progress)
		return p0.bezier_interpolate(
			Vector3(p0.x * 0.7, 4.35, -3.0),
			Vector3(near_pass.x - 1.2, near_pass.y + 1.0, 6.4),
			near_pass, t)
	var settle: float = _smooth(0.63, 1.0, progress)
	return near_pass.bezier_interpolate(
		Vector3(near_pass.x + 0.9, near_pass.y - 0.95, 5.6),
		Vector3(end.x * 1.30, end.y * 1.2, 1.4),
		end, settle)

func _update_trail(i: int, progress: float) -> void:
	var trail: ImmediateMesh = _trails[i]
	trail.clear_surfaces()
	if progress <= 0.04 or progress >= 0.985:
		return
	trail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(12):
		var a_p: float = maxf(0.0, progress - float(segment) * 0.012)
		var b_p: float = maxf(0.0, progress - float(segment + 1) * 0.012)
		if a_p <= b_p:
			continue
		var a: Vector3 = _flight_position(i, a_p)
		var b: Vector3 = _flight_position(i, b_p)
		var direction: Vector3 = (a - b).normalized()
		var perpendicular := Vector3(-direction.y, direction.x, 0.0).normalized()
		var width: float = 0.065 * (1.0 - float(segment) / 12.0)
		var side: Vector3 = perpendicular * width
		var color := Color(1.0, 0.79, 0.39, 0.65 * (1.0 - float(segment) / 12.0))
		_trail_vertex(trail, a + side, color)
		_trail_vertex(trail, b + side, color)
		_trail_vertex(trail, a - side, color)
		_trail_vertex(trail, a - side, color)
		_trail_vertex(trail, b + side, color)
		_trail_vertex(trail, b - side, color)
	trail.surface_end()

func _trail_vertex(trail: ImmediateMesh, vertex: Vector3, color: Color) -> void:
	trail.surface_set_color(color)
	trail.surface_add_vertex(vertex)

func _smooth(start: float, finish: float, value: float) -> float:
	var t: float = clampf((value - start) / maxf(0.001, finish - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
