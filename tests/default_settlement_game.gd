extends SceneTree
## Exercise the real RPG scene, camera, click picker, navigation and chunk owner.
const MAIN = preload("res://scenes/main.tscn")
const PICKER = preload("res://scripts/interaction/world_picker.gd")
const PATH = preload("res://scripts/navigation/crafting_station_path.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL SETTLEMENT GAME: "+description)

func _run() -> void:
	root.set_meta("outpost_input_mode","touch")
	root.set_meta("outpost_new_adventure",true)
	var game = MAIN.instantiate()
	var test_save := "user://settlement_game_regression_%d.json" % Time.get_ticks_usec()
	game.save_path = test_save
	game.get_node("Dungeons").save_path = test_save+".dungeons"
	root.add_child(game)
	await process_frame
	var remote = game.terrain_surface.archipelago
	var plan = remote.terrain.settlement_plan()
	if plan == null:
		check(false,"Default game has no settlement")
		_finish(game)
		return
	check(not game.controls.desktop,"Touch gameplay adapter not active")
	# Keep the character fixed while testing actual physics queries and the
	# game's camera. This is a teleport-assisted integration test, not a
	# claim that a full manual walking/device session was performed.
	game.hero.set_physics_process(false)
	var item: Dictionary = plan.buildings[0]
	var rect: Rect2i = item["rect"]
	var door: Vector2i = item["door"]
	var direction: Vector2i = item["direction"]
	var outside: Vector2i = door+direction
	var floor_y: int = item["floor"]
	var start := Vector3(outside.x+0.5,remote.terrain.height_at(outside.x,outside.y)+0.08,outside.y+0.5)
	var center := Vector3(rect.position.x+3.5,float(floor_y)+0.08,rect.position.y+3.5)
	game.hero.global_position = start
	remote._queue_near(start)
	for i in range(60):
		if remote._pending.is_empty(): break
		remote._build_pending()
		await process_frame
	await physics_frame
	await physics_frame
	var building: Node3D = null
	for node in remote.settlement_nodes:
		if node.spec["id"]==item["id"]: building = node
	check(is_instance_valid(building),"Building did not stream into real game")
	if not is_instance_valid(building):
		_finish(game)
		return
	var inbound := PATH.plan_world(game,start,center)
	check(not inbound.is_empty(),"Click navigation cannot enter doorway")
	var outbound := PATH.plan_world(game,center,start)
	check(not outbound.is_empty(),"Click navigation cannot leave doorway")
	check(PATH.plan_world(game,start,center+Vector3.UP*6.0).is_empty(),"Roof treated as a ground target")
	game.hero.global_position = center
	var floor_target := center+Vector3(1,0.0,0)
	for i in range(8):
		game.camera_angle_target = float(i)*PI/4.0
		game.camera_angle = game.camera_angle_target
		game._camera(1.0)
		remote.update_settlement_views(center,game.camera)
		await physics_frame
		check(not building.parts[5]["mesh"].visible,"Roof visible at angle %d" % i)
		var hit := PICKER.resolve(game,game.camera.unproject_position(floor_target))
		print("SETTLEMENT PICK angle=",i," camera=",game.camera.global_position," hero=",center," target=",floor_target," mask=",building.view_mask," hit=",hit)
		check(not hit.is_empty() and hit.get("target")==null and Vector3(hit.get("position",Vector3.INF)).distance_to(floor_target)<0.25,"Visible floor pick failed at angle %d" % i)
		# Hidden walls must not disappear from the gameplay collision mask.
		for group in building.parts:
			check(building.parts[group]["body"].collision_layer==1,"Cutaway changed movement collision")
	game.hero.global_position = start
	remote.update_settlement_views(start,game.camera)
	check(building.parts[5]["mesh"].visible,"Roof did not restore outside")
	for node in remote.settlement_nodes:
		check(node.view_mask==0,"Adjacent structure did not restore outside")
	game.hero.global_position = Vector3(0,0.35,0)
	await process_frame
	await process_frame
	check(remote.settlement_nodes.is_empty(),"Settlement failed to unload on return to camp")
	game.hero.global_position = start
	remote._queue_near(start)
	for i in range(60):
		if remote._pending.is_empty(): break
		remote._build_pending()
		await process_frame
	await physics_frame
	check(not remote.settlement_nodes.is_empty(),"Settlement failed to reconstruct on re-entry")
	await _test_waystation(game,remote)
	_finish(game)

func _test_waystation(game,remote) -> void:
	var plan = remote.terrain.settlement_plan(1)
	if plan==null:
		check(false,"Western frontier waystation missing")
		return
	var map = game.map_service
	var marker_id := "region:waystation:hub"
	check(not map.known.has(marker_id),"Unvisited waystation revealed by planning")
	var hub: Vector2i = plan.hub
	var square := Vector3(hub.x+0.5,remote.terrain.height_at(hub.x,hub.y)+0.08,hub.y+0.5)
	game.hero.global_position = square
	remote._queue_near(square)
	for i in range(60):
		if remote._pending.is_empty(): break
		remote._build_pending()
		await process_frame
	await physics_frame
	map.observe_player()
	check(map.known.has(marker_id),"Visited waystation not discovered")
	check(not map.search("Frontier Waystation").is_empty(),"Discovered waystation not searchable")
	var saved: Dictionary = map.export_state()
	map.import_state(saved)
	check(map.known.has(marker_id),"Discovered regional landmark lost on map reload")
	var item: Dictionary = plan.buildings[0]
	var rect: Rect2i = item["rect"]
	var door: Vector2i = item["door"]
	var direction: Vector2i = item["direction"]
	var outside: Vector2i = door+direction
	var start := Vector3(outside.x+0.5,remote.terrain.height_at(outside.x,outside.y)+0.08,outside.y+0.5)
	var center := Vector3(rect.get_center().x+0.5,float(item["floor"])+0.08,rect.get_center().y+0.5)
	game.hero.global_position = start
	remote._queue_near(start)
	for i in range(60):
		if remote._pending.is_empty(): break
		remote._build_pending()
		await process_frame
	await physics_frame
	await physics_frame
	var building: Node3D = null
	for node in remote.settlement_nodes:
		check(str(node.spec["id"]).begins_with("waystation_"),"Market-town geometry retained on western island")
		if node.spec["id"]==item["id"]: building=node
	check(is_instance_valid(building),"Waystation building failed to stream")
	if not is_instance_valid(building): return
	check(not PATH.plan_world(game,start,center).is_empty(),"Waystation doorway entry unreachable")
	check(not PATH.plan_world(game,center,start).is_empty(),"Waystation doorway exit unreachable")
	game.hero.global_position=center
	var floor_target := center
	for i in range(8):
		game.camera_angle_target=float(i)*PI/4.0
		game.camera_angle=game.camera_angle_target
		game._camera(1.0)
		remote.update_settlement_views(center,game.camera)
		await physics_frame
		check(not building.parts[5]["mesh"].visible,"Waystation roof visible inside")
		var hit := PICKER.resolve(game,game.camera.unproject_position(floor_target))
		check(not hit.is_empty() and hit.get("target")==null and Vector3(hit.get("position",Vector3.INF)).distance_to(floor_target)<0.25,"Waystation interior pick failed at angle %d" % i)
	print("WAYSTATION GAME CHECK COMPLETE")

func _finish(game: Node) -> void:
	game.queue_free()
	await process_frame
	print("SETTLEMENT GAME RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)
