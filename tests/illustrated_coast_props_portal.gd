extends SceneTree
## Godot 4.7.2: godot --headless --path . -s res://tests/illustrated_coast_props_portal.gd
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ILLUSTRATED WORLD: " + label)
	else:
		failures += 1
		push_error("FAIL ILLUSTRATED WORLD: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sand: Texture2D = load("res://assets/voxel/coastal_terrain_16px.svg") as Texture2D
	check(sand != null and sand.get_size() == Vector2(32, 32),
		"Original 2x2 coastal sand atlas still imports at 32px")
	var props = load("res://scripts/voxel/voxel_props.gd")
	for category in ["tree", "stone", "bush"]:
		var mesh: MeshInstance3D
		if category == "tree":
			mesh = props.tree()
		elif category == "stone":
			mesh = props.rock("stone")
		else:
			mesh = props.bush(true)
		check(mesh != null and mesh.mesh != null,
			"Detailed " + category + " renders in one atlas mesh")
	var vortex: Shader = load("res://scripts/dungeons/pixel_portal_vortex.gdshader")
	check(vortex != null, "Pixel vortex shader imports")
	var portal_script = load("res://scripts/dungeons/dungeon_portal.gd")
	check(portal_script != null, "Existing portal script imports")
	if portal_script != null:
		var portal = portal_script.new()
		portal.configure("visual_test", "visual_chunk", 0)
		check(portal.orb != null and portal.orb.material_override is ShaderMaterial,
			"Entrance still uses the rarity gate with the new animated surface")
	print("ILLUSTRATED WORLD: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
