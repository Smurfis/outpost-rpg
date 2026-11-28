extends "res://scripts/interaction/world_object.gd"
## This container is owned by a worker's persistent stock, not the one-shot
## opened_world_objects map. Empty boxes disappear; later deposits rebuild them.
var work_id := ""
func remaining() -> Dictionary:
	if work_id.is_empty(): return super.remaining()
	return game.village_work.get(work_id,{}).get("stock",{}).duplicate()

func interact(_hero: Node3D) -> void:
	if not game.target_in_range(self): return
	var pending := remaining()
	var received := 0
	for id in pending.keys():
		var count: int = game.grant_item(id,int(pending[id]))
		received+=count
		pending[id]=int(pending[id])-count
		if int(pending[id])<=0: pending.erase(id)
	if work_id.is_empty():
		game.opened_world_objects[object_id]=pending
	else:
		game.village_work[work_id]["stock"]=pending
	game._save()
	game.hud.toast("Collected %d items." % received if received>0 else "Bag full. Contents remain here." if not pending.is_empty() else "Empty.")
	if pending.is_empty():
		hide()
		remove_from_group("world_interactables")
		for child in get_children():
			if child is Area3D: child.set_deferred("collision_layer",0)
		queue_free()
