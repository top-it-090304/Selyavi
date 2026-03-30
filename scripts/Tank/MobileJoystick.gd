extends CanvasLayer

signal use_move_vector(move_vector)
signal fire_touch()

# region private fields
var _touch_button: TouchScreenButton
var _fire_button: TouchScreenButton
var move_vector: Vector2 = Vector2.ZERO
var _is_joystick_active: bool = false
var _inner_circle: Sprite
var _joystick_radius: float = 100.0
var _last_valid_direction: Vector2 = Vector2.ZERO
var _button_center: Vector2
var _joystick_texture: Texture
# endregion

func get_is_joystick_active() -> bool:
	return _is_joystick_active

var is_aim: bool = false

func _ready():
	var original_texture: Texture = load("res://assets/scope.png")
	var image: Image = original_texture.get_data()
	
	image.resize(100, 100, Image.INTERPOLATE_BILINEAR)
	var resized_texture: ImageTexture = ImageTexture.new()
	resized_texture.create_from_image(image)
	
	_joystick_texture = resized_texture
	_touch_button = get_node("TouchScreenButton")
	_fire_button = get_node("JoystickTipArrows/FireButton")
	_inner_circle = get_node("JoystickTipArrows")
	_button_center = _touch_button.position + Vector2(_joystick_radius, _joystick_radius)
	_reset_joystick()
	_fire_button.connect("released", self, "_on_button_fire_pressed")

func init(aim: bool):
	is_aim = aim
	if is_aim:
		_inner_circle.texture = _joystick_texture

func _input(event):
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if _touch_button.is_pressed():
			var event_position: Vector2 = Vector2.ZERO
			
			if event is InputEventScreenTouch:
				event_position = event.position
			elif event is InputEventScreenDrag:
				event_position = event.position
			
			var local_event_pos: Vector2 = event_position - get_final_transform().origin
			var raw_direction: Vector2 = local_event_pos - _button_center
			var clamped_direction: Vector2
			
			if raw_direction.length() > _joystick_radius:
				clamped_direction = raw_direction.normalized() * _joystick_radius
			else:
				clamped_direction = raw_direction
			
			_inner_circle.position = _button_center + clamped_direction
			var new_direction: Vector2 = clamped_direction / _joystick_radius
			
			if is_aim and _last_valid_direction != Vector2.ZERO:
				move_vector = _last_valid_direction.linear_interpolate(new_direction, 0.3)
			else:
				move_vector = new_direction
			
			if new_direction.length() > 0.1:
				_last_valid_direction = new_direction
			
			_is_joystick_active = true
		else:
			if not is_aim:
				_reset_joystick()
			_is_joystick_active = false

func _physics_process(delta):
	if _is_joystick_active:
		emit_signal("use_move_vector", move_vector)

func _on_button_fire_pressed():
	emit_signal("fire_touch")

func _reset_joystick():
	_inner_circle.position = _button_center
	move_vector = Vector2.ZERO
	_last_valid_direction = Vector2.ZERO
