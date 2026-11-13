extends Control
var map: Node
var hits: Array[Dictionary] = []

static func glyph(canvas: CanvasItem, at: Vector2, disposition: String, player: bool = false, angle: float = 0.0) -> void:
	var tint := Color("ffe5a1") if player else Color("76c85c") if disposition == "passive" else Color("f0c65e") if disposition == "neutral" else Color("df6257")
	canvas.draw_rect(Rect2(at - Vector2(7,7), Vector2(14,14)), Color("172022"))
	if player or disposition == "passive":
		canvas.draw_rect(Rect2(at - Vector2(7,7), Vector2(14,14)), tint, false, 2)
	if player:
		canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0,-5).rotated(angle), at + Vector2(-4,4).rotated(angle), at + Vector2(4,4).rotated(angle)]), tint)
	elif disposition == "hostile":
		canvas.draw_polyline(PackedVector2Array([at+Vector2(0,-6),at+Vector2(6,5),at+Vector2(-6,5),at+Vector2(0,-6)]), tint, 2)
	elif disposition == "neutral":
		canvas.draw_polyline(PackedVector2Array([at+Vector2(0,-6),at+Vector2(6,0),at+Vector2(0,6),at+Vector2(-6,0),at+Vector2(0,-6)]), tint, 2)

func _draw_island_circles() -> void:
	if not map.show_island_circles or not map.has_remote_islands:
		return
	var remote: Variant = map.service.biome.archipelago
	if remote == null or remote.terrain == null:
		return
	# Project the *real* procedural island footprint onto the tilted
	# Diorama map. These are debugging rings, not fog-of-war discovery.
	var bounds: Rect2 = Rect2(Vector2.ZERO, size).grow(96.0)
	for i in range(remote.terrain.islands.size()):
		var island: Dictionary = remote.terrain.islands[i]
		var origin: Vector2i = island["center"]
		var radius: float = float(island["radius"]) + 3.0
		var centre: Vector2 = map.project(Vector3(float(origin.x), -2.0, float(origin.y)))
		if not bounds.has_point(centre):
			continue
		var ring := PackedVector2Array()
		for segment in range(49):
			var angle: float = TAU * float(segment) / 48.0
			var at := Vector3(float(origin.x) + cos(angle) * radius,
				-2.0, float(origin.y) + sin(angle) * radius)
			ring.append(map.project(at))
		draw_polyline(ring, Color("80909d", 0.92), 2.5, true)
		draw_circle(centre, 4.0, Color("e6c88b"))
		draw_string(ThemeDB.fallback_font, centre + Vector2(10.0, -7.0),
			"ISLAND %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e6c88b"))

func _draw() -> void:
	if map == null or not map.is_open():
		return
	hits.clear()
	_draw_island_circles()
	var service: Node = map.service
	var hero: Node3D = map.game.hero
	var hero_at: Vector2 = map.project(hero.global_position)
	var occupied: Dictionary = {}
	occupied[Vector2i(hero_at / 20.0)] = true
	for record in service.markers(map.view_span < 90):
		var at: Vector2 = map.project(record.position)
		if not Rect2(Vector2.ZERO, size).has_point(at):
			continue
		if record.get("category", "") == "zones":
			if map.view_span > 65:
				draw_string(ThemeDB.fallback_font, at, record.label, HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color("e0d4a1"))
			continue
		var slot := Vector2i(at / 20.0)
		if occupied.has(slot):
			continue
		occupied[slot] = true
		if record.has("disposition"):
			glyph(self, at, record.disposition)
		else:
			var tint := Color("65cde0") if record.category == "resources" else Color("e5bb71")
			if record.category == "portals":
				tint = service.RARITY.color(int(record.get("quality", 0)))
				draw_arc(at, 7, 0, TAU, 8, tint, 2)
			else:
				draw_rect(Rect2(at - Vector2(4,4), Vector2(8,8)), tint)
		hits.append({"at": at, "record": record})
		if hits.size() >= 128:
			break
	if Rect2(Vector2.ZERO, size).has_point(hero_at):
		var forward: Vector3 = -hero.visual.global_basis.z
		var heading: Vector2 = map.project(hero.global_position + forward) - hero_at
		glyph(self, hero_at, "", true, heading.angle() + PI * 0.5)

func inspect(at: Vector2) -> Dictionary:
	for hit in hits:
		if at.distance_to(hit.at) <= 14:
			return hit.record
	return {}
