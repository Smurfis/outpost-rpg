extends RefCounted
## Persistent encounter-site records are separate from portal clear records.
## This data model never edits world geometry or infers safety from streaming.
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
const SCHEMA := 1
const GENERATOR_VERSION := 1
const STATES := ["undiscovered", "discovered", "active", "cleared", "aftermath", "dormant", "regenerating", "ready", "abandoned"]
const SAFE_FLAGS := ["no_players_nearby", "no_unresolved_rewards", "no_graves", "no_critical_pickups", "no_active_encounters", "no_party_or_ui", "no_navigation", "no_protected_builds", "valid_next_layout"]
var sites: Dictionary = {}

static func cycle_seed(world_seed: int, site_id: String, cycle: int, event_id: String) -> int:
	return LAYOUT.stable_seed("world-site:%d:%s:%d:%s:v%d" % [world_seed, site_id, cycle, event_id, GENERATOR_VERSION])

func register_site(site_id: String, world_seed: int, entrance: Vector3i, chunks: Array) -> bool:
	if site_id.is_empty() or sites.has(site_id) or chunks.is_empty():
		return false
	for key in chunks:
		if not key is String or key.is_empty():
			return false
	sites[site_id] = {"site_id": site_id, "world_seed": world_seed,
		"entrance": [entrance.x, entrance.y, entrance.z], "chunks": chunks.duplicate(),
		"cycle": 0, "state": "undiscovered", "event_id": "initial",
		"layout_seed": cycle_seed(world_seed, site_id, 0, "initial"),
		"next_reset_at": 0, "boss_defeated": false, "reward_claims": {}, "room_state": {}}
	return true

func transition(site_id: String, next: String) -> bool:
	if not sites.has(site_id) or next not in STATES:
		return false
	var site: Dictionary = sites[site_id]
	var allowed := {"undiscovered": ["discovered"], "discovered": ["active"],
		"active": ["cleared", "abandoned"], "cleared": ["aftermath"],
		"aftermath": ["dormant"], "abandoned": ["dormant"], "ready": ["active"]}
	if next not in allowed.get(str(site.state), []):
		return false
	site.state = next
	return true

func claim_reward(site_id: String, reward_id: String, recipient: String) -> bool:
	if not sites.has(site_id) or reward_id.is_empty() or recipient.is_empty():
		return false
	var site: Dictionary = sites[site_id]
	if site.state not in ["active", "cleared", "aftermath", "dormant"]:
		return false
	var receipt: String = "%d:%s:%s" % [int(site.cycle), reward_id, recipient]
	if site.reward_claims.has(receipt):
		return false
	site.reward_claims[receipt] = true
	return true

func can_regenerate(site_id: String, now: int, authoritative_safety: Dictionary) -> bool:
	if not sites.has(site_id):
		return false
	var site: Dictionary = sites[site_id]
	if site.state != "dormant" or now < int(site.next_reset_at):
		return false
	# All gates must be supplied by the authoritative host; missing or
	# malformed evidence fails closed. Streaming state is never a gate.
	for key in SAFE_FLAGS:
		if authoritative_safety.get(key) != true:
			return false
	return true

func export_state() -> Dictionary:
	return {"schema": SCHEMA, "sites": sites.duplicate(true)}

func import_state(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema", 0)) != SCHEMA or not data.get("sites") is Dictionary:
		return false
	var validated: Dictionary = {}
	for key in data.sites:
		var site: Variant = data.sites[key]
		if not site is Dictionary or str(site.get("site_id", "")) != str(key) or site.get("state", "") not in STATES:
			return false
		if not site.get("chunks") is Array or not site.get("entrance") is Array or site.entrance.size() != 3 or not site.get("reward_claims") is Dictionary or not site.get("room_state") is Dictionary:
			return false
		if not site.has("world_seed") or not site.has("cycle") or not site.has("event_id") or not site.has("layout_seed") or not site.has("next_reset_at"):
			return false
		validated[str(key)] = site.duplicate(true)
	sites = validated
	return true
