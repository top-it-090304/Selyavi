class_name Enemy
extends CharacterBody2D

enum State { PATROL, CHASE }
enum TypeEnemy { LIGHT, MEDIUM, HEAVY, STATIONARY, NONE }

# region private fields
var _current_state: int = State.PATROL
var _detection_area: Area2D
var _hp: int = 10
var _player: Node
var _base: Node
@export var _patrol_speed: int = 90
@export var _chase_speed: int = 100
var _velocity: Vector2 = Vector2.ZERO
const TypeBullet = preload("res://scripts/Tank/TypeBullet.gd")
var _bullet_position: Marker2D
var _shoot_timer: Timer
var _gun: Sprite2D
var _body: Sprite2D
var _damage: int = 20
var _nav2d: NavigationAgent2D
var _ray_cast: RayCast2D
@export var _type_enemy: TypeEnemy = TypeEnemy.NONE
var _moving_sound: AudioStreamPlayer
var _smoke_particles: CPUParticles2D
var _max_hp: int = 10
var _is_moving: bool = false
var _normal_movement_volume: float = -20.0
var _fire_rate: float = 1.0
var _spread: float = 0.15 # Разброс пуль в радианах

# Переменные для режима сканирования турели
var _scan_angle: float = 0.0
var _scan_dir: int = 1
var _scan_wait_timer: float = 0.0
var _scan_limit: float = 45.0 # Угол поворота в градусах
# endregion

var _bullet_scene: PackedScene

func get_enemy_type() -> int:
	return _type_enemy

func set_enemy_type(type: int):
	_type_enemy = type as TypeEnemy
	if is_inside_tree():
		_apply_enemy_stats()
		_setup_vision()

func _ready():
	add_to_group("enemies")
	_nav2d = get_node("NavigationAgent2D")
	_ray_cast = get_node("RayCast2D")
	if _ray_cast != null:
		_ray_cast.collide_with_areas = true
		_ray_cast.add_exception(self)

	_gun = get_node("BodyTank/Gun")
	_body = get_node("BodyTank")
	_detection_area = get_node("DetectionArea")
	_moving_sound = get_node("MovingSound")

	_setup_damage_effects()

	if _type_enemy == TypeEnemy.NONE:
		_randomize_enemy_type()

	_apply_enemy_stats()
	_setup_vision()

	_current_state = State.PATROL

	# Универсальный поиск через группы
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_player = players[0]

	var bases = get_tree().get_nodes_in_group("bases")
	for b in bases:
		if b.type_base == 0: # 0 = PLAYER (TypeBase.PLAYER)
			_base = b
			break

	_bullet_position = get_node("BodyTank/Gun/BulletPosition")

	if _detection_area != null:
		if not _detection_area.is_connected("body_entered", _on_detection_area_entered):
			_detection_area.body_entered.connect(_on_detection_area_entered)
		if not _detection_area.is_connected("body_exited", _on_detection_area_exited):
			_detection_area.body_exited.connect(_on_detection_area_exited)

	_bullet_scene = load("res://scenes/Tank/Bullet.tscn")
	_shoot_timer = Timer.new()
	_shoot_timer.wait_time = _fire_rate
	_shoot_timer.one_shot = true
	add_child(_shoot_timer)

	if _nav2d != null:
		_nav2d.max_speed = _patrol_speed
		_nav2d.target_desired_distance = 10.0
		_nav2d.path_desired_distance = 5.0

	_configure_audio_players()
	if _moving_sound != null and _type_enemy != TypeEnemy.STATIONARY:
		_normal_movement_volume = _moving_sound.volume_db

func _apply_enemy_stats():
	if _body == null or _gun == null: return

	match _type_enemy:
		TypeEnemy.LIGHT:
			_patrol_speed = 110
			_chase_speed = 120
			_hp = 50
			_max_hp = 50
			_damage = 10
			_fire_rate = 1.0
			_spread = 0.25 # Большой разброс
			_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_08.png")
			_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_05.png")
			_gun.position = Vector2(0, 0)
			_body.visible = true
		TypeEnemy.MEDIUM:
			_patrol_speed = 100
			_chase_speed = 105
			_hp = 70
			_max_hp = 70
			_damage = 25
			_fire_rate = 1.2
			_spread = 0.15 # Средний разброс
			_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_01.png")
			_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_03.png")
			_gun.position = Vector2(0, 35)
			_body.visible = true
		TypeEnemy.HEAVY:
			_patrol_speed = 90
			_chase_speed = 100
			_hp = 100
			_max_hp = 100
			_damage = 35
			_fire_rate = 2.5
			_spread = 0.1 # Высокая точность
			_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_02.png")
			_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_08.png")
			_gun.position = Vector2(0, 35)
			_body.visible = true
		TypeEnemy.STATIONARY:
			_patrol_speed = 0
			_chase_speed = 0
			_hp = 100
			_max_hp = 100
			_damage = 40
			_fire_rate = 1.5
			_spread = 0.05 # Почти снайперская точность
			_body.visible = true
			_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_C/Hull_03.png")
			_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_C/Gun_01.png")
			_gun.position = Vector2(0, 35)
			if _moving_sound != null:
				_moving_sound.stream = null

func _configure_audio_players():
	if _moving_sound != null:
		_moving_sound.bus = "SFX"

func _physics_process(delta):
	if not is_instance_valid(_base):
		_destroy()
		return
	
	_update_target()
	_aim_gun(delta)
	_update_ray_cast()
	_check_and_fire()
	_move_enemy()
	set_velocity(_velocity)
	move_and_slide()
	_velocity = velocity

func _handle_movement_sound(movement_velocity: Vector2):
	if _type_enemy == TypeEnemy.STATIONARY:
		return

	var is_moving_now = movement_velocity.length() > 0.1
	
	if is_moving_now:
		if not _is_moving:
			if _moving_sound != null:
				_moving_sound.volume_db = _normal_movement_volume
				if not _moving_sound.playing:
					_moving_sound.play()
			_is_moving = true
	else:
		if _is_moving:
			_is_moving = false
			if _moving_sound != null and _moving_sound.playing:
				_fade_sound()

func _update_target():
	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY:
		return
	
	match _current_state:
		State.PATROL:
			if _base != null and is_instance_valid(_base):
				_nav2d.target_position = _base.global_position
			else:
				_destroy()
		State.CHASE:
			if _player != null and is_instance_valid(_player):
				_nav2d.target_position = _player.global_position

func _aim_gun(delta: float):
	if _gun == null:
		return

	if _type_enemy == TypeEnemy.STATIONARY and _current_state == State.PATROL:
		# Сканирование (вращение башней)
		if _scan_wait_timer > 0:
			_scan_wait_timer -= delta
			return

		var rotation_speed = 40.0 # Скорость вращения при сканировании
		_scan_angle += rotation_speed * delta * _scan_dir

		if abs(_scan_angle) >= _scan_limit:
			_scan_dir *= -1
			_scan_wait_timer = 1.5 # Время паузы в крайних точках

		_gun.rotation_degrees = _scan_angle
	else:
		# Наведение на цель ( noticed player )
		var target = _get_current_target()
		if target == null or not is_instance_valid(target):
			return

		var direction_to_target = (target.global_position - _gun.global_position).normalized()
		var target_angle = direction_to_target.angle() + PI / 2

		# Плавный поворот башни
		_gun.global_rotation = lerp_angle(_gun.global_rotation, target_angle, 0.1)

func _move_enemy():
	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY:
		_velocity = Vector2.ZERO
		return
	
	var should_move = false
	match _current_state:
		State.PATROL: should_move = true
		State.CHASE: should_move = not _is_target_visible()
	
	if should_move and not _nav2d.is_navigation_finished():
		var next_location = _nav2d.get_next_path_position()
		var direction = (next_location - global_position).normalized()
		var current_speed = _patrol_speed if _current_state == State.PATROL else _chase_speed
		_velocity = direction * current_speed
		if _velocity.length() > 0.1:
			rotation_degrees = rad_to_deg(_velocity.angle()) + 90
		_handle_movement_sound(_velocity)
	else:
		_velocity = Vector2.ZERO
		_handle_movement_sound(Vector2.ZERO)

func _update_ray_cast():
	if _ray_cast == null: return
	var target = _get_current_target()
	if target == null or not is_instance_valid(target): return

	_ray_cast.target_position = to_local(target.global_position)
	_ray_cast.enabled = true
	_ray_cast.force_raycast_update()

func _is_target_visible() -> bool:
	if _ray_cast == null: return false
	if _ray_cast.is_colliding():
		var collider = _ray_cast.get_collider()
		if collider != null and is_instance_valid(collider):
			if collider == _player: return true
			# База может быть представлена своим StaticBody2D дочерним элементом
			if collider == _base or (collider.get_parent() != null and collider.get_parent() == _base):
				return true
		return false
	return true

func _get_current_target():
	if _current_state == State.CHASE:
		return _player if _player != null and is_instance_valid(_player) else null
	else:
		return _base if _base != null and is_instance_valid(_base) else null

func _check_and_fire():
	var target = _get_current_target()
	if target == null: return

	var dist = global_position.distance_to(target.global_position)
	var attack_range = 450.0

	if _type_enemy == TypeEnemy.STATIONARY:
		attack_range = 600.0
	elif _type_enemy == TypeEnemy.HEAVY:
		attack_range = 500.0

	# Если цель - база, мы должны быть достаточно близко или видеть ее
	if dist <= attack_range and _is_target_visible():
		_fire_at_target(target)

func _on_detection_area_entered(body):
	if body == _player and is_instance_valid(_player):
		_current_state = State.CHASE

func _on_detection_area_exited(body):
	if body == _player:
		if _base != null and is_instance_valid(_base):
			_current_state = State.PATROL

func take_damage(damage: int):
	_hp -= damage
	_update_damage_visuals()
	if _hp <= 0: _destroy()

func _setup_damage_effects():
	_smoke_particles = CPUParticles2D.new()
	add_child(_smoke_particles)
	_smoke_particles.position = Vector2(0, 0)
	_smoke_particles.emitting = false
	_smoke_particles.amount = 20
	_smoke_particles.lifetime = 0.8
	_smoke_particles.texture = load("res://assets/future_tanks/PNG/Effects/Smoke_A.png")
	_smoke_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smoke_particles.emission_sphere_radius = 20.0
	_smoke_particles.spread = 180.0
	_smoke_particles.gravity = Vector2(0, -100)
	_smoke_particles.initial_velocity_min = 20.0
	_smoke_particles.initial_velocity_max = 50.0
	_smoke_particles.scale_amount_min = 0.1
	_smoke_particles.scale_amount_max = 0.3
	_smoke_particles.color = Color(0.3, 0.3, 0.3, 0.6)

	var curve = Gradient.new()
	curve.add_point(0.0, Color(0.5, 0.5, 0.5, 0.0))
	curve.add_point(0.2, Color(0.2, 0.2, 0.2, 0.7))
	curve.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0))
	_smoke_particles.color_ramp = curve

func _update_damage_visuals():
	if _max_hp <= 0: return
	var health_percent = float(_hp) / float(_max_hp)

	var tween = create_tween()
	tween.tween_property(_body, "modulate", Color(5, 5, 5), 0.05)
	tween.tween_property(_body, "modulate", Color(1, 1, 1), 0.05)

	if health_percent <= 0.5:
		_smoke_particles.emitting = true
		if health_percent <= 0.25:
			_smoke_particles.amount = 40
			_smoke_particles.color = Color(0.1, 0.1, 0.1, 0.8)
		else:
			_smoke_particles.amount = 20
			_smoke_particles.color = Color(0.3, 0.3, 0.3, 0.5)
	else:
		_smoke_particles.emitting = false

func _destroy():
	if is_instance_valid(_player) and _player != null:
		var reward = _get_enemy_reward()
		if _player.has_method("add_money"): _player.add_money(reward)
	queue_free()

func _get_enemy_reward() -> int:
	match _type_enemy:
		TypeEnemy.LIGHT: return 50
		TypeEnemy.MEDIUM: return 75
		TypeEnemy.HEAVY: return 100
		TypeEnemy.STATIONARY: return 150
	return 50

func _fire_at_target(target: Node2D):
	if _shoot_timer.time_left > 0: return
	var bullet = _bullet_scene.instantiate()
	var direction_to_target = (target.global_position - _gun.global_position).normalized()
	var gun_angle = direction_to_target.angle() + PI / 2

	# Добавляем случайное отклонение (разброс)
	var random_offset = randf_range(-_spread, _spread)
	bullet.global_rotation = gun_angle + random_offset

	bullet.global_position = _bullet_position.global_position
	get_tree().root.add_child(bullet)

	var bullet_type = TypeBullet.TypeBullet.PLASMA
	if _type_enemy == TypeEnemy.STATIONARY:
		bullet_type = TypeBullet.TypeBullet.MEDIUM

	bullet.init(bullet_type, false, _damage)

	var muzzle_flash = get_node("ShotAnimation")
	if muzzle_flash != null:
		muzzle_flash.global_position = _bullet_position.global_position
		muzzle_flash.frame = 0
		muzzle_flash.play("Fire")
	_shoot_timer.wait_time = _fire_rate
	_shoot_timer.start()

func _fade_sound():
	var tween = create_tween()
	tween.tween_property(_moving_sound, "volume_db", -80, 0.3)
	tween.finished.connect(_on_fade_complete)

func _on_fade_complete():
	if _moving_sound != null:
		_moving_sound.stop()
		_moving_sound.volume_db = _normal_movement_volume

func _randomize_enemy_type():
	var values = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY]
	_type_enemy = values[randi() % values.size()]

func _setup_vision():
	if _detection_area == null or _gun == null: return

	# Привязываем область обнаружения к пушке, чтобы зрение вращалось вместе с дулом
	if _detection_area.get_parent() != _gun:
		var old_p = _detection_area.get_parent()
		if old_p: old_p.remove_child(_detection_area)
		_gun.add_child(_detection_area)
		_detection_area.position = Vector2.ZERO
		_detection_area.rotation = 0

	var short_r = 200.0
	var long_r = 550.0

	match _type_enemy:
		TypeEnemy.LIGHT:
			short_r = 180.0
			long_r = 500.0
		TypeEnemy.MEDIUM:
			short_r = 220.0
			long_r = 600.0
		TypeEnemy.HEAVY:
			short_r = 250.0
			long_r = 650.0
		TypeEnemy.STATIONARY:
			short_r = 300.0
			long_r = 850.0

	# Настройка базового круга (всенаправленное зрение/слух)
	var base_col = _detection_area.get_node_or_null("CollisionShape2D")
	if base_col and base_col.shape is CircleShape2D:
		base_col.shape = base_col.shape.duplicate() # Чтобы не менять радиус у других типов
		base_col.shape.radius = short_r

	# Настройка направленного зрения (вытянутая капсула вперед)
	var long_col = _detection_area.get_node_or_null("LongVision")
	if long_col == null:
		long_col = CollisionShape2D.new()
		long_col.name = "LongVision"
		_detection_area.add_child(long_col)

	var capsule = CapsuleShape2D.new()
	capsule.radius = 100.0
	capsule.height = long_r
	long_col.shape = capsule
	# Смещаем капсулу так, чтобы она торчала вперед от танка
	long_col.position = Vector2(0, -long_r / 2)
