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
var _is_moving: bool = false
var _normal_movement_volume: float = -20.0
var _fire_rate: float = 1.0

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

func _ready():
	add_to_group("enemies")
	_nav2d = get_node("NavigationAgent2D")
	_ray_cast = get_node("RayCast2D")
	if _ray_cast != null:
		_ray_cast.collide_with_areas = true
		_ray_cast.add_exception(self)

	_gun = get_node("BodyTank/Gun")
	_body = get_node("BodyTank")
	_moving_sound = get_node("MovingSound")

	if _type_enemy == TypeEnemy.NONE:
		_randomize_enemy_type()

	_apply_enemy_stats()

	_detection_area = get_node("DetectionArea")
	_current_state = State.PATROL
	_player = get_node("/root/Field/PlayerTank")
	_base = get_node("/root/Field/Base")
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
			_damage = 10
			_fire_rate = 1.0
			_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_08.png")
			_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_05.png")
			_gun.position = Vector2(0, 0)
			_body.visible = true
		TypeEnemy.MEDIUM:
			_patrol_speed = 100
			_chase_speed = 105
			_hp = 70
			_damage = 25
			_fire_rate = 1.2
			_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_01.png")
			_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_03.png")
			_gun.position = Vector2(0, 35)
			_body.visible = true
		TypeEnemy.HEAVY:
			_patrol_speed = 90
			_chase_speed = 100
			_hp = 100
			_damage = 35
			_fire_rate = 2.5
			_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_02.png")
			_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_08.png")
			_gun.position = Vector2(0, 35)
			_body.visible = true
		TypeEnemy.STATIONARY:
			_patrol_speed = 0
			_chase_speed = 0
			_hp = 100
			_damage = 40
			_fire_rate = 1.5
			_body.visible = true
			_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_C/Hull_03.png")
			_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_C/Gun_01.png")
			_gun.position = Vector2(0, 35)
			if _moving_sound != null:
				_moving_sound.stream = null
			if _detection_area != null:
				var shape = _detection_area.get_node("CollisionShape2D")
				if shape != null and shape.shape is CircleShape2D:
					shape.shape.radius = 500.0

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
		# СОСТОЯНИЕ 1: Сканирование (вращение башней)
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
		# СОСТОЯНИЕ 2: Наведение на цель ( noticed player )
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
			if collider == _player or collider == _base: return true
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

	if _type_enemy == TypeEnemy.STATIONARY:
		# СОСТОЯНИЕ 3: Стрельба только при приближении
		var dist = global_position.distance_to(target.global_position)
		if dist > 400.0: # Дистанция атаки турели
			return

	if target == _base:
		if _detection_area == null or not _detection_area.overlaps_area(_base): return

	if _is_target_visible():
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
	if _hp <= 0: _destroy()

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
	bullet.global_rotation = gun_angle
	bullet.global_position = _bullet_position.global_position
	get_tree().root.add_child(bullet)
	bullet.init(TypeBullet.TypeBullet.PLASMA, false, _damage)
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
