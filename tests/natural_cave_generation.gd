extends SceneTree
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const PATH = preload("res://scripts/navigation/fractal_cave_path.gd")
const SEED := 64012

func _initialize() -> void:
	var terrain = DATA.new(SEED)
	var old: Dictionary = terrain.caves.floors.duplicate()
	var start := Time.get_ticks_usec()
	if not terrain.caves.install_natural(terrain, {}):
		push_error("No valid natural network for regression seed")
		quit(1)
		return
	var elapsed := Time.get_ticks_usec()-start
	var cave = terrain.caves.natural
	var valid: bool = cave.chambers.size() >= 3 and not cave.shaft.is_empty()
	var heights := {}
	for cell: Vector2i in cave.floors:
		heights[cave.floors[cell]] = true
		var bits: int = terrain.solid_column(cell.x, cell.y)
		for y in range(DATA.BEDROCK,terrain.height_at(cell.x,cell.y)+1):
			valid = valid and terrain.is_solid(cell.x,y,cell.y) == bool(bits & (1 << (y-DATA.BEDROCK)))
		var floor_y: int = cave.floors[cell]
		valid = valid and terrain.is_solid(cell.x,floor_y-1,cell.y) and not terrain.is_solid(cell.x,floor_y+2,cell.y)
		valid = valid and not old.has(cell)
		var target := Vector3(cell.x+0.5,floor_y+0.1,cell.y+0.5)
		if PATH._branch_path(terrain.caves,cave.approach,cell,target).is_empty():
			print("Unreachable ", cell, " Y ", floor_y)
			valid = false
	for cell in old:
		valid = valid and old[cell] == terrain.caves.floors[cell]
	var repeat = DATA.new(SEED)
	valid = valid and repeat.caves.install_natural(repeat,{}) and repeat.caves.natural.ceilings == cave.ceilings and repeat.caves.natural.floors == cave.floors
	var protected = DATA.new(SEED)
	valid = valid and not protected.caves.install_natural(protected,{cave.mouth:true}) and protected.caves.floors == old
	valid = valid and heights.size() >= 4 and cave.ceilings[cave.shaft_bottom]-cave.floors[cave.shaft_bottom] >= 4
	print("NATURAL seed ",SEED," generation us ",elapsed," mouth ",cave.mouth," rooms ",cave.chambers," shaft ",cave.shaft_bottom," rim ",cave.rim," floors ",heights.keys()," columns ",cave.floors.size()," passed ",valid)
	quit(0 if valid else 1)
