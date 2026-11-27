extends SceneTree
const Sector = preload("res://scripts/world/city_lab_dungeon_sector.gd")
const Dungeon = preload("res://scripts/world/city_lab_dungeon_connectors.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var sector := Sector.new()
	for seed_value in [42,64012,-7]:
		for address in [[0,0],[1,0],[-1,-1],[1000000000000,-1000000000000]]:
			if not sector.generate(seed_value,address[0],address[1]):
				check(false,"Sector generation failed")
				continue
			var first := sector.solver.modules.duplicate(true)
			var links := sector.solver.links.duplicate(true)
			var voxels := sector.materialize()
			check(first.size()==25 and sector.solver.validate(),"Sector graph disconnected")
			# Validate actual walkable paths from center to all four external gateways.
			var walk: Dictionary = {}
			for p: Vector2i in first:
				var reachable := sector.solver._reachable(sector.solver.materialize(p))
				for cell: Vector2i in reachable: walk[p*Dungeon.SIDE+cell] = true
			var grid := AStarGrid2D.new()
			grid.region = Rect2i(0,0,Sector.SIDE,Sector.SIDE)
			grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
			grid.update()
			for z in range(Sector.SIDE):
				for x in range(Sector.SIDE):
					var p := Vector2i(x,z)
					if not walk.has(p): grid.set_point_solid(p,true)
			for d in range(4):
				var gate := sector.gate_cell(d)
				check(not grid.get_id_path(Vector2i(37,37),gate).is_empty(),"Unreachable sector gate")
				var neighbor := Sector.new()
				var dir: Vector2i = Sector.DIRS[d]
				if not neighbor.generate(seed_value,address[0]+dir.x,address[1]+dir.y):
					check(false,"Neighbor generation failed")
					continue
				var opposite: int = (d+2)%4
				var dest := neighbor.gate_cell(opposite)
				check(gate.x == dest.x if d%2==0 else gate.y==dest.y,"Shared gate misaligned")
				var other := neighbor.solver.materialize(neighbor.gate(opposite))
				check(neighbor.solver._clear(other,neighbor.solver._edge(opposite)),"Neighbor gate blocked")
			check(sector.generate(seed_value,address[0],address[1]) and first==sector.solver.modules and links==sector.solver.links and voxels==sector.materialize(),"Sector depends on generation order")
	print("SECTOR LAB RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)
