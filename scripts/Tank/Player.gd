class_name Player
extends KinematicBody2D

signal health_changed(current_health, max_health)
signal lives_changed(current_lives)
signal money_changed(current_money)

# region private fields
var _speed: int = 250
var _hp: int
var _max_hp: int
var _lives: int
var _is_moving: bool = false
var _is_scope_enabled: bool = true
var _normal_movement_volume: float = 0.0
var _damage: int = 30
var _velocity: Vector2 = Vector2.ZERO
var _bullet_position: Position2D
var _shoot_timer: Timer
var _moving_sound: AudioStreamPlayer
var _tween: Tween
var _joystick: CanvasLayer
var _body: Sprite
var _gun: Sprite
var _aim: Node
var _type_bullet: int = 0  # PLASMA
var _start_position: Vector2
var _type_body: int = 1   # Medium
var _type_gun: int = 1    # Medium
var _color: int = 0       # Brown
var _money: int = 0
# endregion

var _bullet_scene: PackedScene

# TypeBullet constants
const PLASMA: int = 0
const MEDIUM: int = 1
const LIGHT: int = 2

# BodyEnum constants
const BODY_LIGHT: int = 0
const BODY_MEDIUM: int = 1
const BODY_HEAVY: int = 2
const BODY_LMEDIUM: int = 3
const BODY_MHEAVY: int = 4

# GunEnum constants
const GUN_LIGHT: int = 0
const GUN_MEDIUM: int = 1
const GUN_HEAVY: int = 2
const GUN_LMEDIUM: int = 3
const GUN_MHEAVY: int = 4

# ColorEnum constants
const COLOR_BROWN: int = 0
const COLOR_GREEN: int = 1
const COLOR_AZURE: int = 2

func get_speed() -> int:
	return _speed

func set_speed(value: int):
	if value > 0 and value <= 800:
		_speed = value

func _ready():
	_bullet_scene = load("res://scenes/Tank/Bullet.tscn")
	_body = get_node("BodyTank")
	_lives = 3
	_hp = 100
	_max_hp = _hp
	_bullet_position = get_node("BodyTank/Gun/BulletPosition")
	_moving_sound = get_node("MovingSound")
	_gun = get_node("BodyTank/Gun")
	_joystick = get_node("Joystick")
	_aim = get_node("Aim")
	_start_position = global_position
	emit_signal("money_changed", _money)
	
	if _aim != null:
		_aim.init(true)
		if not _aim.is_connected("use_move_vector", self, "use_move_vector_aim"):
			_aim.connect("use_move_vector", self, "use_move_vector_aim")
		if not _aim.is_connected("fire_touch", self, "fire_touch"):
			_aim.connect("fire_touch", self, "fire_touch")
	
	if _joystick != null:
		if not _joystick.is_connected("use_move_vector", self, "use_move_vector"):
			_joystick.connect("use_move_vector", self, "use_move_vector")
	
	_tween = Tween.new()
	_shoot_timer = Timer.new()
	_shoot_timer.wait_time = 1.0
	_shoot_timer.one_shot = true
	add_child(_shoot_timer)
	add_child(_tween)
	_configure_audio_players()
	if _moving_sound != null:
		_normal_movement_volume = _moving_sound.volume_db
	
	if AudioManager != null:
		if not AudioManager.is_connected("sfx_volume_changed", self, "_on_sfx_volume_changed"):
			AudioManager.connect("sfx_volume_changed", self, "_on_sfx_volume_changed")
	
	if GameManager != null:
		if not GameManager.is_connected("scope_toggled", self, "_toggle_scope"):
			GameManager.connect("scope_toggled", self, "_toggle_scope")
		_is_scope_enabled = GameManager.get_scope_enabled()
	else:
		_load_initial_scope_state()

func _on_sfx_volume_changed(value: float):
	var db_value = linear2db(value)
	_normal_movement_volume = db_value
	if _moving_sound.playing:
		_moving_sound.volume_db = db_value

func _load_initial_scope_state():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		_is_scope_enabled = config.get_value("game", "scope_enabled", true)
	else:
		_is_scope_enabled = true

func _toggle_scope(checkbox_value: bool):
	_is_scope_enabled = checkbox_value
	update()

func _configure_audio_players():
	if _moving_sound != null:
		_moving_sound.bus = "SFX"

func use_move_vector(move_vector: Vector2):
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

func fire_touch():
	if _shoot_timer.time_left > 0:
		return
	
	var bullet = _bullet_scene.instance()
	bullet.global_position = _bullet_position.global_position
	bullet.rotation_degrees = _gun.global_rotation_degrees
	get_tree().root.add_child(bullet)
	bullet.init(_type_bullet, true, _damage)
	var muzzle_flash = get_node("ShotAnimation")
	muzzle_flash.global_position = _bullet_position.global_position
	muzzle_flash.frame = 0
	muzzle_flash.play("Fire")
	_shoot_timer.start()

func use_move_vector_aim(move_vector: Vector2):
	_rotate_player_mobile_aim(move_vector)

func _physics_process(delta):
	_get_input()
	_velocity = move_and_slide(_velocity)

func _get_input():
	_move()
	_change_bullet()

func _on_Plasma_pressed():
	_type_bullet = PLASMA

func _on_SmallShell_pressed():
	_type_bullet = LIGHT

func _on_MediumShell_pressed():
	_type_bullet = MEDIUM

func _change_bullet():
	var bullet_changed = false
	if Input.is_action_just_pressed("plasma"):
		_type_bullet = PLASMA
		bullet_changed = true
	elif Input.is_action_just_pressed("medium_bullet"):
		_type_bullet = MEDIUM
		bullet_changed = true
	elif Input.is_action_just_pressed("light_bullet"):
		_type_bullet = LIGHT
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
	rotation_degrees = rad2deg(direction.angle()) + 90

func _rotate_player_mobile_aim(direction: Vector2):
	_gun.global_rotation_degrees = rad2deg(direction.angle()) + 90

func _rotate_player(direction: Vector2):
	if direction.x > 0:
		if direction.y < 0:
			rotation_degrees = 45
		elif direction.y > 0:
			rotation_degrees = 135
		else:
			rotation_degrees = 90
	elif direction.x < 0:
		if direction.y < 0:
			rotation_degrees = 315
		elif direction.y > 0:
			rotation_degrees = 225
		else:
			rotation_degrees = 270
	elif direction.y > 0:
		rotation_degrees = 180
	elif direction.y < 0:
		rotation_degrees = 0

func _fire():
	if Input.is_action_just_pressed("fire"):
		fire_touch()

func take_damage(damage: int):
	_hp -= damage
	emit_signal("health_changed", _hp, get_max_health())
	
	if _hp <= 0:
		_destroy()

func _destroy():
	_lives -= 1
	emit_signal("lives_changed", _lives)
	
	if _lives != 0:
		_revive()
	else:
		queue_free()

func _revive():
	_hp = get_max_health()
	global_position = _start_position
	emit_signal("health_changed", _hp, get_max_health())

func _fade_sound():
	if _tween.is_connected("tween_completed", self, "_on_tween_complete"):
		_tween.disconnect("tween_completed", self, "_on_tween_complete")
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
	_tween.connect("tween_completed", self, "_on_tween_complete")

func _on_tween_complete(_obj, _key):
	_moving_sound.stop()
	_moving_sound.volume_db = _normal_movement_volume

func _process(delta):
	update()

func _draw():
	if _aim.get_is_joystick_active() and _is_scope_enabled:
		var global_muzzle_pos = _bullet_position.global_position
		var gun_angle = _gun.global_rotation
		var direction = Vector2(1, 0).rotated(gun_angle)
		var perpendicular = Vector2(direction.y, -direction.x)
		var ray_length = 1000.0
		var global_ray_end = global_muzzle_pos + perpendicular * ray_length
		var local_muzzle_pos = to_local(global_muzzle_pos)
		var local_ray_end = to_local(global_ray_end)
		draw_line(local_muzzle_pos, local_ray_end, Color.red, 2.0)

func select_type(body_type: int, gun_type: int, color_type: int):
	_type_body = body_type
	_type_gun = gun_type
	_color = color_type
	
	_update_tank_appearance()
	_update_stats()

func _update_stats():
	match _type_body:
		BODY_LIGHT:
			_hp = 80
			_damage = 20
		BODY_MEDIUM:
			_hp = 100
			_damage = 30
		BODY_HEAVY:
			_hp = 150
			_damage = 50
		BODY_LMEDIUM:
			_hp = 120
			_damage = 25
		BODY_MHEAVY:
			_hp = 130
			_damage = 40
		_:
			_hp = 100
			_damage = 30
	emit_signal("health_changed", _hp, get_max_health())

func _get_body_file_name() -> String:
	match _type_body:
		BODY_LIGHT:
			return "Hull_05"
		BODY_MEDIUM:
			return "Hull_02"
		BODY_HEAVY:
			return "Hull_06"
		BODY_LMEDIUM:
			return "Hull_01"
		BODY_MHEAVY:
			return "Hull_03"
		_:
			return "Hull_02"

func _get_gun_file_name() -> String:
	match _type_gun:
		GUN_LIGHT:
			return "Gun_01"
		GUN_MEDIUM:
			return "Gun_03"
		GUN_HEAVY:
			return "Gun_08"
		GUN_LMEDIUM:
			return "Gun_04"
		GUN_MHEAVY:
			return "Gun_07"
		_:
			return "Gun_01"

func get_current_health() -> int:
	return _hp

func get_lives() -> int:
	return _lives

func heal(amount: int):
	var old_health = _hp
	_hp += amount
	_hp = min(_hp, get_max_health())
	emit_signal("health_changed", _hp, get_max_health())

func get_max_health() -> int:
	match _type_body:
		BODY_LIGHT:
			return 80
		BODY_MEDIUM:
			return 100
		BODY_HEAVY:
			return 150
		BODY_LMEDIUM:
			return 120
		BODY_MHEAVY:
			return 130
		_:
			return 100

func get_money() -> int:
	return _money

func add_money(amount: int):
	_money += amount
	emit_signal("money_changed", _money)

func spend_money(amount: int) -> bool:
	if _money >= amount:
		_money -= amount
		emit_signal("money_changed", _money)
		return true
	return false

func _update_tank_appearance():
	var color_folder = _get_color_folder()
	var body_file_name = _get_body_file_name()
	var gun_file_name = _get_gun_file_name()
	
	var body_path = "res://assets/future_tanks/PNG/Hulls_" + color_folder + "/" + body_file_name + ".png"
	var gun_path = "res://assets/future_tanks/PNG/Weapon_" + color_folder + "/" + gun_file_name + ".png"
	
	var body_texture = load(body_path)
	var gun_texture = load(gun_path)
	
	if body_texture != null:
		_body.texture = body_texture
	if gun_texture != null:
		_gun.texture = gun_texture

func _get_color_folder() -> String:
	match _color:
		COLOR_BROWN:
			return "Color_A"
		COLOR_GREEN:
			return "Color_B"
		COLOR_AZURE:
			return "Color_C"
		_:
			return "Color_A"

func take_heal(amount: int):
	_hp += amount
	if _hp > _max_hp:
		_hp = _max_hp
	emit_signal("health_changed", _hp, get_max_health())
