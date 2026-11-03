extends RefCounted
## Shared WoW-style dungeon and loot quality colours (no Blizzard assets).
const COMMON: int = 0
const UNCOMMON: int = 1
const RARE: int = 2
const EPIC: int = 3
const LEGENDARY: int = 4

const NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const HEX: Array[String] = ["ffffff", "1eff00", "0070dd", "a335ee", "ff8000"]
# Maximum *distinct* entrance slots per registered world chunk.
const CHUNK_LIMITS: Array[int] = [1, 1, 2, 3, 3]
# Each row is the % weight of the entrance's own quality given chunk quality.
const WEIGHTS: Array = [
	[100, 0, 0, 0, 0],
	[48, 52, 0, 0, 0],
	[28, 43, 29, 0, 0],
	[20, 34, 28, 18, 0],
	[12, 26, 32, 22, 8]
]
const DUNGEON_NAMES: Array[String] = [
	"Forgotten Burrow",
	"Verdant Hollow",
	"Sunken Vault",
	"Shattered Sanctum",
	"Ember Crown"
]

static func bounded(value: int) -> int:
	return clampi(value, COMMON, LEGENDARY)

static func quality_name(quality: int) -> String:
	return NAMES[bounded(quality)]

static func color(quality: int) -> Color:
	return Color(HEX[bounded(quality)])

static func max_entrances(chunk_quality: int) -> int:
	return CHUNK_LIMITS[bounded(chunk_quality)]

static func roll_quality(chunk_quality: int, random: RandomNumberGenerator) -> int:
	var row: Array = WEIGHTS[bounded(chunk_quality)]
	var ticket: int = random.randi_range(1, 100)
	for quality in range(NAMES.size()):
		ticket -= int(row[quality])
		if ticket <= 0:
			return quality
	return COMMON

static func dungeon_name(quality: int) -> String:
	return DUNGEON_NAMES[bounded(quality)]

static func guard_count(quality: int) -> int:
	return 1 + bounded(quality)

static func roll_chest(quality: int, random: RandomNumberGenerator) -> Dictionary:
	var tier: int = bounded(quality)
	var ranges: Array = [
		[8, 15, 12, 20],
		[15, 27, 22, 34],
		[30, 55, 42, 62],
		[65, 110, 80, 110],
		[140, 210, 130, 180]
	]
	var row: Array = ranges[tier]
	var pools: Array = [
		["wood", "stone", "fiber", "berries"],
		["iron", "herbs", "clay", "reeds"],
		["iron_ingot", "linen", "coal", "bricks"],
		["tonic", "iron_ingot", "linen", "bricks"],
		["tonic", "iron_ingot", "bricks", "stew"]
	]
	var pool: Array = pools[tier]
	var selected: String = str(pool[random.randi_range(0, pool.size() - 1)])
	return {
		"coins": random.randi_range(int(row[0]), int(row[1])),
		"xp": random.randi_range(int(row[2]), int(row[3])),
		"item": selected,
		"amount": maxi(1, int(floor(float(tier + 1) / 2.0)))
	}
