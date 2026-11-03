extends RefCounted
## Refunds at most 70% of the original consumed materials; never mint input resources.
const BALANCE = "res://data/progression/balance.json"

static func refund(item: Dictionary) -> Dictionary:
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE))
	var rates: Array = [0.50, 0.55, 0.60, 0.65, 0.70]
	if cfg is Dictionary:
		rates = cfg.get("salvage_rates", rates)
	var rarity: int = clampi(int(item.get("rarity", 0)), 0, 4)
	var rate: float = clampf(float(rates[rarity]), 0.0, 0.70)
	var output: Dictionary = {}
	var materials: Dictionary = item.get("spent", {})
	for key in materials:
		var original: int = maxi(0, int(materials[key]))
		var count: int = int(floor(float(original) * rate))
		if count > 0:
			output[str(key)] = count
	if int(item.get("item_level", 1)) >= 15:
		output["ether_dust"] = 1
	if rarity >= 3 and int(item.get("item_level", 1)) >= 20:
		output["gem_fragment"] = int(output.get("gem_fragment", 0)) + 1
	# Prismatic gems are intentionally NEVER recovered intact.
	return output

static func protected(item: Dictionary, loadout: Dictionary) -> bool:
	var uid: String = str(item.get("uid", ""))
	return bool(item.get("locked", false)) or bool(item.get("favourite", false)) or str(loadout.get(str(item.get("slot", "")), "")) == uid

static func salvage_one(items: Array, material_inventory: Dictionary, loadout: Dictionary, uid: String) -> Dictionary:
	for index in range(items.size()):
		var item: Dictionary = items[index]
		if str(item.get("uid", "")) != uid or protected(item, loadout):
			continue
		var recovered: Dictionary = refund(item)
		for key in recovered:
			material_inventory[str(key)] = int(material_inventory.get(str(key), 0)) + int(recovered[key])
		items.remove_at(index)
		return recovered
	return {}

static func salvage_bulk(items: Array, material_inventory: Dictionary, loadout: Dictionary, uids: Array) -> Dictionary:
	var output: Dictionary = {}
	for uid in uids:
		var returned: Dictionary = salvage_one(items, material_inventory, loadout, str(uid))
		for key in returned:
			output[str(key)] = int(output.get(str(key), 0)) + int(returned[key])
	return output
