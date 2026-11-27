extends SceneTree
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const BUILDING = preload("res://scripts/world/default_settlement_building.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for seed_value in [64012,64013,42]:
		var source := DATA.new(seed_value)
		var plan = source.settlement_plan()
		if plan == null:
			check(false,"No default settlement for seed %d" % seed_value)
			continue
		var duplicate := DATA.new(seed_value)
		var repeat = duplicate.settlement_plan()
		check(repeat != null,"Repeat settlement missing")
		if repeat != null:
			check(repeat.roads==plan.roads and repeat.buildings==plan.buildings,"Settlement is nondeterministic")
		check(plan.buildings.size()>=2,"Missing built-in structures")
		check(plan.roads.has(plan.hub) and plan.roads.has(plan.landing),"Missing coastal approach")
		for p: Vector2i in plan.roads:
			check(not source.caves.has_cave(p.x,p.y),"Road intersects cave")
			check(source.top_tile(p.x,p.y)==5,"Terrain sampler disagrees with planned path")
			check(not plan.reserved.has(p),"Road intersects building footprint")
		for item in plan.buildings:
			var route: Array = item["route"]
			check(route.front()==plan.hub,"Building not connected to hub")
			for i in range(1,route.size()):
				var a: Vector2i = route[i-1]
				var b: Vector2i = route[i]
				check(absi(a.x-b.x)+absi(a.y-b.y)==1,"Noncardinal route")
				check(absi(source.height_at(a.x,a.y)-source.height_at(b.x,b.y))<=1,"Unwalkable route step")
			var rect: Rect2i = item["rect"]
			var floor_y: int = item["floor"]
			var door: Vector2i = item["door"]
			var direction: Vector2i = item["direction"]
			var outside: Vector2i = door+direction
			check(route.back()==outside,"Route misses door")
			check(absi(floor_y-source.height_at(outside.x,outside.y))<=1,"Door has unsafe step")
			var building := BUILDING.new()
			root.add_child(building)
			building.build(item,source)
			check(building.quad_count<building.exposed_count,"Greedy merge did not reduce quads")
			check(building.parts.has(0) and building.parts.has(5),"Missing floor or roof")
			var hero := Vector3(rect.position.x+3.5,floor_y,rect.position.y+3.5)
			for d in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD,Vector3(1,0,1),Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(-1,0,1)]:
				building.update_view(hero,hero+d*20+Vector3.UP*20)
				check(not building.parts[5]["mesh"].visible,"Interior roof not removed")
				for group in building.parts:
					var part: Dictionary = building.parts[group]
					check(part["body"].collision_layer==1,"Visual cutaway changed physical collision")
					check(part["body"].get_meta("building_cutaway_hidden",false)==not part["mesh"].visible,"Picker flag differs from visibility")
				check(building.parts[0]["mesh"].visible,"Floor cut away")
			building.update_view(hero+Vector3(30,0,0),hero+Vector3(40,20,0))
			for part in building.parts.values():
				check(part["mesh"].visible and not part["body"].get_meta("building_cutaway_hidden",false),"Exterior restoration failed")
			building.queue_free()
	print("DEFAULT SETTLEMENT RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)
