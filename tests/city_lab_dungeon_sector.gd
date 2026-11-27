extends SceneTree
const Sector = preload("res://scripts/world/city_lab_dungeon_sector.gd")
const Dungeon = preload("res://scripts/world/city_lab_dungeon_connectors.gd")
const Pack = preload("res://scripts/world/city_lab_dungeon_pack.gd")
const Site = preload("res://scripts/world/city_lab_site.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var sector := Sector.new()
	for seed_value in [42,64012,-7]:
		for address in [[0,0],[1,0],[-1,-1],[1000000000000,-1000000000000]]:
			if not sector.generate(seed_value,address[0],address[1]):
				check(false,"Sector generation failed")
				continue
			var first := sector.solver.modules.duplicate(true)
			var links := sector.solver.links.duplicate(true)
			var voxels := sector.materialize()
			check(first.size()==25 and sector.solver.validate(),"Sector graph disconnected")
			# Validate actual walkable paths from center to all four external gateways.
			var walk: Dictionary = {}
			for p: Vector2i in first:
				var reachable := sector.solver._reachable(sector.solver.materialize(p))
				for cell: Vector2i in reachable: walk[p*Dungeon.SIDE+cell] = true
			var grid := AStarGrid2D.new()
			grid.region = Rect2i(0,0,Sector.SIDE,Sector.SIDE)
			grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
			grid.update()
			for z in range(Sector.SIDE):
				for x in range(Sector.SIDE):
					var p := Vector2i(x,z)
					if not walk.has(p): grid.set_point_solid(p,true)
			for d in range(4):
				var gate := sector.gate_cell(d)
				check(not grid.get_id_path(Vector2i(37,37),gate).is_empty(),"Unreachable sector gate")
				var neighbor := Sector.new()
				var dir: Vector2i = Sector.DIRS[d]
				if not neighbor.generate(seed_value,address[0]+dir.x,address[1]+dir.y):
					check(false,"Neighbor generation failed")
					continue
				var opposite: int = (d+2)%4
				var dest := neighbor.gate_cell(opposite)
				check(gate.x == dest.x if d%2==0 else gate.y==dest.y,"Shared gate misaligned")
				var other := neighbor.solver.materialize(neighbor.gate(opposite))
				check(neighbor.solver._clear(other,neighbor.solver._edge(opposite)),"Neighbor gate blocked")
			check(sector.generate(seed_value,address[0],address[1]) and first==sector.solver.modules and links==sector.solver.links and voxels==sector.materialize(),"Sector depends on generation order")
	_test_pack_and_site()
	print("SECTOR LAB RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)

func _edge_count(sector) -> int:
	var result := 0
	for p in sector.solver.links:
		result += sector.solver.links[p].size()
	return result/2

func _test_pack_and_site() -> void:
	var codec := Pack.new()
	var solver := Dungeon.new()
	var a := solver._builtin("creator:wide_turn",[0,1],100,true)
	var b := solver._builtin("creator:wide_straight",[0,2],100,true)
	var pack := codec.with_asset(codec.empty_pack(),a)
	pack = codec.with_asset(pack,b)
	check(not pack.is_empty() and pack["modules"].size()==2,"Multi-asset pack rejected")
	if pack.is_empty(): return
	check(codec.with_asset(pack,a).is_empty(),"Duplicate asset ID accepted")
	var reversed := pack.duplicate(true)
	reversed["modules"].reverse()
	check(codec.normalize(reversed)==codec.normalize(pack),"Pack ordering changes canonical content")
	check(codec.fingerprint(reversed)==codec.fingerprint(pack),"Pack fingerprint changes with module ordering")
	var invalid := pack.duplicate(true)
	invalid["loop_percent"] = 101
	check(codec.normalize(invalid).is_empty(),"Invalid loop density accepted")
	invalid = pack.duplicate(true)
	invalid["modules"][0]["sockets"][0]["type"] = "unsupported"
	check(codec.normalize(invalid).is_empty(),"Unsupported socket type accepted")
	var sector := Sector.new()
	pack["loop_percent"] = 0
	if not sector.generate(42,0,0,pack):
		check(false,"Zero-loop pack generation failed")
		return
	check(_edge_count(sector)==24,"Spanning tree does not have 24 edges")
	var first := sector.solver.modules.duplicate(true)
	reversed["loop_percent"] = 0
	check(sector.generate(42,0,0,reversed) and sector.solver.modules==first,"Pack ordering changes generated modules")
	pack["loop_percent"] = 100
	check(sector.generate(42,0,0,pack) and _edge_count(sector)==40,"Full-loop pack did not connect all cardinal edges")
	var site := Site.new()
	var context := site.context(64012,1000000000000,-1000000000000)
	check(context["site_id"]==site.identity(64012,1000000000000,-1000000000000),"Site context identity mismatch")
	check(context["dungeon_seed"]==site.dungeon_seed(64012,1000000000000,-1000000000000),"Site seed mismatch")
	check(context["site_id"]!=site.identity(64012,1000000000001,-1000000000000),"Site identity aliases neighboring city")
