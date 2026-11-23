extends SceneTree
const REGISTRY = preload("res://scripts/dungeons/world_site_registry.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	if ok:
		print("PASS WORLD SITE: " + detail)
	else:
		failures += 1
		push_error("FAIL WORLD SITE: " + detail)

func run() -> void:
	var registry = REGISTRY.new()
	check(registry.register_site("iron_mine", 64012, Vector3i(180, 4, 62), ["15:5", "14:5"]), "Stable site and owned chunks register")
	check(not registry.register_site("iron_mine", 64012, Vector3i.ZERO, ["0:0"]), "Duplicate site cannot replace the anchor")
	check(registry.transition("iron_mine", "discovered") and registry.transition("iron_mine", "active"), "Discovery and entry follow the lifecycle")
	check(registry.claim_reward("iron_mine", "chest", "solo") and not registry.claim_reward("iron_mine", "chest", "solo"), "Reward receipt is idempotent within a cycle")
	var snapshot: Variant = JSON.parse_string(JSON.stringify(registry.export_state()))
	var restored = REGISTRY.new()
	check(restored.import_state(snapshot), "Versioned site state survives JSON reload")
	check(not restored.claim_reward("iron_mine", "chest", "solo"), "Reload preserves claimed receipts")
	check(restored.sites.iron_mine.layout_seed == registry.sites.iron_mine.layout_seed, "Current cycle seed remains stable")
	check(REGISTRY.cycle_seed(64012, "iron_mine", 0, "initial") != REGISTRY.cycle_seed(64012, "iron_mine", 1, "initial"), "New cycle has a different deterministic seed")
	check(restored.transition("iron_mine", "cleared") and restored.transition("iron_mine", "aftermath") and restored.transition("iron_mine", "dormant"), "Cleared site enters dormancy")
	restored.sites.iron_mine.next_reset_at = 100
	var gates := {}
	for key in REGISTRY.SAFE_FLAGS:
		gates[key] = true
	check(not restored.can_regenerate("iron_mine", 99, gates), "Cooldown blocks regeneration")
	check(restored.can_regenerate("iron_mine", 100, gates), "All authoritative gates and cooldown are required")
	for key in REGISTRY.SAFE_FLAGS:
		gates[key] = false
		check(not restored.can_regenerate("iron_mine", 100, gates), "Unsafe gate blocks regeneration: " + key)
		gates[key] = true
	gates.erase("no_players_nearby")
	check(not restored.can_regenerate("iron_mine", 100, gates), "Missing host evidence fails closed")
	check(not restored.import_state({"schema": 99, "sites": {}}) and restored.sites.has("iron_mine"), "Unknown schema cannot erase existing state")
	check_mine_lifecycle()
	print("WORLD SITE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func check_mine_lifecycle() -> void:
	var registry = REGISTRY.new()
	var id := "fractal_physical_goblin_mine_1_64013"
	registry.register_site(id, 64013, Vector3i(192, 3, 62), ["island_192_60"], REGISTRY.MINE)
	registry.transition(id, "discovered")
	registry.transition(id, "active")
	check(not registry.transition(id, "cleared"), "Physical clear requires both objectives")
	check(not registry.record_mine_defeat(id, "stranger"), "Unknown encounter rejected")
	registry.record_mine_defeat(id, "miner")
	var legacy: Dictionary = registry.export_state()
	legacy.schema = 1
	legacy.sites[id].erase("kind")
	var restored = REGISTRY.new()
	check(restored.import_state(JSON.parse_string(JSON.stringify(legacy))), "Physical schema-one migration")
	check(restored.sites[id].kind == REGISTRY.MINE and not restored.record_mine_defeat(id, "miner"), "Migrated defeat is idempotent")
	check(restored.record_mine_defeat(id, "foreman") and restored.sites[id].state == "cleared", "Final objective clears physical site")
	check(not restored.advance_mine(id, "sealed", true), "Claim strongbox before sealing")
	check(restored.claim_reward(id, "treasure", "player"), "Claim physical treasure")
	check(not restored.advance_mine(id, "sealed", false), "Occupancy veto")
	check(not restored.transition(id, "aftermath") and not restored.transition(id, "sealed"), "Generic transitions cannot bypass sealing checks")
	var receipts: Dictionary = restored.sites[id].reward_claims.duplicate()
	var layout: int = restored.sites[id].layout_seed
	for stage in ["sealed", "ready_for_renewal"]:
		check(restored.advance_mine(id, stage, true), "Advance to " + stage)
		if stage == "sealed":
			restored.sites[id].auto_renew_remaining_ms = 1000
		var encoded: Variant = JSON.parse_string(JSON.stringify(restored.export_state()))
		check(restored.import_state(encoded) and restored.sites[id].state == stage and restored.sites[id].get("auto_renew_remaining_ms") == 1000, "Reload " + stage)
		check(not restored.record_mine_defeat(id, "miner") and not restored.claim_reward(id, "treasure", "player"), "Closed site rejects new progression")
	check(restored.sites[id].reward_claims == receipts and restored.sites[id].layout_seed == layout and restored.sites[id].cycle == 0, "Renewal eligibility preserves current cycle")
	var gates := {}
	for flag in REGISTRY.SAFE_FLAGS:
		gates[flag] = true
	var plan: Dictionary = restored.renewal_proposal(id, 0, gates)
	check(plan.get("layout_seed") == REGISTRY.cycle_seed(64013, id, 1, "initial") and plan.get("from_cycle") == 0, "Read-only deterministic next cycle")
	gates.erase("no_protected_builds")
	check(restored.renewal_proposal(id, 0, gates).is_empty(), "No renewal proposal without protection evidence")
	var corrupt: Dictionary = restored.export_state()
	for invalid in [-1, 1.5, 3600001]:
		corrupt = restored.export_state()
		corrupt.sites[id].auto_renew_remaining_ms = invalid
		check(not restored.import_state(corrupt), "Invalid mine timer rejected " + str(invalid))
	corrupt = restored.export_state()
	corrupt.sites[id].reward_claims.clear()
	check(not restored.import_state(corrupt) and restored.sites[id].reward_claims == receipts, "Invalid closed record leaves loaded state intact")
