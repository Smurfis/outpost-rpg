extends SceneTree
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")

func _initialize() -> void:
	var valid := true
	var layouts := {}
	OS.set_environment("OUTPOST_TEST_SIDE_CHAMBER","0")
	for seed_value in [64012,64013,64014,1979,319]:
		OS.set_environment("OUTPOST_TEST_PROCEDURAL_CAVE","0")
		var original = DATA.new(seed_value)
		OS.set_environment("OUTPOST_TEST_PROCEDURAL_CAVE","1")
		var terrain = DATA.new(seed_value)
		var cave = terrain.caves
		valid = valid and cave.branches == DATA.new(seed_value).caves.branches
		valid = valid and cave.branches.size() in range(2,5) and cave.routes == original.caves.routes
		for cell: Vector2i in original.caves.floors:
			valid = valid and cave.floors[cell] == original.caves.floors[cell]
		var centers := []
		for branch in cave.branches:
			centers.append(branch.center)
			print(seed_value," junction ",branch.junction," threshold ",branch.threshold," room ",branch.center," size ",branch.size," floor ",cave.floors[branch.center])
			for cells: Dictionary in [branch.room,branch.passage]:
				for cell: Vector2i in cells:
					var y: int = cave.floors[cell]
					valid = valid and terrain.is_solid(cell.x,y-1,cell.y) and terrain.is_solid(cell.x,y+3,cell.y)
					for dy in 3:
						valid = valid and not terrain.is_solid(cell.x,y+dy,cell.y)
		# Compare the streamer's packed columns to the physical occupancy.
		var samples: Array = cave.floors.keys()
		samples.append_array([Vector2i.ZERO,Vector2i(205,62),Vector2i(207,62),Vector2i(172,57)])
		for cell: Vector2i in samples:
			var solid: int = terrain.solid_column(cell.x,cell.y)
			for y in range(DATA.BEDROCK,terrain.height_at(cell.x,cell.y)+4):
				if bool(solid & (1 << (y-DATA.BEDROCK))) != terrain.is_solid(cell.x,y,cell.y):
					valid = false
					push_error("Occupancy mismatch at %s, Y=%d" % [cell,y])
		layouts[str(centers)] = true
	OS.set_environment("OUTPOST_TEST_SIDE_CHAMBER","1")
	valid = valid and DATA.new(64012).caves.branches.is_empty() and layouts.size() == 5
	print("PROCEDURAL LAYOUT ", valid)
	quit(0 if valid else 1)
