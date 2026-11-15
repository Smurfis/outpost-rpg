extends Node3D
## Small shared contract for chests, loose loot, NPCs and inspectable props.
const PICKER = preload("res://scripts/interaction/world_picker.gd")
var game
var object_id: String = ""
var title: String = ""
var action_kind: String = "inspect"
var contents: Dictionary = {}
var message: String = ""

func setup(ref: Node, id: String, label: String, kind: String, art: Node3D, loot: Dictionary = {}) -> void:
	game = ref
	object_id = id
	title = label
	action_kind = kind
	contents = loot.duplicate()
	add_child(art)
	set_meta("display_name", title)
	set_meta("world_action", "Open" if kind == "chest" else "Collect" if kind == "loot" else "Talk" if kind == "npc" else "Inspect")
	PICKER.attach(self, kind)

func inspection_text() -> String:
	return "%s\n%s%s" % [title, get_meta("world_action"), " · Empty" if action_kind in ["chest", "loot"] and remaining().is_empty() else ""]

func remaining() -> Dictionary:
	return game.opened_world_objects.get(object_id, contents).duplicate()

func interact(_hero: Node3D) -> void:
	# Controller and mobile context both enter here only after range validation.
	if not game.target_in_range(self):
		return
	if action_kind in ["chest", "loot"]:
		var pending: Dictionary = remaining()
		var received: int = 0
		for id in pending.keys():
			var amount: int = game.grant_item(id, int(pending[id]))
			pending[id] = int(pending[id]) - amount
			received += amount
			if int(pending[id]) == 0:
				pending.erase(id)
		game.opened_world_objects[object_id] = pending
		game._save()
		game.hud.toast("Collected %d items." % received if received > 0 else "Empty." if pending.is_empty() else "Bag full. Contents remain here.")
		if action_kind == "loot" and pending.is_empty():
			hide()
	else:
		game.hud.toast(message if not message.is_empty() else title)
