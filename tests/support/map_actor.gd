extends Node3D
var disposition: String = "passive"
var dimension: String = "overworld"
var alive: bool = true

func map_record() -> Dictionary:
	return {"id": "fixture", "position": global_position, "category": "creature", "label": "Test creature", "dimension": dimension, "alive": alive, "visible_on_radar": visible, "disposition": disposition}
