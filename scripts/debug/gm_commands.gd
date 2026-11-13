extends RefCounted
## Temporary Alpha GM console. Commands are LOCAL and intentionally unrestricted
## so every tester can use them. Do not trust this as multiplayer authority.
const MAX_TELEPORT: float = 380.0
const MAX_GIVE: int = 99
const PITLORD = preload("res://scripts/creatures/gm_pitlord.gd")

static func execute(game: Node, raw: String) -> String:
	var words: PackedStringArray = raw.strip_edges().split(" ", false)
	if words.is_empty() or not words[0].begins_with("."):
		return "Commands begin with . — try .help"
	var cmd: String = words[0].to_lower()
	match cmd:
		".help":
			return "GM: .help  .where  .home  .tp X Z  .island 1-3  .map islands true|false  .spawn pitlord  .despawn pitlord  .heal  .give ITEM [COUNT]  .time day|night|dawn|dusk  .speed 1-3  .clear"
		".where", ".pos":
			var p: Vector3 = game.hero.global_position
			return "Position: X %.1f  Y %.1f  Z %.1f" % [p.x, p.y, p.z]
		".home":
			_move(game, Vector3(0, 0.35, 0))
			return "Returned to Outpost."
		".heal":
			game.hero.health = 100.0
			game.mana = float(game.MAX_MANA)
			return "Health and mana fully restored."
		".time":
			if words.size() != 2:
				return "Usage: .time day|night|dawn|dusk"
			var phases: Dictionary = {"day": 0.5, "night": 0.95, "dawn": 0.26, "dusk": 0.74}
			var moment: String = words[1].to_lower()
			if not phases.has(moment) or game.day_night == null:
				return "Choose day, night, dawn or dusk."
			game.day_night.set_phase(float(phases[moment]))
			return "World time set to %s." % moment
		".speed":
			if words.size() != 2 or not words[1].is_valid_float():
				return "Usage: .speed 1-3 (1 resets normal speed)"
			var factor: float = words[1].to_float()
			if factor < 1.0 or factor > 3.0:
				return "Speed must be between 1 and 3."
			game.hero.gm_speed_multiplier = factor
			return "Movement speed: %.1fx" % factor
		".give":
			if words.size() < 2 or words.size() > 3:
				return "Usage: .give wood 10"
			var item_id: String = words[1].to_lower()
			if not game.inventory.has(item_id):
				return "Unknown item: %s" % item_id
			var count: int = 1
			if words.size() == 3:
				if not words[2].is_valid_int():
					return "Amount must be a whole number (1-99)."
				count = words[2].to_int()
			if count < 1 or count > MAX_GIVE:
				return "Amount must be between 1 and 99."
			var received: int = int(game.grant_item(item_id, count))
			game._refresh_menu()
			if received > 0:
				game._save()
			return "Granted %d of %s." % [received, item_id] if received > 0 else "Inventory full; nothing granted."
		".tp":
			if words.size() != 3 and words.size() != 4:
				return "Usage: .tp X Z  or  .tp X Y Z"
			for index in range(1, words.size()):
				if not words[index].is_valid_float():
					return "Teleport coordinates must be numbers."
			var x: float = words[1].to_float()
			var z: float = words[2].to_float() if words.size() == 3 else words[3].to_float()
			if absf(x) >= MAX_TELEPORT or absf(z) >= MAX_TELEPORT:
				return "Teleport is limited to the playable 380m ocean region."
			var y: float = 0.0
			if words.size() == 4:
				y = clampf(words[2].to_float(), -8.0, 100.0)
			else:
				var biome: Node = game.terrain_surface
				var cell: Dictionary = biome.map_cell_at(floori(x), floori(z)) if biome != null else {}
				if cell.is_empty():
					return "Terrain unavailable there on this build."
				y = -3.60 if str(cell.get("zone", "")) == "water" else float(cell.get("ground_height", 0.0)) + 0.45
			_move(game, Vector3(x, y, z))
			return "Teleported to X %.1f  Y %.1f  Z %.1f" % [x, y, z]
		".island":
			if words.size() != 2 or not words[1].is_valid_int():
				return "Usage: .island 1, .island 2 or .island 3"
			var number: int = words[1].to_int()
			var biome: Node = game.terrain_surface
			var remote: Variant = biome.get("archipelago") if biome != null else null
			if remote == null or remote.terrain == null:
				return "Exploration islands are available on the fractal feature branch."
			var islands: Array = remote.terrain.islands
			if number < 1 or number > islands.size():
				return "Choose an island from 1 to %d." % islands.size()
			var centre: Vector2i = islands[number - 1]["center"]
			var at: Vector3 = Vector3(float(centre.x), float(remote.terrain.height_at(centre.x, centre.y)) + 0.6, float(centre.y))
			_move(game, at)
			return "Island %d at X %d  Z %d." % [number, centre.x, centre.y]
		".map":
			if words.size() != 3 or words[1].to_lower() != "islands" or words[2].to_lower() not in ["true", "false"]:
				return "Usage: .map islands true|false"
			var map: Variant = game.get("world_map")
			if map == null or not map.has_method("set_island_circles_visible"):
				return "Island map markers are unavailable on this build."
			var enabled: bool = words[2].to_lower() == "true"
			if not map.set_island_circles_visible(enabled):
				return "Island map markers are unavailable on this build."
			return "Island map circles enabled." if enabled else "Island map circles hidden."
		".spawn":
			if words.size() != 2 or words[1].to_lower() != "pitlord":
				return "Usage: .spawn pitlord"
			if game.hero == null:
				return "No player is loaded."
			if not game.get_tree().get_nodes_in_group("gm_pitlords").is_empty():
				return "A Pitlord is already spawned. Use .despawn pitlord first."
			var at: Vector3 = game.hero.global_position + Vector3(4.0, 0.0, 2.0)
			var biome: Node = game.terrain_surface
			if biome != null and biome.has_method("map_cell_at"):
				var cell: Dictionary = biome.map_cell_at(floori(at.x), floori(at.z))
				if str(cell.get("zone", "")) == "water":
					return "Stand on dry land to spawn the Pitlord."
				at.y = float(cell.get("ground_height", at.y)) + 0.20
			var boss = PITLORD.new()
			game.add_child(boss)
			boss.setup_gm(game, game.hero, at)
			return "Spawned Abyssal Pitlord (GM-only test boss)."
		".despawn":
			if words.size() != 2 or words[1].to_lower() != "pitlord":
				return "Usage: .despawn pitlord"
			var removed: int = 0
			for existing in game.get_tree().get_nodes_in_group("gm_pitlords"):
				existing.remove_from_group("gm_pitlords")
				existing.queue_free()
				removed += 1
			return "Despawned %d Pitlord boss(es)." % removed
		".clear":
			return "__CHAT_CLEAR__"
		_:
			return "Unknown GM command: %s — try .help" % cmd

static func _move(game: Node, at: Vector3) -> void:
	if game.controls != null:
		game.controls.cancel()
	var biome: Node = game.terrain_surface
	if biome != null:
		var remote: Variant = biome.get("archipelago")
		if remote != null and remote.terrain != null and remote.terrain.near_island(at):
			remote._queue_near(at)
			# The player's immediate collision chunk is first in the queue.
			remote._build_pending()
	game.hero.stop_interaction_move()
	game.hero.global_position = at
	game.hero.velocity = Vector3.ZERO
	game.hero.knockback_velocity = Vector3.ZERO
	game.camera_focus_smooth = Vector3.ZERO
