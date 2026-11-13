extends Node3D
## Lightweight animated Cube World Kit visual; no gameplay or physics ownership.
## Native Godot 4.7 glTF imports; all model credits in kit/LICENSE_AND_CREDITS.md.
const ROOT: String = "res://assets/third_party/quaternius_cube_world/"
const MODEL_PATHS: Dictionary = {
	"pig": "Animals/glTF/Pig.gltf",
	"raccoon": "Animals/glTF/Raccoon.gltf",
	"wolf": "Animals/glTF/Wolf.gltf",
	"skeleton": "Enemies/glTF/Skeleton.gltf",
	"goblin": "Enemies/glTF/Goblin.gltf",
}
var model: Node3D
var animator: AnimationPlayer
var animation_names: Dictionary = {}
var event_lock: float = 0.0
var current_state: String = ""

func configure(kind: String, size: float = 1.0) -> bool:
	var relative: String = str(MODEL_PATHS.get(kind, ""))
	if relative.is_empty():
		return false
	var scene: PackedScene = load(ROOT + relative) as PackedScene
	if scene == null:
		push_warning("Cube World model missing for " + kind)
		return false
	model = scene.instantiate() as Node3D
	if model == null:
		return false
	add_child(model)
	model.scale = Vector3.ONE * size
	# Quaternius glTF creatures face local +Z, but Outpost's actors aim local -Z.
	# Turn only the imported artwork so gameplay movement and hitboxes stay unchanged.
	model.rotation.y = PI
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("Cube World model without animations: " + kind)
		return false
	animator = players[0] as AnimationPlayer
	for full_name in animator.get_animation_list():
		var label: String = str(full_name)
		animation_names[label.get_slice("/", label.get_slice_count("/") - 1).to_lower()] = label
	# Preserve original atlas colours but force pixel-crisp sampling in Compatibility renderer.
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var rendered: MeshInstance3D = node as MeshInstance3D
		if rendered.mesh == null:
			continue
		for surface_index in range(rendered.mesh.get_surface_count()):
			var original: Material = rendered.get_active_material(surface_index)
			if original is StandardMaterial3D:
				var pixel_mat: StandardMaterial3D = original.duplicate() as StandardMaterial3D
				pixel_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				rendered.set_surface_override_material(surface_index, pixel_mat)
	play_motion(0.0)
	return true

func _process(delta: float) -> void:
	event_lock = maxf(0.0, event_lock - delta)

func _play(label: String) -> bool:
	if animator == null:
		return false
	var canonical: String = str(animation_names.get(label.to_lower(), ""))
	if canonical.is_empty():
		return false
	if current_state == canonical and animator.is_playing():
		return true
	var clip: Animation = animator.get_animation(canonical)
	if clip == null:
		return false
	clip.loop_mode = Animation.LOOP_LINEAR if label in ["Idle", "Idle_Eating", "Walk", "Run"] else Animation.LOOP_NONE
	animator.play(canonical, 0.13 if current_state != "" else 0.0)
	current_state = canonical
	return true

func play_motion(speed: float, eating: bool = false) -> void:
	if event_lock > 0.0:
		return
	var idle: String = "Idle_Eating" if eating and animation_names.has("idle_eating") else "Idle"
	var desired: String = "Run" if speed >= 2.65 else "Walk" if speed > 0.15 else idle
	_play(desired)

func play_event(label: String, fallback: String = "") -> void:
	event_lock = 0.0
	var key: String = label if animation_names.has(label.to_lower()) else fallback
	if key.is_empty() or not _play(key):
		return
	var clip: Animation = animator.get_animation(current_state)
	event_lock = maxf(0.2, clip.length if clip != null else 0.5)

func revive() -> void:
	event_lock = 0.0
	current_state = ""
	play_motion(0.0)
