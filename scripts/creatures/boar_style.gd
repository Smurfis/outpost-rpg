extends RefCounted
## Quaternius pig rig is animated; boar-only materials and extra cuboid features
## give the enemy its own broad brown, tusked, bristled Cube World silhouette.
## The source pig mesh/animations are not modified, keeping passive pigs distinct.

static func decorate(model: Node3D) -> void:
	if model == null:
		return
	# Duplicate imported materials per boar; tint does not affect passive pigs.
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var rendered: MeshInstance3D = node as MeshInstance3D
		if rendered.mesh == null:
			continue
		for surface_index in range(rendered.mesh.get_surface_count()):
			var existing: Material = rendered.get_active_material(surface_index)
			if existing is StandardMaterial3D:
				var fur: StandardMaterial3D = existing.duplicate() as StandardMaterial3D
				fur.albedo_color *= Color(0.67, 0.53, 0.43, 1.0)
				fur.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				rendered.set_surface_override_material(surface_index, fur)
	var accents := Node3D.new()
	accents.name = "BoarAccents"
	model.add_child(accents)
	# +Z is the imported pig's muzzle direction; cube_world_visual turns
	# the whole model around once to match Outpost's actor-facing convention.
	for side in [-1.0, 1.0]:
		_box(accents, "CurvedTusk", Vector3(side * 0.32, 0.46, 0.92),
			Vector3(0.17, 0.39, 0.17), Color("#e7d7ab"), -24.0)
		_box(accents, "TuskPoint", Vector3(side * 0.34, 0.68, 0.98),
			Vector3(0.10, 0.17, 0.11), Color("#fff0ce"), 25.0)
		_box(accents, "DarkEar", Vector3(side * 0.37, 1.20, 0.54),
			Vector3(0.24, 0.34, 0.16), Color("#4e322e"), -20.0)
	for index in range(7):
		var z: float = -0.70 + float(index) * 0.23
		_box(accents, "BackBristle", Vector3(0.0, 1.38, z),
			Vector3(0.32, 0.23, 0.16), Color("#402b26"), -27.0)

static func _box(parent: Node3D, label: String, at: Vector3, dimensions: Vector3,
		tint: Color, pitch: float) -> void:
	var decoration := MeshInstance3D.new()
	decoration.name = label
	var block := BoxMesh.new()
	block.size = dimensions
	decoration.mesh = block
	decoration.position = at
	decoration.rotation_degrees.x = pitch
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	decoration.material_override = material
	decoration.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(decoration)
