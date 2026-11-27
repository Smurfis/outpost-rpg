extends RefCounted
## Versioned data-only dungeon packs, shared by Creator and sector generator.
const Dungeon = preload("res://scripts/world/city_lab_dungeon_connectors.gd")
const MAX_ASSETS := 64
const MAX_BYTES := 4000000
const TYPE := "stone_corridor"
const FORMAT := "outpost:dungeon_pack"

func empty_pack() -> Dictionary:
	return {"format":FORMAT,"schema_version":1,"id":"creator:dungeon_pack","loop_percent":22,"modules":[]}

func _valid_id(value: Variant) -> bool:
	if not value is String or value.length()<3 or value.length()>100: return false
	var split: PackedStringArray = value.split(":")
	if split.size()!=2 or split[0].is_empty() or split[1].is_empty(): return false
	for character in value:
		if not "abcdefghijklmnopqrstuvwxyz0123456789_:-.".contains(character): return false
	return true

func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("format","") != FORMAT or value.get("schema_version",0)!=1: return {}
	if not _valid_id(value.get("id")): return {}
	var percent: Variant = value.get("loop_percent")
	var solver := Dungeon.new()
	if not solver.codec._integer(percent) or int(percent)<0 or int(percent)>100: return {}
	var assets: Variant = value.get("modules")
	if not assets is Array or assets.size()>MAX_ASSETS: return {}
	if not solver.load_defaults(): return {}
	var indexed: Dictionary = {}
	for asset in assets:
		if not asset is Dictionary or not _valid_id(asset.get("id")): return {}
		if not solver.register_asset(asset): return {}
		for direction in solver.library[asset["id"]]["sockets"]:
			if solver.library[asset["id"]]["sockets"][direction]!=TYPE: return {}
		indexed[asset["id"]] = asset.duplicate(true)
	var ids: Array = indexed.keys()
	ids.sort()
	var ordered: Array = []
	for id in ids: ordered.append(indexed[id])
	var result := {"format":FORMAT,"schema_version":1,"id":value["id"],"loop_percent":int(percent),"modules":ordered}
	if JSON.stringify(result).to_utf8_buffer().size()>MAX_BYTES: return {}
	return result

func with_asset(value: Variant, asset: Variant) -> Dictionary:
	var pack := normalize(value)
	if pack.is_empty() or not asset is Dictionary or not _valid_id(asset.get("id")): return {}
	# No silent overwrite of a previously authored module.
	for item in pack["modules"]:
		if item["id"] == asset["id"]: return {}
	pack["modules"].append(asset)
	return normalize(pack)

func fingerprint(pack: Dictionary) -> String:
	var normalized := normalize(pack)
	if normalized.is_empty(): return ""
	return JSON.stringify(normalized).sha256_text()
