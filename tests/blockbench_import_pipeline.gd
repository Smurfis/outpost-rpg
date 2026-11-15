extends SceneTree
## Import pipeline smoke; must run after headless editor import.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS BLOCKBENCH: " + description)
	else:
		failures += 1
		push_error("FAIL BLOCKBENCH: " + description)

func _run() -> void:
	var plugins: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	_check("res://addons/bbmodel-importer/plugin.cfg" in plugins, "Pinned MIT Blockbench importer enabled in Godot editor")
	var source: String = "res://tests/fixtures/blockbench/outpost_import_probe.bbmodel"
	_check(FileAccess.file_exists(source), "Editable original Blockbench test fixture is present")
	_check(ResourceLoader.exists(source), "Godot imported .bbmodel as a resource")
	var packed: PackedScene = load(source) as PackedScene
	_check(packed != null, "Blockbench source imports as Godot PackedScene")
	if packed != null:
		var root_scene: Node = packed.instantiate()
		_check(root_scene is Node3D, "Imported model has a spatial scene root")
		var found: bool = false
		for child in root_scene.get_children():
			if child is MeshInstance3D:
				found = true
		_check(found, "Original cube becomes an actual Godot mesh")
		root_scene.free()
	print("BLOCKBENCH IMPORT RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
