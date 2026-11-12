extends SceneTree
## Bounded camera/voxel cutaway regression. Island chunk generation/collision
## are covered by the existing fractal archetype and shoreline smoke suites.
const ISLAND = preload("res://scripts/world/island_archipelago.gd")
const GREEDY = preload("res://scripts/voxel/greedy_mesher.gd")
const ATLAS = preload("res://scripts/voxel/greedy_atlas.gdshader")
var failures: int = 0

class CameraHost:
	extends Node3D
	var camera: Camera3D
	var hero: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS CAVE CAMERA: " + message)
	else:
		failures += 1
		push_error("FAIL CAVE CAMERA: " + message)

func _run() -> void:
	var host := CameraHost.new()
	root.add_child(host)
	host.camera = Camera3D.new()
	host.add_child(host.camera)
	host.hero = Node3D.new()
	host.add_child(host.hero)
	var land := Node3D.new()
	host.add_child(land)
	var island = ISLAND.new()
	island.setup(64012)
	land.add_child(island)
	var world = island.terrain
	check(island._cutaway_material != null and island._cutaway_material != GREEDY.material(),
		"Island atlas material is independent from shared Fields")
	check(GREEDY.material().get_shader_parameter("island_cutaway_enabled") != true,
		"Ordinary Fields never inherit fractal cutaways")
	check(ATLAS.code.contains("discard;") and ATLAS.code.contains("island_world_position"),
		"Cutaway is pixel-local and does not remove any physics bodies")
	var tunnel: Vector3i = Vector3i.ZERO
	var covered: bool = false
	for route in world.caves.routes:
		for point in route:
			var at: Vector3i = point
			if at.x <= (route[0] as Vector3i).x - 7 and world.height_at(at.x, at.z) >= at.y + 5:
				tunnel = at
				covered = true
				break
		if covered:
			break
	check(covered, "Island generation provides covered descending cave cells")
	if not covered:
		host.queue_free()
		quit(1)
		return
	var cave_player := Vector3(float(tunnel.x) + 0.5, float(tunnel.y) + 0.35, float(tunnel.z) + 0.5)
	host.hero.global_position = cave_player
	host.camera.global_position = cave_player + Vector3(22.0, 20.0, 22.0)
	check(island._is_below_terrain(cave_player), "Cave floor is correctly classified as underground")
	var roof := MeshInstance3D.new()
	island.add_child(roof)
	roof.visible = false
	island._roof_nodes.append(roof)
	island._update_cutaway(host, cave_player)
	check(roof.visible, "Previously hidden cave roof is retained for per-pixel cutaway")
	check(island._cave_mode and island._cutaway_material.get_shader_parameter("island_cave_mode") == true,
		"Cave interior enables the wider opening")
	check(is_equal_approx(float(island._cutaway_material.get_shader_parameter("island_cutaway_radius")), 4.6),
		"Cave opening uses the expected world-space radius")
	check(island._cutaway_material.get_shader_parameter("island_cutaway_enabled") == true,
		"Cutaway follows an actual camera")
	check((island._cutaway_material.get_shader_parameter("island_cutaway_eye") as Vector3).distance_to(host.camera.global_position) < 0.01,
		"Cutaway uses the current camera orbit")
	check((island._cutaway_material.get_shader_parameter("island_cutaway_focus") as Vector3).distance_to(cave_player + Vector3.UP * 0.95) < 0.01,
		"Cutaway focus follows the real avatar position")
	# Preserve the physical-looking cave mouth rather than cutting a
	# 6x14 block of visible hill out of the camera foreground.
	var mouth: Vector3 = world.caves.entrances[0] + Vector3.UP * 0.35
	host.hero.global_position = mouth
	island._update_cutaway(host, mouth)
	check(island._cutaway_material.get_shader_parameter("island_cutaway_enabled") == false,
		"Natural cave mouth retains its visible hillside without a large camera cutout")
	check(island._cave_mode == false, "Camera does not classify the surface entrance as a deep cavern")
	var center: Vector2i = world.islands[0]["center"]
	var shore_x: int = center.x + 32
	var shore_z: int = center.y
	var shore := Vector3(float(shore_x) + 0.5, float(world.height_at(shore_x, shore_z)) + 0.35, float(shore_z) + 0.5)
	island._update_cutaway(host, shore)
	check(not island._cave_mode and not island._cutaway_material.get_shader_parameter("island_cave_mode") == true,
		"Outdoor hillside uses the narrower cutaway")
	check(is_equal_approx(float(island._cutaway_material.get_shader_parameter("island_cutaway_radius")), 3.6),
		"Outdoor corridor is narrower than a cave")
	check(GREEDY.material().get_shader_parameter("island_cutaway_enabled") != true,
		"Fractal uniforms cannot affect original Fields terrain")
	host.hero.global_position = Vector3.ZERO
	island._process(0.016)
	check(not island._cutaway_material.get_shader_parameter("island_cutaway_enabled") == true,
		"Leaving the islands restores uncut foreground rendering")
	host.queue_free()
	print("CAVE CAMERA RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
