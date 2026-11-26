extends SceneTree
const Plan = preload("res://scripts/world/terrain_city_lab_plan.gd")
const Mesher = preload("res://scripts/world/city_lab_mesher.gd")
const Prefab = preload("res://scripts/world/city_lab_prefab.gd")
const Edits = preload("res://scripts/world/city_lab_edits.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	for seed_value in [64012,64013,64014,42,-5]:
		var first := Plan.new()
		var second := Plan.new()
		if not first.generate(seed_value) or not second.generate(seed_value):
			check(false,"City route validation failed: %d" % seed_value)
			continue
		check(first.blocks == second.blocks and first.districts == second.districts,"Non-deterministic city: %d" % seed_value)
		for p in first.districts:
			for d in Plan.DIRS:
				if first.districts.has(p+d):
					check(first._compatible(first.districts[p],first.districts[p+d]),"Invalid WFC adjacency")
			if first.districts[p] == "market":
				check(first.entrances.has(p),"Market missing road socket")
		check(first.rooms.size() >= 2,"BSP did not subdivide")
		for z in range(Plan.SIZE):
			for x in range(Plan.SIZE):
				var cell := Vector2i(x,z)
				for d in [Vector2i.RIGHT,Vector2i.DOWN]:
					var q: Vector2i = cell+d
					if q.x < Plan.SIZE and q.y < Plan.SIZE:
						check(absi(first.height_at(cell)-first.height_at(q)) <= 1,"Unwalkable terrain step")
		var far := Plan.new()
		var far_repeat := Plan.new()
		check(far.generate(seed_value,1000000000000,-1000000000000),"Far region failed")
		check(far_repeat.generate(seed_value,1000000000000,-1000000000000),"Far repeat failed")
		check(far.blocks == far_repeat.blocks,"Far region not deterministic")
		check(first.region.heights != far.region.heights,"Far region lost its address identity")
	var mesher := Mesher.new()
	var blocks: Dictionary = {}
	for x in range(3):
		for y in range(3):
			for z in range(3):
				blocks[Vector3i(x,y,z)] = 2
	var buckets := mesher.bucket(blocks)
	var result := mesher.rectangles(blocks,buckets[Vector3i.ZERO],Vector3i.ZERO)
	check(result["exposed"] == 54 and result["quads"].size() == 6,"Solid cube greedy mesh regression")
	var area := 0
	for q in result["quads"]: area += int(q[3])*int(q[4])
	check(area == result["exposed"],"Greedy merge lost surface area")
	blocks = {Vector3i(15,-1,0):2,Vector3i(16,-1,0):2}
	buckets = mesher.bucket(blocks)
	var exposed := 0
	for key: Vector3i in buckets:
		result = mesher.rectangles(blocks,buckets[key],key)
		exposed += int(result["exposed"])
	check(exposed == 10,"Cross-section internal face was emitted")
	check(mesher.section_of(Vector3i(-1,-1,-1)) == Vector3i(-1,-1,-1),"Negative section addressing")
	_test_creator()
	print("CITY LAB RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _test_creator() -> void:
	var prefab := Prefab.new()
	var edits := Edits.new()
	var plan := Plan.new()
	if not plan.generate(64012):
		check(false,"Cannot test editor without a valid city")
		return
	edits.reset(plan.blocks)
	var original := plan.blocks.duplicate()
	var a := Vector3i(15,20,15)
	var b := Vector3i(16,21,17)
	var patch: Dictionary = {}
	for p in prefab.selection(b,a): patch[p] = 2
	check(patch.size() == 12,"Inclusive reversed selection")
	check(edits.apply(plan,patch,plan.start),"Valid fill rejected")
	check(edits.changes.size() == 12,"Overlay did not record fill")
	var dirty := edits.dirty_sections(patch)
	check(dirty.has(Vector3i(0,1,0)) and dirty.has(Vector3i(1,1,1)),"Boundary dirty sections missing")
	var captured := prefab.capture(plan.blocks,a,b)
	var decoded := prefab.decode(JSON.parse_string(JSON.stringify(captured)))
	check(not decoded.is_empty() and decoded.get("size") == Vector3i(2,2,3),"Prefab round trip dimensions")
	var stamp := prefab.stamp(captured,Vector3i(30,20,30),1)
	check(stamp.size() == 12 and stamp.has(Vector3i(32,21,31)),"Quarter-turn stamp bounds")
	check(edits.apply(plan,stamp,plan.start),"Stamp rejected")
	var encoded: Variant = JSON.parse_string(JSON.stringify(edits.encode(64012,1000000000000,-1000000000000)))
	var test_file := "user://city_lab_test_%d.json" % Time.get_ticks_usec()
	check(edits.write_json(test_file,encoded),"Overlay disk write failed")
	check(edits.write_json(test_file,encoded),"Overlay replacement failed")
	var disk_value: Variant = edits.read_json(test_file)
	check(disk_value == encoded,"Overlay disk round trip")
	if FileAccess.file_exists(test_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_file))
	var overlay: Variant = edits.decode(encoded,64012,1000000000000,-1000000000000)
	check(overlay is Dictionary and overlay.size() == 24,"Overlay round trip")
	check(edits.decode(encoded,64012,1000000000001,-1000000000000) == null,"Wrong-region overlay accepted")
	var fresh := Plan.new()
	if fresh.generate(64012) and overlay is Dictionary:
		var replay := Edits.new()
		replay.reset(fresh.blocks)
		check(replay.apply(fresh,overlay,fresh.start,false) and fresh.blocks == plan.blocks,"Overlay replay changed world")
	else:
		check(false,"Cannot test replay")
	var before := plan.blocks.duplicate()
	var forbidden := Vector3i(plan.start.x,plan.height_at(plan.start)+1,plan.start.y)
	check(not edits.apply(plan,{forbidden:2},plan.start),"Blocking the spawn was accepted")
	check(before == plan.blocks,"Rejected edit mutated occupancy")
	check(not edits.undo(plan,plan.start).is_empty(),"Stamp undo failed")
	check(not edits.undo(plan,plan.start).is_empty(),"Fill undo failed")
	check(plan.blocks == original and edits.changes.is_empty(),"Undo did not restore generated base")
	check(prefab.decode({"schema_version":1,"size":[2,2,2],"voxels":[[0,0,0,2],[0,0,0,3]]}).is_empty(),"Duplicate prefab positions accepted")
	check(prefab.selection(Vector3i.ZERO,Vector3i(24,0,0)).is_empty(),"Oversized selection accepted")
	check(prefab.stamp(captured,Vector3i(87,20,87),1).is_empty(),"Out-of-bounds stamp accepted")
