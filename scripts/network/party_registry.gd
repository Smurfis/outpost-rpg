extends RefCounted
## Host-owned party and dungeon-session state. No scene dependencies.
## Each peer belongs to exactly one party; each party owns at most one active run.
const MAX_MEMBERS: int = 4
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
var parties: Dictionary = {}
var memberships: Dictionary = {}
var next_party: int = 1
var next_run: int = 1

func create_party(leader_id: int) -> int:
	if leader_id <= 0:
		return -1
	var previous_party: int = party_of(leader_id)
	if previous_party != 0 and not active_run(previous_party).is_empty():
		return -1
	leave_party(leader_id)
	var party_id: int = next_party
	next_party += 1
	parties[party_id] = {"leader": leader_id, "members": [leader_id], "run": {}}
	memberships[leader_id] = party_id
	return party_id

func party_of(peer_id: int) -> int:
	return int(memberships.get(peer_id, 0))

func join_party(peer_id: int, party_id: int) -> bool:
	if peer_id <= 0 or not parties.has(party_id):
		return false
	if party_of(peer_id) == party_id:
		return true
	var destination: Dictionary = parties[party_id]
	var members: Array = destination.get("members", [])
	if members.size() >= MAX_MEMBERS or not (destination.get("run", {}) as Dictionary).is_empty():
		return false
	# No switching into a dungeon or abandoning an active run silently.
	var previous: int = party_of(peer_id)
	if previous != 0 and not (parties[previous].get("run", {}) as Dictionary).is_empty():
		return false
	leave_party(peer_id)
	members = destination.get("members", [])
	members.append(peer_id)
	destination["members"] = members
	parties[party_id] = destination
	memberships[peer_id] = party_id
	return true

func leave_party(peer_id: int) -> bool:
	var party_id: int = party_of(peer_id)
	if party_id == 0 or not parties.has(party_id):
		return false
	var party: Dictionary = parties[party_id]
	var members: Array = party.get("members", [])
	members.erase(peer_id)
	memberships.erase(peer_id)
	var current_run: Dictionary = party.get("run", {})
	if not current_run.is_empty():
		var run_members: Array = current_run.get("members", [])
		run_members.erase(peer_id)
		current_run["members"] = run_members
		party["run"] = current_run
	if members.is_empty():
		parties.erase(party_id)
	else:
		party["members"] = members
		if int(party.get("leader", 0)) == peer_id:
			party["leader"] = int(members[0])
		parties[party_id] = party
	return true

func remove_peer(peer_id: int) -> void:
	leave_party(peer_id)

func leader_of(party_id: int) -> int:
	if not parties.has(party_id):
		return 0
	return int(parties[party_id].get("leader", 0))

func members_of(party_id: int) -> Array:
	if not parties.has(party_id):
		return []
	return (parties[party_id].get("members", []) as Array).duplicate()

func active_run(party_id: int) -> Dictionary:
	if not parties.has(party_id):
		return {}
	return (parties[party_id].get("run", {}) as Dictionary).duplicate(true)

func start_run(requester_id: int, entrance_id: String, rarity: int) -> Dictionary:
	var party_id: int = party_of(requester_id)
	if party_id == 0 or leader_of(party_id) != requester_id:
		return {}
	if entrance_id.is_empty() or entrance_id.length() > 80 or rarity < 0 or rarity > 4:
		return {}
	if not active_run(party_id).is_empty():
		return {}
	var profile: Dictionary = LAYOUT.profile(entrance_id, rarity)
	var layout: Dictionary = LAYOUT.generate(entrance_id, rarity, 0)
	if not LAYOUT.validate(layout):
		return {}
	var descriptor: Dictionary = {
		"id": next_run,
		"party_id": party_id,
		"entrance_id": entrance_id,
		"rarity": rarity,
		"seed": int(profile["seed"]),
		"floor": 1,
		"floors": int(profile["floors"]),
		"members": members_of(party_id),
		"state": "active"
	}
	next_run += 1
	var party: Dictionary = parties[party_id]
	party["run"] = descriptor.duplicate(true)
	parties[party_id] = party
	return descriptor.duplicate(true)

func advance_floor(requester_id: int, run_id: int) -> Dictionary:
	var party_id: int = party_of(requester_id)
	var run: Dictionary = active_run(party_id)
	if leader_of(party_id) != requester_id or int(run.get("id", 0)) != run_id:
		return {}
	if int(run.get("floor", 0)) >= int(run.get("floors", 0)):
		return {}
	run["floor"] = int(run["floor"]) + 1
	var party: Dictionary = parties[party_id]
	party["run"] = run
	parties[party_id] = party
	return run.duplicate(true)

func end_run(requester_id: int, run_id: int) -> bool:
	var party_id: int = party_of(requester_id)
	var run: Dictionary = active_run(party_id)
	if leader_of(party_id) != requester_id or int(run.get("id", 0)) != run_id:
		return false
	var party: Dictionary = parties[party_id]
	party["run"] = {}
	parties[party_id] = party
	return true

func snapshot() -> Dictionary:
	var entries: Array = []
	for party_id in parties:
		var item: Dictionary = parties[party_id]
		entries.append({
			"id": int(party_id),
			"leader": int(item["leader"]),
			"members": (item.get("members", []) as Array).duplicate(),
			"run": (item.get("run", {}) as Dictionary).duplicate(true)
		})
	entries.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	return {"parties": entries}
