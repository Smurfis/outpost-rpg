extends SceneTree

const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const REGISTRY = preload("res://scripts/dungeons/world_site_registry.gd")

func _initialize() -> void:
	var failed := false
	for world_seed in [64012, 64013]:
		var id := "fractal_physical_goblin_mine_1_%d" % world_seed
		var last := {}
		for cycle in range(16):
			var seed := REGISTRY.cycle_seed(world_seed,id,cycle,"initial")
			var terrain = DATA.new(world_seed)
			var built: bool = terrain.caves.carve_mine(terrain,seed)
			var repeated = DATA.new(world_seed)
			var rebuilt: bool = repeated.caves.carve_mine(repeated,seed)
			if not built or not rebuilt or terrain.caves.floors != repeated.caves.floors or terrain.caves.floors == last:
				push_error("Invalid or unchanged mine for world %d cycle %d" % [world_seed,cycle])
				failed = true
			last = terrain.caves.floors.duplicate()
	print("MINE SEEDS ", not failed)
	quit(int(failed))
