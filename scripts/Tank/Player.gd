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
var _invul_tween: Tween

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

	# Неуязвимость при старте уровня
	_start_invulnerability(3.0)

	if AudioManager != null:
		if not AudioManager.sfx_volume_changed.is_connected(_on_sfx_volume_changed):
			AudioManager.sfx_volume_changed.connect(_on_sfx_volume_changed)
	
	if GameManager != null:
		if not GameManager.on_visual_scope_updated.is_connected(_toggle_scope):
			GameManager.on_visual_scope_updated.connect(_toggle_scope)
		is_scope_on = GameManager.is_scope_currently_enabled()

	if SaveManager != null:
		if not SaveManager.settings_changed.is_connected(_apply_camera_fov):
			SaveManager.settings_changed.connect(_apply_camera_fov)
	call_deferred("_apply_camera_fov")

func _connect_hud_controls():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		_joystick = hud.find_child("Joystick", true)
		_aim = hud.find_child("Aim", true)

		if _joystick:
			if not _joystick.use_move_vector.is_connected(use_move_vector):
				_joystick.use_move_vector.connect(use_move_vector)
		if _aim:
			_aim.init(true)
			if not _aim.use_move_vector.is_connected(use_move_vector_aim):
				_aim.use_move_vector.connect(use_move_vector_aim)

func _load_all_data():
	if SaveManager != null:
		SaveManager.load_game()
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
	rotation = move_vector.angle() + PI/2
	_handle_movement_sound(velocity)

func fire_touch():
	if _shoot_timer.time_left > 0: return

	if AudioManager != null:
		AudioManager.play_bullet_sound(_type_bullet, global_position)

	var bullet = _bullet_scene.instantiate()
	bullet.global_position = _bullet_position.global_position
	bullet.rotation_degrees = _gun.global_rotation_degrees
	get_parent().add_child(bullet)

	# УРОН ПО ТИПАМ СНАРЯДОВ (фиксированный по запросу)
	var base_bullet_damage = 25
	match _type_bullet:
		PLASMA: base_bullet_damage = 25
		MEDIUM: base_bullet_damage = 40
		LIGHT: base_bullet_damage = 20

	# Учитываем бафф урона от базы, если он есть
	var final_damage = int(base_bullet_damage * _base_damage_mult)
	bullet.init(_type_bullet, true, final_damage)

	var muzzle_flash = get_node_or_null("ShotAnimation")
	if muzzle_flash:
		muzzle_flash.global_position = _bullet_position.global_position
		muzzle_flash.frame = 0
		muzzle_flash.play("Fire")

	# Запуск таймера стрельбы с учетом баффа скорости атаки
	_shoot_timer.start(_get_reload_time() * _base_rof_mult)

func _get_reload_time() -> float:
	var reload_base = 1.0
	match _type_gun:
		GUN_LIGHT: reload_base = 0.65
		GUN_MEDIUM: reload_base = 1.0
		GUN_HEAVY: reload_base = 1.8
		GUN_LMEDIUM: reload_base = 0.9
		GUN_MHEAVY: reload_base = 0.8

	var rof_color_bonus = 0.0
	match _color:
		COLOR_GREEN: rof_color_bonus = 0.1
		COLOR_AZURE: rof_color_bonus = 0.05

	return max(0.1, reload_base + rof_color_bonus)

func _handle_auto_shoot():
	if _aim != null and _aim.get_is_joystick_active():
		if _aim.move_vector.length() > 0.2:
			fire_touch()

func use_move_vector_aim(move_vector: Vector2):
	var desired_dir = move_vector.normalized()
	var final_angle = move_vector.angle() + PI/2

	# --- Агрессивный автоприцел ---
	var is_assist_on = true
	if SaveManager != null:
		is_assist_on = SaveManager.get_setting("game", "aim_assist", true)

	if is_assist_on:
		var best_enemy = null
		var min_angle_diff = deg_to_rad(35.0) # Порог срабатывания (градусы)

		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				# 1. Проверка видимости: автоприцел работает только на тех, кого игрок видит (не за стеной)
				if not _is_enemy_visible_for_assist(enemy):
					continue

				# 2. Проверка нахождения на экране (визуальная видимость игроком)
				if not _is_enemy_on_screen(enemy):
					continue

				var dir_to_enemy = (enemy.global_position - global_position).normalized()
				var angle_diff = abs(desired_dir.angle_to(dir_to_enemy))

				if angle_diff < min_angle_diff:
					min_angle_diff = angle_diff
					best_enemy = enemy

		if best_enemy:
			final_angle = (best_enemy.global_position - global_position).angle() + PI/2
	# -----------------------------

	_gun.global_rotation = final_angle

# Функция проверки видимости врага для автоприцела
func _is_enemy_visible_for_assist(enemy: Node) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, enemy.global_position)
	query.exclude = [self, enemy] # Игнорируем себя и цель
	query.collision_mask = 1 # Слой стен (предположительно 1)

	var result = space_state.intersect_ray(query)
	return result.is_empty() # Если на пути луча ничего нет, враг видим

# Функция проверки нахождения врага на экране (визуально для игрока)
func _is_enemy_on_screen(enemy: Node) -> bool:
	var viewport_rect = get_viewport().get_visible_rect()
	var canvas_transform = get_viewport().get_canvas_transform()
	var screen_pos = canvas_transform * enemy.global_position
	return viewport_rect.has_point(screen_pos)

func _physics_process(delta):
	_get_input()
	_handle_auto_shoot()
	_check_base_buffs()
	move_and_slide()
	queue_redraw()

func _check_base_buffs():
	var in_range = false
	var base_found = null

	# Проверяем все базы игрока на уровне
	for b in get_tree().get_nodes_in_group("bases"):
		if b.get("type_base") == 0: # PLAYER
			var dist = global_position.distance_to(b.global_position)
			var radius = b.get("_heal_radius")
			if dist <= radius:
				apply_base_buffs(b.get("_damage_bonus"), b.get("_armor_bonus"), b.get("_rof_bonus"))
				in_range = true
				base_found = b
				break

	if not in_range:
		apply_base_buffs(1.0, 0.0, 1.0) # Мгновенный сброс баффов

	# Обновляем состояние иконки в HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_buff_icon_visible"):
		hud.set_buff_icon_visible(in_range)

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
	if _is_invulnerable: return

	super.take_damage(damage)
	health_changed.emit(_hp, _max_hp)

	# Щит на 1 секунду после получения урона (если игрок выжил)
	if _hp > 0:
		_start_invulnerability(1.0)

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
	_start_invulnerability(3.0)

func _start_invulnerability(duration: float):
	_is_invulnerable = true

	if _invul_tween:
		_invul_tween.kill()

	_invul_tween = create_tween().set_loops()
	_invul_tween.tween_property(self, "modulate:a", 0.3, 0.2)
	_invul_tween.tween_property(self, "modulate:a", 1.0, 0.2)

	get_tree().create_timer(duration).timeout.connect(func():
		_is_invulnerable = false
		if _invul_tween:
			_invul_tween.kill()
		modulate.a = 1.0
	)

func select_type(body_type: int, gun_type: int, color_type: int):
	_type_body = body_type; _type_gun = gun_type; _color = color_type
	_update_stats()
	_update_appearance()

func _update_stats():
	var hp_base = 100; var speed_base = 250; var dmg_mod = 1.0; var reload_base = 1.0; var armor_base = 0.0
	match _type_body:
		BODY_LIGHT: hp_base = 80; speed_base = 280; armor_base = -0.15
		BODY_MEDIUM: hp_base = 100; speed_base = 250; armor_base = 0.0
		BODY_HEAVY: hp_base = 250; speed_base = 200; armor_base = 0.3
		BODY_LMEDIUM: hp_base = 120; speed_base = 260; armor_base = 0.1
		BODY_MHEAVY: hp_base = 175; speed_base = 220; armor_base = 0.2
	match _type_gun:
		GUN_LIGHT: dmg_mod = 0.7; reload_base = 0.65
		GUN_MEDIUM: dmg_mod = 1.0; reload_base = 1.0
		GUN_HEAVY: dmg_mod = 2.5; reload_base = 1.8
		GUN_LMEDIUM: dmg_mod = 1.15; reload_base = 0.9
		GUN_MHEAVY: dmg_mod = 1.3; reload_base = 0.8

	var hp_bonus = 0; var speed_bonus = 0; var armor_bonus = 0.0; var rof_bonus = 0.0
	match _color:
		COLOR_GREEN: hp_bonus = 30; speed_bonus = -15; armor_bonus = 0.1; rof_bonus = 0.1
		COLOR_AZURE: hp_bonus = 5; speed_bonus = 20; armor_bonus = -0.1; rof_bonus = 0.05

	_max_hp = hp_base + hp_bonus
	_hp = _max_hp
	_speed = speed_base + speed_bonus
	_damage = int(30 * dmg_mod)
	_armor = clamp(armor_base + armor_bonus, -0.9, 0.9)

	if _shoot_timer: _shoot_timer.wait_time = max(0.1, reload_base + rof_bonus)
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

	# Крепление к корпусу: как у Enemy — offset.y = -position.y, иначе спрайт «уезжает» по Y.
	var gun_mount_y := [40.0, 42.0, 40.0, 36.0, 38.0]
	if _gun:
		var my: float = gun_mount_y[_type_body]
		_gun.position = Vector2(0, my)
		_gun.offset = Vector2(0, -my)

func take_heal(amount: int):
	_hp = min(_hp + amount, _max_hp)
	health_changed.emit(_hp, _max_hp)
	_update_damage_visuals()

func _apply_camera_fov():
	var cam = get_node_or_null("Camera2D") as Camera2D
	if cam == null or GameManager == null:
		return
	var z = GameManager.get_camera_zoom_from_settings()
	cam.zoom = Vector2(z, z)

func _draw():
	if is_scope_on and _aim != null and _aim.get_is_joystick_active():
		var direction = Vector2(0, -1).rotated(_gun.global_rotation)
		var range_len = 600.0
		match _type_bullet:
			MEDIUM: range_len = 275.0
			LIGHT: range_len = 900.0
		draw_line(to_local(_bullet_position.global_position), to_local(_bullet_position.global_position + direction * range_len), Color(1, 0, 0, 0.5), 2.0)
