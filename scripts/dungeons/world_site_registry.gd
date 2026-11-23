extends RefCounted
## Persistent encounter-site records are separate from portal clear records.
## This data model never edits world geometry or infers safety from streaming.
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
const SCHEMA := 2
const MINE := "physical_mine"
const GUARDS := ["miner", "foreman"]
const CLOSED := ["sealed", "ready_for_renewal"]
const GENERATOR_VERSION := 1
const MAX_MINE_CYCLE := 1000000
const STATES := ["undiscovered", "discovered", "active", "cleared", "aftermath", "dormant", "regenerating", "ready", "abandoned"]
const SAFE_FLAGS := ["no_players_nearby", "no_unresolved_rewards", "no_graves", "no_critical_pickups", "no_active_encounters", "no_party_or_ui", "no_navigation", "no_protected_builds", "valid_next_layout"]
var sites: Dictionary = {}

static func cycle_seed(world_seed: int, site_id: String, cycle: int, event_id: String) -> int:
	return LAYOUT.stable_seed("world-site:%d:%s:%d:%s:v%d" % [world_seed, site_id, cycle, event_id, GENERATOR_VERSION])

func register_site(site_id: String, world_seed: int, entrance: Vector3i, chunks: Array, kind := "portal") -> bool:
	if site_id.is_empty() or sites.has(site_id) or chunks.is_empty() or kind not in ["portal", MINE]:
		return false
	for key in chunks:
		if not key is String or key.is_empty():
			return false
	sites[site_id] = {"site_id": site_id, "world_seed": world_seed, "kind": kind,
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
	if site.kind == MINE:
		allowed = {"undiscovered": ["discovered"], "discovered": ["active"], "active": ["cleared"]}
		if next == "cleared" and not _objectives_met(site):
			return false
	if next not in allowed.get(str(site.state), []):
		return false
	site.state = next
	return true

static func _objectives_met(site: Dictionary) -> bool:
	for guard in GUARDS:
		if site.room_state.get(guard) != true:
			return false
	return true

func record_mine_defeat(site_id: String, guard: String) -> bool:
	var site: Dictionary = sites.get(site_id, {})
	if site.get("kind") != MINE or site.state != "active" or guard not in GUARDS or site.room_state.has(guard):
		return false
	site.room_state[guard] = true
	if guard == "foreman":
		site.boss_defeated = true
	if _objectives_met(site):
		transition(site_id, "cleared")
	return true

static func mine_object_id(site: Dictionary, id: String) -> String:
	if int(site.cycle) == 0:
		return site.site_id + "_" + id
	return "%s_cycle_%d_%s" % [site.site_id, int(site.cycle), id]

static func treasure_receipt(site: Dictionary) -> String:
	return "%d:treasure:player" % int(site.cycle)

# The caller must establish that the physical site is vacant before either
# transition. This does not advance the generation or clear any receipts.
func advance_mine(site_id: String, next: String, vacant: bool) -> bool:
	var site: Dictionary = sites.get(site_id, {})
	if not vacant or site.get("kind") != MINE or not _objectives_met(site):
		return false
	if site.reward_claims.get(treasure_receipt(site)) != true:
		return false
	if not ((site.state == "cleared" and next == "sealed") or (site.state == "sealed" and next == "ready_for_renewal")):
		return false
	site.state = next
	return true

func claim_reward(site_id: String, reward_id: String, recipient: String) -> bool:
	if not sites.has(site_id) or reward_id.is_empty() or recipient.is_empty():
		return false
	var site: Dictionary = sites[site_id]
	if site.state not in ["active", "cleared", "aftermath", "dormant"]:
		return false
	if site.kind == MINE and reward_id == "treasure" and site.state != "cleared":
		return false
	var receipt: String = "%d:%s:%s" % [int(site.cycle), reward_id, recipient]
	if site.reward_claims.has(receipt):
		return false
	site.reward_claims[receipt] = true
	if site.kind == MINE and int(site.cycle) == 1 and reward_id == "treasure" and recipient == "player" and site.has("world_event"):
		site.world_event.completed = true
		site.world_event.phase = "completed"
	return true

func can_regenerate(site_id: String, now: int, authoritative_safety: Dictionary) -> bool:
	if not sites.has(site_id):
		return false
	var site: Dictionary = sites[site_id]
	var eligible_state := "ready_for_renewal" if site.kind == MINE else "dormant"
	if site.state != eligible_state or now < int(site.next_reset_at):
		return false
	# All gates must be supplied by the authoritative host; missing or
	# malformed evidence fails closed. Streaming state is never a gate.
	for key in SAFE_FLAGS:
		if authoritative_safety.get(key) != true:
			return false
	return true

func renewal_proposal(site_id: String, now: int, safety: Dictionary) -> Dictionary:
	if not can_regenerate(site_id, now, safety):
		return {}
	var site: Dictionary = sites[site_id]
	if site.kind != MINE:
		return {}
	var next_cycle := int(site.cycle) + 1
	return {"site_id": site_id, "from_cycle": int(site.cycle), "cycle": next_cycle,
		"world_seed": site.world_seed, "event_id": site.event_id, "generator_version": GENERATOR_VERSION,
		"layout_seed": cycle_seed(int(site.world_seed), site_id, next_cycle, site.event_id),
		"entrance": site.entrance.duplicate(), "chunks": site.chunks.duplicate()}

func export_state() -> Dictionary:
	return {"schema": SCHEMA, "sites": sites.duplicate(true)}

func import_state(data: Variant) -> bool:
	if not data is Dictionary or not data.get("sites") is Dictionary:
		return false
	var schema: Variant = data.get("schema")
	if typeof(schema) not in [TYPE_INT, TYPE_FLOAT] or (schema != 1 and schema != SCHEMA):
		return false
	var validated: Dictionary = {}
	for key in data.sites:
		var site: Variant = data.sites[key]
		if not key is String or key.is_empty() or not site is Dictionary or site.get("site_id") != key:
			return false
		if not site.get("chunks") is Array or not site.get("entrance") is Array or site.entrance.size() != 3 or not site.get("reward_claims") is Dictionary or not site.get("room_state") is Dictionary:
			return false
		if not site.has("world_seed") or not site.has("cycle") or not site.has("event_id") or not site.has("layout_seed") or not site.has("next_reset_at"):
			return false
		var record: Dictionary = site.duplicate(true)
		var legacy_mine: bool = key.begins_with("fractal_physical_goblin_mine_1_")
		if data.schema == 1:
			# Only the original physical mine had this namespace in 5A/5B.
			record.kind = MINE if legacy_mine else "portal"
		if legacy_mine and record.get("kind") != MINE:
			return false
		if record.get("kind") == MINE:
			if record.get("state") not in ["undiscovered", "discovered", "active", "cleared", "sealed", "ready_for_renewal"]:
				return false
			if not _valid_mine_record(record):
				return false
		elif record.get("kind") != "portal" or record.get("state") not in STATES:
			return false
		validated[key] = record
	sites = validated
	return true

static func _valid_mine_record(site: Dictionary) -> bool:
	if site.has("auto_renew_remaining_ms"):
		var timer: Variant = site.auto_renew_remaining_ms
		if typeof(timer) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(timer)) or int(timer) != timer or timer < 0 or timer > 3600000:
			return false
		if site.state not in CLOSED:
			return false
	# JSON numbers load as floats. Reject fractional generations and invalid
	# seed metadata before they can address a different reward namespace.
	for key in ["cycle", "world_seed", "layout_seed"]:
		var value: Variant = site[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or absf(float(value)) > 9007199254740991 or int(value) != value:
			return false
	if site.cycle < 0 or site.cycle > MAX_MINE_CYCLE or site.event_id != "initial":
		return false
	if site.site_id != "fractal_physical_goblin_mine_1_%d" % int(site.world_seed):
		return false
	if site.layout_seed != cycle_seed(int(site.world_seed), site.site_id, int(site.cycle), site.event_id):
		return false
	if site.cycle > 0 and not site.has("world_event"):
		return false
	if site.chunks.is_empty() or not site.get("boss_defeated") is bool:
		return false
	for chunk in site.chunks:
		if not chunk is String or chunk.is_empty():
			return false
	for coord in site.entrance:
		if typeof(coord) not in [TYPE_INT, TYPE_FLOAT] or int(coord) != coord:
			return false
	for guard in site.room_state:
		if guard not in GUARDS or site.room_state[guard] != true:
			return false
	if site.boss_defeated != site.room_state.has("foreman"):
		return false
	if site.state in ["undiscovered", "discovered"] and not site.room_state.is_empty():
		return false
	if _objectives_met(site) != (site.state == "cleared" or site.state in CLOSED):
		return false
	for receipt in site.reward_claims:
		if not receipt is String or site.reward_claims[receipt] != true:
			return false
	if site.has("world_event"):
		var event: Variant = site.world_event
		if not event is Dictionary or event.get("id") != "goblin_reoccupation" or event.get("site_id") != site.site_id:
			return false
		if not event.get("phase") is String or typeof(event.get("seed")) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not event.get("completed") is bool or event.get("objective") != "Investigate the disturbance at the Goblin Mine.":
			return false
		if event.get("seed") != cycle_seed(int(site.world_seed), site.site_id, 1, "goblin_reoccupation"):
			return false
		if event.get("phase") not in ["reported", "ready_for_renewal", "completed"]:
			return false
		if (event.phase == "completed") != event.completed:
			return false
		if event.completed and site.reward_claims.get("1:treasure:player") != true:
			return false
		if site.cycle == 0 and not ((site.state == "sealed" and event.phase == "reported") or (site.state == "ready_for_renewal" and event.phase == "ready_for_renewal")):
			return false
		if site.cycle > 0 and not event.completed and event.phase != "ready_for_renewal":
			return false
		if site.cycle > 1 and not event.completed:
			return false
	if site.has("reopened") and (site.cycle < 1 or not site.reopened is bool or not site.reopened):
		return false
	if site.has("reopened") and site.state in CLOSED and not (site.cycle == 1 and site.state == "ready_for_renewal" and not site.has("cycle_history")):
		return false
	if site.has("renewal_committed") and (not site.renewal_committed is bool or not site.renewal_committed or site.cycle < 1 or site.state != "ready_for_renewal" or site.has("renewal") or not site.has("cycle_history")):
		return false
	if site.has("renewal"):
		var journal: Variant = site.renewal
		if site.cycle >= MAX_MINE_CYCLE or site.state != "ready_for_renewal" or not site.has("world_event") or not journal is Dictionary:
			return false
		for field in ["cycle", "seed", "from_cycle", "generator_version"]:
			if journal.has(field) and typeof(journal[field]) not in [TYPE_INT, TYPE_FLOAT]:
				return false
		if journal.get("phase") not in ["prepared", "publishing"] or journal.get("cycle") != int(site.cycle) + 1:
			return false
		if journal.get("seed") != cycle_seed(int(site.world_seed), site.site_id, int(site.cycle) + 1, site.event_id):
			return false
		if journal.get("from_cycle", 0) != site.cycle or journal.get("generator_version", GENERATOR_VERSION) != GENERATOR_VERSION:
			return false
		var digest: Variant = journal.get("digest")
		if not digest is String or digest.length() != 64 or not digest.is_valid_hex_number(false):
			return false
	if site.has("cycle_history"):
		if not site.cycle_history is Dictionary or site.cycle_history.size() != int(site.cycle):
			return false
		for cycle in site.cycle_history:
			if not cycle is String or not cycle.is_valid_int() or str(int(cycle)) != cycle or int(cycle) < 0 or int(cycle) >= int(site.cycle):
				return false
			var previous: Variant = site.cycle_history[cycle]
			if not previous is Dictionary or previous.size() != GUARDS.size() or not previous.get("miner") is bool or not previous.get("foreman") is bool:
				return false
			if not previous.miner or not previous.foreman:
				return false
			if site.reward_claims.get(cycle + ":treasure:player") != true:
				return false
	elif site.cycle > 1:
		return false
	# Existing cycle-one records were sealed before their encounter existed.
	var prior_cycle_pending: bool = site.get("renewal_committed", false) or (site.cycle == 1 and site.state == "ready_for_renewal" and not site.has("cycle_history"))
	var required_receipt := "%d:treasure:player" % (int(site.cycle) - 1) if prior_cycle_pending else treasure_receipt(site)
	return site.state not in CLOSED or site.reward_claims.has(required_receipt)
