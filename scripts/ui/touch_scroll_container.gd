extends ScrollContainer
## Android-friendly swipe scrolling even when the finger starts on an item button.
## A short tap is never consumed; only a deliberate vertical drag moves content.
@export var swipe_deadzone: float = 8.0

var _finger: int = -1
var _start_point: Vector2 = Vector2.ZERO
var _previous_point: Vector2 = Vector2.ZERO
var _dragged: bool = false

func _ready() -> void:
	scroll_horizontal_enabled = false
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_deadzone = 4

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_finger = -1
		_dragged = false
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _finger == -1 and get_global_rect().has_point(touch.position):
			_finger = touch.index
			_start_point = touch.position
			_previous_point = touch.position
			_dragged = false
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			_dragged = false
	elif event is InputEventScreenDrag and _finger >= 0:
		var drag: InputEventScreenDrag = event
		if drag.index != _finger:
			return
		if not _dragged and absf(drag.position.y - _start_point.y) >= swipe_deadzone:
			_dragged = true
		var delta_y: float = drag.position.y - _previous_point.y
		_previous_point = drag.position
		if _dragged:
			var maximum: int = maxi(0, roundi(get_v_scroll_bar().max_value - get_v_scroll_bar().page))
			scroll_vertical = clampi(scroll_vertical - roundi(delta_y), 0, maximum)
			get_viewport().set_input_as_handled()
