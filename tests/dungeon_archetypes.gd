extends SceneTree
## Deterministic dungeon archetypes, reachability and pixel-styled room geometry.
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
const INSTANCE = preload("res://scripts/dungeons/dungeon_instance.gd")
const PIXELS = preload("res://scripts/voxel/voxel_palette.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS ROOMS: " + description)
	else:
		failures += 1
		push_error("FAIL ROOMS: " + description)

func _run() -> void:
	var examples: Array[String] = ["old_crypt", "forest_crypt", "volcanic_hall", "lunar_chambers"]
	var counted_types: Dictionary = {}
	var checked_rooms: int = 0
	var style_variations: int = 0
	for index in range(examples.size()):
		var entry: String = examples[index]
		var layout: Dictionary = LAYOUT.generate(entry, mini(4, index + 1), 0)
		var replay: Dictionary = LAYOUT.generate(entry, mini(4, index + 1), 0)
		check(LAYOUT.validate(layout), "Existing dungeon graph remains connected: " + entry)
		check(layout == replay, "Room archetypes are deterministic: " + entry)
		var normals: Dictionary = {}
		for room in layout["rooms"]:
			var role: String = str(room.get("role", ""))
			var archetype: String = str(room.get("archetype", ""))
			var seed: int = int(room.get("decor_seed", 0))
			check(archetype != "" and seed > 0, "Room type and decor seed recorded: " + entry)
			counted_types[archetype] = true
			if role == "normal":
				normals[archetype] = true
			if role == "start":
				check(archetype == "entry", "Dungeon entrance is a distinct gatehouse")
			elif role == "boss":
				check(archetype == "boss", "Final room has boss arena type")
			elif role == "treasure":
				check(archetype == "treasure", "Bonus cache room has vault decorations")
			checked_rooms += 1
		if normals.size() >= 2:
			style_variations += 1
	check(counted_types.size() >= 7, "At least seven distinct room archetypes occur")
	check(style_variations >= 3, "Ordinary rooms vary across independent dungeon layouts")
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		check(false, "Gameplay scene imports")
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var dungeon = INSTANCE.new()
	game.add_child(dungeon)
	dungeon.position = Vector3(2500.0, 0, 2500.0)
	dungeon.setup("archetypes_integration", 2, game.hero, 1)
	await physics_frame
	var pieces: Array = []
	for child in dungeon.floor_root.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("RoomDecor_"):
			pieces.append(child)
	check(pieces.size() == dungeon.layout["rooms"].size(), "One batched decoration mesh built for every generated room")
	for piece in pieces:
		check(piece.material_override == PIXELS.get_material(), "Room art uses existing nearest-filtered voxel atlas")
	check(dungeon.layout["rooms"][0]["archetype"] == "entry", "Spawn room renders as a gatehouse")
	check(dungeon.guards_remaining > 0, "Original guardian encounters remain active")
	check(dungeon.can_claim_chest() == false, "Original boss/treasure gating preserved")
	game.queue_free()
	await process_frame
	print("ROOM ARCHETYPES RESULT: %d failures, %d rooms, %d styles." % [failures, checked_rooms, counted_types.size()])
	quit(0 if failures == 0 else 1)
