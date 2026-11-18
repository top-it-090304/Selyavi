extends ScrollContainer

var _finger := -1
var _origin := Vector2.ZERO
var _initial_scroll := 0
var _dragging := false
var _last_drag_end := -1000

func can_select_item() -> bool:
	return not _dragging and Time.get_ticks_msec() - _last_drag_end > 150

func _input(event: InputEvent):
	if not is_visible_in_tree():
		_finger = -1
		_dragging = false
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and get_global_rect().has_point(event.position):
			_finger = event.index
			_origin = event.position
			_initial_scroll = scroll_vertical
		elif not event.pressed and event.index == _finger:
			if _dragging:
				_last_drag_end = Time.get_ticks_msec()
				get_viewport().set_input_as_handled()
				_release_buttons(self)
			_finger = -1
			_dragging = false
	elif event is InputEventScreenDrag and event.index == _finger:
		var distance: float = event.position.y - _origin.y
		if absf(distance) > 12.0:
			_dragging = true
		if _dragging:
			scroll_vertical = _initial_scroll - int(distance)
			_release_buttons(self)
			get_viewport().set_input_as_handled()

func _release_buttons(node: Node):
	for child in node.get_children():
		if child is BaseButton:
			child.set_pressed_no_signal(false)
		_release_buttons(child)
