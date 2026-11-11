extends RefCounted
## Seeded, data-driven guardian prefixes. A tier is not itself an affix.
## Future rare mechanics (vampiric, volatile, shielding, summoning) should
## be added here only when their combat behaviours and telegraphs exist.
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
const BASIC: Array = [
	{"id": "brutal", "name": "Brutal", "description": "Double damage", "damage": 2.0, "hp": 1.0, "speed": 1.0, "defence": 1.0, "colour": Color("e98b76")},
	{"id": "titanic", "name": "Titanic", "description": "Double health", "damage": 1.0, "hp": 2.0, "speed": 1.0, "defence": 1.0, "colour": Color("80c59e")}
]
const ADVANCED: Array = [
	{"id": "swift", "name": "Swift", "description": "35% faster movement", "damage": 1.0, "hp": 1.0, "speed": 1.35, "defence": 1.0, "colour": Color("e4cb72")},
	{"id": "armoured", "name": "Armoured", "description": "25% less damage received", "damage": 1.0, "hp": 1.0, "speed": 1.0, "defence": 0.75, "colour": Color("83b1e0")}
]
const CHANCE: Array[float] = [0.35, 0.52, 0.72, 0.90, 1.0]

static func roll(entrance_id: String, floor_number: int, encounter_slot: int, rarity: int, is_boss: bool = false) -> Array[Dictionary]:
	var quality: int = clampi(rarity, 0, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT.stable_seed("%s:affix:%d:%d:%d" % [entrance_id, floor_number, encounter_slot, quality])
	var rolled: Array[Dictionary] = []
	if not is_boss and rng.randf() > CHANCE[quality]:
		return rolled
	var pool: Array = BASIC.duplicate()
	if quality >= 2:
		pool.append_array(ADVANCED)
	var count: int = 2 if quality >= 3 and rng.randf() < (0.85 if quality == 4 else 0.52) else 1
	for _index in range(count):
		if pool.is_empty():
			break
		var pick: int = rng.randi_range(0, pool.size() - 1)
		rolled.append(pool[pick].duplicate())
		pool.remove_at(pick)
	return rolled

static func prefix(entries: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry in entries:
		parts.append(str(entry.get("name", "")))
	return " ".join(parts)

static func descriptions(entries: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry in entries:
		parts.append(str(entry.get("description", "")))
	return " • ".join(parts)
