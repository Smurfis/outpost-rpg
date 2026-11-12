extends RefCounted
## The legacy "coins" balance is copper. Preserve save/reward compatibility
## and include any explicitly stored copper without duplicating balances.
static func balance(inventory: Dictionary, denomination: String) -> int:
	var amount: int = maxi(0, int(inventory.get(denomination, 0)))
	if denomination == "copper":
		amount += maxi(0, int(inventory.get("coins", 0)))
	return amount
