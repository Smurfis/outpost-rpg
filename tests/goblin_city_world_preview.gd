extends SceneTree
const RIVAL = preload("res://scripts/world/regional_rival.gd")
const WORK = preload("res://scripts/world/goblin_village_work.gd")
const OCEAN = preload("res://scripts/world/ocean_surface.gd")
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")
const SKELETAL = preload("res://scripts/world/skeletal_city_plan.gd")
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
		_test_skeletal(data)
		var city = data.goblin_city
		check(data.islands.size()==5 and city!=null,"Preview island set missing")
		if city==null: continue
		check(city.validate(),"Disconnected city or overlapping buildings")
		check(city.buildings.size()==17 and city.guards.size()==11 and city.gatherers.size()==2 and city.caches.size()==7,"Incomplete stronghold")
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
		OCEAN.update(coast)
		_test_wave_field(coast)
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
	await _test_village(game)
	await _test_live_skeletal(game)
	await _test_rivals(game)
	await _test_nameplates(game)
	game.queue_free()
	await process_frame
	print("WORLD PREVIEW RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)

func _test_wave_field(at: Vector3) -> void:
	var p := Vector2(at.x,at.z)
	var h := OCEAN.height_at(p,2.0)
	check(is_equal_approx(h,OCEAN.height_at(p,2.0)),"Wave sampler nondeterministic")
	check(absf(h)<=0.6,"Ocean displacement outside safe visual bound")
	check(not is_equal_approx(h,OCEAN.height_at(p,3.0)),"Wave field static")
	check(is_zero_approx(OCEAN.height_at(OCEAN.center+Vector2(48.0,0),2.0)),"Near/far wave seam not flat")
	var pose := OCEAN.hull_pose(at,0.4)
	check(pose.is_finite() and absf(pose.y)<=0.20 and absf(pose.z)<=0.20,"Invalid six-point hull pose")
	check(OCEAN.coefficients.size()==6 and OCEAN.dynamics.size()==6,"Shared wave parameters missing")

func _test_skeletal(data) -> void:
	var city = data.skeletal_city
	check(city!=null,"Skeletal island missing")
	if city==null: return
	check(city.validate() and city.floors.size()>700,"Skeletal city disconnected or undersized")
	check(data.islands[2]["radius"]==64.0 and data.islands[1]["radius"]==56.0,"Preview islands not widened")
	var entry: Vector2i = city.entrance
	for lane in range(-4,5):
		var p := entry+Vector2i(0,lane)
		check(data.is_solid(p.x,city.ceilings[p],p.y),"Dwarven entrance open to sky")
		check(not data.is_solid(p.x,SKELETAL.ENTRY_Y+2,p.y),"Dwarven entrance blocked")
	var path := PATH._branch_path(data.caves,entry,city.heart,Vector3(city.heart.x+0.5,SKELETAL.CITY_Y+0.1,city.heart.y+0.5))
	check(not path.is_empty(),"Skeletal heart unreachable")
	var south: Vector3i = data.caves.routes[2].front()
	check(data.is_solid(south.x,data.caves.ceiling_at(south.x,south.z,south.y),south.z),"Southern mouth still a ravine")
	check(data.height_at(south.x+1,south.z)==south.y,"Southern cave apron obstructed")
	var old: Dictionary = data.caves.floors.duplicate()
	check(data.regenerate_skeletal_city(),"Skeletal regeneration failed")
	check(data.skeletal_city.cycle==1,"Skeletal cycle unchanged")
	for p: Vector2i in old:
		if not city.contains(p): check(data.caves.floors.get(p)==old[p],"Skeletal regeneration altered unrelated cave")

func _test_live_skeletal(game) -> void:
	var remote = game.terrain_surface.archipelago
	var city = remote.terrain.skeletal_city
	if city==null:
		check(false,"Live skeletal city missing")
		return
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
	check(not remote.regenerate_skeletal_city_for_preview(game.hero),"Skeletal reset allowed beneath player")
	var entry: Vector2i = city.entrance
	var inner := entry-Vector2i(3,0)
	var inside := Vector3(inner.x+0.5,float(city.floors[inner])+0.08,inner.y+0.5)
	game.hero.global_position=inside
	game._camera(1.0)
	remote._update_cutaway(game,inside,1.0)
	check(remote.section_active or remote._cave_mode,"Skeletal entrance camera reveal missing")
	var query := PhysicsRayQueryParameters3D.create(inside+Vector3.UP,inside-Vector3.UP*0.5,1,[game.hero.get_rid()])
	var hit: Dictionary = game.hero.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty(),"Skeletal stair floor has no collision")
	var heart: Vector2i = city.heart
	var hall := Vector3(heart.x+0.5,float(city.floors[heart])+0.08,heart.y+0.5)
	game.hero.global_position=hall
	remote._queue_near(hall)
	for i in range(60):
		if remote._pending.is_empty(): break
		remote._build_pending()
		await process_frame
	await physics_frame
	game._camera(1.0)
	remote._update_cutaway(game,hall,1.0)
	check(remote.section_active or remote._cave_mode,"Skeletal hall camera reveal missing")
	var scenery_count := 0
	for members in remote._loaded.values():
		for member in members:
			if str(member.name).begins_with("SkeletalCavern_"): scenery_count+=1
	check(scenery_count>0,"Skeletal cavern decoration absent")
	var skeletons := 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.get("appearance")=="skeleton" and city.contains(Vector2i(floori(enemy.global_position.x),floori(enemy.global_position.z))): skeletons+=1
	check(skeletons>0,"No actual skeletons in streamed city")
	game.hero.global_position=Vector3(0,0.35,0)
	await process_frame
	check(remote.regenerate_skeletal_city_for_preview(game.hero),"Live isolated skeletal reset failed")
	print("SKELETAL STREAM: %d decorated chunks" % scenery_count)

func _test_village(game) -> void:
	var record := WORK.sanitize({})
	check(not WORK.advance(record,74.0,42,0) and record["stock"].is_empty(),"Worker generated chest before round trip")
	check(WORK.advance(record,1.0,42,0) and not record["stock"].is_empty(),"Worker failed to deposit")
	WORK.defeat(record)
	var round_before: int = record["round"]
	WORK.advance(record,75.0,42,0)
	check(record["round"]==round_before and record["rest"]>0.0,"Defeated worker continued gathering")
	var remote = game.terrain_surface.archipelago
	var city = remote.terrain.goblin_city
	var spec: Dictionary = city.gatherers[0]
	var yard: Vector2i = spec["yard"]
	var at := Vector3(yard.x+0.5,10.08,yard.y+0.5)
	game.hero.global_position=at
	remote._queue_near(at)
	for i in range(60):
		if remote._pending.is_empty(): break
		remote._build_pending()
		await process_frame
	await physics_frame
	var id := "goblin_work:%d:%s" % [remote.terrain.seed,spec["id"]]
	remote._update_village(game,0.5)
	check(remote.village_workers.has(id),"Live gatherer missing")
	var live: Dictionary = game.village_work[id]
	live["stock"]={"wood":4}
	remote._update_village(game,0.5)
	var chest = remote.village_chests.get(id)
	check(is_instance_valid(chest),"Gatherer did not build chest")
	if is_instance_valid(chest):
		game.hero.global_position=chest.global_position+Vector3(0,0,1)
		game.inventory.clear()
		game.inventory["wood"]=998
		chest.interact(game.hero)
		check(int(game.inventory["wood"])==999 and chest.remaining().get("wood")==3 and not chest.is_queued_for_deletion(),"Partial pickup lost stored loot")
		game.inventory["wood"]=0
		chest.interact(game.hero)
		check(int(game.inventory["wood"])==3 and chest.is_queued_for_deletion() and live["stock"].is_empty(),"Fully looted chest not destroyed")
		await process_frame
		remote._update_village(game,0.5)
		check(not is_instance_valid(remote.village_chests.get(id)),"Empty stockpile respawned")
		live["work"]=WORK.ROUND_SECONDS-0.25
		remote._update_village(game,0.5)
		# A worker near the hero may pause for combat. Advance the pure
		# work clock in isolation, then require streamed stock to reappear.
		if live["stock"].is_empty(): WORK.advance(live,1.0,remote.terrain.seed,0)
		remote._update_village(game,0.5)
		check(is_instance_valid(remote.village_chests.get(id)),"Renewed stock did not rebuild chest")
	game._save()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(saved is Dictionary and saved.get("village_work",{}).has(id),"Gatherer stock not saved")
	print("VILLAGE WORK: streamed gatherer, partial pickup, chest destruction and renewal checked")

func _test_rivals(game) -> void:
	var policy := RIVAL.fresh()
	for rank in range(1,5):
		check(RIVAL.promote(policy) and policy["rank"]==rank,"Rival failed to advance")
		check(RIVAL.follower_count(rank)==[0,1,2,4,6][rank],"Wrong retinue count")
	check(not RIVAL.promote(policy) and policy["rank"]==4,"Rival rank exceeded cap")
	check(RIVAL.sanitize(JSON.parse_string(JSON.stringify(policy)))==policy,"Career save roundtrip mismatch")
	RIVAL.retire(policy)
	check(policy["rank"]==0 and policy["generation"]==1,"Successor inherited defeated rival rank")
	var remote = game.terrain_surface.archipelago
	for species in ["goblin","skeleton"]:
		var city = remote.terrain.goblin_city if species=="goblin" else remote.terrain.skeletal_city
		var cell: Vector2i = city.hub if species=="goblin" else city.heart
		var y: int = remote.terrain.height_at(cell.x,cell.y) if species=="goblin" else city.floors[cell]
		var at := Vector3(cell.x+0.5,y+0.08,cell.y+0.5)
		game.hero.global_position=at
		remote._queue_near(at)
		for i in range(60):
			if remote._pending.is_empty(): break
			remote._build_pending()
			await process_frame
		await physics_frame
		var killer: Node3D
		var other: Node3D
		for enemy in get_nodes_in_group("enemies"):
			if not enemy.has_method("credit_player_defeat") or enemy.rival_id.is_empty() or enemy.rival_kind!=species: continue
			if killer==null and enemy.global_position.distance_to(at)<24.0: killer=enemy
			elif other==null: other=enemy
		check(is_instance_valid(killer),"Missing regional "+species+" rival")
		if not is_instance_valid(killer): continue
		var id: String = killer.rival_id
		var before: int = killer.rival_record["rank"]
		var other_rank: int = other.rival_record["rank"] if is_instance_valid(other) else -1
		game.hero.global_position=killer.global_position+Vector3(0,0,1)
		game.hero.health=1.0
		killer.strike_player(100.0)
		check(game.hero.health==100.0 and game.regional_rivals[id]["rank"]==mini(before+1,4),"Lethal strike failed to credit exact rival")
		if is_instance_valid(other): check(other.rival_record["rank"]==other_rank,"Wrong NPC gained promotion")
		var name_before: String = killer.display_name
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
		check(saved is Dictionary and saved.get("regional_rivals",{}).get(id,{}).get("rank",-1)==mini(before+1,4),"Promotion missing from death save")
		remote._clear_stream()
		await process_frame
		game.hero.global_position=at
		remote._queue_near(at)
		for i in range(60):
			if remote._pending.is_empty(): break
			remote._build_pending()
			await process_frame
		await physics_frame
		var returned: Node3D
		for enemy in get_nodes_in_group("enemies"):
			if enemy.has_method("credit_player_defeat") and enemy.rival_id==id:
				returned=enemy
				break
		check(is_instance_valid(returned),"Promoted rival absent on return")
		if is_instance_valid(returned):
			check(returned.display_name==name_before and returned.quality==mini(before+1,4),"Named career lost on stream reload")
			var generation: int = returned.rival_generation
			returned.receive_damage(100000.0)
			check(game.regional_rivals[id]["rank"]==0 and game.regional_rivals[id]["generation"]==generation+1,"Rival defeat did not retire career")
		game.hero.global_position=Vector3(0,0.35,0)
		await process_frame
	print("REGIONAL RIVALS: exact lethal credit, both species, persistent rank and retirement checked")

func _test_nameplates(game) -> void:
	var plates = game.hud.combat_nameplates
	check(is_instance_valid(plates),"Preview combat nameplate canvas missing")
	if not is_instance_valid(plates): return
	check(plates.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Nameplates intercept gameplay")
	game.hero.global_position=Vector3(0,0.35,0)
	game._camera(1.0)
	var guide: Node3D
	for actor in get_nodes_in_group("world_interactables"):
		if actor.get_meta("world_kind","")=="npc":
			guide=actor
			break
	check(is_instance_valid(guide) and plates.friendly(guide),"Friendly NPC nameplate classification missing")
	if is_instance_valid(guide):
		game.hero.global_position=guide.global_position+Vector3(1,0,0)
		game._camera(1.0)
		await physics_frame
		check(plates.same_floor(guide),"Nearby guide failed floor check")
		game.hero.global_position=guide.global_position+Vector3(30,0,0)
		check(not plates.visible_actor(guide,plates.RANGE),"Distant NPC nameplate leaked")
		game.hero.global_position=guide.global_position+Vector3(0,8,0)
		check(not plates.same_floor(guide),"Nameplate leaked across floors")
	game.hero.global_position=Vector3(0,0.35,0)
	game._camera(1.0)
	plates.refresh()
	check(plates.actors.size()<=plates.LIMIT,"Nameplate cap exceeded")
	game.hud.enemy_target_frame.configure_boss_style(4)
	check(game.hud.enemy_target_frame.boss_stars==5,"Five-star boss frame missing")
	print("NAMEPLATES: input pass-through, friendly identity, distance/floor culling and boss stars checked")
