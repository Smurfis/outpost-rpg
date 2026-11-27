extends SceneTree
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const PLAN = preload("res://scripts/world/goblin_city_plan.gd")
const MAIN = preload("res://scenes/main.tscn")
const PATH = preload("res://scripts/navigation/fractal_cave_path.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error("FAIL WORLD PREVIEW: "+message)

func _run() -> void:
	ProjectSettings.set_setting("application/config/build_channel","world-preview")
	for seed_value in [42,64012,64013]:
		var data := DATA.new(seed_value)
		var city = data.goblin_city
		check(data.islands.size()==4 and city!=null,"Fourth island missing")
		if city==null: continue
		check(city.validate(),"Disconnected city or overlapping buildings")
		check(city.buildings.size()==11 and city.guards.size()==9,"Incomplete stronghold")
		check(city.floors.size()>400,"Dungeon too small")
		check(data.biome_at(PLAN.CENTER.x,PLAN.CENTER.y)=="goblin_badlands","City biome missing")
		var original: Dictionary = data.caves.floors.duplicate()
		var layout: Dictionary = city.floors.duplicate()
		var path := PATH._branch_path(data.caves,city.entrance,city.throne,Vector3(city.throne.x+0.5,PLAN.CITY_Y+0.1,city.throne.y+0.5))
		check(not path.is_empty(),"City throne unreachable from entrance")
		for p: Vector2i in city.floors:
			var y: int = city.floors[p]
			check(data.is_solid(p.x,y-1,p.y) and not data.is_solid(p.x,y,p.y),"Missing carved floor")
			if p.x<city.entrance.x-2:
				var ceiling: int = city.ceilings[p]
				check(data.is_solid(p.x,ceiling,p.y) and data.is_solid(p.x,ceiling+1,p.y),"Missing roof backing")
		check(data.regenerate_goblin_city(),"City regeneration rejected")
		check(data.goblin_city.cycle==1 and data.goblin_city.floors!=layout,"City generation did not vary")
		for p: Vector2i in original:
			if not city.contains(p): check(data.caves.floors.get(p)==original[p],"City reset altered unrelated cave")
		print("CITY SEED %d: %d walkable columns, %d buildings" % [seed_value,city.floors.size(),city.buildings.size()])
	root.set_meta("outpost_input_mode","touch")
	root.set_meta("outpost_new_adventure",true)
	var game = MAIN.instantiate()
	game.save_path="user://world_preview_test_%d.json" % Time.get_ticks_usec()
	game.get_node("Dungeons").save_path=game.save_path+".dungeons"
	root.add_child(game)
	await process_frame
	var remote = game.terrain_surface.archipelago
	var city = remote.terrain.goblin_city
	check(city!=null,"Actual game omitted city")
	if city!=null:
		game.hero.set_physics_process(false)
		var hub: Vector2i = city.hub
		var at := Vector3(hub.x+0.5,remote.terrain.height_at(hub.x,hub.y)+0.08,hub.y+0.5)
		game.hero.global_position=at
		remote._queue_near(at)
		for i in range(60):
			if remote._pending.is_empty(): break
			remote._build_pending()
			await process_frame
		await physics_frame
		check(remote.settlement_nodes.size()>=6,"City buildings not streamed")
		check(not remote.regenerate_city_for_preview(game.hero),"Reset allowed under player")
		var entrance: Vector2i = city.entrance
		var cave_at := Vector3(entrance.x-12+0.5,city.floors[entrance-Vector2i(12,0)]+0.08,entrance.y+0.5)
		game.hero.global_position=cave_at
		remote._queue_near(cave_at)
		for i in range(60):
			if remote._pending.is_empty(): break
			remote._build_pending()
			await process_frame
		await physics_frame
		game._camera(1.0)
		remote._update_cutaway(game,cave_at,1.0)
		check(remote.section_active or remote._cave_mode,"City cave cutaway did not activate")
		game.hero.global_position=Vector3(0,0.35,0)
		await process_frame
		check(remote.regenerate_city_for_preview(game.hero),"Isolated reset failed away from city")
		var shelf := Vector2i(PLAN.CENTER.x+roundi(PLAN.RADIUS)+4,PLAN.CENTER.y)
		check(not remote.terrain.is_land_at(shelf.x+0.5,shelf.y+0.5) and remote.terrain.height_at(shelf.x,shelf.y)<DATA.SEA_LEVEL,"Shelf alters dry shore")
		var coast := Vector3(PLAN.CENTER.x+PLAN.RADIUS+8,DATA.SEA_LEVEL,PLAN.CENTER.y)
		game.hero.global_position=coast
		remote._update_ocean_shoals(game,coast)
		check(not remote.ocean_shoals.is_empty(),"Coastal schools absent")
		for shoal in remote.ocean_shoals.values():
			check(shoal.school.instance_count==8 and shoal.rank>=0 and shoal.rank<=4,"Invalid fish school")
		check(not game._recipe_by_id("rowboat").is_empty(),"Boat recipe missing")
		game.inventory["axe"]=1
		check(not game.select_quick_tool("axe"),"Quick tool secretly equipped bag item")
		check(game.equip_item("axe") and game.select_quick_tool("axe"),"Equipped quick tool unusable")
		var bag = game.menu.inventory_window
		check(bag._bag_quantity("axe")==0,"Worn gear duplicated in preview bag")
		check(game.equip_item("axe") and bag._bag_quantity("axe")==1,"Unequipped gear not returned to displayed bag")
		game.inventory["rowboat"]=1
		check(game.equip_item("rowboat") and game.equipment["trinket"]=="rowboat","Boat trinket equip failed")
		game.hero.swimming=true
		game.hero._update_boat()
		game.hero._update_boat_pose(0.0,Vector3.ZERO)
		check(not game.hero.boating and game.hero.boat_launch_age>=0.0 and game.hero.boat_art.visible,"Boat skipped overhead launch")
		check(game.hero.boat_art.position.y>=2.0,"Boat not overhead at start")
		game.hero._update_boat(0.50)
		game.hero._update_boat_pose(0.0,Vector3.ZERO)
		check(game.hero.boat_contact and not game.hero.boating,"Boat failed contact phase")
		game.hero._update_boat(0.30)
		game.hero._update_boat_pose(0.23,Vector3.FORWARD)
		check(game.hero.boating and game.hero.boat_art.visible and game.hero.boat_launch_age<0.0,"Equipped boat failed deployment")
		check(game.hero.boat_oars.size()==2 and game.hero.boat_oars[0].visible and game.hero.boat_row_phase>0.0,"Rowing pose or oars missing")
		check(game.hero.boat_wake_age==0.0,"Moving boat failed wake emission")
		game.hero.swimming=false
		game.hero._update_boat()
		check(not game.hero.boating and not game.hero.boat_art.visible,"Boat persisted on dry land")
		game.hero.swimming=true
		game.hero._update_boat()
		check(game.hero.boat_launch_age==0.0 and not game.hero.boat_contact,"Re-entry failed fresh launch")
		game.hero.swimming=false
		game.hero._update_boat()
		check(game.hero.boat_launch_age<0.0,"Leaving water did not cancel launch")
	game.queue_free()
	await process_frame
	print("WORLD PREVIEW RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)
