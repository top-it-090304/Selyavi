class_name Player
extends Tank

signal health_changed(current_health, max_health)
signal lives_changed(current_lives)
signal money_changed(current_money)
signal ammo_changed(type)

var _lives: int = 3
var _money: int = 0
var _speed: int = 250
var _start_position: Vector2
var is_scope_on: bool = true

var _joystick: Node
var _aim: Node
var _type_bullet: int = 0
var _type_body: int = 1
var _type_gun: int = 1
var _color: int = 0

const PLASMA: int = 0
const MEDIUM: int = 1
const LIGHT: int = 2

const BODY_LIGHT = 0; const BODY_MEDIUM = 1; const BODY_HEAVY = 2; const BODY_LMEDIUM = 3; const BODY_MHEAVY = 4
const GUN_LIGHT = 0; const GUN_MEDIUM = 1; const GUN_HEAVY = 2; const GUN_LMEDIUM = 3; const GUN_MHEAVY = 4
const COLOR_BROWN = 0; const COLOR_GREEN = 1; const COLOR_AZURE = 2

func _ready():
	add_to_group("players")
	_init_base_tank()
	_start_position = global_position
	_load_all_data()

	call_deferred("_connect_hud_controls")

	if AudioManager != null:
		AudioManager.sfx_volume_changed.connect(_on_sfx_volume_changed)
	
	if GameManager != null:
		GameManager.on_visual_scope_updated.connect(_toggle_scope)
		is_scope_on = GameManager.is_scope_currently_enabled()

func _connect_hud_controls():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		_joystick = hud.get_node_or_null("HealthPanel/BottomLeft/Joystick")
		_aim = hud.get_node_or_null("HealthPanel/BottomRight/Aim")

		if _joystick:
			if _joystick.use_move_vector.is_connected(use_move_vector):
				_joystick.use_move_vector.disconnect(use_move_vector)
			_joystick.use_move_vector.connect(use_move_vector)
		if _aim:
			_aim.init(true)
			if _aim.use_move_vector.is_connected(use_move_vector_aim):
				_aim.use_move_vector.disconnect(use_move_vector_aim)
			if _aim.fire_touch.is_connected(fire_touch):
				_aim.fire_touch.disconnect(fire_touch)
			_aim.use_move_vector.connect(use_move_vector_aim)
			_aim.fire_touch.connect(fire_touch)

func _load_all_data():
	if SaveManager != null:
		SaveManager.load_game()
		# Важно: берем деньги через get_player_stat или напрямую из словаря по ключу
		_money = SaveManager.save_data.get("money", 0)
		_type_body = SaveManager.get_player_stat("body_type", 1)
		_type_gun = SaveManager.get_player_stat("gun_type", 1)
		_color = SaveManager.get_player_stat("color_type", 0)

		select_type(_type_body, _type_gun, _color)
		money_changed.emit(_money)

func get_current_health() -> int: return _hp
func get_max_health() -> int: return _max_hp
func get_lives() -> int: return _lives
func get_money() -> int: return _money

func _on_sfx_volume_changed(value: float):
	_normal_movement_volume = linear_to_db(value)
	if _moving_sound and _moving_sound.playing:
		_moving_sound.volume_db = _normal_movement_volume

func _toggle_scope(checkbox_value: bool):
	is_scope_on = checkbox_value
	queue_redraw()

func use_move_vector(move_vector: Vector2):
	velocity = move_vector * _speed
	move_and_slide()
	rotation = move_vector.angle() + PI/2
	_handle_movement_sound(velocity)

func fire_touch():
	if _shoot_timer.time_left > 0: return
	
	var bullet = _bullet_scene.instantiate()
	bullet.global_position = _bullet_position.global_position
	bullet.rotation_degrees = _gun.global_rotation_degrees
	get_parent().add_child(bullet)
	bullet.init(_type_bullet, true, _damage)

	var muzzle_flash = get_node_or_null("ShotAnimation")
	if muzzle_flash:
		muzzle_flash.global_position = _bullet_position.global_position
		muzzle_flash.frame = 0
		muzzle_flash.play("Fire")
	_shoot_timer.start()

func use_move_vector_aim(move_vector: Vector2):
	_gun.global_rotation = move_vector.angle() + PI/2

func _physics_process(_delta):
	_get_input()
	move_and_slide()
	queue_redraw()

func _get_input():
	if _joystick == null or not _joystick.get_is_joystick_active():
		var input_dir = Vector2.ZERO
		input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

		if input_dir.length() > 0:
			velocity = input_dir.normalized() * _speed
			rotation = velocity.angle() + PI/2
			_handle_movement_sound(velocity)
		else:
			velocity = Vector2.ZERO
			_handle_movement_sound(Vector2.ZERO)

func _on_ammo_selected(type: int):
	_type_bullet = type
	ammo_changed.emit(_type_bullet)

func take_damage(damage: int):
	super.take_damage(damage)
	health_changed.emit(_hp, _max_hp)

func _destroy():
	_lives -= 1
	lives_changed.emit(_lives)
	if _lives > 0:
		_revive()
	else:
		SaveManager.save_game()
		super._destroy()

func _revive():
	_hp = _max_hp
	global_position = _start_position
	health_changed.emit(_hp, _max_hp)
	_update_damage_visuals()

func select_type(body_type: int, gun_type: int, color_type: int):
	_type_body = body_type; _type_gun = gun_type; _color = color_type
	_update_stats()
	_update_appearance()

func _update_stats():
	var hp_base = 100; var speed_base = 250; var dmg_mod = 1.0; var reload_base = 1.0
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

	_max_hp = hp_base + (20 if _color == COLOR_AZURE else 10 if _color == COLOR_GREEN else 0)
	_hp = _max_hp
	_speed = speed_base + (20 if _color == COLOR_GREEN else -10 if _color == COLOR_AZURE else 0)
	_damage = int(30 * dmg_mod)
	if _shoot_timer: _shoot_timer.wait_time = max(0.1, reload_base)
	health_changed.emit(_hp, _max_hp)

func add_money(amount: int):
	_money += amount
	money_changed.emit(_money)
	SaveManager.save_game()

func _update_appearance():
	var color_f = "Color_A" if _color == COLOR_BROWN else "Color_B" if _color == COLOR_GREEN else "Color_C"
	var b_name = ["Hull_05", "Hull_02", "Hull_06", "Hull_01", "Hull_03"][_type_body]
	var g_name = ["Gun_01", "Gun_03", "Gun_08", "Gun_04", "Gun_07"][_type_gun]
	if _body: _body.texture = load("res://assets/future_tanks/PNG/Hulls_" + color_f + "/" + b_name + ".png")
	if _gun: _gun.texture = load("res://assets/future_tanks/PNG/Weapon_" + color_f + "/" + g_name + ".png")
	if _gun: _gun.position = Vector2(0, 0 if (_type_body == BODY_LIGHT or _type_body == BODY_LMEDIUM) else 35)

func take_heal(amount: int):
	_hp = min(_hp + amount, _max_hp)
	health_changed.emit(_hp, _max_hp)

func _draw():
	if is_scope_on and _aim != null and _aim.get_is_joystick_active():
		var direction = Vector2(0, -1).rotated(_gun.global_rotation)
		draw_line(to_local(_bullet_position.global_position), to_local(_bullet_position.global_position + direction * 1000), Color(1, 0, 0, 0.5), 2.0)
