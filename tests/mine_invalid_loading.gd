extends "res://tests/side_chamber_walk.gd"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "negative"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://cycle_fixture_sites.json"))
	var id := "fractal_physical_goblin_mine_1_64012"
	match mode:
		"wrong_id": source.world_sites.sites[id].site_id = "other"
		"negative": source.world_sites.sites[id].cycle = -1
		"fractional": source.world_sites.sites[id].cycle = 0.5
		"future": source.world_sites.sites[id].cycle = 2
		"seed": source.world_sites.sites[id].layout_seed = 1
		"schema": source.world_sites.schema = 99
	var player := "user://cycle_fixture_player.json"
	if mode == "protected":
		var terrain0 = preload("res://scripts/world/fractal_archipelago_data.gd").new(64012)
		var terrain1 = preload("res://scripts/world/fractal_archipelago_data.gd").new(64012)
		var reg = preload("res://scripts/dungeons/world_site_registry.gd")
		terrain0.caves.carve_mine(terrain0,reg.cycle_seed(64012,id,0,"initial"))
		terrain1.caves.carve_mine(terrain1,reg.cycle_seed(64012,id,1,"initial"))
		var changed: Vector2i = Vector2i.MAX
		for cell: Vector2i in terrain1.caves.floors:
			if terrain0.caves.floors.get(cell) != terrain1.caves.floors.get(cell):
				changed = cell
				break
		check(changed != Vector2i.MAX,"missing changed terrain")
		player = "user://protected_player.json"
		var construction := FileAccess.open(player,FileAccess.WRITE)
		construction.store_string(JSON.stringify({"version":5,"placed_blocks":[[changed.x,0,changed.y]]}))
		construction.close()
	var path := "user://invalid_%s_sites.json" % mode
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(source))
	file.close()
	var raw := FileAccess.get_file_as_string(path)
	await setup_walk(player,path,false)
	var manager = game.get_node("Dungeons")
	if mode != "protected":
		check(not manager.world_site_save_valid,"invalid record accepted")
	check(island.mine == null and island.mine_load_failed,"unsafe mine constructed")
	island._queue_near(Vector3(192,3,62))
	check(island._pending.is_empty() and island._loaded.is_empty(),"unsafe terrain queued")
	check(FileAccess.get_file_as_string(path) == raw,"invalid save modified")
	print("INVALID LOAD ",mode," ",not failed)
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
