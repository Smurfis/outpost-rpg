extends CanvasLayer
## Host-side join request popup. No permanent co-op HUD button required.
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
var session: Node
var _backdrop: ColorRect
var _frame: PanelContainer
var _heading: Label
var _current_id: int = 0
var _pending: Array[Dictionary] = []

func setup(session_ref: Node) -> void:
	session = session_ref

func _ready() -> void:
	layer = 35
	var root_ui := Control.new()
	root_ui.name = "JoinRequestSurface"
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_ui)
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.03, 0.02, 0.05, 0.46)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(_backdrop)
	_frame = PanelContainer.new()
	_frame.name = "JoinApprovalPanel"
	_frame.add_theme_stylebox_override("panel", SKIN.box("frame"))
	_frame.custom_minimum_size = Vector2(490, 235)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_frame.position = Vector2(-245, -118)
	_frame.size = Vector2(490, 235)
	root_ui.add_child(_frame)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 19)
	_frame.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	_heading = Label.new()
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.add_theme_font_size_override("font_size", 25)
	_heading.add_theme_color_override("font_color", Color("fff0cd"))
	layout.add_child(_heading)
	var detail := Label.new()
	detail.text = "Allow this adventurer into your LAN outpost?"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_color_override("font_color", Color("e3cba0"))
	layout.add_child(detail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	layout.add_child(row)
	for caption in ["DECLINE", "ALLOW JOIN"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(200, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SKIN.apply_button(button, "red" if caption == "DECLINE" else "green")
		button.pressed.connect(_reject if caption == "DECLINE" else _accept)
		row.add_child(button)
	_backdrop.visible = false
	_frame.visible = false
	if session != null:
		session.join_approval_requested.connect(_on_request)

func _on_request(peer_id: int, nickname: String) -> void:
	_pending.append({"id": peer_id, "name": nickname})
	_show_next()

func _show_next() -> void:
	if _current_id != 0 or _pending.is_empty():
		return
	var request: Dictionary = _pending.pop_front()
	_current_id = int(request["id"])
	_heading.text = "%s wants to join!" % str(request["name"])
	_backdrop.visible = true
	_frame.visible = true

func dismiss_peer(peer_id: int) -> void:
	for index in range(_pending.size() - 1, -1, -1):
		if int(_pending[index].get("id", 0)) == peer_id:
			_pending.remove_at(index)
	if _current_id == peer_id:
		_current_id = 0
		_backdrop.visible = false
		_frame.visible = false
		_show_next()

func _accept() -> void:
	_respond(true)

func _reject() -> void:
	_respond(false)

func _respond(accept: bool) -> void:
	var peer_id: int = _current_id
	if peer_id == 0:
		return
	if session != null:
		session.respond_to_join(peer_id, accept)
	dismiss_peer(peer_id)
