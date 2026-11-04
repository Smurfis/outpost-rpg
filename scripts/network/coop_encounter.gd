extends RefCounted
## Server-owned, per-run guardian HP and melee validation. No client damage math.
const DAMAGE_PER_HIT: float = 8.0
const MELEE_RADIUS: float = 3.4
const ATTACK_COOLDOWN_MS: int = 550

var run_id: int = 0
var floor_number: int = 0
var guards: Dictionary = {}
var last_attack_ms: Dictionary = {}
var revision: int = 0

func configure(descriptor: Dictionary, records: Array) -> void:
	run_id = int(descriptor.get("id", 0))
	floor_number = int(descriptor.get("floor", 0))
	guards.clear()
	last_attack_ms.clear()
	revision = 0
	for record in records:
		var slot: int = int(record.get("slot", -1))
		if slot < 0 or guards.has(slot):
			continue
		var hp: float = maxf(1.0, float(record.get("hp", 1.0)))
		var position_at: Vector3 = record.get("position", Vector3.ZERO)
		if not position_at.is_finite():
			continue
		guards[slot] = {"hp": hp, "position": position_at}

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

func snapshot() -> Dictionary:
	var health: Dictionary = {}
	for slot in guards:
		health[slot] = float(guards[slot].get("hp", 0.0))
	return {"run_id": run_id, "floor": floor_number, "revision": revision, "hp": health, "remaining": remaining()}
