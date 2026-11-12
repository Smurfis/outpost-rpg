extends Node3D
## LAN-first small co-op session. Host owns parties and run descriptors.
## LAN co-op foundation; party dungeons are preview-only until server combat and loot authority is implemented.
signal session_changed()
signal roster_changed()
signal private_run_changed()
signal join_approval_requested(peer_id: int, nickname: String)

const REGISTRY = preload("res://scripts/network/party_registry.gd")
const INSTANCE = preload("res://scripts/dungeons/dungeon_instance.gd")
const UI = preload("res://scripts/network/coop_ui.gd")
const JOIN_APPROVAL = preload("res://scripts/network/coop_join_approval.gd")
const VOXEL_CHARACTER = preload("res://scripts/voxel/voxel_character.gd")
const ENCOUNTER = preload("res://scripts/network/coop_encounter.gd")
const LOOT = preload("res://scripts/dungeons/dungeon_loot.gd")
const PORT: int = 30115
const MAX_CLIENTS: int = 3
const TICK: float = 0.12

var game
var display_name: String = "Adventurer"
var mode: String = "solo"
var status_message: String = "Offline — solo adventure"
var registry = REGISTRY.new()
var players: Dictionary = {}
var roster: Dictionary = {}
var party_snapshot: Dictionary = {"parties": []}
var remote_avatars: Dictionary = {}
var run_preview: Node3D
var preview_descriptor: Dictionary = {}
var return_position: Vector3 = Vector3.ZERO
var has_return_point: bool = false
var peer: ENetMultiplayerPeer
var ui: CanvasLayer
var join_approval: CanvasLayer
var pending_peer_names: Dictionary = {}
var tick_elapsed: float = 0.0
var host_encounters: Dictionary = {}
var host_session_id: String = ""
var preview_health_revision: int = -1
var party_health: Dictionary = {}
var last_synced_health: float = 100.0
var return_health: float = 100.0

func _ready() -> void:
	name = "CoopSession"
	game = get_parent()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	ui = UI.new()
	ui.setup(self)
	add_child(ui)
	join_approval = JOIN_APPROVAL.new()
	join_approval.setup(self)
	add_child(join_approval)

func in_party_dungeon() -> bool:
	return online() and not preview_descriptor.is_empty()

func online() -> bool:
	return mode == "hosting" or mode == "joined"

func _safe_name(text_value: String) -> String:
	var clean: String = text_value.strip_edges().substr(0, 20)
	return "Adventurer" if clean.is_empty() else clean

func host_lan(preferred_name: String) -> int:
	disconnect_session()
	display_name = _safe_name(preferred_name)
	peer = ENetMultiplayerPeer.new()
	var result: int = peer.create_server(PORT, MAX_CLIENTS)
	if result != OK:
		peer = null
		status_message = "Could not host UDP %d (error %d)" % [PORT, result]
		session_changed.emit()
		return result
	multiplayer.multiplayer_peer = peer
	mode = "hosting"
	host_session_id = "%d-%d" % [Time.get_ticks_usec(), randi()]
	registry = REGISTRY.new()
	pending_peer_names.clear()
	registry.create_party(1)
	players = {1: {"name": display_name, "position": game.hero.global_position, "yaw": 0.0}}
	_broadcast_snapshot()
	status_message = "Hosting LAN on UDP %d. Same Wi-Fi required." % PORT
	session_changed.emit()
	return OK

func join_lan(ip: String, preferred_name: String) -> int:
	disconnect_session()
	var address: String = ip.strip_edges()
	if not address.is_valid_ip_address() or address.contains(":"):
		status_message = "Enter a valid IPv4 LAN address."
		session_changed.emit()
		return ERR_INVALID_PARAMETER
	display_name = _safe_name(preferred_name)
	peer = ENetMultiplayerPeer.new()
	var result: int = peer.create_client(address, PORT)
	if result != OK:
		peer = null
		status_message = "Could not connect (error %d)" % result
		session_changed.emit()
		return result
	multiplayer.multiplayer_peer = peer
	mode = "connecting"
	status_message = "Connecting to %s:%d..." % [address, PORT]
	session_changed.emit()
	return OK

func disconnect_session() -> void:
	_clear_host_encounters()
	_clear_preview()
	_clear_avatars()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if peer != null:
		peer.close()
		peer = null
	mode = "solo"
	status_message = "Offline — solo adventure"
	registry = REGISTRY.new()
	pending_peer_names.clear()
	players.clear()
	roster.clear()
	party_snapshot = {"parties": []}
	preview_descriptor.clear()
	tick_elapsed = 0.0
	host_session_id = ""
	session_changed.emit()

func party_id() -> int:
	var local_id: int = multiplayer.get_unique_id() if online() else 0
	for party in party_snapshot.get("parties", []):
		if local_id in party.get("members", []):
			return int(party.get("id", 0))
	return 0

func my_party() -> Dictionary:
	var id: int = party_id()
	for party in party_snapshot.get("parties", []):
		if int(party.get("id", 0)) == id:
			return party
	return {}

func is_party_leader() -> bool:
	var party: Dictionary = my_party()
	return online() and int(party.get("leader", 0)) == multiplayer.get_unique_id()

func request_new_party() -> void:
	if not online():
		return
	if multiplayer.is_server():
		_make_party(multiplayer.get_unique_id())
	else:
		_request_create_party.rpc_id(1)

func request_join_party(id: int) -> void:
	if not online() or id <= 0:
		return
	if multiplayer.is_server():
		_join_party(multiplayer.get_unique_id(), id)
	else:
		_request_join_party.rpc_id(1, id)

func request_preview(entrance_id: String, rarity: int) -> void:
	if not online() or not is_party_leader():
		return
	if multiplayer.is_server():
		_start_preview(multiplayer.get_unique_id(), entrance_id, rarity)
	else:
		_request_start_preview.rpc_id(1, entrance_id, rarity)

func request_strike(slot: int) -> void:
	if not in_party_dungeon() or slot < 0 or float(party_health.get(multiplayer.get_unique_id(), 100.0)) <= 0.0:
		return
	var run_id: int = int(preview_descriptor.get("id", 0))
	var floor_number: int = int(preview_descriptor.get("floor", 0))
	if multiplayer.is_server():
		_handle_strike(1, run_id, floor_number, slot)
	else:
		_request_strike.rpc_id(1, run_id, floor_number, slot)

func revive_available() -> bool:
	if not in_party_dungeon() or float(party_health.get(multiplayer.get_unique_id(), 100.0)) <= 0.0:
		return false
	for member in my_party().get("members", []):
		var peer_id: int = int(member)
		if peer_id == multiplayer.get_unique_id() or float(party_health.get(peer_id, 100.0)) > 0.0:
			continue
		var at: Vector3 = roster.get(peer_id, {}).get("position", Vector3.ZERO)
		if game.hero.global_position.distance_to(at) <= ENCOUNTER.REVIVE_RADIUS:
			return true
	return false

func request_revive_nearest() -> void:
	if not revive_available():
		return
	var run_id: int = int(preview_descriptor.get("id", 0))
	var floor_number: int = int(preview_descriptor.get("floor", 0))
	for member in my_party().get("members", []):
		var peer_id: int = int(member)
		if peer_id == multiplayer.get_unique_id() or float(party_health.get(peer_id, 100.0)) > 0.0:
			continue
		var at: Vector3 = roster.get(peer_id, {}).get("position", Vector3.ZERO)
		if game.hero.global_position.distance_to(at) > ENCOUNTER.REVIVE_RADIUS:
			continue
		if multiplayer.is_server():
			_revive_member(1, run_id, floor_number, peer_id)
		else:
			_request_revive.rpc_id(1, run_id, floor_number, peer_id)
		return

func can_advance_preview() -> bool:
	return run_preview != null and is_instance_valid(run_preview) and int(run_preview.guards_remaining) == 0

func request_complete_run() -> void:
	if not in_party_dungeon() or not is_party_leader():
		return
	var run_id: int = int(preview_descriptor.get("id", 0))
	if not can_advance_preview():
		game.hud.toast("Defeat the remaining guardians before claiming the chest.")
		return
	if multiplayer.is_server():
		_complete_run(1, run_id)
	else:
		_request_complete_run.rpc_id(1, run_id)

func request_next_floor() -> void:
	if not online() or not is_party_leader():
		return
	var descriptor: Dictionary = my_party().get("run", {})
	if descriptor.is_empty():
		return
	if not can_advance_preview():
		game.hud.toast("Defeat the remaining guardians before climbing the stairs.")
		return
	if multiplayer.is_server():
		_next_floor(multiplayer.get_unique_id(), int(descriptor.get("id", 0)))
	else:
		_request_next_floor.rpc_id(1, int(descriptor.get("id", 0)))

func request_end_preview() -> void:
	if not online() or not is_party_leader():
		return
	var descriptor: Dictionary = my_party().get("run", {})
	if descriptor.is_empty():
		return
	if multiplayer.is_server():
		_end_preview(multiplayer.get_unique_id(), int(descriptor.get("id", 0)))
	else:
		_request_end_preview.rpc_id(1, int(descriptor.get("id", 0)))

func _peer_connected(_peer_id: int) -> void:
	# Handshake begins on the client once ENet establishes the connection.
	pass

func _peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	players.erase(peer_id)
	pending_peer_names.erase(peer_id)
	if join_approval != null:
		join_approval.dismiss_peer(peer_id)
	registry.remove_peer(peer_id)
	_broadcast_snapshot()

func _connected_to_server() -> void:
	mode = "joined"
	players[multiplayer.get_unique_id()] = {"name": display_name, "position": game.hero.global_position, "yaw": 0.0}
	status_message = "Connected to LAN host — waiting for party roster."
	session_changed.emit()
	_introduce.rpc_id(1, display_name)

func _connection_failed() -> void:
	disconnect_session()
	status_message = "LAN connection failed. Check Wi-Fi, address and firewall."
	session_changed.emit()

func _server_disconnected() -> void:
	disconnect_session()
	status_message = "Host disconnected; returned to solo."
	session_changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func _introduce(requested_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1 or not multiplayer.get_peers().has(sender):
		return
	if players.has(sender) or pending_peer_names.has(sender):
		return
	# A remote peer may connect to ENet but is NOT added to the roster or
	# party/dungeons until the host explicitly approves this name.
	var safe: String = _safe_name(requested_name)
	pending_peer_names[sender] = safe
	join_approval_requested.emit(sender, safe)

func respond_to_join(peer_id: int, accepted: bool) -> void:
	if not multiplayer.is_server() or not pending_peer_names.has(peer_id):
		return
	var safe_name: String = str(pending_peer_names[peer_id])
	pending_peer_names.erase(peer_id)
	if not multiplayer.get_peers().has(peer_id):
		return
	if not accepted:
		if peer != null:
			peer.disconnect_peer(peer_id)
		return
	players[peer_id] = {"name": safe_name, "position": Vector3(0, 0.35, 0), "yaw": 0.0}
	if registry.party_of(peer_id) == 0:
		var lobby_party: int = registry.party_of(1)
		if lobby_party != 0 and not registry.join_party(peer_id, lobby_party):
			_make_party(peer_id)
		elif lobby_party == 0:
			_make_party(peer_id)
	_broadcast_snapshot()

func _make_party(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var new_id: int = registry.create_party(peer_id)
	if new_id > 0:
		_broadcast_snapshot()

func _join_party(peer_id: int, id: int) -> void:
	if not players.has(peer_id):
		return
	if registry.join_party(peer_id, id):
		_broadcast_snapshot()

@rpc("any_peer", "call_remote", "reliable")
func _request_create_party() -> void:
	if multiplayer.is_server():
		_make_party(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func _request_join_party(id: int) -> void:
	if multiplayer.is_server():
		_join_party(multiplayer.get_remote_sender_id(), id)

func _start_preview(requester: int, entrance_id: String, rarity: int) -> void:
	if not players.has(requester):
		return
	# A run is only created through the host's membership/leader validation.
	var descriptor: Dictionary = registry.start_run(requester, entrance_id, rarity)
	if not descriptor.is_empty():
		_broadcast_snapshot()

func _next_floor(requester: int, run_id: int) -> void:
	if not _encounter_cleared(requester, run_id):
		return
	var descriptor: Dictionary = registry.advance_floor(requester, run_id)
	if not descriptor.is_empty():
		_broadcast_snapshot()

func _end_preview(requester: int, run_id: int) -> void:
	if registry.end_run(requester, run_id):
		_broadcast_snapshot()

@rpc("any_peer", "call_remote", "reliable")
func _request_start_preview(entrance_id: String, rarity: int) -> void:
	if multiplayer.is_server():
		_start_preview(multiplayer.get_remote_sender_id(), entrance_id, rarity)

@rpc("any_peer", "call_remote", "reliable")
func _request_next_floor(run_id: int) -> void:
	if multiplayer.is_server():
		_next_floor(multiplayer.get_remote_sender_id(), run_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_end_preview(run_id: int) -> void:
	if multiplayer.is_server():
		_end_preview(multiplayer.get_remote_sender_id(), run_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_strike(run_id: int, floor_number: int, slot: int) -> void:
	if multiplayer.is_server():
		_handle_strike(multiplayer.get_remote_sender_id(), run_id, floor_number, slot)

@rpc("any_peer", "call_remote", "reliable")
func _request_complete_run(run_id: int) -> void:
	if multiplayer.is_server():
		_complete_run(multiplayer.get_remote_sender_id(), run_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_revive(run_id: int, floor_number: int, ally_id: int) -> void:
	if multiplayer.is_server():
		_revive_member(multiplayer.get_remote_sender_id(), run_id, floor_number, ally_id)

func _revive_member(sender: int, run_id: int, floor_number: int, ally_id: int) -> void:
	if not multiplayer.is_server() or not players.has(sender):
		return
	var run: Dictionary = registry.active_run(registry.party_of(sender))
	if int(run.get("id", 0)) != run_id or int(run.get("floor", 0)) != floor_number:
		return
	if not (run.get("members", []) as Array).has(ally_id) or not host_encounters.has(run_id):
		return
	var positions: Dictionary = _party_positions(run)
	if host_encounters[run_id]["ledger"].revive(sender, ally_id, positions):
		_broadcast_encounter_state(run_id)

func _party_positions(descriptor: Dictionary) -> Dictionary:
	var positions: Dictionary = {}
	for member in descriptor.get("members", []):
		var peer_id: int = int(member)
		if players.has(peer_id):
			positions[peer_id] = game.hero.global_position if peer_id == 1 else players[peer_id].get("position", Vector3.ZERO)
	return positions

func _tick_host_encounters(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for run_id in host_encounters:
		var descriptor: Dictionary = {}
		for party in party_snapshot.get("parties", []):
			var run: Dictionary = party.get("run", {})
			if int(run.get("id", 0)) == int(run_id):
				descriptor = run
				break
		if descriptor.is_empty():
			continue
		var ledger = host_encounters[run_id]["ledger"]
		var before: int = int(ledger.revision)
		ledger.tick_ai(delta, _party_positions(descriptor), Time.get_ticks_msec())
		if int(ledger.revision) != before:
			_broadcast_encounter_state(int(run_id))

func _encounter_cleared(requester: int, run_id: int) -> bool:
	var party: int = registry.party_of(requester)
	var run: Dictionary = registry.active_run(party)
	if int(run.get("id", 0)) != run_id or not host_encounters.has(run_id):
		return false
	var ledger = host_encounters[run_id]["ledger"]
	return ledger.floor_number == int(run.get("floor", 0)) and ledger.cleared()

func _handle_strike(sender: int, run_id: int, floor_number: int, slot: int) -> void:
	if not multiplayer.is_server() or not players.has(sender):
		return
	var party: int = registry.party_of(sender)
	var run: Dictionary = registry.active_run(party)
	if int(run.get("id", 0)) != run_id or int(run.get("floor", 0)) != floor_number:
		return
	if not (run.get("members", []) as Array).has(sender) or not host_encounters.has(run_id):
		return
	var player_position: Vector3 = game.hero.global_position if sender == 1 else players[sender].get("position", Vector3.ZERO)
	var ledger = host_encounters[run_id]["ledger"]
	var result: Dictionary = ledger.strike(sender, run_id, floor_number, slot, player_position, Time.get_ticks_msec())
	if not result.is_empty():
		_broadcast_encounter_state(run_id)

func _complete_run(requester: int, run_id: int) -> void:
	if not multiplayer.is_server() or not _encounter_cleared(requester, run_id):
		return
	var party: int = registry.party_of(requester)
	if registry.leader_of(party) != requester:
		return
	var descriptor: Dictionary = registry.active_run(party)
	if int(descriptor.get("floor", 0)) != int(descriptor.get("floors", -1)):
		return
	# End the run BEFORE dispatching loot; replayed requests then fail validation.
	if not registry.end_run(requester, run_id):
		return
	var reward: Dictionary = LOOT.chest(str(descriptor["entrance_id"]), int(descriptor["rarity"]), int(descriptor["floor"]) - 1, int(descriptor["floors"]))
	var receipt: String = "lan:%s:%d" % [host_session_id, run_id]
	for member in descriptor.get("members", []):
		if not players.has(member):
			continue
		if int(member) == 1:
			game.receive_coop_reward(receipt, reward)
		else:
			_receive_run_reward.rpc_id(int(member), receipt, reward)
	_broadcast_snapshot()

@rpc("authority", "call_remote", "reliable")
func _receive_run_reward(receipt: String, reward: Dictionary) -> void:
	if online() and game != null:
		game.receive_coop_reward(receipt, reward)

func _clear_host_encounters() -> void:
	for entry in host_encounters.values():
		var instance: Node3D = entry.get("instance", null)
		if bool(entry.get("owned", false)) and is_instance_valid(instance):
			instance.queue_free()
	host_encounters.clear()

func _sync_host_encounters() -> void:
	if not multiplayer.is_server() or not online():
		return
	var active_ids: Dictionary = {}
	for party in party_snapshot.get("parties", []):
		var descriptor: Dictionary = party.get("run", {})
		if descriptor.is_empty():
			continue
		var run_id: int = int(descriptor.get("id", 0))
		var floor_number: int = int(descriptor.get("floor", 0))
		active_ids[run_id] = true
		if host_encounters.has(run_id) and int(host_encounters[run_id]["ledger"].floor_number) == floor_number:
			continue
		if host_encounters.has(run_id):
			var previous: Dictionary = host_encounters[run_id]
			if bool(previous.get("owned", false)) and is_instance_valid(previous.get("instance", null)):
				previous["instance"].queue_free()
			host_encounters.erase(run_id)
		var dungeon: Node3D
		var owned: bool = false
		if run_preview != null and is_instance_valid(run_preview) and int(preview_descriptor.get("id", 0)) == run_id:
			dungeon = run_preview
		else:
			# Other parties also need host-owned encounters, even when the host
			# is not physically present in their dungeon.
			dungeon = INSTANCE.new()
			add_child(dungeon)
			dungeon.position = Vector3(0.0, 10.0, -800.0 - float(party.get("id", 0)) * 700.0)
			dungeon.setup(str(descriptor["entrance_id"]), int(descriptor["rarity"]), game.hero, floor_number)
			dungeon.visible = false
			owned = true
		var records: Array = []
		for guardian in get_tree().get_nodes_in_group("dungeon_guardians"):
			if not dungeon.is_ancestor_of(guardian):
				continue
			guardian.set_physics_process(false)
			guardian.set_process(false)
			guardian.collision_layer = 0
			guardian.collision_mask = 0
			records.append({
				"slot": int(guardian.get_meta("encounter_slot", -1)),
				"hp": float(guardian.hp), "position": guardian.global_position,
				"damage": (6.0 + float(guardian.quality) * 2.1) * float(guardian.damage_multiplier)
			})
		var ledger = ENCOUNTER.new()
		ledger.configure(descriptor, records)
		host_encounters[run_id] = {"ledger": ledger, "instance": dungeon, "owned": owned}
	for stored_id in host_encounters.keys():
		if not active_ids.has(stored_id):
			var entry: Dictionary = host_encounters[stored_id]
			if bool(entry.get("owned", false)) and is_instance_valid(entry.get("instance", null)):
				entry["instance"].queue_free()
			host_encounters.erase(stored_id)

func _broadcast_encounter_states() -> void:
	for run_id in host_encounters.keys():
		_broadcast_encounter_state(int(run_id))

func _broadcast_encounter_state(run_id: int) -> void:
	if not multiplayer.is_server() or not host_encounters.has(run_id):
		return
	var state: Dictionary = host_encounters[run_id]["ledger"].snapshot()
	_apply_encounter_state(state)
	_receive_encounter_state.rpc(state)

@rpc("authority", "call_remote", "reliable")
func _receive_encounter_state(state: Dictionary) -> void:
	_apply_encounter_state(state)

func _apply_encounter_state(state: Dictionary) -> void:
	if run_preview == null or not is_instance_valid(run_preview):
		return
	if int(preview_descriptor.get("id", 0)) != int(state.get("run_id", -1)) or int(preview_descriptor.get("floor", 0)) != int(state.get("floor", -1)):
		return
	var current_revision: int = int(state.get("revision", -1))
	if current_revision <= preview_health_revision:
		return
	preview_health_revision = current_revision
	var hp_data: Dictionary = state.get("hp", {})
	var positions: Dictionary = state.get("positions", {})
	var health_snapshot: Dictionary = state.get("player_health", {})
	party_health = health_snapshot.duplicate(true)
	var self_id: int = multiplayer.get_unique_id()
	if health_snapshot.has(self_id):
		var new_hp: float = clampf(float(health_snapshot[self_id]), 0.0, 100.0)
		if new_hp < last_synced_health:
			game.hero.enter_combat()
		if new_hp <= 0.0 and last_synced_health > 0.0:
			game.hud.toast("Knocked out! Another party member can revive you.")
		elif new_hp > last_synced_health + 1.0 and last_synced_health <= 0.0:
			game.hud.toast("Revived! Return to the fight.")
		elif new_hp < last_synced_health - 0.5:
			game.hud.toast("Guardian struck! -%d HP" % int(ceilf(last_synced_health - new_hp)))
		last_synced_health = new_hp
		game.hero.health = new_hp
		game.hero.interaction_locked = new_hp <= 0.0
	for guardian in get_tree().get_nodes_in_group("dungeon_guardians"):
		if not run_preview.is_ancestor_of(guardian):
			continue
		var slot: int = int(guardian.get_meta("encounter_slot", -1))
		if positions.has(slot):
			var at: Vector3 = positions[slot]
			if at.is_finite():
				guardian.global_position = at
		if not hp_data.has(slot):
			continue
		var hp: float = maxf(0.0, float(hp_data[slot]))
		if hp <= 0.0 and guardian.alive:
			guardian.receive_damage(guardian.hp)
		elif guardian.alive:
			guardian.hp = hp
	private_run_changed.emit()

func _broadcast_snapshot() -> void:
	if not multiplayer.is_server() or not online():
		return
	var payload: Dictionary = players.duplicate(true)
	var snapshot: Dictionary = registry.snapshot()
	_apply_snapshot(payload, snapshot)
	_receive_snapshot.rpc(payload, snapshot)
	_broadcast_encounter_states()

@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(player_data: Dictionary, party_data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	_apply_snapshot(player_data, party_data)

func _apply_snapshot(player_data: Dictionary, party_data: Dictionary) -> void:
	roster = player_data.duplicate(true)
	party_snapshot = party_data.duplicate(true)
	_sync_preview()
	_sync_avatars()
	_sync_host_encounters()
	roster_changed.emit()
	session_changed.emit()

func _sync_preview() -> void:
	var descriptor: Dictionary = my_party().get("run", {})
	if descriptor.is_empty():
		_clear_preview()
		return
	var new_id: int = int(descriptor.get("id", 0))
	var new_floor: int = int(descriptor.get("floor", 1))
	if run_preview != null and is_instance_valid(run_preview) and int(preview_descriptor.get("id", 0)) == new_id and int(preview_descriptor.get("floor", 1)) == new_floor:
		return
	_clear_preview()
	# A local deterministic copy allows each peer to walk the same seeded rooms.
	# Enemy combat, damage, loot and final completion are intentionally disabled
	# until they can be governed by one authoritative encounter simulation.
	var dungeon = INSTANCE.new()
	dungeon.name = "PartyDungeonPreview"
	add_child(dungeon)
	dungeon.position = Vector3(0.0, 10.0, -800.0 - float(party_id()) * 700.0)
	dungeon.setup(str(descriptor.get("entrance_id", "")), int(descriptor.get("rarity", 0)), game.hero, new_floor)
	dungeon.stairs_selected.connect(_on_preview_exit_selected)
	dungeon.chest_selected.connect(_on_preview_exit_selected)
	for guardian in dungeon.get_tree().get_nodes_in_group("dungeon_guardians"):
		if dungeon.is_ancestor_of(guardian):
			guardian.set_physics_process(false)
			guardian.set_process(false)
			guardian.set_collision_layer(0)
			guardian.set_collision_mask(0)
	run_preview = dungeon
	preview_descriptor = descriptor.duplicate(true)
	preview_health_revision = -1
	party_health.clear()
	last_synced_health = 100.0
	if not has_return_point:
		return_position = game.hero.global_position
		return_health = game.hero.health
		has_return_point = true
	game.hero.health = 100.0
	game.hero.stop_interaction_move()
	game.hero.interaction_locked = false
	game.hud._reset_touch()
	game.hero.global_position = dungeon.hero_spawn_point()
	game.hero.velocity = Vector3.ZERO
	status_message = "Party %d — dungeon floor %d/%d (host-controlled guardians)" % [party_id(), new_floor, int(descriptor.get("floors", 1))]
	private_run_changed.emit()

func _on_preview_exit_selected(_instance: Node3D) -> void:
	if not is_party_leader():
		game.hud.toast("The party leader must open this dungeon exit.")
		return
	if not can_advance_preview():
		game.hud.toast("Defeat the guardians to unlock the exit.")
		return
	if int(preview_descriptor.get("floor", 1)) < int(preview_descriptor.get("floors", 1)):
		request_next_floor()
	else:
		request_complete_run()

func _clear_preview() -> void:
	if run_preview != null and is_instance_valid(run_preview):
		run_preview.queue_free()
	run_preview = null
	preview_descriptor.clear()
	preview_health_revision = -1
	party_health.clear()
	if has_return_point and game != null and game.hero != null:
		game.hero.health = return_health
		game.hero.global_position = return_position
		game.hero.velocity = Vector3.ZERO
		game.hero.interaction_locked = false
		game.hero.stop_interaction_move()
	has_return_point = false
	private_run_changed.emit()

func _process(delta: float) -> void:
	if not online() or game == null or game.hero == null:
		return
	tick_elapsed += delta
	if tick_elapsed < TICK:
		return
	var actual_tick: float = tick_elapsed
	tick_elapsed = 0.0
	var world_pos: Vector3 = game.hero.global_position
	if multiplayer.is_server():
		players[1]["position"] = world_pos
		players[1]["yaw"] = game.hero.visual.rotation.y
		_tick_host_encounters(actual_tick)
		_send_positions()
	else:
		_send_position.rpc_id(1, world_pos, game.hero.visual.rotation.y)
	_update_avatar_positions(delta)

@rpc("any_peer", "call_remote", "unreliable")
func _send_position(at: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender) or not at.is_finite() or not is_finite(yaw):
		return
	# Movement is reported by peers; the host validates encounter actions
	# but does not yet simulate player movement/anti-cheat.
	if at.length() > 10000.0:
		return
	players[sender]["position"] = at
	players[sender]["yaw"] = yaw

func _send_positions() -> void:
	if not multiplayer.is_server():
		return
	var payload: Dictionary = {}
	for id in players:
		payload[id] = {"position": players[id].get("position", Vector3.ZERO), "yaw": float(players[id].get("yaw", 0.0))}
	_receive_positions.rpc(payload)
	_apply_positions(payload)

@rpc("authority", "call_remote", "unreliable")
func _receive_positions(payload: Dictionary) -> void:
	_apply_positions(payload)

func _apply_positions(payload: Dictionary) -> void:
	for id in payload:
		if not roster.has(id):
			continue
		var info: Dictionary = payload[id]
		if not (info.get("position", null) is Vector3):
			continue
		roster[id]["position"] = info["position"]
		roster[id]["yaw"] = float(info.get("yaw", 0.0))
	_sync_avatars()

func _sync_avatars() -> void:
	if not online():
		return
	var local_id: int = multiplayer.get_unique_id()
	for id in remote_avatars.keys():
		if not roster.has(id) or int(id) == local_id:
			var avatar: Node3D = remote_avatars[id]
			avatar.queue_free()
			remote_avatars.erase(id)
	for id in roster:
		if int(id) == local_id:
			continue
		if not remote_avatars.has(id):
			remote_avatars[id] = _create_avatar(int(id), str(roster[id].get("name", "Friend")))
		var peer_party: int = _party_for_peer(int(id))
		var local_party: int = party_id()
		var both_overworld: bool = preview_descriptor.is_empty() and _run_for_party(peer_party).is_empty()
		var both_preview: bool = not preview_descriptor.is_empty() and int(preview_descriptor.get("party_id", 0)) == peer_party
		remote_avatars[id].visible = local_party != 0 and local_party == peer_party and (both_overworld or both_preview)

func _party_for_peer(peer_id: int) -> int:
	for entry in party_snapshot.get("parties", []):
		if peer_id in entry.get("members", []):
			return int(entry.get("id", 0))
	return 0

func _run_for_party(id: int) -> Dictionary:
	for entry in party_snapshot.get("parties", []):
		if int(entry.get("id", 0)) == id:
			return entry.get("run", {})
	return {}

func _create_avatar(peer_id: int, peer_name: String) -> Node3D:
	var actor := Node3D.new()
	actor.name = "Remote_%d" % peer_id
	add_child(actor)
	var body: MeshInstance3D
	var head: MeshInstance3D
	if bool(game.get("voxel_art_enabled")):
		body = VOXEL_CHARACTER.create_part("adventurer_torso")
		head = VOXEL_CHARACTER.create_part("adventurer_head")
	else:
		body = MeshInstance3D.new()
		body.mesh = load("res://assets/models/adventurer_torso.obj") as Mesh
		body.material_override = _avatar_material(Color("78a0bd"))
		head = MeshInstance3D.new()
		head.mesh = load("res://assets/models/adventurer_head.obj") as Mesh
	actor.add_child(body)
	head.position = Vector3(0, 1.89, 0)
	actor.add_child(head)
	var plate := Label3D.new()
	plate.text = peer_name
	plate.position = Vector3(0, 2.5, 0)
	plate.font_size = 44
	plate.pixel_size = 0.007
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.add_child(plate)
	return actor

func _avatar_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _update_avatar_positions(_delta: float) -> void:
	for id in remote_avatars:
		if not roster.has(id):
			continue
		var info: Dictionary = roster[id]
		var destination: Vector3 = info.get("position", Vector3.ZERO)
		var avatar: Node3D = remote_avatars[id]
		if avatar.global_position.distance_to(destination) > 28.0:
			avatar.global_position = destination
		else:
			avatar.global_position = avatar.global_position.lerp(destination, 0.45)
		avatar.rotation.y = float(info.get("yaw", 0.0))

func _clear_avatars() -> void:
	for actor in remote_avatars.values():
		if is_instance_valid(actor):
			actor.queue_free()
	remote_avatars.clear()

func local_ips() -> Array[String]:
	var found: Array[String] = []
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172.16.") or addr.begins_with("172.17.") or addr.begins_with("172.18.") or addr.begins_with("172.19."):
			found.append(addr)
	return found
