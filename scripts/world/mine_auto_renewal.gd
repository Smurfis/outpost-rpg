extends RefCounted
## Gameplay-time scheduler for the existing physical mine transaction.
## The registry and mine_renewal.gd remain the only progression publishers.
const REGISTRY = preload("res://scripts/dungeons/world_site_registry.gd")
const RENEWAL = preload("res://scripts/world/mine_renewal.gd")
const DEFAULT_RENEWAL_SECONDS := 180
const ENTRANCE_CLEARANCE := 16.0
var accumulator := 0.0
var pending_ms := 0

func tick(island, game, delta: float) -> void:
	accumulator += maxf(0.0, minf(delta, 1.0))
	if accumulator < 1.0:
		return
	var seconds := floori(accumulator)
	accumulator -= seconds
	if island.mine == null or Engine.is_in_physics_frame():
		return
	var mine = island.mine
	var manager = mine.manager
	if manager == null or not manager.world_site_save_valid or not manager.world_sites.sites.has(mine.site_id):
		return
	var site: Dictionary = manager.world_sites.sites[mine.site_id]
	if site.state == "cleared":
		if not _safe(island, game):
			return
		if not mine.trigger_reoccupation_for_test():
			return
		_set_timer(manager, site, _duration_ms())
		game.hud.toast("The cleared mine entrance has been sealed.")
		return
	if site.state == "sealed":
		if not site.has("auto_renew_remaining_ms"):
			_set_timer(manager, site, _duration_ms())
			return
		var remaining: int = int(site.auto_renew_remaining_ms)
		if remaining > 0:
			pending_ms += seconds * 1000
			# Persist in five-second batches; a crash can only delay renewal by
			# the unflushed gameplay time, never advance it prematurely.
			if pending_ms >= mini(5000, remaining):
				if _set_timer(manager, site, maxi(0, remaining - pending_ms)):
					pending_ms = 0
			return
		pending_ms = 0
		if not _safe(island, game):
			return
		if mine.advance_for_test("ready_for_renewal"):
			game.hud.toast("Unusual activity stirs beneath the sealed mine.")
		return
	if site.state == "ready_for_renewal" and _safe(island, game):
		var result: String = RENEWAL.advance(island, game)
		if result == "open":
			game.hud.toast("The Goblin Mine is ready for another expedition.")

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

func _safe(island, game) -> bool:
	var mine = island.mine
	if mine == null or game.hero == null or not game.player_save_valid_for_mine and not game.mine_started_without_saves:
		return false
	if game.coop != null and game.coop.mode != "solo":
		return false
	if game.controls.navigating or game.hero.interaction_moving or game.station_walk_target != "" or game.controls.modal_open() or is_instance_valid(game.controls.target):
		return false
	if game.hero.velocity.length_squared() > 0.01:
		return false
	var entrance: Vector3 = mine.entrance
	for actor in [game.hero] + game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(actor):
			continue
		var pos: Vector3 = actor.global_position
		if not mine.access.clear_of_player(pos):
			return false
		if Vector2(pos.x - entrance.x, pos.z - entrance.z).length() < ENTRANCE_CLEARANCE:
			return false
	return true
