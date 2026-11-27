extends RefCounted
## Data-only policy. Travel cost is supplied by a validated route planner,
## never inferred from straight-line distance or an undiscovered objective.
## No live quest payout or inventory mutation occurs here.
const LOCAL := "quest"
const EXPEDITION := "expedition"
const UNAVAILABLE := "unavailable"
const MAX_BASE_REWARD := 1000000000

static func classify(route_cost: int, local_budget: int, remote_travel: bool, route_verified: bool) -> String:
	if not route_verified or route_cost<0 or local_budget<=0: return UNAVAILABLE
	if remote_travel or route_cost>local_budget: return EXPEDITION
	return LOCAL

static func reward_preview(base_amount: int, category: String) -> int:
	if base_amount<0 or base_amount>MAX_BASE_REWARD: return -1
	if category==LOCAL: return base_amount
	if category==EXPEDITION:
		# Exact 5/2 multiplier; integer amounts round half up.
		@warning_ignore("integer_division")
		var result: int = (base_amount*5+1)/2
		return result
	return -1
