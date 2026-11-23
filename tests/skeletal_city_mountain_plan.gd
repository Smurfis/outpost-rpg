extends SceneTree
## Run with: godot --headless --path . --script res://tests/skeletal_city_mountain_plan.gd
## Pure data test: no changes to active worlds, saves, or terrain.
const GENERATOR = preload("res://scripts/world/skeletal_city_mountain_plan.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS SKELETAL CITY: " + message)
	else:
		failures += 1
		push_error("FAIL SKELETAL CITY: " + message)

func _check_path(route: Array, floors: Dictionary, air: Dictionary,
		supports: Dictionary, name: String) -> void:
	check(not route.is_empty(), name + " exists")
	for i in range(route.size()):
		var at: Vector3i = route[i]
		check(floors.has(at) and air.has(at) and supports.has(at + Vector3i.DOWN),
			name + " has supported, carved tile %d" % i)
		if i > 0:
			var prev: Vector3i = route[i - 1]
			check(absi(at.y - prev.y) <= 1 and
				absi(at.x - prev.x) + absi(at.z - prev.z) <= 1,
				name + " has continuous one-voxel traversal at step %d" % i)

func _run() -> void:
	for world_seed in [64012, 64013, 64014]:
		var proposal: Dictionary = GENERATOR.new().generate(world_seed)
		var repeat: Dictionary = GENERATOR.new().generate(world_seed)
		var entrance: Array = proposal["entrance_route"]
		var spiral: Array = proposal["spiral_route"]
		var exit_path: Array = proposal["exit_route"]
		var floors: Dictionary = proposal["floors"]
		var air: Dictionary = proposal["air"]
		var supports: Dictionary = proposal["supports"]
		var levels: Dictionary = proposal["column_levels"]
		check(spiral == repeat["spiral_route"], "Same seed yields identical spiral")
		check(entrance == repeat["entrance_route"], "Same seed yields identical gateway")
		check(spiral.size() >= 350, "Three full perimeter turns are generated")
		check(spiral.front() == entrance.back(), "Gateway joins spiral physically")
		check(spiral.back() == exit_path.front(), "Spiral joins exit physically")
		check(spiral.front().y - spiral.back().y >= 30, "Multi-level descent reaches lower city")
		check(proposal["city_center"].y == exit_path.back().y,
			"Reserved city anchor uses the final landing's height")
		_check_path(entrance, floors, air, supports, "Gateway")
		_check_path(spiral, floors, air, supports, "Spiral")
		_check_path(exit_path, floors, air, supports, "Lower exit")
		var stacked_columns: int = 0
		for column: Vector2i in levels:
			if (levels[column] as Array).size() >= 2:
				stacked_columns += 1
		check(stacked_columns > 0, "Same X/Z positions retain multiple walkable Y levels")
		var conflicts: int = 0
		for support: Vector3i in supports:
			if air.has(support):
				conflicts += 1
		check(conflicts == 0, "Proposed solid supports never intersect carved air")
	check(GENERATOR.new().generate(64012)["spiral_route"] !=
		GENERATOR.new().generate(64013)["spiral_route"],
		"Different seeds vary the mountain spiral footprint")
	print("SKELETAL CITY MOUNTAIN PLAN RESULT: %d failures." % failures)
	quit(0 if failures == 0 else 1)
