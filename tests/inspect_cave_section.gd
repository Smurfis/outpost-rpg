extends SceneTree
## Print a vertical slice. A = physical cave air, H = hidden solid,
## F = retained solid touching a hidden neighbour (new face), # = other solid.
const DATA = preload("res://scripts/world/fractal_archipelago_data.gd")

func _initialize() -> void:
	OS.set_environment("OUTPOST_TEST_SIDE_CHAMBER","1")
	var island = preload("res://scripts/world/island_archipelago.gd").new()
	island.setup(64012)
	var terrain = island.terrain
	var route: Array = terrain.caves.routes[0]
	var end: Vector3i = route.back()
	island._identify_regions(Vector2i(end.x,end.z))
	for cell: Vector2i in [Vector2i(route[0].x,route[0].z),island.side_chamber.junction,island.side_chamber.center,Vector2i(end.x,end.z)]:
		var floor_y: int = terrain.caves.floor_at(cell.x,cell.y)
		var variant := Dictionary(island._variant(island._owners[cell],2))
		var hidden: Dictionary = variant.hidden
		print("cell=",cell," floor=",floor_y," surface=",terrain.height_at(cell.x,cell.y)," roof=",terrain.is_solid(cell.x,floor_y+3,cell.y)," footing=",terrain.is_solid(cell.x,floor_y-1,cell.y)," hidden columns=",hidden.size())
		for y in range(17,floor_y-2,-1):
			var line := ""
			for z in range(cell.y-6,cell.y+18):
				var v := Vector3i(cell.x,y,z)
				if is_hidden(hidden,v): line += "H"
				elif terrain.is_solid(v.x,y,z):
					var cut := false
					for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.BACK,Vector3i.FORWARD]:
						cut = cut or is_hidden(hidden,v+d)
					line += "F" if cut else "#"
				elif terrain.caves.has_cave(v.x,z) and y < terrain.height_at(v.x,z): line += "A"
				else: line += "."
			print("%3d " % y,line)
	island.free()
	quit()

func is_hidden(columns: Dictionary, v: Vector3i) -> bool:
	return v.y >= DATA.BEDROCK and bool(int(columns.get(Vector2i(v.x,v.z),0)) & (1 << (v.y-DATA.BEDROCK)))
