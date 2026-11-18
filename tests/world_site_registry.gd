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
	print("WORLD SITE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
