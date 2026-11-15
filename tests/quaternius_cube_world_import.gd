extends SceneTree
## Confirms the installed CC0 Cube World glTFs become usable animated
## Godot 4.7.2 scenes. Does not replace working animal AI/hitboxes.
const ROOT = "res://assets/third_party/quaternius_cube_world"
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS CUBE WORLD: " + description)
	else:
		failures += 1
		push_error("FAIL CUBE WORLD: " + description)

func _run() -> void:
	check(FileAccess.file_exists(ROOT + "/SOURCE_MANIFEST.json"), "Source hashes, Quaternius and CC0 licence recorded")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "/SOURCE_MANIFEST.json"))
	check(raw is Dictionary, "Cube World provenance JSON is readable")
	if raw is Dictionary:
		check(int(raw.get("model_count_in_mirror", 0)) >= 100, "Installed mirrored pack contains 100+ original models")
		check(str(raw.get("license", "")).contains("CC0"), "CC0 licence identified")
	var subjects: Dictionary = {
		"Animals/glTF/Wolf.gltf": ["Idle", "Walk", "Run", "Death"],
		"Animals/glTF/Pig.gltf": ["Idle", "Walk", "Run", "Death"],
		"Enemies/glTF/Skeleton.gltf": ["Idle", "Walk", "Attack", "Death"],
	}
	for name in subjects:
		var path: String = ROOT + "/" + name
		check(ResourceLoader.exists(path), "Imported source file exists: " + name)
		var scene: PackedScene = load(path) as PackedScene
		check(scene != null, "Godot imports the glTF as a PackedScene: " + name)
		if scene == null:
			continue
		var root_scene: Node = scene.instantiate()
		var animators: Array[Node] = root_scene.find_children("*", "AnimationPlayer", true, false)
		var meshes: Array[Node] = root_scene.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), "Model contains actual skinned geometry: " + name)
		check(not animators.is_empty(), "Imported scene exposes an AnimationPlayer: " + name)
		if not animators.is_empty():
			var animations: PackedStringArray = (animators[0] as AnimationPlayer).get_animation_list()
			for needed in subjects[name]:
				var found: bool = false
				for label in animations:
					if str(label).to_lower().ends_with(str(needed).to_lower()):
						found = true
				check(found, "Has animation " + str(needed) + ": " + name)
		root_scene.free()
	print("CUBE WORLD KIT RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
