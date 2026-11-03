extends RefCounted
## Books permanently unlock skills, sockets enforce red/yellow/blue matching.
const PATH = "res://data/progression/skills.json"

static func all_skills() -> Array:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return value if value is Array else []

static func definition(id: String) -> Dictionary:
	for entry in all_skills():
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return entry
	return {}

static func from_book(book_id: String) -> Dictionary:
	for entry in all_skills():
		if entry is Dictionary and str(entry.get("book", "")) == book_id:
			return entry
	return {}

static func learn(known: Dictionary, materials: Dictionary, book_id: String) -> bool:
	var entry: Dictionary = from_book(book_id)
	if entry.is_empty() or int(materials.get(book_id, 0)) < 1:
		return false
	var id: String = str(entry.get("id", ""))
	if bool(known.get(id, false)):
		return false
	materials[book_id] = int(materials[book_id]) - 1
	known[id] = true
	return true

static func recycle_duplicate(known: Dictionary, materials: Dictionary, book_id: String) -> bool:
	var entry: Dictionary = from_book(book_id)
	if entry.is_empty() or int(materials.get(book_id, 0)) <= 0 or not bool(known.get(str(entry.get("id", "")), false)):
		return false
	materials[book_id] = int(materials[book_id]) - 1
	materials["ether_dust"] = int(materials.get("ether_dust", 0)) + 2
	return true

static func compatible(socket: Dictionary, skill: Dictionary) -> bool:
	if skill.is_empty():
		return false
	var color: String = str(socket.get("color", ""))
	return color == "prismatic" or color == str(skill.get("family", ""))

static func assign(items: Array, known: Dictionary, uid: String, index: int, skill_id: String) -> bool:
	var skill: Dictionary = definition(skill_id)
	if skill.is_empty() or not bool(known.get(skill_id, false)):
		return false
	for item in items:
		if not (item is Dictionary) or str(item.get("uid", "")) != uid:
			continue
		var sockets: Array = item.get("sockets", [])
		if index < 0 or index >= sockets.size() or not (sockets[index] is Dictionary):
			return false
		if not compatible(sockets[index], skill):
			return false
		sockets[index]["skill"] = skill_id
		item["sockets"] = sockets
		return true
	return false

static func clear(items: Array, uid: String, index: int) -> bool:
	for item in items:
		if item is Dictionary and str(item.get("uid", "")) == uid:
			var sockets: Array = item.get("sockets", [])
			if index < 0 or index >= sockets.size():
				return false
			sockets[index]["skill"] = ""
			item["sockets"] = sockets
			return true
	return false

static func active_skills(items: Array, loadout: Dictionary, known: Dictionary) -> Array:
	var result: Array = []
	for item in items:
		if not (item is Dictionary):
			continue
		if str(loadout.get(str(item.get("slot", "")), "")) != str(item.get("uid", "")):
			continue
		var sockets: Array = item.get("sockets", [])
		for socket in sockets:
			var id: String = str(socket.get("skill", ""))
			if id != "" and bool(known.get(id, false)):
				var skill: Dictionary = definition(id)
				if not skill.is_empty():
					result.append(skill)
	return result
