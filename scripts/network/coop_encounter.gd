extends RefCounted
## LAN host-owned dungeon guardian combat: HP, bounded pursuit, melee, knockouts.
## Remote peers only submit movement and target IDs; NPC state/HP is computed here.
const DAMAGE_PER_HIT: float = 8.0
const MELEE_RADIUS: float = 3.4
const ATTACK_COOLDOWN_MS: int = 550
const AGGRO_RADIUS: float = 7.0
const ENEMY_ATTACK_RADIUS: float = 1.75
const ENEMY_ATTACK_COOLDOWN_MS: int = 1700
const GUARD_SPEED: float = 1.45
const MAX_LEASH_DISTANCE: float = 2.5
const REVIVE_RADIUS: float = 2.75
const REVIVE_HP: float = 35.0

var run_id: int = 0
var floor_number: int = 0
var guards: Dictionary = {}
var player_health: Dictionary = {}
var last_attack_ms: Dictionary = {}
var last_guard_hit_ms: Dictionary = {}
var revision: int = 0

func configure(descriptor: Dictionary, records: Array) -> void:
	run_id = int(descriptor.get("id", 0))
	floor_number = int(descriptor.get("floor", 0))
	guards.clear()
	player_health.clear()
	last_attack_ms.clear()
	last_guard_hit_ms.clear()
	revision = 0
	for member in descriptor.get("members", []):
		var peer_id: int = int(member)
		if peer_id > 0:
			player_health[peer_id] = 100.0
	for record in records:
		var slot: int = int(record.get("slot", -1))
		if slot < 0 or guards.has(slot):
			continue
		var hp: float = maxf(1.0, float(record.get("hp", 1.0)))
		var position_at: Vector3 = record.get("position", Vector3.ZERO)
		if not position_at.is_finite():
			continue
		guards[slot] = {
			"hp": hp,
			"position": position_at,
			"home": position_at,
			"damage": maxf(1.0, float(record.get("damage", 6.0)))
		}

func remaining() -> int:
	var count: int = 0
	for slot in guards:
		if float(guards[slot].get("hp", 0.0)) > 0.0:
			count += 1
	return count

func cleared() -> bool:
	return not guards.is_empty() and remaining() == 0

func strike(peer_id: int, requested_run: int, requested_floor: int, slot: int, player_position: Vector3, at_ms: int) -> Dictionary:
	if peer_id < 1 or requested_run != run_id or requested_floor != floor_number:
		return {}
	if player_health.has(peer_id) and float(player_health[peer_id]) <= 0.0:
		return {}
	if not guards.has(slot) or not player_position.is_finite():
		return {}
	var target: Dictionary = guards[slot]
	if float(target.get("hp", 0.0)) <= 0.0:
		return {}
	if player_position.distance_to(target["position"]) > MELEE_RADIUS:
		return {}
	var last: int = int(last_attack_ms.get(peer_id, -1000000))
	if at_ms < last or at_ms - last < ATTACK_COOLDOWN_MS:
		return {}
	last_attack_ms[peer_id] = at_ms
	target["hp"] = maxf(0.0, float(target["hp"]) - DAMAGE_PER_HIT)
	guards[slot] = target
	revision += 1
	return {"slot": slot, "hp": target["hp"], "remaining": remaining(), "cleared": cleared()}

func tick_ai(delta: float, party_positions: Dictionary, at_ms: int) -> Array:
	## The host chooses targets and resolves hits. Guardians remain tethered to
	## their own chamber until navigation/obstacle pathfinding is implemented.
	var attacks: Array = []
	if delta <= 0.0 or delta > 0.5 or cleared():
		return attacks
	var changed: bool = false
	for slot in guards:
		var guard: Dictionary = guards[slot]
		if float(guard.get("hp", 0.0)) <= 0.0:
			continue
		var at: Vector3 = guard["position"]
		var home: Vector3 = guard["home"]
		var target_peer: int = 0
		var target_at: Vector3 = Vector3.ZERO
		var nearest: float = AGGRO_RADIUS
		for member in player_health:
			var peer_id: int = int(member)
			if float(player_health[peer_id]) <= 0.0 or not party_positions.has(peer_id):
				continue
			var candidate: Vector3 = party_positions[peer_id]
			if not candidate.is_finite() or absf(candidate.y - at.y) > 3.5:
				continue
			var dist: float = Vector2(at.x - candidate.x, at.z - candidate.z).length()
			if dist < nearest:
				target_peer = peer_id
				target_at = candidate
				nearest = dist
		if target_peer == 0:
			continue
		if nearest > ENEMY_ATTACK_RADIUS:
			var travel: Vector3 = target_at - at
			travel.y = 0.0
			if travel.length_squared() > 0.0001:
				var candidate: Vector3 = at + travel.normalized() * minf(travel.length(), GUARD_SPEED * delta)
				var from_home: Vector3 = candidate - home
				from_home.y = 0.0
				if from_home.length() > MAX_LEASH_DISTANCE:
					candidate = home + from_home.normalized() * MAX_LEASH_DISTANCE
				if at.distance_squared_to(candidate) > 0.0000001:
					guard["position"] = candidate
					guards[slot] = guard
					changed = true
		else:
			var last: int = int(last_guard_hit_ms.get(slot, -1000000))
			if at_ms >= last and at_ms - last >= ENEMY_ATTACK_COOLDOWN_MS:
				last_guard_hit_ms[slot] = at_ms
				var hp: float = maxf(0.0, float(player_health[target_peer]) - float(guard["damage"]))
				player_health[target_peer] = hp
				attacks.append({"slot": int(slot), "target": target_peer, "hp": hp})
				changed = true
	if changed:
		revision += 1
	return attacks

func revive(requester: int, ally: int, party_positions: Dictionary) -> bool:
	if requester <= 0 or requester == ally or not player_health.has(requester) or not player_health.has(ally):
		return false
	if float(player_health[requester]) <= 0.0 or float(player_health[ally]) > 0.0:
		return false
	if not party_positions.has(requester) or not party_positions.has(ally):
		return false
	var at: Vector3 = party_positions[requester]
	var ally_at: Vector3 = party_positions[ally]
	if not at.is_finite() or not ally_at.is_finite() or at.distance_to(ally_at) > REVIVE_RADIUS:
		return false
	player_health[ally] = REVIVE_HP
	revision += 1
	return true

func snapshot() -> Dictionary:
	var health: Dictionary = {}
	var positions: Dictionary = {}
	for slot in guards:
		health[slot] = float(guards[slot].get("hp", 0.0))
		positions[slot] = guards[slot].get("position", Vector3.ZERO)
	return {
		"run_id": run_id, "floor": floor_number, "revision": revision,
		"hp": health, "positions": positions,
		"player_health": player_health.duplicate(), "remaining": remaining()
	}
