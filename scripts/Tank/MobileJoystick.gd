extends Control

signal use_move_vector(move_vector)
signal fire_touch()

## Движение — оливковый «броня / HUD»
const CLR_SHADOW := Color(0.02, 0.03, 0.02, 0.45)
const CLR_BASE := Color(0.11, 0.13, 0.10, 0.96)
const CLR_BASE_INNER := Color(0.14, 0.16, 0.12, 0.88)
const CLR_RING_OUT := Color(0.40, 0.46, 0.34, 0.98)
const CLR_RING_IN := Color(0.28, 0.33, 0.24, 0.9)
const CLR_ACCENT := Color(0.74, 0.82, 0.71, 0.55)
const CLR_TICK := Color(0.55, 0.62, 0.48, 0.22)
const CLR_KNOB := Color(0.19, 0.22, 0.17, 1.0)
const CLR_KNOB_EDGE := Color(0.32, 0.37, 0.28, 1.0)
const CLR_KNOB_HI := Color(0.78, 0.86, 0.68, 0.45)

## Прицел — холоднее, без засечек-«диал», акцент сине-серый
const AIM_CLR_SHADOW := Color(0.02, 0.03, 0.05, 0.42)
const AIM_CLR_BASE := Color(0.10, 0.12, 0.16, 0.96)
const AIM_CLR_BASE_INNER := Color(0.14, 0.16, 0.22, 0.88)
const AIM_CLR_RING_OUT := Color(0.38, 0.48, 0.58, 0.9)
const AIM_CLR_RING_IN := Color(0.22, 0.28, 0.36, 0.75)
const AIM_CLR_ACCENT := Color(0.55, 0.72, 0.88, 0.65)
const AIM_CLR_CROSS := Color(0.65, 0.78, 0.9, 0.38)
const AIM_CLR_KNOB := Color(0.16, 0.19, 0.24, 1.0)
const AIM_CLR_KNOB_EDGE := Color(0.35, 0.48, 0.58, 1.0)
const AIM_CLR_KNOB_HI := Color(0.7, 0.82, 0.95, 0.4)
const AIM_CLR_RETICLE := Color(0.85, 0.92, 0.98, 0.85)

var _touch_button: TouchScreenButton
var _fire_button: TouchScreenButton
var move_vector: Vector2 = Vector2.ZERO
var _is_joystick_active: bool = false
var _knob_pivot: Node2D
var _joystick_radius: float = 100.0
var _last_valid_direction: Vector2 = Vector2.ZERO
var _button_center: Vector2
var _active_touch_index: int = -1

func get_is_joystick_active() -> bool:
	return _is_joystick_active

var is_aim: bool = false

func _ready():
	_touch_button = get_node_or_null("TouchScreenButton")
	_knob_pivot = get_node_or_null("KnobPivot")
	_fire_button = get_node_or_null("KnobPivot/FireButton")

	if _touch_button:
		_touch_button.texture_normal = _make_clear_texture(int(_joystick_radius * 2))
		_button_center = _touch_button.position + Vector2(_joystick_radius, _joystick_radius)
		_touch_button.action = ""

	if _fire_button:
		_fire_button.texture_normal = _make_clear_texture(100)
		_fire_button.action = ""

	_reset_joystick()
	queue_redraw()

func init(aim: bool):
	is_aim = aim
	if _fire_button:
		_fire_button.visible = aim
	queue_redraw()

func _make_clear_texture(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func is_pos_inside(pos: Vector2) -> bool:
	var local_pos: Vector2 = pos - global_position
	return local_pos.distance_to(_button_center) <= _joystick_radius * 1.5

func _input(event):
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var event_pos: Vector2 = touch.position - global_position
		var dist: float = event_pos.distance_to(_button_center)

		if touch.pressed:
			if _active_touch_index == -1 and dist <= _joystick_radius * 1.5:
				_active_touch_index = touch.index
				_is_joystick_active = true
				_handle_movement(event_pos)
				get_viewport().set_input_as_handled()
		elif touch.index == _active_touch_index:
			if _is_joystick_active:
				if is_aim and move_vector.length() > 0.2:
					fire_touch.emit()
				_active_touch_index = -1
				_is_joystick_active = false
				_reset_joystick()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _active_touch_index and _is_joystick_active:
			var event_pos: Vector2 = drag.position - global_position
			_handle_movement(event_pos)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if is_pos_inside(mb.position):
			get_viewport().set_input_as_handled()

func _handle_movement(local_pos: Vector2):
	var raw_direction := local_pos - _button_center
	var clamped_direction: Vector2
	if raw_direction.length() > _joystick_radius:
		clamped_direction = raw_direction.normalized() * _joystick_radius
	else:
		clamped_direction = raw_direction

	if _knob_pivot:
		_knob_pivot.position = _button_center + clamped_direction

	var new_direction := clamped_direction / _joystick_radius

	if is_aim and _last_valid_direction != Vector2.ZERO:
		move_vector = _last_valid_direction.lerp(new_direction, 0.4)
	else:
		move_vector = new_direction

	if new_direction.length() > 0.1:
		_last_valid_direction = new_direction

	queue_redraw()

func _physics_process(_delta):
	if _is_joystick_active:
		use_move_vector.emit(move_vector)

func _reset_joystick():
	if _knob_pivot:
		_knob_pivot.position = _button_center
	move_vector = Vector2.ZERO
	if not is_aim:
		_last_valid_direction = Vector2.ZERO
	queue_redraw()

func _draw():
	var c := _button_center
	var r := _joystick_radius
	if is_aim:
		_draw_aim_base(c, r)
		_draw_hud_corners_aim(c, r + 4.0)
	else:
		_draw_move_base(c, r)
		_draw_hud_corners_move(c, r + 4.0)

	var kc: Vector2 = _knob_pivot.position if _knob_pivot else c
	if is_aim:
		_draw_aim_knob(kc)
		_draw_aim_overlay(c, kc)
	else:
		_draw_move_knob(kc)

func _draw_move_base(c: Vector2, r: float):
	draw_circle(c + Vector2(4, 5), r + 8.0, CLR_SHADOW)
	draw_circle(c, r - 2.0, CLR_BASE)
	draw_circle(c, r * 0.52, CLR_BASE_INNER)
	draw_arc(c, r - 1.0, 0.0, TAU, 96, CLR_RING_OUT, 5.0, true)
	draw_arc(c, r * 0.52, 0.0, TAU, 64, Color(CLR_RING_IN.r, CLR_RING_IN.g, CLR_RING_IN.b, 0.4), 2.0, true)
	for i in range(8):
		var a := float(i) * TAU / 8.0
		var dir := Vector2.from_angle(a)
		draw_line(c + dir * (r * 0.58), c + dir * (r * 0.82), CLR_TICK, 2.0)

func _draw_aim_base(c: Vector2, r: float):
	draw_circle(c + Vector2(3, 4), r + 8.0, AIM_CLR_SHADOW)
	draw_circle(c, r - 2.0, AIM_CLR_BASE)
	draw_circle(c, r * 0.52, AIM_CLR_BASE_INNER)
	draw_arc(c, r - 1.0, 0.0, TAU, 96, AIM_CLR_RING_OUT, 4.0, true)
	draw_arc(c, r * 0.52, 0.0, TAU, 64, Color(AIM_CLR_RING_IN.r, AIM_CLR_RING_IN.g, AIM_CLR_RING_IN.b, 0.5), 2.0, true)
	# Только 4 кардинальные метки — «прицельная» сетка
	for i in range(4):
		var a := float(i) * PI * 0.5 + PI * 0.25
		var dir := Vector2.from_angle(a)
		draw_line(c + dir * (r * 0.62), c + dir * (r * 0.86), Color(AIM_CLR_ACCENT.r, AIM_CLR_ACCENT.g, AIM_CLR_ACCENT.b, 0.28), 1.5)

func _draw_hud_corners_move(center: Vector2, extent: float):
	_draw_hud_corners(center, extent, CLR_ACCENT)

func _draw_hud_corners_aim(center: Vector2, extent: float):
	_draw_hud_corners(center, extent, AIM_CLR_ACCENT)

func _draw_hud_corners(center: Vector2, extent: float, col: Color):
	var arm := 16.0
	var w := 2.5
	var inset := extent * 0.78
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for s in corners:
		var corner := center + Vector2(s.x * inset, s.y * inset)
		draw_line(corner, corner + Vector2(s.x * arm, 0), col, w)
		draw_line(corner, corner + Vector2(0, s.y * arm), col, w)

func _draw_move_knob(p: Vector2):
	var kr := 28.0
	draw_circle(p + Vector2(2, 3), kr, Color(0, 0, 0, 0.28))
	draw_circle(p, kr, CLR_KNOB)
	draw_arc(p, kr - 0.5, 0.0, TAU, 40, CLR_KNOB_EDGE, 2.5, true)
	draw_arc(p, kr * 0.65, -2.7, -0.9, 12, CLR_KNOB_HI, 5.0, true)

func _draw_aim_knob(p: Vector2):
	var kr := 24.0
	draw_circle(p + Vector2(1, 2), kr, Color(0, 0, 0, 0.35))
	draw_circle(p, kr, AIM_CLR_KNOB)
	draw_arc(p, kr - 0.5, 0.0, TAU, 36, AIM_CLR_KNOB_EDGE, 2.0, true)
	draw_arc(p, kr * 0.55, -2.5, -0.8, 10, AIM_CLR_KNOB_HI, 4.0, true)
	draw_circle(p, 4.0, AIM_CLR_RETICLE)

func _draw_aim_overlay(base_c: Vector2, knob_c: Vector2):
	var ext := 52.0
	draw_line(base_c + Vector2(-ext, 0), base_c + Vector2(-ext * 0.38, 0), AIM_CLR_CROSS, 1.5)
	draw_line(base_c + Vector2(ext * 0.38, 0), base_c + Vector2(ext, 0), AIM_CLR_CROSS, 1.5)
	draw_line(base_c + Vector2(0, -ext), base_c + Vector2(0, -ext * 0.38), AIM_CLR_CROSS, 1.5)
	draw_line(base_c + Vector2(0, ext * 0.38), base_c + Vector2(0, ext), AIM_CLR_CROSS, 1.5)
	var cross := 9.0
	draw_line(knob_c + Vector2(-cross, 0), knob_c + Vector2(cross, 0), AIM_CLR_ACCENT, 1.5)
	draw_line(knob_c + Vector2(0, -cross), knob_c + Vector2(0, cross), AIM_CLR_ACCENT, 1.5)
