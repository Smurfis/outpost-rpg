extends Node3D
const VOXEL_PALETTE = preload("res://scripts/voxel/voxel_palette.gd")
## Five clickable 3D Crafting Stations. Built-in meshes; original, mobile-friendly.
var station_id: String = "workbench"
var activity: float = 0.0
var effect: MeshInstance3D
var legacy_fire_parts: Array[MeshInstance3D] = []
var pyrolux_fire: Node3D
var time: float = 0.0
var station_label: Label3D
const STATION_LABEL_RADIUS: float = 7.0

func setup(id: String) -> void:
	station_id = id
	name = id.capitalize() + "Station"
	_build()
	add_to_group("stations")

func _part(mesh: Mesh, at: Vector3, tint: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = mesh
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.85
	mesh_node.material_override = mat
	add_child(mesh_node)
	return mesh_node

func _block(size: Vector3, at: Vector3, tint: Color) -> MeshInstance3D:
	if get_parent() != null and bool(get_parent().get("voxel_art_enabled")):
		var top_tile: int = 11
		var side_tile: int = 8
		match station_id:
			"forge":
				top_tile = 4
				side_tile = 12
				if tint.v < 0.40:
					top_tile = 15
			"enchanting":
				top_tile = 13
				side_tile = 12
			"loom":
				top_tile = 11
				side_tile = 8
			"campfire":
				top_tile = 8
				side_tile = 8
			"workbench":
				if tint.s < 0.22:
					top_tile = 4
					side_tile = 4
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		VOXEL_PALETTE.box(st, Vector3.ZERO, size, top_tile, side_tile)
		var mesh_node: MeshInstance3D = VOXEL_PALETTE.as_instance(st, "PixelCraftingBlock")
		mesh_node.position = at
		add_child(mesh_node)
		return mesh_node
	var shape := BoxMesh.new()
	shape.size = size
	return _part(shape, at, tint)

func _glow_block(size: Vector3, at: Vector3, tint: Color) -> MeshInstance3D:
	# Emissive pixel-shaped fire without a shadowed mobile point light.
	var shape := BoxMesh.new()
	shape.size = size
	var flame: MeshInstance3D = _part(shape, at, tint)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = material
	return flame

func _rod(bottom: float, top: float, height: float, at: Vector3, tint: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 7
	return _part(shape, at, tint)

func _label(message: String, tint: Color) -> void:
	var tag := Label3D.new()
	tag.name = "ProximityStationLabel"
	tag.text = message
	tag.font_size = 48
	tag.pixel_size = 0.006
	tag.position = Vector3(0, 2.55, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = false # Geometry and the avatar may occlude world text.
	tag.modulate = tint
	tag.visible = false
	add_child(tag)
	station_label = tag

func _build() -> void:
	match station_id:
		"workbench":
			# Layered walnut work surface, chunky joinery, shelf and rear tool rack.
			_block(Vector3(2.78, 0.19, 1.57), Vector3(0, 0.90, 0), Color("9f7446"))
			_block(Vector3(2.90, 0.12, 1.65), Vector3(0, 1.04, 0), Color("c39557"))
			for x in [-1.10, 1.10]:
				for z in [-0.50, 0.50]:
					_block(Vector3(0.25, 0.87, 0.25), Vector3(x, 0.43, z), Color("5e402f"))
			_block(Vector3(2.22, 0.13, 1.10), Vector3(0, 0.24, 0), Color("865d37"))
			_block(Vector3(2.55, 0.54, 0.17), Vector3(0, 1.44, 0.69), Color("a97947"))
			for i in range(4):
				_block(Vector3(0.13, 0.08, 1.45), Vector3(-0.90 + float(i) * 0.59, 1.13, 0), Color("d0a165"))
			# Two upright hanging implements (recognisable crafting silhouette).
			_block(Vector3(0.12, 0.48, 0.10), Vector3(-0.78, 1.51, 0.53), Color("8a603c"))
			_block(Vector3(0.39, 0.15, 0.14), Vector3(-0.78, 1.77, 0.53), Color("b6b9ad"))
			_block(Vector3(0.10, 0.44, 0.10), Vector3(0.70, 1.55, 0.53), Color("8a603c"))
			_block(Vector3(0.31, 0.11, 0.17), Vector3(0.70, 1.77, 0.53), Color("aaa9a0"))
			effect = _block(Vector3(0.50, 0.12, 0.31), Vector3(0.08, 1.24, -0.11), Color("cad0c7"))
			_label("WORKBENCH • CRAFTING STATION", Color("f3dc9e"))
		"forge":
			# Tiered cobblestone and dark hearth; tall chimney reads from iso view.
			_block(Vector3(2.96, 0.39, 2.35), Vector3(0, 0.19, 0), Color("6b6660"))
			for x in [-1.10, 1.10]:
				_block(Vector3(0.46, 1.17, 2.14), Vector3(x, 0.75, 0), Color("777a75"))
			_block(Vector3(2.0, 0.24, 1.62), Vector3(0, 0.56, 0), Color("34312c"))
			_block(Vector3(2.0, 0.31, 0.43), Vector3(0, 1.28, 0.87), Color("9c9082"))
			_block(Vector3(0.95, 2.08, 0.76), Vector3(0, 1.82, 0.92), Color("756f68"))
			_block(Vector3(1.12, 0.22, 0.94), Vector3(0, 2.91, 0.92), Color("aaa29a"))
			legacy_fire_parts.append(_glow_block(Vector3(1.47, 0.15, 1.00), Vector3(0, 0.75, -0.12), Color("eb6a2b")))
			effect = _glow_block(Vector3(0.61, 0.49, 0.44), Vector3(0, 1.02, -0.20), Color("ffb24d"))
			legacy_fire_parts.append(effect)
			_block(Vector3(0.89, 0.55, 0.64), Vector3(0, 0.30, -1.65), Color("67645f"))
			_block(Vector3(1.35, 0.21, 0.71), Vector3(0, 0.71, -1.65), Color("88929a"))
			_block(Vector3(0.40, 0.17, 0.34), Vector3(0, 0.87, -1.65), Color("a9b2b6"))
			_label("FORGE • CRAFTING STATION", Color("f7b56e"))
		"loom":
			for x in [-1.18, 1.18]:
				_block(Vector3(0.23, 2.15, 0.28), Vector3(x, 1.1, 0), Color("856545"))
			for y in [0.65, 1.95]:
				_block(Vector3(2.62, 0.18, 0.24), Vector3(0, y, 0), Color("b69059"))
			for i in range(13):
				_block(Vector3(0.038, 1.3, 0.045), Vector3(-1.03 + float(i) * 0.17, 1.28, 0.05), Color("d8d1b2"))
			effect = _block(Vector3(1.92, 0.52, 0.12), Vector3(0, 1.04, 0.2), Color("7b9e88"))
			_label("LOOM • CRAFTING STATION", Color("d9dfb4"))
		"enchanting":
			_block(Vector3(2.55, 0.36, 1.8), Vector3(0, 0.87, 0), Color("#535075"))
			for x in [-0.97, 0.97]:
				for z in [-0.59, 0.59]:
					_block(Vector3(0.28, 0.78, 0.28), Vector3(x, 0.4, z), Color("#474256"))
			effect = _block(Vector3(0.76, 0.18, 0.76), Vector3(0, 1.20, 0), Color("#ba82df"))
			for x in [-0.83, 0.83]:
				_block(Vector3(0.26, 0.76, 0.25), Vector3(x, 1.41, 0), Color("#e2b661"))
			_label("ENCHANTING • CRAFTING STATION", Color("#e9b9fe"))
		"campfire":
			for i in range(8):
				var a: float = TAU * float(i) / 8.0
				_rod(0.30, 0.28, 0.24, Vector3(cos(a) * 0.9, 0.12, sin(a) * 0.9), Color("a9a19a"))
			_block(Vector3(1.65, 0.16, 0.25), Vector3(0, 0.28, 0), Color("6b4c32"))
			_block(Vector3(0.25, 0.16, 1.65), Vector3(0, 0.30, 0), Color("805636"))
			# A simple primitive flame + odd grey smoke cylinder existed before
			# PyroLux. Keep them only as no-addon fallbacks, never draw both.
			effect = _rod(0.40, 0.0, 0.8, Vector3(0, 0.68, 0), Color("f2a649"))
			effect.name = "LegacyCampfireFlame"
			legacy_fire_parts.append(effect)
			var old_smoke: MeshInstance3D = _rod(0.73, 0.73, 0.25, Vector3(0, 1.18, 0), Color("525d5d"))
			old_smoke.name = "LegacyCampfireSmoke"
			legacy_fire_parts.append(old_smoke)
			for x in [-0.62, 0.62]:
				var old_post: MeshInstance3D = _rod(0.07, 0.07, 0.56, Vector3(x, 1.25, 0), Color("555d5a"))
				old_post.name = "LegacyCampfireSmokePost"
				legacy_fire_parts.append(old_post)
			_label("CAMPFIRE • CRAFTING STATION", Color("f2c583"))
	# PyroLux fire is loaded dynamically so the source tree still opens before
	# installing the licensed addon. The Alpha APK installs it before export.
	if station_id in ["campfire", "forge"]:
		var preset_path: String = "res://addons/pyrolux_fx/presets/3d/fire_campfire.tscn"
		if ResourceLoader.exists(preset_path):
			var fire_scene: PackedScene = load(preset_path) as PackedScene
			if fire_scene != null:
				var fire: Node3D = fire_scene.instantiate() as Node3D
				if fire != null:
					fire.name = "PyroLuxFlames"
					pyrolux_fire = fire
					fire.position = Vector3(0, 0.36, 0) if station_id == "campfire" else Vector3(0, 0.89, -0.20)
					fire.scale = Vector3.ONE * (0.62 if station_id == "campfire" else 0.44)
					add_child(fire)
					# Remove ALL legacy fire VFX, not just the orange flame cone:
					# the forge had a second glow tile and the campfire still
					# showed the old grey cylinder/posts behind PyroLux.
					# Keep logs, stones and real crafting station geometry.
					_disable_legacy_fire_vfx()
	if effect != null and pyrolux_fire == null:
		effect.position.y += 0.01

func _disable_legacy_fire_vfx() -> void:
	# Used by PyroLux integration and callable in headless regression tests
	# without redistributing the licensed add-on into GitHub.
	for old_part in legacy_fire_parts:
		if is_instance_valid(old_part):
			old_part.visible = false


func set_activity(progress: float) -> void:
	activity = progress

func stroke() -> void:
	if effect != null and pyrolux_fire == null:
		var tween := create_tween()
		tween.tween_property(effect, "scale", Vector3(1.18, 1.27, 1.18), 0.08)
		tween.tween_property(effect, "scale", Vector3.ONE, 0.18)

func _process(delta: float) -> void:
	time += delta
	if station_label != null:
		var world: Node = get_parent()
		var adventurer: Node3D = world.get("hero") as Node3D if world != null else null
		station_label.visible = adventurer != null and Vector2(adventurer.global_position.x - global_position.x, adventurer.global_position.z - global_position.z).length_squared() < STATION_LABEL_RADIUS * STATION_LABEL_RADIUS
	if effect != null and pyrolux_fire == null and station_id in ["forge", "campfire", "enchanting"]:
		effect.scale.x = 1.0 + 0.06 * sin(time * 6.0)
		effect.scale.z = 1.0 + 0.06 * sin(time * 6.0)
	if activity > 0.0 and effect != null and pyrolux_fire == null:
		effect.rotation.y += delta * 0.24
