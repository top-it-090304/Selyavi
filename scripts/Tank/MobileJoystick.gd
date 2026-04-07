extends Control

signal use_move_vector(move_vector)
signal fire_touch()

var _touch_button: TouchScreenButton
var _fire_button: TouchScreenButton
var move_vector: Vector2 = Vector2.ZERO
var _is_joystick_active: bool = false
var _inner_circle: Sprite2D
var _joystick_radius: float = 100.0
var _last_valid_direction: Vector2 = Vector2.ZERO
var _button_center: Vector2
var _joystick_texture: Texture2D
var _active_touch_index: int = -1

func get_is_joystick_active() -> bool:
	return _is_joystick_active

var is_aim: bool = false

func _ready():
	var original_texture = load("res://assets/scope.png")
	if original_texture:
		var image: Image = original_texture.get_image()
		image.resize(100, 100, Image.INTERPOLATE_BILINEAR)
		_joystick_texture = ImageTexture.create_from_image(image)
	
	_touch_button = get_node_or_null("TouchScreenButton")
	_fire_button = get_node_or_null("JoystickTipArrows/FireButton")
	_inner_circle = get_node_or_null("JoystickTipArrows")

	if _touch_button:
		_button_center = _touch_button.position + Vector2(_joystick_radius, _joystick_radius)
		_touch_button.action = ""

	if _fire_button:
		_fire_button.action = ""

	_reset_joystick()

func init(aim: bool):
	is_aim = aim
	if is_aim and _inner_circle and _joystick_texture:
		_inner_circle.texture = _joystick_texture

# Метод для проверки, находится ли палец в зоне джойстика
func is_pos_inside(pos: Vector2) -> bool:
	var local_pos = pos - global_position
	return local_pos.distance_to(_button_center) <= _joystick_radius * 1.5

func _input(event):
	if event is InputEventScreenTouch:
		var event_pos = event.position - global_position
		var dist = event_pos.distance_to(_button_center)

		if event.pressed:
			if _active_touch_index == -1 and dist <= _joystick_radius * 1.5:
				_active_touch_index = event.index
				_is_joystick_active = true
				_handle_movement(event_pos)
				get_viewport().set_input_as_handled()
		elif event.index == _active_touch_index:
			if _is_joystick_active:
				if is_aim and move_vector.length() > 0.2:
					fire_touch.emit()
				_active_touch_index = -1
				_is_joystick_active = false
				_reset_joystick()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		if _is_joystick_active:
			var event_pos = event.position - global_position
			_handle_movement(event_pos)
			get_viewport().set_input_as_handled()

	# Блокируем эмуляцию мыши, если она в зоне джойстика
	elif event is InputEventMouseButton:
		if is_pos_inside(event.position):
			get_viewport().set_input_as_handled()

func _handle_movement(local_pos: Vector2):
	var raw_direction: Vector2 = local_pos - _button_center
	var clamped_direction: Vector2
	if raw_direction.length() > _joystick_radius:
		clamped_direction = raw_direction.normalized() * _joystick_radius
	else:
		clamped_direction = raw_direction

	if _inner_circle:
		_inner_circle.position = _button_center + clamped_direction

	var new_direction: Vector2 = clamped_direction / _joystick_radius

	if is_aim and _last_valid_direction != Vector2.ZERO:
		move_vector = _last_valid_direction.lerp(new_direction, 0.4)
	else:
		move_vector = new_direction

	if new_direction.length() > 0.1:
		_last_valid_direction = new_direction

func _physics_process(_delta):
	if _is_joystick_active:
		use_move_vector.emit(move_vector)

func _reset_joystick():
	if _inner_circle:
		_inner_circle.position = _button_center
	move_vector = Vector2.ZERO
	if not is_aim: _last_valid_direction = Vector2.ZERO
