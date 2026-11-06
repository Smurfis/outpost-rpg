@tool
extends Label
## Dynamic, locally editable Minecraft/Terraria-style title splash.
## Rotates editable phrases; for the hero slogan, prefers hand-lettered transparent PNG.
## All other phrases remain editable Godot Labels, with matching colors and outline.
@export var messages: PackedStringArray = PackedStringArray([
	"Now with deeper\\ndungeons!",
	"Craft your own legend!",
	"Pixel by pixel!",
	"Adventure awaits!",
	"Don't forget your torch!",
	"The Fields are calling!",
	"A world worth exploring!",
	"The depths are calling!",
	"Bring a friend!",
	"Build your Outpost!",
	"Every camp needs a hero!"
])
@export var rotation_angle: float = -10.0
@export var cycle_seconds: float = 8.0
@export var animate_bounce: bool = true

var _elapsed := 0.0
var _message_index := 0
var _hero_texture: TextureRect
const HERO_LINE := "Now with deeper\ndungeons!"
const HERO_ART := "res://assets/ui/title/splash_deeper_dungeons.png"

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
	if ResourceLoader.exists(HERO_ART):
		_hero_texture = TextureRect.new()
		_hero_texture.name = "HandLetteredHero"
		_hero_texture.texture = load(HERO_ART) as Texture2D
		_hero_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_hero_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hero_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hero_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_hero_texture)
	if not messages.is_empty():
		set_message(messages[0])
	set_process(not Engine.is_editor_hint())

func set_message(message: String) -> void:
	var resolved: String = message.replace("\\n", "\n")
	var use_illustration: bool = _hero_texture != null and resolved == HERO_LINE
	if _hero_texture != null:
		_hero_texture.visible = use_illustration
	text = "" if use_illustration else resolved
	# The approved drawn PNG is already tilted; rotate only dynamic text.
	rotation_degrees = 0.0 if use_illustration else rotation_angle

func _process(delta: float) -> void:
	_elapsed += delta
	if cycle_seconds > 0.0 and _elapsed >= cycle_seconds and not messages.is_empty():
		_elapsed = 0.0
		_message_index = (_message_index + 1) % messages.size()
		set_message(messages[_message_index])
	if animate_bounce:
		scale = Vector2.ONE * (1.0 + 0.035 * sin(float(Time.get_ticks_msec()) * 0.003))
