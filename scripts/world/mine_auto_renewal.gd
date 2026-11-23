extends RefCounted
## Gameplay-time scheduler for the existing physical mine transaction.
## The registry and mine_renewal.gd remain the only progression publishers.
const REGISTRY = preload("res://scripts/dungeons/world_site_registry.gd")
const RENEWAL = preload("res://scripts/world/mine_renewal.gd")
const DEFAULT_RENEWAL_SECONDS := 180
const ENTRANCE_CLEARANCE := 10.0
var accumulator := 0.0
var pending_ms := 0
var check_count := 0
var last_check_ms := 0
var last_result := "waiting for first check"

func tick(island, game, delta: float) -> void:
	accumulator += maxf(0.0, minf(delta, 1.0))
	if accumulator < 1.0:
		return
	var seconds := floori(accumulator)
	accumulator -= seconds
	check_count += 1
	last_check_ms = Time.get_ticks_msec()
	if island.mine == null or Engine.is_in_physics_frame():
		last_result = "mine unavailable or physics update in progress"
		return
	var mine = island.mine
	var manager = mine.manager
	if manager == null or not manager.world_site_save_valid or not manager.world_sites.sites.has(mine.site_id):
		last_result = "site save unavailable"
		return
	var site: Dictionary = manager.world_sites.sites[mine.site_id]
	if site.state == "cleared":
		last_result = _seal_blocker(island, game, site)
		if last_result != "":
			return
		if not mine.trigger_reoccupation_for_test():
			last_result = "seal transition rejected"
			return
		if not _set_timer(manager, site, _duration_ms()):
			last_result = "sealed; timer save deferred"
		else:
			last_result = "sealed; countdown started"
		game.hud.toast("The cleared mine entrance has been sealed.")
		return
	if site.state == "sealed":
		if not site.has("auto_renew_remaining_ms"):
			last_result = "initializing sealed countdown" if _set_timer(manager, site, _duration_ms()) else "timer save failed"
			return
		var remaining: int = int(site.auto_renew_remaining_ms)
		if remaining > 0:
			last_result = "sealed countdown"
			pending_ms += seconds * 1000
			# Persist in five-second batches; a crash can only delay renewal by
			# the unflushed gameplay time, never advance it prematurely.
			if pending_ms >= mini(5000, remaining):
				if _set_timer(manager, site, maxi(0, remaining - pending_ms)):
					pending_ms = 0
			return
		pending_ms = 0
		last_result = _physical_blocker(island, game)
		if last_result != "":
			return
		if mine.advance_for_test("ready_for_renewal"):
			last_result = "ready for renewal"
			game.hud.toast("Unusual activity stirs beneath the sealed mine.")
		else:
			last_result = "ready transition rejected"
		return
	if site.state == "ready_for_renewal":
		last_result = _physical_blocker(island, game)
		if last_result != "":
			return
		var result: String = RENEWAL.advance(island, game)
		last_result = result
		if result == "open":
			game.hud.toast("The Goblin Mine is ready for another expedition.")
	else:
		last_result = "waiting for encounter completion"

func _duration_ms() -> int:
	var override := OS.get_environment("OUTPOST_TEST_MINE_RENEWAL_SECONDS")
	if override.is_valid_int() and int(override) >= 1 and int(override) <= 3600:
		return int(override) * 1000
	return DEFAULT_RENEWAL_SECONDS * 1000

func _set_timer(manager, site: Dictionary, remaining: int) -> bool:
	var previous: Variant = site.get("auto_renew_remaining_ms")
	site.auto_renew_remaining_ms = remaining
	if not manager._save_clears():
		if previous == null:
			site.erase("auto_renew_remaining_ms")
		else:
			site.auto_renew_remaining_ms = previous
		return false
	return true

func _seal_blocker(island, game, site: Dictionary) -> String:
	for guard in REGISTRY.GUARDS:
		if site.room_state.get(guard) != true:
			return "required goblin alive: " + guard
	if site.reward_claims.get(REGISTRY.treasure_receipt(site)) != true:
		return "strongbox reward unclaimed"
	return _physical_blocker(island, game)

func _physical_blocker(island, game) -> String:
	var mine = island.mine
	if mine == null or game.hero == null:
		return "mine or player unavailable"
	if not game.player_save_valid_for_mine and not game.mine_started_without_saves:
		return "player save invalid for mine renewal"
	if mine.manager == null or not mine.manager.world_site_save_valid:
		return "site save invalid"
	if game.coop != null and game.coop.mode != "solo":
		return "multiplayer session active"
	if mine.manager.active_instance != null:
		return "another dungeon active"
	if game.controls.navigating or game.hero.interaction_moving or game.station_walk_target != "":
		return "movement route pending"
	if game.controls.modal_open():
		return "interface open"
	# CharacterBody3D applies a small downward floor-hugging velocity even
	# while idle. Horizontal motion is what can carry an actor into the site.
	var horizontal := Vector2(game.hero.velocity.x, game.hero.velocity.z)
	if horizontal.length_squared() > 0.0025:
		return "player still moving"
	var entrance: Vector3 = mine.entrance
	if not mine.access.clear_of_player(game.hero.global_position):
		return "player inside mine footprint"
	var hero_at: Vector3 = game.hero.global_position
	if Vector2(hero_at.x - entrance.x, hero_at.z - entrance.z).length() < ENTRANCE_CLEARANCE:
		return "player within entrance clearance"
	for actor in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		var pos: Vector3 = actor.global_position
		if not mine.access.clear_of_player(pos):
			return "actor inside mine footprint: " + str(actor.name)
		if Vector2(pos.x - entrance.x, pos.z - entrance.z).length() < 2.0 and absf(pos.y - entrance.y) < 4.0:
			return "actor at mine entrance: " + str(actor.name)
	return ""

func status(island, game) -> String:
	if island.mine == null or island.mine.manager == null:
		return "Mine unavailable; scheduler checks %d" % check_count
	var site: Dictionary = island.mine.manager.world_sites.sites.get(island.mine.site_id, {})
	if site.is_empty():
		return "Mine site not registered; scheduler checks %d" % check_count
	var age := "never" if check_count == 0 else "%.1fs ago" % (float(Time.get_ticks_msec() - last_check_ms) / 1000.0)
	var remaining := "not started" if not site.has("auto_renew_remaining_ms") else "%.1fs" % (float(site.auto_renew_remaining_ms) / 1000.0)
	var journal: String = site.get("renewal", {}).get("phase", "none")
	if site.get("renewal_committed", false):
		journal = "committed"
	var blocker: String = _seal_blocker(island, game, site) if site.state == "cleared" else _physical_blocker(island, game)
	if site.state == "sealed" and int(site.get("auto_renew_remaining_ms", _duration_ms())) > 0:
		blocker = "sealed countdown"
	if site.state == "ready_for_renewal" and blocker == "" and last_result not in ["ready for renewal", "waiting for encounter completion"]:
		blocker = last_result
	if blocker == "":
		blocker = "none"
	var missing := []
	for guard in REGISTRY.GUARDS:
		if site.room_state.get(guard) != true:
			missing.append(guard)
	if site.reward_claims.get(REGISTRY.treasure_receipt(site)) != true:
		missing.append("strongbox")
	return "cycle %d %s | timer %s | scheduler %d checks, last %s | blocked: %s | objectives: %s | transaction: %s" % [int(site.cycle), site.state, remaining, check_count, age, blocker, ", ".join(missing) if not missing.is_empty() else "complete", journal]
