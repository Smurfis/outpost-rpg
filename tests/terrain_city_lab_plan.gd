extends SceneTree
const Plan = preload("res://scripts/world/terrain_city_lab_plan.gd")
func _initialize() -> void:
	var failures := 0
	for seed_value in [64012,64013,64014,42,-5]:
		var first := Plan.new()
		var second := Plan.new()
		if not first.generate(seed_value) or not second.generate(seed_value):
			push_error("City route validation failed: %d" % seed_value)
			failures += 1
			continue
		if first.blocks != second.blocks or first.districts != second.districts:
			push_error("Non-deterministic city: %d" % seed_value)
			failures += 1
		for p in first.districts:
			for d in Plan.DIRS:
				if first.districts.has(p+d) and not first._compatible(first.districts[p],first.districts[p+d]):
					failures += 1
		if first.rooms.size() < 2:
			failures += 1
	print("CITY LAB RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
