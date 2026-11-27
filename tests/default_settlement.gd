extends SceneTree
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const BUILDING = preload("res://scripts/world/default_settlement_building.gd")
const SCENERY = preload("res://scripts/world/default_settlement_scenery.gd")
const ADVENTURE = preload("res://scripts/world/regional_adventure_policy.gd")
const MATURITY = preload("res://scripts/world/ore_maturity.gd")
const QUALITY = preload("res://scripts/crafting/equipment_quality.gd")
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
		check(plan.plaza.has(plan.hub),"Missing public square")
		check(plan.roads.has(plan.hub) and plan.roads.has(plan.landing),"Missing coastal approach")
		check(plan._graph.get_point_count()==0 and plan._ids.is_empty() and plan._heights.is_empty(),"Planning graph retained after generation")
		if not plan.cave_route.is_empty():
			check(plan.cave_route.front()==plan.hub and plan.cave_route.back()==plan.cave_approach,"Cave trail misses its POI approach")
			for i in range(1,plan.cave_route.size()):
				var a: Vector2i = plan.cave_route[i-1]
				var b: Vector2i = plan.cave_route[i]
				check(a.distance_squared_to(b)==1 and absi(source.height_at(a.x,a.y)-source.height_at(b.x,b.y))<=1,"Unsafe cave approach step")
				check(plan.roads.has(b) and not plan.reserved.has(b),"Cave approach intersects a building or lacks path material")
		print("SETTLEMENT SEED %d: %d buildings, %d road cells, %d cave approach cells" % [seed_value,plan.buildings.size(),plan.roads.size(),plan.cave_route.size()])
		for p: Vector2i in plan.roads:
			check(not source.caves.has_cave(p.x,p.y),"Road intersects cave")
			check(source.top_tile(p.x,p.y)==(6 if plan.plaza.has(p) else 5),"Terrain sampler disagrees with planned path")
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
			for v: Vector3i in building.voxels:
				check(v.x>=0 and v.z>=0 and v.x<rect.size.x and v.z<rect.size.y,"Prefab geometry exceeds its reserved footprint")
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
	_test_regional_plans()
	_test_adventure_policy()
	_test_maturity()
	print("DEFAULT SETTLEMENT RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)

func _test_regional_plans() -> void:
	for seed_value in [64012,64013,42]:
		var source := DATA.new(seed_value)
		check(source._settlements.is_empty(),"Regional planning not lazy")
		check(source.settlement_plan(0)==null,"Mine island received settlement")
		var west = source.settlement_plan(1)
		var south = source.settlement_plan(2)
		if west==null or south==null:
			check(false,"Missing regional settlement seed %d" % seed_value)
			continue
		var reverse := DATA.new(seed_value)
		var south_again = reverse.settlement_plan(2)
		var west_again = reverse.settlement_plan(1)
		check(south_again!=null and west_again!=null,"Reverse generation lost site")
		if south_again==null or west_again==null: continue
		check(west.buildings==west_again.buildings and west.roads==west_again.roads and west.landmarks==west_again.landmarks and west.fields==west_again.fields and west.scenery==west_again.scenery and west.quest_anchors==west_again.quest_anchors and west.gathering.nodes==west_again.gathering.nodes,"Western site changes with visit order")
		check(south.buildings==south_again.buildings and south.roads==south_again.roads and south.landmarks==south_again.landmarks and south.fields==south_again.fields and south.scenery==south_again.scenery and south.quest_anchors==south_again.quest_anchors and south.gathering.nodes==south_again.gathering.nodes,"Southern site changes with visit order")
		check(west.profile=="frontier_waystation" and south.profile=="market_town","Regional identities lost")
		check(west.buildings.size()==3 and south.buildings.size()==6,"Default regional kit incomplete")
		var ids: Dictionary = {}
		for plan in [west,south]:
			check(not plan.west_route.is_empty(),"Missing western route")
			check(not plan.eastern_route.is_empty(),"Missing eastern approach")
			check(not plan.cave_route.is_empty(),"Missing cave approach")
			check(plan._validate_network(source),"Published road network disconnected")
			for record in plan.landmarks:
				check(not ids.has(record["id"]),"Duplicate regional landmark ID")
				ids[record["id"]]=true
				var cell: Vector2i = record["cell"]
				check(plan.roads.has(cell) and source.settlement_index_at(cell.x,cell.y)==plan.island_index,"Landmark not on local road")
			for item in plan.buildings:
				var rect: Rect2i = item["rect"]
				check(source.settlement_at(rect.position.x,rect.position.y)==item,"Building lookup resolves wrong island")
			for cell: Vector2i in plan.roads:
				check(not source.caves.has_cave(cell.x,cell.y) and not plan.reserved.has(cell),"Regional route intersects protected geometry")
				check(source.top_tile(cell.x,cell.y)==(6 if plan.plaza.has(cell) else 5),"Regional terrain map differs from road plan")
			_test_countryside(source,plan)
			_test_quest_anchors(source,plan)
			_test_gathering(source,plan)
			print("REGION SEED %d | %s | %d buildings | %d road cells | %d landmarks" % [seed_value,plan.profile,plan.buildings.size(),plan.roads.size(),plan.landmarks.size()])

func _test_countryside(source,plan) -> void:
	check(not plan.fields.is_empty(),"No farmland on default regional seed")
	check(not plan.scenery.is_empty(),"No countryside scenery")
	var chunks: Dictionary = {}
	for field in plan.fields:
		var rect: Rect2i = field["rect"]
		var entry: Vector2i = field["entry"]
		check(plan.roads.has(entry),"Farm disconnected from road")
		for z in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var p := Vector2i(x,z)
				check(plan.field_tiles.has(p) and not plan.roads.has(p) and not plan.reserved.has(p),"Farm overlaps protected land")
				check(not source.caves.has_cave(x,z) and source.top_tile(x,z)==3,"Farm sampler or cave clearance mismatch")
				for d in [Vector2i.RIGHT,Vector2i.DOWN]:
					var q: Vector2i = p+d
					if rect.has_point(q):
						check(absi(source.height_at(p.x,p.y)-source.height_at(q.x,q.y))<=1,"Unsafe farm terrace step")
	for p: Vector2i in plan.scenery:
		var spec: Dictionary = plan.scenery[p]
		check(not plan.roads.has(p) and not plan.reserved.has(p) and not source.caves.has_cave(p.x,p.y),"Scenery obstructs reserved route or cave")
		check(spec["height"]==source.height_at(p.x,p.y),"Scenery floats above terrain")
		if spec["kind"]=="crop": check(plan.field_tiles.has(p),"Crop outside field")
		var key := Vector2i(floori(p.x/16.0)*16,floori(p.y/16.0)*16)
		chunks[key]=int(chunks.get(key,0))+1
	var total := 0
	for key: Vector2i in chunks:
		var mesh := SCENERY.build(plan,key,16)
		check(mesh!=null,"Missing countryside mesh")
		if mesh==null: continue
		check(mesh.mesh.get_surface_count()==1 and mesh.get_child_count()==0,"Scenery not a single collision-free batch")
		check(mesh.get_meta("scenery_count")==chunks[key],"Wrong chunk scenery count")
		total+=int(mesh.get_meta("scenery_count"))
		mesh.free()
	check(total==plan.scenery.size(),"Scenery missing or duplicated across chunks")
	print("COUNTRYSIDE | %s | %d fields | %d decorations | %d batches" % [plan.profile,plan.fields.size(),total,chunks.size()])

func _test_quest_anchors(source,plan) -> void:
	var occupied: Dictionary = {}
	var coordinator := false
	var ids: Dictionary = {}
	for record in plan.landmarks: ids[record["id"]]=record
	for anchor in plan.quest_anchors:
		var p: Vector2i = anchor["cell"]
		var q: Vector2i = anchor["approach"]
		var objective: Vector2i = anchor["objective_hint"]
		check(not occupied.has(p),"Quest contacts share a cell")
		occupied[p]=true
		check(ids.has(anchor["landmark_id"]),"Contact has no landmark")
		check(not plan.roads.has(p) and not plan.reserved.has(p) and not plan.field_tiles.has(p) and not plan.scenery.has(p),"Quest contact overlaps protected area")
		check(not source.caves.has_cave(p.x,p.y),"Quest contact in cave column")
		check(p.distance_squared_to(q)==1 and plan.roads.has(q),"Quest contact lacks road access")
		check(absi(source.height_at(p.x,p.y)-source.height_at(q.x,q.y))<=1,"Unsafe contact access")
		check(absi(p.x-objective.x)<=3 and absi(p.y-objective.y)<=3,"Contact too far from landmark")
		if anchor["allows_expeditions"]:
			coordinator=true
			check(anchor["role"]=="expedition_coordinator","Expedition role mismatch")
	check(coordinator,"No expedition coordinator placement")
	print("QUEST ANCHORS | %s | %d contacts" % [plan.profile,plan.quest_anchors.size()])

func _test_adventure_policy() -> void:
	# 80 is a test fixture, not a shipped balance threshold.
	check(ADVENTURE.classify(80,80,false,true)==ADVENTURE.LOCAL,"Local boundary classified incorrectly")
	check(ADVENTURE.classify(81,80,false,true)==ADVENTURE.EXPEDITION,"Long route not expedition")
	check(ADVENTURE.classify(5,80,true,true)==ADVENTURE.EXPEDITION,"Remote journey not expedition")
	check(ADVENTURE.classify(500,80,true,false)==ADVENTURE.UNAVAILABLE,"Unverified route generated offer")
	check(ADVENTURE.reward_preview(100,ADVENTURE.LOCAL)==100,"Local reward changed")
	check(ADVENTURE.reward_preview(100,ADVENTURE.EXPEDITION)==250,"Expedition multiplier incorrect")
	check(ADVENTURE.reward_preview(1,ADVENTURE.EXPEDITION)==3,"Reward rounding mismatch")
	check(ADVENTURE.reward_preview(100,ADVENTURE.UNAVAILABLE)==-1,"Unavailable offer rewarded")

func _test_gathering(source,plan) -> void:
	var ids: Dictionary = {}
	var kinds: Dictionary = {}
	for record in plan.gathering.nodes:
		var p: Vector2i = record["cell"]
		check(not ids.has(record["id"]),"Duplicate regional node")
		ids[record["id"]]=true
		kinds[record["kind"]]=true
		check(record["tier"]>=1 and record["tier"]<=3,"Invalid gathering tier")
		if record["habitat"]=="cavern":
			check(source.caves.floor_at(p.x,p.y)==floori(record["position"].y),"Cave node not on cave floor")
			continue
		check(not plan.roads.has(p) and not plan.reserved.has(p) and not plan.field_tiles.has(p) and not source.caves.has_cave(p.x,p.y),"Gathering node intersects reserved land")
		var route: Array = record["approach"]
		check(not route.is_empty(),"Gathering node lacks approach")
		if route.is_empty(): continue
		check(plan.roads.has(route.back()),"Gathering approach not linked to road")
		for i in range(1,route.size()):
			var a: Vector2i = route[i-1]
			var b: Vector2i = route[i]
			check(a.distance_squared_to(b)==1 and absi(source.height_at(a.x,a.y)-source.height_at(b.x,b.y))<=1,"Unwalkable gathering approach")
	check(kinds.has("wood"),"No woodland tree node")
	check(kinds.has("stone") or kinds.has("iron") or kinds.has("coal"),"No mineral node")
	print("GATHERING | %s | %d nodes" % [plan.profile,ids.size()])

func _test_maturity() -> void:
	check(MATURITY.stars(0)==0 and MATURITY.stars(29.9)==0,"Ore recovers too soon")
	check(MATURITY.stars(30)==1 and MATURITY.stars(120)==2,"Early maturity stage incorrect")
	check(MATURITY.stars(390)==5 and MATURITY.stars(99999)==5,"Ore maturity not capped")
	check(MATURITY.age(1000,900)==0 and MATURITY.age(0,900)==MATURITY.MAX_AGE,"Ore timestamp handling incorrect")
	var previous := 0.0
	for stars in range(1,6):
		var odds := MATURITY.rarity_chances(stars)
		var sum := 0.0
		for chance in odds:
			check(chance>0,"Rarity chance removed")
			sum+=chance
		check(is_equal_approx(sum,1.0),"Crafting odds do not sum to one")
		check(odds[4]>=previous,"Mature materials reduce legendary chance")
		previous=odds[4]
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed=64012
	b.seed=64012
	check(QUALITY.roll_item("iron_blade",a)==QUALITY.roll_item("iron_blade",b,1),"Baseline crafting RNG changed")
