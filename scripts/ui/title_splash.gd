@tool
extends Label
## Pixel-art slogan; long messages are deliberately laid out in two lines.
## The original hand-lettered hero PNG is retained as a separate optional frame.
@export var messages: PackedStringArray = PackedStringArray([
	"Bring a torch!",
	"Now with deeper\\ndungeons!",
	"Pixel by pixel!",
	"Now with nights!",
	"Craft your own legend!",
	"Adventure awaits!",
	"The Fields are calling!",
	"Build your Outpost!",
	"Don't forget your torch!",
	"Bring a friend!",
	"Every camp needs a hero!"
])
@export var rotation_angle: float = -7.0
@export var cycle_seconds: float = 8.0
@export var animate_bounce: bool = true

const HERO_LINE := "Now with deeper\ndungeons!"
const HERO_ART := "res://assets/ui/title/splash_deeper_dungeons.png"
var _elapsed: float = 0.0
var _message_index: int = 0
var _hero_texture: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# A wrapped/rotated Label used to produce a stray vertical glyph at the
	# left of phrases such as "Pixel by pixel!" on widescreen Android phones.
	autowrap_mode = TextServer.AUTOWRAP_OFF
	clip_text = false
	pivot_offset = size * 0.5
	var style := LabelSettings.new()
	style.font_size = 27
	style.font_color = Color("ffda46")
	style.outline_color = Color("372132")
	style.outline_size = 4
	style.shadow_color = Color(0.16, 0.09, 0.16, 0.75)
	style.shadow_offset = Vector2i(2, 3)
	label_settings = style
	if ResourceLoader.exists(HERO_ART):
		_hero_texture = TextureRect.new()
		_hero_texture.name = "HandLetteredHero"
		_hero_texture.texture = load(HERO_ART) as Texture2D
		_hero_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	# Keep all glyphs inside the sky to the RIGHT of the tent. The previous
	# 31px single-line label clipped off its own edge and overlapped the crest.
	var two_lines: Dictionary = {
		"Craft your own legend!": "Craft your own\\nlegend!",
		"The Fields are calling!": "The Fields are\\ncalling!",
		"Don't forget your torch!": "Don't forget\\nyour torch!",
		"Every camp needs a hero!": "Every camp needs\\na hero!",
		"Build your Outpost!": "Build your\\nOutpost!"
	}
	var display_text: String = str(two_lines.get(resolved, resolved)).replace("\\n", "\n")
	text = "" if use_illustration else display_text
	if label_settings != null:
		label_settings.font_size = 26 if "\n" in display_text else 27
	# The illustrated phrase is pre-angled; rotate only actual live text.
	rotation_degrees = 0.0 if use_illustration else rotation_angle
	pivot_offset = size * 0.5
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if cycle_seconds > 0.0 and _elapsed >= cycle_seconds and not messages.is_empty():
		_elapsed = 0.0
		_message_index = (_message_index + 1) % messages.size()
		set_message(messages[_message_index])
	if animate_bounce:
		scale = Vector2.ONE * (1.0 + 0.018 * sin(float(Time.get_ticks_msec()) * 0.0024))
	elif not scale.is_equal_approx(Vector2.ONE):
		scale = Vector2.ONE
