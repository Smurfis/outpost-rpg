extends RefCounted
## Optional deterministic overlay, installed before the first streamed chunk.
## Only extend empty columns whose current ground already supplies a roof.
var center: Vector2i
var junction: Vector2i
var branch := {}
var room := {}

func install(terrain) -> bool:
	var route: Array = terrain.caves.routes[0]
	for index in range(route.size()-10, 7, -1):
		var at: Vector3i = route[index]
		for side in [-1,1]:
			var direction := Vector2i(0,side)
			junction = Vector2i(at.x,at.z + (1 if side == 1 else 0))
			center = junction + direction * 7
			branch.clear()
			room.clear()
			for step in range(1,5):
				branch[junction + direction*step] = at.y
			for x in range(-2,3):
				for z in range(-2,3):
					room[center+Vector2i(x,z)] = at.y
			var extra := branch.duplicate()
			extra.merge(room)
			var ok := true
			for c: Vector2i in extra:
				if terrain.caves.floors.has(c) or terrain.height_at(c.x,c.y) < at.y+4:
					ok = false
					break
			if ok:
				terrain.caves.floors.merge(extra)
				return true
	return false
