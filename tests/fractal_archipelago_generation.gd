extends SceneTree
## Pure generation regressions: runnable without Android or entering gameplay.
const GEN = preload("res://scripts/world/fractal_archipelago_data.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS FRACTAL: " + detail)
	else:
		failures += 1
		push_error("FAIL FRACTAL: " + detail)

func _run() -> void:
	var world = GEN.new(64012)
	var again = GEN.new(64012)
	check(world.islands.size() == 3, "Three separate exploration islands are defined")
	check(not world.is_land_at(0.5, 0.5), "Archipelago does not replace home Outpost")
	check(not world.is_land_at(110.5, 26.5), "Navigable ocean separates Outpost and first island")
	for island in world.islands:
		var center: Vector2i = island["center"]
		check(world.is_land_at(center.x + 0.5, center.y + 0.5),
			"Island center is dry land at %s" % str(center))
		check(world.height_at(center.x, center.y) > 0,
			"An elevated inland landscape is present at %s" % str(center))
		for dx in [-8, 0, 8]:
			var x: int = center.x + dx
			var z: int = center.y + dx
			check(world.height_at(x, z) == again.height_at(x, z),
				"Generation is repeatable for fixed seed at %d,%d" % [x, z])
	# The old Y=-2 shore was >1.5 metres above a swimmer's feet. Require
	# a shallow landing step and a walking-height route towards cave access.
	for island in world.islands:
		var centre: Vector2i = island["center"]
		var radius: int = ceili(float(island["radius"]))
		var z: int = centre.y
		var was_land: bool = false
		var last_y: int = -9999
		var max_y: int = -9999
		for x in range(centre.x + radius + 6, centre.x + roundi(radius * 0.50), -1):
			if not world.is_land_at(float(x) + 0.5, float(z) + 0.5):
				continue
			var y: int = world.height_at(x, z)
			if not was_land:
				check(y <= -3, "Island shore starts within swimming auto-step reach")
				was_land = true
			else:
				check(absi(y - last_y) <= 1, "One-block maximum along island landing route")
			last_y = y
			max_y = maxi(max_y, y)
		check(was_land and max_y >= 1, "Landing route rises from ocean to explorable terrain")
	check(world.caves.routes.size() == world.islands.size(), "One connected cave route per exploration island")
	check(world.caves.chests.size() == world.islands.size(), "One persistent chest position per cave")
	var covered_ceiling: bool = false
	for route in world.caves.routes:
		check(route.size() >= 20, "Cave tunnel extends into the mountain")
		check(world.caves.route_has_safe_steps(route), "All transitions fit one-block vertical climbing")
		for cell in route:
			var at: Vector3i = cell
			var floor_y: int = world.caves.floor_at(at.x, at.z)
			check(floor_y >= 0, "Tunnel floors remain above sea level")
			check(not world.is_solid(at.x, floor_y, at.z),
				"Guaranteed tunnel air space at %s" % str(at))
			check(world.is_solid(at.x, floor_y - 1, at.z),
				"Solid walkable floor beneath tunnel at %s" % str(at))
			if world.is_solid(at.x, floor_y + 6, at.z):
				covered_ceiling = true
	# The first design was only two voxels wide and erased entire stone
	# columns, leaving a roughly 6x14 rectangular tear near the entrance.
	# Validate a walkable arched opening, real stone roof and an intact
	# hillside from entrance through chamber on every procedural island.
	for i in range(world.caves.routes.size()):
		var route: Array = world.caves.routes[i]
		var mouth: Vector3i = route[0]
		var entry_air: int = 0
		for side in range(-3, 4):
			var z: int = mouth.z + side
			if world.caves.is_air(mouth.x, mouth.y + 1, z):
				entry_air += 1
		check(entry_air >= 5, "Island %d has a broad walk-in cave mouth" % [i + 1])
		check(not world.caves.is_air(mouth.x + 1, mouth.y + 1, mouth.z),
			"Island %d entrance begins in the rock wall, not a surface trench" % [i + 1])
		var roofed: int = 0
		var flat_roofs: int = 0
		for step in range(2, mini(route.size(), 15)):
			var cell: Vector3i = route[step]
			var floor_y: int = world.caves.floor_at(cell.x, cell.z)
			if world.height_at(cell.x, cell.z) >= floor_y + 7:
				roofed += 1
			if world.is_solid(cell.x, world.height_at(cell.x, cell.z) - 1, cell.z):
				flat_roofs += 1
		check(roofed >= 9, "Island %d keeps actual mountain rock above its tunnel" % [i + 1])
		check(flat_roofs >= 9, "Island %d has no long surface trench over its cave" % [i + 1])
		var end: Vector3i = route[route.size() - 1]
		var room_width: int = 0
		for side in range(-4, 5):
			if world.caves.is_air(end.x, end.y + 2, end.z + side):
				room_width += 1
		check(room_width >= 7, "Island %d ends in a roomy, connected treasure chamber" % [i + 1])
	check(covered_ceiling, "At least one cave tunnel has an actual solid overhead roof")
	check(world.map_cell_at(172, 62).get("zone") == "inland", "Diorama reads distant island heights")
	print("FRACTAL ARCHIPELAGO RESULT: %d failures." % failures)
	quit(0 if failures == 0 else 1)
