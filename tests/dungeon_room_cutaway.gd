extends SceneTree
const DUNGEON = preload("res://scripts/dungeons/dungeon_instance.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS DUNGEON ROOM: " + detail)
	else:
		failures += 1
		push_error("FAIL DUNGEON ROOM: " + detail)

func run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var dungeon = DUNGEON.new()
	game.add_child(dungeon)
	dungeon.global_position = Vector3(500, 0, 500)
	dungeon.setup("room_reveal_test", 0, game.hero)
	var rooms: Array = dungeon.layout.rooms
	check(rooms.size() >= 2, "Dungeon contains separate formal rooms")
	var first: Dictionary = rooms[0]
	var second: Dictionary = rooms[1]
	game.hero.global_position = dungeon.to_global(dungeon._room_center(first) + Vector3.UP)
	game.camera.global_position = game.hero.global_position + Vector3(20, 20, 20)
	dungeon._update_room_visibility()
	check(dungeon.active_room_id == int(first.id), "Player selects the occupied room")
	var first_art: VisualInstance3D = dungeon.room_visuals[int(first.id)][0].node
	var second_art: VisualInstance3D = dungeon.room_visuals[int(second.id)][0].node
	check(first_art.layers != 0 and second_art.layers == 0, "Unoccupied room architecture stays concealed")
	var walls: Array = dungeon.room_walls.get(int(first.id), [])
	var hidden_wall := false
	for wall in walls:
		if wall.collider.get_meta("dungeon_cutaway_hidden", false):
			hidden_wall = true
			check(wall.collider.collision_layer == 1 and wall.mesh.layers == 0, "Foreground wall remains physically solid")
			break
	check(hidden_wall, "Camera-facing walls are opened")
	var before: Array[bool] = []
	for wall in walls:
		before.append(bool(wall.collider.get_meta("dungeon_cutaway_hidden", false)))
	game.camera.global_position = game.hero.global_position + Vector3(-20, 20, -20)
	dungeon._update_room_visibility()
	var rotated: bool = false
	for index in range(walls.size()):
		if before[index] != bool(walls[index].collider.get_meta("dungeon_cutaway_hidden", false)):
			rotated = true
	check(rotated, "Camera rotation switches foreground walls")
	if int(dungeon.layout.exit) != int(first.id):
		check(dungeon.chest_area.get_meta("dungeon_room_id") == int(dungeon.layout.exit), "Exit chest remains assigned to its own room")
	game.hero.global_position = dungeon.to_global(dungeon._room_center(second) + Vector3.UP)
	dungeon._update_room_visibility()
	check(first_art.layers == 0 and second_art.layers != 0, "Changing rooms updates the reveal")
	game.queue_free()
	await process_frame
	print("DUNGEON ROOM RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
