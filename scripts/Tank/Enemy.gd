class_name Enemy
extends Tank

signal enemy_died(type: int)

enum State { PATROL, CHASE }
enum TypeEnemy { LIGHT, MEDIUM, HEAVY, STATIONARY, TRIPLE, NONE }

# Ссылка на базу, которая создала этого врага
var creator_base: Node = null

# region Поля ИИ
var _current_state: int = State.PATROL
var _player: Node
var _base: Node
var _nav2d: NavigationAgent2D
var _ray_cast: RayCast2D
var _detection_area: Area2D
var _shot_flash: AnimatedSprite2D

@export var _type_enemy: TypeEnemy = TypeEnemy.NONE
@export var _patrol_speed: int = 90
@export var _chase_speed: int = 60 # Медленное приближение к игроку

var _fire_rate: float = 1.0
var _spread: float = 0.15
var _scan_angle: float = 0.0
var _scan_dir: int = 1
var _scan_wait_timer: float = 0.0
var _scan_limit: float = 45.0
# endregion

func get_enemy_type() -> int:
	return _type_enemy

func _ready():
	add_to_group("enemies")
	_init_base_tank() # Инициализация из Tank.gd

	_nav2d = get_node_or_null("NavigationAgent2D")
	_ray_cast = get_node_or_null("RayCast2D")
	_detection_area = get_node_or_null("DetectionArea")
	_shot_flash = get_node_or_null("ShotAnimation")

	if _ray_cast:
		_ray_cast.collide_with_areas = false # Не сталкиваемся с триггерами
		_ray_cast.add_exception(self)

	if _type_enemy == TypeEnemy.NONE: _randomize_enemy_type()
	_apply_enemy_stats()

	# Привязываем вспышку к дулу
	if _shot_flash and _bullet_position:
		if _shot_flash.get_parent() != _bullet_position:
			_shot_flash.get_parent().remove_child(_shot_flash)
			_bullet_position.add_child(_shot_flash)
		_shot_flash.position = Vector2.ZERO
		_shot_flash.rotation = 0

	# Поиск целей
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0: _player = players[0]

	for b in get_tree().get_nodes_in_group("bases"):
		if b.type_base == 0: _base = b; break

	if _detection_area:
		_detection_area.body_entered.connect(_on_detection_area_entered)
		_detection_area.body_exited.connect(_on_detection_area_exited)

	_shoot_timer.wait_time = _fire_rate

func _physics_process(delta):
	# Если цели потеряны (например, после перезагрузки), пробуем найти их снова
	if not is_instance_valid(_player) or not is_instance_valid(_base):
		_find_targets()
		if not is_instance_valid(_base): return # Если базы всё ещё нет, стоим
	
	_update_target()
	_aim_gun(delta)
	_update_ray_cast()
	_check_and_fire()
	_move_enemy()

	move_and_slide()
	_handle_movement_sound(velocity)

func _find_targets():
	# Ищем игрока в группе
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_player = players[0]

	# Ищем базу игрока (type_base == 0)
	var bases = get_tree().get_nodes_in_group("bases")
	for b in bases:
		if b.get("type_base") == 0:
			_base = b
			break

func _update_target():
	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY: return
	
	if _current_state == State.CHASE and is_instance_valid(_player):
		_nav2d.target_position = _player.global_position
	elif is_instance_valid(_base):
		_nav2d.target_position = _base.global_position

func _aim_gun(delta: float):
	if _gun == null: return

	if _type_enemy == TypeEnemy.STATIONARY and _current_state == State.PATROL:
		if _scan_wait_timer > 0: _scan_wait_timer -= delta; return
		_scan_angle += 40.0 * delta * _scan_dir
		if abs(_scan_angle) >= _scan_limit:
			_scan_dir *= -1; _scan_wait_timer = 1.5
		_gun.rotation_degrees = _scan_angle
	else:
		var target = _get_current_target()
		if target:
			var target_angle = (target.global_position - _gun.global_position).angle() + PI / 2
			_gun.global_rotation = lerp_angle(_gun.global_rotation, target_angle, 0.1)

func _move_enemy():
	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY:
		velocity = Vector2.ZERO; return

	# Враг едет к цели в обоих состояниях, если навигация не закончена
	if not _nav2d.is_navigation_finished():
		var dir = (_nav2d.get_next_path_position() - global_position).normalized()
		# Выбираем скорость в зависимости от состояния
		var current_speed = _chase_speed if _current_state == State.CHASE else _patrol_speed
		velocity = dir * current_speed
		rotation = dir.angle() + PI/2
	else:
		velocity = Vector2.ZERO

func _update_ray_cast():
	if _ray_cast == null: return
	var target = _get_current_target()
	if target:
		_ray_cast.target_position = _ray_cast.to_local(target.global_position)
		_ray_cast.enabled = true
		_ray_cast.force_raycast_update() # Принудительно обновляем, чтобы данные были актуальны в этом же кадре

func _is_target_visible() -> bool:
	if _ray_cast == null: return false
	if not _ray_cast.is_colliding(): return true

	var collider = _ray_cast.get_collider()
	var target = _get_current_target()
	if target == null: return false

	if collider == target: return true

	# Проверка для базы (у неё могут быть дочерние коллизии)
	if target == _base:
		if collider == _base or (collider.get_parent() != null and collider.get_parent() == _base):
			return true

	return false

func _get_current_target():
	return _player if (_current_state == State.CHASE and is_instance_valid(_player)) else _base

func _check_and_fire():
	var target = _get_current_target()
	if target == null: return

	var dist = global_position.distance_to(target.global_position)
	# Дальность турели уменьшена до 650
	var attack_range = 650.0 if _type_enemy == TypeEnemy.STATIONARY else 700.0

	# Стреляем только при наличии прямой видимости цели
	if dist <= attack_range and _is_target_visible():
		_fire_at_pos(target.global_position)

func _fire_at_pos(pos: Vector2):
	if _shoot_timer.time_left > 0: return

	var base_angle = (pos - _gun.global_position).angle() + PI/2

	if _type_enemy == TypeEnemy.TRIPLE:
		# Стрельба веером (3 пули) - Увеличили разлет до 0.4
		var angles = [base_angle, base_angle - 0.4, base_angle + 0.4]
		for angle in angles:
			var bullet = _bullet_scene.instantiate()
			bullet.global_position = _bullet_position.global_position
			bullet.global_rotation = angle
			get_parent().add_child(bullet)
			# Используем тип пули 0 (обычная)
			bullet.init(0, false, _damage)
	else:
		# Обычная стрельба
		var bullet = _bullet_scene.instantiate()
		var angle = base_angle + randf_range(-_spread, _spread)
		bullet.global_position = _bullet_position.global_position
		bullet.global_rotation = angle
		get_parent().add_child(bullet)
		var b_type = 2 if _type_enemy == TypeEnemy.STATIONARY else 0
		bullet.init(b_type, false, _damage)

	if _shot_flash: _shot_flash.play("Fire")
	_shoot_timer.start()

func _on_detection_area_entered(body):
	if body == _player: _current_state = State.CHASE

func _on_detection_area_exited(body):
	if body == _player: _current_state = State.PATROL

func _destroy():
	enemy_died.emit(_type_enemy)
	if is_instance_valid(_player) and _player.has_method("add_money"):
		_player.add_money(_get_reward())
	super._destroy()

func _get_reward() -> int:
	if _type_enemy == TypeEnemy.TRIPLE: return 40
	return [50, 75, 100, 150][_type_enemy] if _type_enemy != TypeEnemy.NONE else 50

func _apply_enemy_stats():
	var hull_path: String = ""
	var gun_path: String = ""
	var gun_offset: float = 42.0

	match _type_enemy:
		TypeEnemy.LIGHT:
			_hp = 50; _damage = 10; _fire_rate = 1.0; _spread = 0.25
			hull_path = "res://assets/future_tanks/PNG/Hulls_Color_D/Hull_08.png"
			gun_path = "res://assets/future_tanks/PNG/Weapon_Color_D/Gun_05.png"
			gun_offset = 35.0
		TypeEnemy.MEDIUM:
			_hp = 70; _damage = 25; _fire_rate = 1.2; _spread = 0.15
		TypeEnemy.HEAVY:
			_hp = 100; _damage = 35; _fire_rate = 2.5; _spread = 0.1
			hull_path = "res://assets/future_tanks/PNG/Hulls_Color_D/Hull_06.png"
			gun_path = "res://assets/future_tanks/PNG/Weapon_Color_D/Gun_07.png"
			gun_offset = 40.0
		TypeEnemy.STATIONARY:
			_hp = 100; _damage = 40; _fire_rate = 1.5; _spread = 0.05
			hull_path = "res://assets/turret/SniperTurretBase.png"
			gun_path = "res://assets/turret/SniperTurretGun.png"
			gun_offset = 0.0
			scale = Vector2(2.0, 2.0)
		TypeEnemy.TRIPLE:
			_hp = 100; _damage = 30; _fire_rate = 1.2; _spread = 0.0
			hull_path = "res://assets/future_tanks/PNG/Hulls_Color_D/Hull_05.png"
			gun_path = "res://assets/future_tanks/PNG/Weapon_Color_D/Gun_04.png"
			gun_offset = 35.0

	_max_hp = _hp
	_shoot_timer.wait_time = _fire_rate

	# Применяем текстуры, если они заданы
	if _body and hull_path != "":
		_body.texture = load(hull_path)
	if _gun and gun_path != "":
		_gun.texture = load(gun_path)
		_gun.position.y = gun_offset
		_gun.offset.y = -gun_offset
		# Обновляем позицию спавна пули, так как пушка сместилась
		if _bullet_position:
			_bullet_position.position.y = -85 # Стандартное смещение для дула

	# Корректируем масштаб вспышки выстрела
	if _shot_flash:
		# Целевой глобальный масштаб анимации 0.3.
		# Т.к. она теперь внутри BodyTank (0.5), то формула:
		# scale.x (врага) * 0.5 (корпуса) * flash_local_scale = 0.3
		var needed_scale = 0.6 / scale.x
		_shot_flash.scale = Vector2(needed_scale, needed_scale)

func _randomize_enemy_type():
	var available_types = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY]

	# Проверяем текущий уровень. Если уровень > 1, добавляем тройного бота в список возможных
	# Мета-данные в SaveManager хранят текущий уровень во время игры
	var current_lvl = 1
	if SaveManager and SaveManager.has_meta("current_level"):
		current_lvl = SaveManager.get_meta("current_level")

	if current_lvl > 1:
		available_types.append(TypeEnemy.TRIPLE)

	_type_enemy = available_types[randi() % available_types.size()]

func _setup_vision():
	# Метод оставлен пустым, чтобы не ломать логику вызова,
	# но перемещение области отключено
	pass
