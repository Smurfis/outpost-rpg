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
	check(ATLAS.code.contains("discard;") and ATLAS.code.contains("island_world_normal"),
		"Isometric cutaway uses roof-face normals rather than deleting all foreground rock")
	check(ATLAS.code.contains("bool roof_face") and ATLAS.code.contains("bool overhead"),
		"Cutaway clips only ceiling faces high above the avatar; not cliff walls or floor")
	check(ATLAS.code.contains("floor(island_world_position.xz") and ATLAS.code.contains("cave_visibility_mask"),
		"Shader uses the connected room visibility mask")
	var tunnel: Vector3i = Vector3i.ZERO
	var covered: bool = false
	for route in world.caves.routes:
		for point in route:
			var at: Vector3i = point
			if world.height_at(at.x, at.z) >= at.y + 4:
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
		"Cave interior enables the local overhead cutout")
	check(island._reveal_cells.size() > 1, "Cave opening includes connected nearby cells")
	check(island._cutaway_material.get_shader_parameter("island_cutaway_enabled") == true,
		"Cutaway follows an actual camera")
	check((island._cutaway_material.get_shader_parameter("island_cutaway_eye") as Vector3).distance_to(host.camera.global_position) < 0.01,
		"Cutaway uses the current camera orbit")
	check((island._cutaway_material.get_shader_parameter("island_cutaway_focus") as Vector3).distance_to(cave_player + Vector3.UP * 0.95) < 0.01,
		"Cutaway focus follows the real avatar position")
	# Picking is allowed through exactly the clipped roof shape, but
	# never through a wall or the walkable cave floor in that body.
	var body := StaticBody3D.new()
	body.set_meta("island_roof_shape_index", 1)
	var inside: Vector3 = Vector3(cave_player.x, island._cutaway_focus.y + 3.0, cave_player.z)
	var roof_hit: Dictionary = {"collider": body, "shape": 1, "position": inside, "normal": Vector3.UP}
	check(island.cutaway_hides_hit(roof_hit), "Picking passes through the revealed overhead roof")
	roof_hit["position"] = inside + Vector3(float(island.REVEAL_RADIUS + 2), 0, 0)
	check(not island.cutaway_hides_hit(roof_hit), "Roof beyond the bounded reveal still blocks picking")
	roof_hit["position"] = inside
	roof_hit["normal"] = Vector3.RIGHT
	check(not island.cutaway_hides_hit(roof_hit),
		"Vertical cliff faces always stay solid and visible")
	roof_hit["normal"] = Vector3.UP
	roof_hit["shape"] = 0
	check(not island.cutaway_hides_hit(roof_hit), "World picking retains physical stone walls and cave floor")
	roof_hit["shape"] = 1
	roof_hit["position"] = island._cutaway_focus
	check(not island.cutaway_hides_hit(roof_hit), "World picking retains ground at player altitude")
	body.free()
	var center: Vector2i = world.islands[0]["center"]
	var shore_x: int = center.x + 32
	var shore_z: int = center.y
	var shore := Vector3(float(shore_x) + 0.5, float(world.height_at(shore_x, shore_z)) + 0.35, float(shore_z) + 0.5)
	island._update_cutaway(host, shore)
	check(not island._cave_mode and not island._cutaway_material.get_shader_parameter("island_cave_mode") == true,
		"Outdoor hillside uses the narrower cutaway")
	check(is_equal_approx(float(island._cutaway_material.get_shader_parameter("island_cutaway_radius")), 1.5),
		"Outdoor camera keeps the same tiny debug radius but disables all cutaways")
	check(island._cutaway_material.get_shader_parameter("island_cutaway_enabled") == false,
		"Outdoor mountain stays physically and visually opaque; hero can receive an outline")
	check(GREEDY.material().get_shader_parameter("island_cutaway_enabled") != true,
		"Fractal uniforms cannot affect original Fields terrain")
	host.hero.global_position = Vector3.ZERO
	island._process(0.016)
	check(not island._cutaway_material.get_shader_parameter("island_cutaway_enabled") == true,
		"Leaving the islands restores uncut foreground rendering")
	host.queue_free()
	print("CAVE CAMERA RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
