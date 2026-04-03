class_name Player
extends CharacterBody2D

signal health_changed(current_health, max_health)
signal lives_changed(current_lives)
signal money_changed(current_money)

# region private fields
var _speed: int = 250
var _hp: int
var _max_hp: int
var _lives: int
var _is_moving: bool = false
var is_scope_on: bool = true
var _normal_movement_volume: float = 0.0
var _damage: int = 30
var _velocity: Vector2 = Vector2.ZERO
var _bullet_position: Marker2D
var _shoot_timer: Timer
var _moving_sound: AudioStreamPlayer
var _fade_tween: Tween
var _joystick: Node
var _body: Sprite2D
var _gun: Sprite2D
var _aim: Node
var _type_bullet: int = 0 # По умолчанию ПЛАЗМА (PLASMA = 0)
var _start_position: Vector2
var _type_body: int = 1
var _type_gun: int = 1
var _color: int = 0
var _money: int = 0
# endregion

var _bullet_scene: PackedScene

const PLASMA: int = 0
const MEDIUM: int = 1
const LIGHT: int = 2

const BODY_LIGHT: int = 0
const BODY_MEDIUM: int = 1
const BODY_HEAVY: int = 2
const BODY_LMEDIUM: int = 3
const BODY_MHEAVY: int = 4

const GUN_LIGHT: int = 0
const GUN_MEDIUM: int = 1
const GUN_HEAVY: int = 2
const GUN_LMEDIUM: int = 3
const GUN_MHEAVY: int = 4

const COLOR_BROWN: int = 0
const COLOR_GREEN: int = 1
const COLOR_AZURE: int = 2

func _ready():
	_bullet_scene = load("res://scenes/Tank/Bullet.tscn")
	_body = get_node("BodyTank")
	_lives = 3
	_bullet_position = get_node("BodyTank/Gun/BulletPosition")
	_moving_sound = get_node("MovingSound")
	_gun = get_node("BodyTank/Gun")
	_joystick = get_node("Joystick")
	_aim = get_node("Aim")
	_start_position = global_position

	_shoot_timer = Timer.new()
	_shoot_timer.one_shot = true
	add_child(_shoot_timer)

	# Загружаем сохраненные настройки танка и деньги
	_load_all_data()

	if _aim != null:
		_aim.init(true)
		if not _aim.use_move_vector.is_connected(use_move_vector_aim):
			_aim.use_move_vector.connect(use_move_vector_aim)
		if not _aim.fire_touch.is_connected(fire_touch):
			_aim.fire_touch.connect(fire_touch)
	
	if _joystick != null:
		if not _joystick.use_move_vector.is_connected(use_move_vector):
			_joystick.use_move_vector.connect(use_move_vector)
	
	_configure_audio_players()
	if _moving_sound != null:
		_normal_movement_volume = _moving_sound.volume_db
	
	if AudioManager != null:
		if not AudioManager.sfx_volume_changed.is_connected(_on_sfx_volume_changed):
			AudioManager.sfx_volume_changed.connect(_on_sfx_volume_changed)
	
	if GameManager != null:
		if not GameManager.on_visual_scope_updated.is_connected(_toggle_scope):
			GameManager.on_visual_scope_updated.connect(_toggle_scope)
		is_scope_on = GameManager.is_scope_currently_enabled()
	else:
		is_scope_on = SaveManager.get_setting("game", "scope_enabled", true)

func _load_all_data():
	if SaveManager != null:
		# Сначала подписываемся на сигнал, потом загружаем
		if not SaveManager.money_loaded.is_connected(_on_money_loaded):
			SaveManager.money_loaded.connect(_on_money_loaded)

		SaveManager.load_game()

		_type_body = SaveManager.get_player_stat("body_type", 1)
		_type_gun = SaveManager.get_player_stat("gun_type", 1)
		_color = SaveManager.get_player_stat("color_type", 0)
		_money = SaveManager.save_data.get("money", 0)

		select_type(_type_body, _type_gun, _color)
		money_changed.emit(_money)

func _on_money_loaded(amount: int):
	_money = amount
	money_changed.emit(_money)

func _on_sfx_volume_changed(value: float):
	var db_value = linear_to_db(value)
	_normal_movement_volume = db_value
	if _moving_sound.playing:
		_moving_sound.volume_db = db_value

func _toggle_scope(checkbox_value: bool):
	is_scope_on = checkbox_value
	queue_redraw()

func _configure_audio_players():
	if _moving_sound != null:
		_moving_sound.bus = "SFX"

func use_move_vector(move_vector: Vector2):
	var joystick_velocity = move_vector * _speed
	velocity = joystick_velocity
	move_and_slide()
	_rotate_player_mobile(move_vector)
	_handle_movement_sound(joystick_velocity)

func _handle_movement_sound(movement_velocity: Vector2):
	var is_moving_now = movement_velocity.length() > 0.1
	if is_moving_now:
		if not _is_moving:
			if _fade_tween != null and _fade_tween.is_running():
				_fade_tween.kill()
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
	
	var bullet = _bullet_scene.instantiate()
	bullet.global_position = _bullet_position.global_position
	bullet.rotation_degrees = _gun.global_rotation_degrees
	get_tree().root.add_child(bullet)
	bullet.init(_type_bullet, true, _damage)

	var muzzle_flash = get_node_or_null("ShotAnimation")
	if muzzle_flash:
		muzzle_flash.global_position = _bullet_position.global_position
		muzzle_flash.frame = 0
		muzzle_flash.play("Fire")
	_shoot_timer.start()

func use_move_vector_aim(move_vector: Vector2):
	_rotate_player_mobile_aim(move_vector)

func _physics_process(delta):
	_get_input()
	move_and_slide()
	queue_redraw()

func _input(event):
	# Игнорируем любые события мыши/тача в _input,
	# чтобы они не эмулировали стрельбу при нажатии на джойстики.
	# Вместо этого используем _unhandled_input для стрельбы в пустом месте.
	pass

func _unhandled_input(event):
	# Стрельба по клику/тапу в пустом месте (не на джойстике)
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		# Явно проверяем, не попадает ли клик в зону джойстиков,
		# так как _unhandled_input может вызываться, если джойстик не поглотил событие на 100%
		if _joystick and _joystick.has_method("is_pos_inside") and _joystick.is_pos_inside(event.position):
			return
		if _aim and _aim.has_method("is_pos_inside") and _aim.is_pos_inside(event.position):
			return

		fire_touch()

func _get_input():
	_move()
	_change_bullet()

func _change_bullet():
	if Input.is_action_just_pressed("plasma"):
		_on_Plasma_pressed()
	elif Input.is_action_just_pressed("medium_bullet"):
		_on_MediumShell_pressed()
	elif Input.is_action_just_pressed("light_bullet"):
		_on_SmallShell_pressed()

func _on_Plasma_pressed():
	_type_bullet = PLASMA
	_shoot_timer.start()

func _on_SmallShell_pressed():
	_type_bullet = LIGHT
	_shoot_timer.start()

func _on_MediumShell_pressed():
	_type_bullet = MEDIUM
	_shoot_timer.start()

func _move():
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_dir.length() > 0:
		velocity = input_dir.normalized() * _speed
		_rotate_player(velocity)
		_handle_movement_sound(velocity)
	else:
		velocity = Vector2.ZERO
		_handle_movement_sound(Vector2.ZERO)

func _rotate_player_mobile(direction: Vector2):
	rotation_degrees = rad_to_deg(direction.angle()) + 90

func _rotate_player_mobile_aim(direction: Vector2):
	_gun.global_rotation_degrees = rad_to_deg(direction.angle()) + 90

func _rotate_player(direction: Vector2):
	rotation = direction.angle() + PI/2

func take_damage(damage: int):
	_hp -= damage
	health_changed.emit(_hp, _max_hp)
	if _hp <= 0:
		_destroy()

func _destroy():
	_lives -= 1
	lives_changed.emit(_lives)
	if _lives > 0:
		_revive()
	else:
		# Сохраняем прогресс перед выходом
		SaveManager.save_game()
		queue_free()

func _revive():
	_hp = _max_hp
	global_position = _start_position
	health_changed.emit(_hp, _max_hp)

func _fade_sound():
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_moving_sound, "volume_db", -80.0, 0.3)
	_fade_tween.finished.connect(_on_tween_complete)

func _on_tween_complete():
	_moving_sound.stop()
	_moving_sound.volume_db = _normal_movement_volume

func select_type(body_type: int, gun_type: int, color_type: int):
	_type_body = body_type
	_type_gun = gun_type
	_color = color_type
	_update_tank_appearance()
	_update_stats()

func _update_stats():
	var hp_base = 100
	var speed_base = 250
	var dmg_mod = 1.0
	var reload_base = 1.0

	match _type_body:
		BODY_LIGHT: hp_base = 80; speed_base = 300
		BODY_MEDIUM: hp_base = 100; speed_base = 250
		BODY_HEAVY: hp_base = 150; speed_base = 180
		BODY_LMEDIUM: hp_base = 120; speed_base = 220
		BODY_MHEAVY: hp_base = 135; speed_base = 200

	match _type_gun:
		GUN_LIGHT: dmg_mod = 0.8; reload_base = 0.5
		GUN_MEDIUM: dmg_mod = 1.0; reload_base = 1.0
		GUN_HEAVY: dmg_mod = 1.5; reload_base = 2.5
		GUN_LMEDIUM: dmg_mod = 1.1; reload_base = 0.8
		GUN_MHEAVY: dmg_mod = 1.3; reload_base = 1.8

	var hp_bonus = 0
	var speed_bonus = 0
	var reload_bonus = 0

	match _color:
		COLOR_GREEN: hp_bonus = 10; speed_bonus = 20; reload_bonus = -0.1
		COLOR_AZURE: hp_bonus = 20; speed_bonus = -10; reload_bonus = -0.2

	_max_hp = hp_base + hp_bonus
	_hp = _max_hp
	_speed = speed_base + speed_bonus
	_damage = int(30 * dmg_mod)
	if _shoot_timer != null:
		_shoot_timer.wait_time = max(0.1, reload_base + reload_bonus)

	health_changed.emit(_hp, _max_hp)

func get_money() -> int:
	return _money

func add_money(amount: int):
	_money += amount
	money_changed.emit(_money)
	SaveManager.save_game()

func spend_money(amount: int) -> bool:
	if _money >= amount:
		_money -= amount
		money_changed.emit(_money)
		SaveManager.save_game()
		return true
	return false

func _update_tank_appearance():
	var color_folder = _get_color_folder()
	var body_path = "res://assets/future_tanks/PNG/Hulls_" + color_folder + "/" + _get_body_file_name() + ".png"
	var gun_path = "res://assets/future_tanks/PNG/Weapon_" + color_folder + "/" + _get_gun_file_name() + ".png"
	
	_body.texture = load(body_path)
	_gun.texture = load(gun_path)

	var gun_offset = 35
	if _type_body == BODY_LIGHT or _type_body == BODY_LMEDIUM:
		gun_offset = 0
	_gun.position = Vector2(0, gun_offset)

func _get_body_file_name() -> String:
	match _type_body:
		BODY_LIGHT: return "Hull_05"
		BODY_HEAVY: return "Hull_06"
		BODY_LMEDIUM: return "Hull_01"
		BODY_MHEAVY: return "Hull_03"
		_: return "Hull_02"

func _get_gun_file_name() -> String:
	match _type_gun:
		GUN_LIGHT: return "Gun_01"
		GUN_MEDIUM: return "Gun_03"
		GUN_HEAVY: return "Gun_08"
		GUN_LMEDIUM: return "Gun_04"
		GUN_MHEAVY: return "Gun_07"
		_: return "Gun_01"

func _get_color_folder() -> String:
	match _color:
		COLOR_BROWN: return "Color_A"
		COLOR_GREEN: return "Color_B"
		COLOR_AZURE: return "Color_C"
		_: return "Color_A"

func take_heal(amount: int):
	_hp = min(_hp + amount, _max_hp)
	health_changed.emit(_hp, _max_hp)

func _draw():
	if is_scope_on and _aim != null and _aim.get_is_joystick_active():
		var muzzle_pos = _bullet_position.global_position
		var gun_angle = _gun.global_rotation
		var direction = Vector2(0, -1).rotated(gun_angle)
		var ray_length = 1000.0
		var local_muzzle = to_local(muzzle_pos)
		var local_end = to_local(muzzle_pos + direction * ray_length)
		draw_line(local_muzzle, local_end, Color(1, 0, 0, 0.5), 2.0)
