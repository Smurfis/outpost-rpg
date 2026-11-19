extends SceneTree

const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const SECTION = preload("res://scripts/world/island_section_mesh.gd")

func _initialize() -> void:
	var terrain = DATA.new(64012)
	var chamber: Vector3i = terrain.caves.routes[0].back()
	# Remove a foundation block across the east edge of a one-column chunk.
	var neighbor := chamber + Vector3i(1, -2, 0)
	var origin := Vector2i(chamber.x, chamber.z)
	var intact := SECTION.build(terrain, origin, 1, {})
	var section := SECTION.build(terrain, origin, 1, {neighbor: true})
	var valid: bool = intact.cut_faces == 0 and section.cut_faces == 1
	var arrays: Array = section.mesh.surface_get_arrays(0)
	var cap_vertices := 0
	var floor_vertices := 0
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var p: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
		var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
		if is_equal_approx(p.x,neighbor.x) and n.dot(Vector3.RIGHT)>0.99:
			cap_vertices += 1
		if is_equal_approx(p.y,chamber.y) and n.dot(Vector3.UP)>0.99:
			floor_vertices += 1
	valid = valid and cap_vertices >= 6 and floor_vertices >= 6 and terrain.is_solid(neighbor.x,neighbor.y,neighbor.z)
	print("SECTION MESH ",valid," new faces=",section.cut_faces," floor vertices=",floor_vertices)
	quit(0 if valid else 1)
