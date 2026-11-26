extends SceneTree
const Dungeon = preload("res://scripts/world/city_lab_dungeon_connectors.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var d := Dungeon.new()
	if not d.load_defaults():
		check(false,"Default library invalid")
		_finish()
		return
	var invalid := d._builtin("blocked", [0,2], 1)
	invalid["prefab"]["voxels"].append([Dungeon.MID,1,0,2])
	check(not d.register_asset(invalid),"Obstructed doorway accepted")
	var wrong := d._builtin("wrong",[0,2],1)
	wrong["sockets"][0]["direction"] = 1
	check(not d.register_asset(wrong),"Wrong-facing opening accepted")
	var custom := d._builtin("custom_chamber",[0,1],1,true)
	check(d.register_asset(JSON.parse_string(JSON.stringify(custom))),"Creator-format JSON asset rejected")
	for seed_value in [42,64012,64013,-7]:
		if not d.generate(seed_value,32):
			check(false,"Generation failed for seed %d" % seed_value)
			continue
		var layout := d.modules.duplicate(true)
		var edges := d.links.duplicate(true)
		check(d.validate() and d.modules.size()==32,"Disconnected layout")
		for p: Vector2i in d.modules:
			var cells := d.materialize(p)
			var reachable := d._reachable(cells)
			for dir in range(4):
				var edge := d._edge(dir)
				var across: Vector2i = Dungeon.DIRS[(dir+1)%4]
				for offset in range(-1,2):
					var open: bool = reachable.has(edge+across*offset)
					check(open==d.links[p].has(dir),"Physical opening differs from graph")
				if d.links[p].has(dir):
					var q: Vector2i = d.links[p][dir]
					var other := d.materialize(q)
					var other_edge := d._edge((dir+2)%4)
					for offset in range(-1,2):
						check(d._clear(other,other_edge+across*offset),"Neighbour aperture obstructed")
		check(d.generate(seed_value,32) and d.modules==layout and d.links==edges,"Non-deterministic assembly")
	check(not d.generate(0,Dungeon.MAX_MODULES+1),"Unbounded allocation accepted")
	_finish()

func _finish() -> void:
	print("CONNECTOR LAB RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)
