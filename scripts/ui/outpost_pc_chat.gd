extends CanvasLayer
## Compact PC chat + temporary local GM console. The input is intentionally
## invisible on touch devices; keyboard focus blocks movement and hotkeys.
const COMMANDS = preload("res://scripts/debug/gm_commands.gd")
const MAX_LINES: int = 24
const SHOW_SECONDS: float = 12.0
var game
var root: Control
var frame: PanelContainer
var frame_style: StyleBoxFlat
var heading: Label
var last_chat_size: Vector2 = Vector2.ZERO
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
	frame.offset_left = 12.0
	frame.offset_right = 420.0
	frame.offset_top = -183.0
	frame.offset_bottom = -28.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.02, 0.027, 0.036, 0.23)
	frame_style.border_color = Color(0.61, 0.53, 0.36, 0.36)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(0)
	frame_style.set_content_margin_all(6.0)
	frame_style.anti_aliasing = false
	frame.add_theme_stylebox_override("panel", frame_style)
	root.add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	frame.add_child(stack)
	heading = Label.new()
	heading.name = "ChatTitle"
	heading.text = "CHAT    ENTER TO SEND  ·  ESC TO CLOSE"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color("#f0d389"))
	heading.add_theme_color_override("font_outline_color", Color("#12141c"))
	heading.add_theme_constant_override("outline_size", 2)
	heading.visible = false
	stack.add_child(heading)
	transcript = RichTextLabel.new()
	transcript.name = "ChatHistory"
	transcript.custom_minimum_size = Vector2(0, 94)
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.bbcode_enabled = false # Never evaluate player-provided markup.
	transcript.scroll_following = true
	transcript.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transcript.add_theme_font_size_override("normal_font_size", 13)
	transcript.add_theme_color_override("default_color", Color("#f0f0de"))
	transcript.add_theme_color_override("font_outline_color", Color("#10141c"))
	transcript.add_theme_constant_override("outline_size", 2)
	transcript.add_theme_constant_override("line_separation", 1)
	stack.add_child(transcript)
	input = LineEdit.new()
	input.name = "ChatInput"
	input.placeholder_text = "Message or .help for GM commands"
	input.max_length = 180
	input.clear_button_enabled = true
	input.add_theme_font_size_override("font_size", 13)
	input.add_theme_color_override("font_color", Color("#f2ead9"))
	input.add_theme_color_override("font_placeholder_color", Color("#9c9b91"))
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.045, 0.054, 0.069, 0.96)
	input_style.border_color = Color("#c2a565")
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(0)
	input_style.set_content_margin_all(5)
	input.add_theme_stylebox_override("normal", input_style)
	input.add_theme_stylebox_override("focus", input_style)
	input.visible = false
	input.text_submitted.connect(_submit)
	stack.add_child(input)
	frame.hide()
	_layout_chat()

func _layout_chat() -> void:
	if frame == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return
	var left_margin: float = clampf(screen.x * 0.013, 8.0, 16.0)
	var panel_width: float = minf(420.0, maxf(244.0, screen.x * 0.40))
	frame.offset_left = left_margin
	frame.offset_right = left_margin + panel_width
	# Leave the continuous XP bar unobstructed at the bottom of the screen.
	frame.offset_bottom = -maxf(24.0, screen.y * 0.036)
	var panel_height: float = minf(210.0 if chat_open else 157.0, screen.y * (0.48 if chat_open else 0.36))
	frame.offset_top = frame.offset_bottom - panel_height
	frame.mouse_filter = Control.MOUSE_FILTER_STOP if chat_open else Control.MOUSE_FILTER_IGNORE
	frame_style.bg_color = Color(0.02, 0.027, 0.036, 0.83 if chat_open else 0.23)
	frame_style.border_color = Color(0.79, 0.67, 0.42, 0.82 if chat_open else 0.32)
	heading.visible = chat_open
	last_chat_size = screen

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
	_layout_chat()
	game.hud.move_vector = Vector2.ZERO
	game.hero.stop_interaction_move()
	input.grab_focus()

func close_chat() -> void:
	chat_open = false
	input.clear()
	input.release_focus()
	input.hide()
	_layout_chat()
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
	_render_lines()
	last_line_time = Time.get_ticks_msec() / 1000.0
	_refresh_visibility()

func _render_lines() -> void:
	transcript.clear()
	for line in lines:
		var colon: int = line.find(": ")
		var sender: String = line.substr(0, colon) if colon >= 0 else ""
		var message: String = line.substr(colon + 2) if colon >= 0 else line
		# Cube World-like, pixel-sharp coloured speakers and light chat text.
		var sender_colour: Color = Color("#efcb78") if sender == "GM" else Color("#94d6fb")
		transcript.push_color(sender_colour)
		transcript.add_text(sender + ": " if colon >= 0 else "")
		transcript.pop()
		transcript.push_color(Color("#f3f4e1"))
		transcript.add_text(message + "\n")
		transcript.pop()

func _refresh_visibility() -> void:
	if frame != null:
		frame.visible = desktop_available() and (chat_open or Time.get_ticks_msec() / 1000.0 - last_line_time < SHOW_SECONDS)

func _process(_delta: float) -> void:
	if get_viewport().get_visible_rect().size != last_chat_size:
		_layout_chat()
	_refresh_visibility()
