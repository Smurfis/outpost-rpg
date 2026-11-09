extends CanvasLayer
const SKIN = preload("res://scripts/ui/outpost_skin.gd")
## Compact LAN co-op lobby. Solo gameplay stays unchanged when closed/offline.
var session
var shell: Control
var header: Label
var status: Label
var roster_label: Label
var party_label: Label
var profile_name: LineEdit
var ip_address: LineEdit
var party_code: SpinBox
var rarity: OptionButton
var entry_name: LineEdit
var online_actions: VBoxContainer
var run_actions: VBoxContainer
var host_button: Button
var join_button: Button
var disconnect_button: Button
var create_button: Button
var join_party_button: Button
var preview_button: Button
var next_button: Button
var end_button: Button
var revive_button: Button

func setup(ref: Node3D) -> void:
	session = ref

func _ready() -> void:
	layer = 29
	shell = Control.new()
	shell.name = "CoopLobby"
	shell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.025, 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.16
	panel.anchor_right = 0.84
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.94
	panel.add_theme_stylebox_override("panel", SKIN.translucent_surface())
	shell.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 11)
	scroll.add_child(contents)
	var top := HBoxContainer.new()
	contents.add_child(top)
	header = _label("CO-OP  /  PRIVATE ADVENTURES", 24, Color("ebd3a6"))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	var close := _button("✕", close_page)
	close.custom_minimum_size = Vector2(58, 50)
	top.add_child(close)
	status = _label("", 17, Color("c7dbd6"))
	contents.add_child(status)
	profile_name = _field("Your adventurer name", "Adventurer")
	contents.add_child(profile_name)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	contents.add_child(join_row)
	ip_address = _field("Host's LAN IP", "192.168.1.100")
	ip_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_address.text = ""
	join_row.add_child(ip_address)
	host_button = _button("HOST LAN", _host)
	join_row.add_child(host_button)
	join_button = _button("JOIN IP", _join)
	join_row.add_child(join_button)
	disconnect_button = _button("DISCONNECT / SOLO", _disconnect)
	contents.add_child(disconnect_button)
	roster_label = _label("", 18, Color("e5d5b4"))
	contents.add_child(roster_label)
	party_label = _label("", 17, Color("ced8d0"))
	contents.add_child(party_label)
	online_actions = VBoxContainer.new()
	online_actions.add_theme_constant_override("separation", 6)
	contents.add_child(online_actions)
	var party_row := HBoxContainer.new()
	online_actions.add_child(party_row)
	create_button = _button("CREATE PARTY", _create_party)
	party_row.add_child(create_button)
	party_code = SpinBox.new()
	party_code.min_value = 1
	party_code.max_value = 100000
	party_code.value = 1
	party_code.step = 1
	party_code.custom_minimum_size = Vector2(86, 50)
	party_row.add_child(party_code)
	join_party_button = _button("JOIN PARTY #", _join_party)
	party_row.add_child(join_party_button)
	var tip := _label("Only the party leader advances cleared floors or claims the final chest. Four players maximum.", 15, Color("9fb6b1"))
	online_actions.add_child(tip)
	run_actions = VBoxContainer.new()
	run_actions.add_theme_constant_override("separation", 6)
	contents.add_child(run_actions)
	var demo_row := HBoxContainer.new()
	run_actions.add_child(demo_row)
	entry_name = _field("Dungeon seed / entrance ID", "coop_caverns")
	entry_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demo_row.add_child(entry_name)
	rarity = OptionButton.new()
	for tier in ["Common", "Uncommon", "Rare", "Epic", "Legendary"]:
		rarity.add_item(tier)
	rarity.select(0)
	rarity.custom_minimum_size = Vector2(130, 50)
	demo_row.add_child(rarity)
	preview_button = _button("ENTER PRIVATE DUNGEON PREVIEW", _preview)
	run_actions.add_child(preview_button)
	var floor_row := HBoxContainer.new()
	run_actions.add_child(floor_row)
	next_button = _button("NEXT FLOOR", _next_floor)
	floor_row.add_child(next_button)
	end_button = _button("LEAVE PREVIEW", _end_preview)
	floor_row.add_child(end_button)
	revive_button = _button("REVIVE NEARBY ALLY", _revive)
	run_actions.add_child(revive_button)
	var note := _label("EARLY CO-OP: Host-owned guardians pursue nearby adventurers and strike with synchronized damage. Knocked-out allies can be revived within reach. This is LAN-only: remote movement still needs anti-cheat and advanced pathfinding is not yet available.", 15, Color("bdc9c2"))
	contents.add_child(note)
	visible = false
	session.session_changed.connect(_refresh)
	session.roster_changed.connect(_refresh)
	session.private_run_changed.connect(_refresh)

func _style(fill: Color, outline: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = outline
	box.set_border_width_all(2)
	box.set_corner_radius_all(9)
	box.set_content_margin_all(11)
	return box

func _label(value: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result

func _field(placeholder_text: String, start_text: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder_text
	field.text = start_text
	field.custom_minimum_size = Vector2(0, 48)
	return field

func _button(value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size = Vector2(0, 48)
	result.add_theme_font_size_override("font_size", 16)
	SKIN.apply_translucent_button(result, "wood")
	result.pressed.connect(callback)
	return result

func open() -> void:
	visible = true
	if session.game.hud != null:
		session.game.hud._reset_touch()
	_refresh()

func close_page() -> void:
	visible = false

func _refresh() -> void:
	if status == null:
		return
	status.text = session.status_message
	var peers: Array[String] = []
	for id in session.roster:
		var data: Dictionary = session.roster[id]
		peers.append("%s (#%d)" % [str(data.get("name", "Friend")), int(id)])
	roster_label.text = "PLAYERS: " + (", ".join(peers) if not peers.is_empty() else "Not connected")
	var party: Dictionary = session.my_party()
	party_label.text = "PARTY #%d  •  Leader #%d  •  %d/4 players" % [int(party.get("id", 0)), int(party.get("leader", 0)), (party.get("members", []) as Array).size()]
	var run: Dictionary = party.get("run", {})
	if not run.is_empty():
		party_label.text += "\nPRIVATE RUN #%d  •  Floor %d/%d" % [int(run.get("id", 0)), int(run.get("floor", 1)), int(run.get("floors", 1))]
	var connected: bool = session.online()
	online_actions.visible = connected
	run_actions.visible = connected
	host_button.disabled = connected or session.mode == "connecting"
	join_button.disabled = connected or session.mode == "connecting"
	disconnect_button.disabled = not connected and session.mode != "connecting"
	create_button.disabled = not connected or not run.is_empty()
	join_party_button.disabled = not connected or not run.is_empty()
	preview_button.disabled = not session.is_party_leader() or not run.is_empty()
	next_button.text = "CLAIM FINAL TREASURE" if not run.is_empty() and int(run.get("floor", 1)) >= int(run.get("floors", 1)) else "NEXT FLOOR"
	next_button.disabled = not session.is_party_leader() or run.is_empty() or not session.can_advance_preview()
	end_button.disabled = not session.is_party_leader() or run.is_empty()
	revive_button.disabled = not session.revive_available()

func _host() -> void:
	session.host_lan(profile_name.text)
	_refresh()

func _join() -> void:
	session.join_lan(ip_address.text, profile_name.text)
	_refresh()

func _disconnect() -> void:
	session.disconnect_session()
	_refresh()

func _create_party() -> void:
	session.request_new_party()

func _join_party() -> void:
	session.request_join_party(int(party_code.value))

func _preview() -> void:
	session.request_preview(entry_name.text.strip_edges(), rarity.selected)
	close_page()

func _next_floor() -> void:
	var run: Dictionary = session.my_party().get("run", {})
	if not run.is_empty() and int(run.get("floor", 1)) >= int(run.get("floors", 1)):
		session.request_complete_run()
	else:
		session.request_next_floor()
	close_page()

func _revive() -> void:
	session.request_revive_nearest()
	close_page()

func _end_preview() -> void:
	session.request_end_preview()
	close_page()
