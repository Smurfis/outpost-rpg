extends "res://scripts/interaction/world_object.gd"
var mine

func reconcile() -> void:
	# Item delivery and the remaining contents share the player save. Repair
	# a missing registry receipt if the game stopped between the two writes.
	if game.opened_world_objects.has(object_id) and remaining().is_empty():
		if mine.manager.world_sites.claim_reward(mine.site_id,"treasure","player"):
			mine.manager._save_clears()

func interact(player: Node3D) -> void:
	if not game.target_in_range(self):
		return
	var site: Dictionary = mine.manager.world_sites.sites[mine.site_id]
	if site.state != "cleared":
		game.hud.toast("Defeat the mine guards to open the strongbox.")
		return
	if site.reward_claims.has("0:treasure:player"):
		game.hud.toast("Empty.")
		return
	super.interact(player)
	reconcile()
