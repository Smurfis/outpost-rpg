extends SceneTree
const Plan = preload("res://scripts/world/terrain_city_lab_plan.gd")
const Mesher = preload("res://scripts/world/city_lab_mesher.gd")
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
	print("CITY LAB RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
