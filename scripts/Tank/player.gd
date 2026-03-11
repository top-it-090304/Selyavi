extends CharacterBody2D
class_name Player

# region private fields
var _speed: int = 250:
	set(value):
		if value > 0 and value <= 800:
			_speed = value
	get:
		return _speed
var _hp: int
var _lives: int
var _is_moving: bool = false
var _is_scope_enabled: bool = true
var _normal_movement_volume: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _bullet_position: Position2D
var _shoot_timer: Timer
var _moving_sound: AudioStreamPlayer
var _shoot_sound: AudioStreamPlayer2D
var _tween: Tween
var _joystick: CanvasLayer
var _gun: Sprite
var _aim: MobileJoystick
var _type_bullet: int = 0  # TypeBullet.Plasma
var _start_position: Vector2
# endregion

var bullet_scene: PackedScene

func _ready():
	_init()
	add_child(_shoot_timer)
	add_child(_tween)
	_configure_audio_players()
	if _moving_sound != null:
		_normal_movement_volume = _moving_sound.volume_db
	
	if AudioManager.instance != null:
		if not AudioManager.instance.sfx_volume_changed.is_connected(_on_sfx_volume_changed):
			AudioManager.instance.sfx_volume_changed.connect(_on_sfx_volume_changed)
	
	if GameManager.instance != null:
		if not GameManager.instance.scope_toggled.is_connected(_toggle_scope):
			GameManager.instance.scope_toggled.connect(_toggle_scope)
		_is_scope_enabled = GameManager.instance._scope_enabled
	else:
		_load_initial_scope_state()

func _on_sfx_volume_changed(value: float):
	var db_value = linear_to_db(value)
	_normal_movement_volume = db_value
	if _moving_sound.playing:
		_moving_sound.volume_db = db_value
	print("Громкость SFX изменена: ", value, " (", db_value, " dB)")

func linear_to_db(linear: float) -> float:
	if linear <= 0:
		return -80
	return 20.0 * log(linear) / log(10)

func _load_initial_scope_state():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		_is_scope_enabled = config.get_value("game", "scope_enabled", true)
	else:
		_is_scope_enabled = true

func _toggle_scope(checkbox_value: bool):
	_is_scope_enabled = checkbox_value
	queue_redraw()

func _configure_audio_players():
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	
	if _moving_sound != null:
		_moving_sound.bus = "SFX"

func _use_move_vector(move_vector: Vector2):
	var joystick_velocity = move_vector * 200
	move_and_slide(joystick_velocity)
	_rotate_player_mobile(move_vector)
	_handle_movement_sound(joystick_velocity)

func _handle_movement_sound(movement_velocity: Vector2):
	var is_moving_now = movement_velocity.length() > 0.1
	
	if is_moving_now:
		if not _is_moving:
			if _tween.is_active():
				_tween.stop_all()
				_tween.remove_all()
			_moving_sound.volume_db = _normal_movement_volume
			if not _moving_sound.playing:
				_moving_sound.play()
			_is_moving = true
	else:
		if _is_moving:
			_is_moving = false
			if _moving_sound.playing:
				_fade_sound()

func _fire_touch():
	if _shoot_timer.time_left > 0:
		return
	
	var bullet = bullet_scene.instantiate()
	bullet.global_position = _bullet_position.global_position
	bullet.rotation_degrees = _gun.global_rotation_degrees
	get_tree().root.add_child(bullet)
	bullet.init(_type_bullet, true)
	_shoot_timer.start()

func _use_move_vector_aim(move_vector: Vector2):
	_rotate_player_mobile_aim(move_vector)

func _physics_process(delta):
	_get_input()
	_velocity = move_and_slide(_velocity)

func _get_input():
	_move()
	_change_bullet()

func _change_bullet():
	var bullet_changed = false
	if Input.is_action_just_pressed("plasma"):
		_type_bullet = 0  # TypeBullet.Plasma
		bullet_changed = true
	elif Input.is_action_just_pressed("medium_bullet"):
		_type_bullet = 1  # TypeBullet.Medium
		bullet_changed = true
	elif Input.is_action_just_pressed("light_bullet"):
		_type_bullet = 2  # TypeBullet.Light
		bullet_changed = true
	
	if bullet_changed:
		_shoot_timer.start()

func _move():
	_velocity.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	_velocity.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if _velocity.length() > 0:
		_velocity = _velocity.normalized() * _speed
		_rotate_player(_velocity)
		_handle_movement_sound(_velocity)
	else:
		_handle_movement_sound(Vector2.ZERO)

func _rotate_player_mobile(direction: Vector2):
	rotation_degrees = rad_to_deg(direction.angle()) + 90

func _rotate_player_mobile_aim(direction: Vector2):
	_gun.global_rotation_degrees = rad_to_deg(direction.angle()) + 90

func _rotate_player(direction: Vector2):
	if direction.x > 0:
		if direction.y < 0:
			rotation_degrees = 45
		elif direction.y > 0:
			rotation_degrees = 90 + 45
		else:
			rotation_degrees = 90
	elif direction.x < 0:
		if direction.y < 0:
			rotation_degrees = 270 + 45
		elif direction.y > 0:
			rotation_degrees = 270 - 45
		else:
			rotation_degrees = 270
	elif direction.y > 0:
		rotation_degrees = 180
	elif direction.y < 0:
		rotation_degrees = 0

func _fire():
	if Input.is_action_just_pressed("fire"):
		_fire_touch()

func take_damage(damage: int):
	_hp -= damage
	if _hp <= 0:
		_destroy()

func _destroy():
	_lives -= 1
	if _lives != 0:
		_revive()
	else:
		queue_free()

func _revive():
	_hp = 20
	global_position = _start_position

func _fade_sound():
	if _tween.tween_completed.is_connected(_on_tween_complete):
		_tween.tween_completed.disconnect(_on_tween_complete)
	
	if _tween.is_active():
		_tween.stop_all()
		_tween.remove_all()
	
	_tween.interpolate_property(
		_moving_sound,
		"volume_db",
		_moving_sound.volume_db,
		-80,
		0.3,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	_tween.start()
	_tween.tween_completed.connect(_on_tween_complete)

func _on_tween_complete(obj: Object, key: NodePath):
	_moving_sound.stop()
	_moving_sound.volume_db = _normal_movement_volume

func _process(delta):
	queue_redraw()

func _draw():
	if _aim.is_joystick_active and _is_scope_enabled:
		var global_muzzle_pos = _bullet_position.global_position
		
		var gun_angle = _gun.global_rotation
		var direction = Vector2(1, 0).rotated(gun_angle)
		
		var perpendicular = Vector2(direction.y, -direction.x)
		
		var ray_length = 1000.0
		
		var global_ray_end = global_muzzle_pos + perpendicular * ray_length
		
		var local_muzzle_pos = to_local(global_muzzle_pos)
		var local_ray_end = to_local(global_ray_end)
		
		var ray_color = Color.RED
		var ray_width = 2.0
		draw_line(local_muzzle_pos, local_ray_end, ray_color, ray_width)

func _init():
	bullet_scene = load("res://scenes/Tank/Bullet.tscn")
	_lives = 5
	_hp = 20
	_bullet_position = $BodyTank/Gun/BulletPosition
	_moving_sound = $MovingSound
	_gun = $BodyTank/Gun
	_joystick = $Joystick
	_aim = $Aim
	_start_position = global_position
	_aim.init(true)
	
	if _aim != null:
		_aim.init(true)
		if not _aim.use_move_vector.is_connected(_use_move_vector_aim):
			_aim.use_move_vector.connect(_use_move_vector_aim)
		if not _aim.fire_touch.is_connected(_fire_touch):
			_aim.fire_touch.connect(_fire_touch)
	
	if not _joystick.use_move_vector.is_connected(_use_move_vector):
		_joystick.use_move_vector.connect(_use_move_vector)
	
	_tween = Tween.new()
	_shoot_timer = Timer.new()
	_shoot_timer.wait_time = 1.0
	_shoot_timer.one_shot = true
