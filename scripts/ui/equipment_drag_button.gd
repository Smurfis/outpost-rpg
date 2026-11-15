extends Button
## Reusable drag-to-equip control. Player-owned items are dragged from the
## character bag onto compatible equipment slots. Tap-to-inspect remains live.
var item_id: String = ""
var target_slot: String = ""
var game_ref
var on_item_dropped: Callable

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or game_ref == null or int(game_ref.inventory.get(item_id, 0)) < 1:
		return null
	if str(game_ref.equipment_slot(item_id)) == "":
		return null
	var preview := PanelContainer.new()
	var text := Label.new()
	text.text = item_id.replace("_", " ").capitalize()
	text.add_theme_font_size_override("font_size", 15)
	preview.add_child(text)
	set_drag_preview(preview)
	return {"source": "outpost_character_inventory", "item_id": item_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if target_slot.is_empty() or game_ref == null or not data is Dictionary:
		return false
	var payload: Dictionary = data as Dictionary
	if str(payload.get("source", "")) != "outpost_character_inventory":
		return false
	var incoming: String = str(payload.get("item_id", ""))
	return not incoming.is_empty() and int(game_ref.inventory.get(incoming, 0)) > 0 and str(game_ref.equipment_slot(incoming)) == target_slot

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	if on_item_dropped.is_valid():
		on_item_dropped.call(str((data as Dictionary).get("item_id", "")))
