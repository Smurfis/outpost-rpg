@tool
extends Label
## Dynamic, locally editable Minecraft/Terraria-style title splash.
## Replace/update phrases without redrawing a PNG or baking text into the backdrop.
@export var messages: PackedStringArray = PackedStringArray([
	"Now with deeper\\ndungeons!",
	"Adventure awaits!",
	"Craft your legend!",
	"The depths are calling!",
	"Bring a friend!"
])
@export var rotation_angle: float = -10.0
@export var cycle_seconds: float = 8.0
@export var animate_bounce: bool = true

var _elapsed := 0.0
var _message_index := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotation_degrees = rotation_angle
	pivot_offset = size * 0.5
	var style := LabelSettings.new()
	style.font_size = 35
	style.font_color = Color("ffda38")
	style.outline_color = Color("3e202b")
	style.outline_size = 7
	style.shadow_color = Color("301c25")
	style.shadow_offset = Vector2i(3, 5)
	label_settings = style
	if not messages.is_empty():
		set_message(messages[0])
	set_process(not Engine.is_editor_hint())

func set_message(message: String) -> void:
	text = message.replace("\\n", "\n")

func _process(delta: float) -> void:
	_elapsed += delta
	if cycle_seconds > 0.0 and _elapsed >= cycle_seconds and not messages.is_empty():
		_elapsed = 0.0
		_message_index = (_message_index + 1) % messages.size()
		set_message(messages[_message_index])
	if animate_bounce:
		scale = Vector2.ONE * (1.0 + 0.035 * sin(float(Time.get_ticks_msec()) * 0.003))
