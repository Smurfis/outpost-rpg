extends CanvasLayer
## Compact PC chat + temporary local GM console. The input is intentionally
## invisible on touch devices; keyboard focus blocks movement and hotkeys.
const COMMANDS = preload("res://scripts/debug/gm_commands.gd")
const MAX_LINES: int = 24
const SHOW_SECONDS: float = 12.0
var game
var root: Control
var frame: PanelContainer
var transcript: RichTextLabel
var input: LineEdit
var chat_open: bool = false
var lines: Array[String] = []
var last_line_time: float = -9999.0

func setup(owner: Node) -> void:
	game = owner

func desktop_available() -> bool:
	return game != null and game.controls != null and bool(game.controls.desktop) and not OS.has_feature("mobile")

func _ready() -> void:
	layer = 30 # Below world map (40), above gameplay HUD.
	name = "OutpostChat"
	root = Control.new()
	root.name = "ChatRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame = PanelContainer.new()
	frame.name = "ChatFrame"
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = 16.0
	frame.offset_right = 426.0
	frame.offset_top = -252.0
	frame.offset_bottom = -76.0
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.044, 0.055, 0.84)
	style.border_color = Color(0.48, 0.39, 0.24, 0.80)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	frame.add_theme_stylebox_override("panel", style)
	root.add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	frame.add_child(stack)
	var heading := Label.new()
	heading.name = "ChatTitle"
	heading.text = "OUTPOST  /  CHAT       Enter to send  ·  Esc to close"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color("dec58b"))
	stack.add_child(heading)
	transcript = RichTextLabel.new()
	transcript.name = "ChatHistory"
	transcript.custom_minimum_size = Vector2(0, 104)
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.bbcode_enabled = false # Never evaluate player-provided markup.
	transcript.scroll_following = true
	transcript.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transcript.add_theme_font_size_override("normal_font_size", 13)
	stack.add_child(transcript)
	input = LineEdit.new()
	input.name = "ChatInput"
	input.placeholder_text = "Message or .help for GM commands"
	input.max_length = 180
	input.clear_button_enabled = true
	input.visible = false
	input.text_submitted.connect(_submit)
	stack.add_child(input)
	frame.hide()

func _input(event: InputEvent) -> void:
	if not desktop_available() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if chat_open:
			# LineEdit handles submit while it has keyboard focus.
			return
		if game.controls.modal_open():
			return
		open_chat()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and chat_open:
		close_chat()
		get_viewport().set_input_as_handled()

func open_chat() -> void:
	if chat_open or not desktop_available():
		return
	if game.world_map != null and game.world_map.is_open():
		return
	chat_open = true
	frame.show()
	input.show()
	game.hud.move_vector = Vector2.ZERO
	game.hero.stop_interaction_move()
	input.grab_focus()

func close_chat() -> void:
	chat_open = false
	input.clear()
	input.release_focus()
	input.hide()
	last_line_time = Time.get_ticks_msec() / 1000.0
	_refresh_visibility()

func _submit(message: String) -> void:
	if not chat_open:
		return
	var clean: String = message.strip_edges()
	if clean != "":
		if clean.begins_with("."):
			var result: String = COMMANDS.execute(game, clean)
			if result == "__CHAT_CLEAR__":
				lines.clear()
				transcript.clear()
			else:
				add_line("GM", result)
		else:
			var display: String = str(game.hud.player_display_name).substr(0, 24)
			add_line(display, clean)
	close_chat()

func add_line(author: String, message: String) -> void:
	var safe_author: String = author.replace("\n", " ").replace("\r", " ").substr(0, 24)
	var safe_text: String = message.replace("\n", " ").replace("\r", " ").substr(0, 320)
	lines.append("%s: %s" % [safe_author, safe_text])
	while lines.size() > MAX_LINES:
		lines.pop_front()
	transcript.text = "\n".join(lines)
	last_line_time = Time.get_ticks_msec() / 1000.0
	_refresh_visibility()

func _refresh_visibility() -> void:
	if frame != null:
		frame.visible = desktop_available() and (chat_open or Time.get_ticks_msec() / 1000.0 - last_line_time < SHOW_SECONDS)

func _process(_delta: float) -> void:
	_refresh_visibility()
