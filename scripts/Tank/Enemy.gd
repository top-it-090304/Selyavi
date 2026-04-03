class_name Enemy
extends Tank

enum State { PATROL, CHASE }
enum TypeEnemy { LIGHT, MEDIUM, HEAVY, STATIONARY, NONE }

# region Поля ИИ
var _current_state: int = State.PATROL
var _player: Node
var _base: Node
var _nav2d: NavigationAgent2D
var _ray_cast: RayCast2D
var _detection_area: Area2D

@export var _type_enemy: TypeEnemy = TypeEnemy.NONE
@export var _patrol_speed: int = 90
@export var _chase_speed: int = 100

var _fire_rate: float = 1.0
var _spread: float = 0.15
var _scan_angle: float = 0.0
var _scan_dir: int = 1
var _scan_wait_timer: float = 0.0
var _scan_limit: float = 45.0
# endregion

func _ready():
	add_to_group("enemies")
	_init_base_tank() # Инициализация из Tank.gd

	_nav2d = get_node_or_null("NavigationAgent2D")
	_ray_cast = get_node_or_null("RayCast2D")
	_detection_area = get_node_or_null("DetectionArea")

	if _ray_cast:
		_ray_cast.collide_with_areas = true
		_ray_cast.add_exception(self)

	if _type_enemy == TypeEnemy.NONE: _randomize_enemy_type()
	_apply_enemy_stats()
	_setup_vision()

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
	if not is_instance_valid(_base): return
	
	_update_target()
	_aim_gun(delta)
	_update_ray_cast()
	_check_and_fire()
	_move_enemy()

	move_and_slide()
	_handle_movement_sound(velocity)

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
	
	var should_move = _current_state == State.PATROL or not _is_target_visible()
	
	if should_move and not _nav2d.is_navigation_finished():
		var dir = (_nav2d.get_next_path_position() - global_position).normalized()
		velocity = dir * (_patrol_speed if _current_state == State.PATROL else _chase_speed)
		rotation = dir.angle() + PI/2
	else:
		velocity = Vector2.ZERO

func _update_ray_cast():
	if _ray_cast == null: return
	var target = _get_current_target()
	if target:
		_ray_cast.target_position = to_local(target.global_position)
		_ray_cast.enabled = true

func _is_target_visible() -> bool:
	if _ray_cast == null or not _ray_cast.is_colliding(): return true
	var collider = _ray_cast.get_collider()
	if not collider: return false

	if collider == _player: return true
	if collider == _base or (collider.get_parent() != null and collider.get_parent() == _base): return true
	if collider.has_method("take_damage"): return true
	return false

func _get_current_target():
	return _player if (_current_state == State.CHASE and is_instance_valid(_player)) else _base

func _check_and_fire():
	var target = _get_current_target()
	if target == null: return

	# Проверка препятствий (стен)
	if _ray_cast and _ray_cast.is_colliding():
		var col = _ray_cast.get_collider()
		if col and col != _player and col != _base and col.has_method("take_damage"):
			if global_position.distance_to(col.global_position) < 300.0:
				_fire_at_pos(col.global_position)
				return

	var dist = global_position.distance_to(target.global_position)
	var attack_range = 600.0 if _type_enemy == TypeEnemy.STATIONARY else 450.0

	if dist <= attack_range and _is_target_visible():
		_fire_at_pos(target.global_position)

func _fire_at_pos(pos: Vector2):
	if _shoot_timer.time_left > 0: return

	var bullet = _bullet_scene.instantiate()
	var angle = (pos - _gun.global_position).angle() + PI/2 + randf_range(-_spread, _spread)
	bullet.global_position = _bullet_position.global_position
	bullet.global_rotation = angle

	get_tree().root.add_child(bullet)
	var b_type = 1 if _type_enemy == TypeEnemy.STATIONARY else 0
	bullet.init(b_type, false, _damage)

	var flash = get_node_or_null("ShotAnimation")
	if flash: flash.play("Fire")
	_shoot_timer.start()

func _on_detection_area_entered(body):
	if body == _player: _current_state = State.CHASE

func _on_detection_area_exited(body):
	if body == _player: _current_state = State.PATROL

func _destroy():
	if is_instance_valid(_player) and _player.has_method("add_money"):
		_player.add_money(_get_reward())
	super._destroy()

func _get_reward() -> int:
	return [50, 75, 100, 150][_type_enemy] if _type_enemy != TypeEnemy.NONE else 50

func _apply_enemy_stats():
	match _type_enemy:
		TypeEnemy.LIGHT: _hp = 50; _damage = 10; _fire_rate = 1.0; _spread = 0.25
		TypeEnemy.MEDIUM: _hp = 70; _damage = 25; _fire_rate = 1.2; _spread = 0.15
		TypeEnemy.HEAVY: _hp = 100; _damage = 35; _fire_rate = 2.5; _spread = 0.1
		TypeEnemy.STATIONARY: _hp = 100; _damage = 40; _fire_rate = 1.5; _spread = 0.05
	_max_hp = _hp

func _randomize_enemy_type():
	_type_enemy = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY][randi() % 3]

func _setup_vision():
	if not _detection_area or not _gun: return
	if _detection_area.get_parent() != _gun:
		_detection_area.get_parent().remove_child(_detection_area)
		_gun.add_child(_detection_area)
		_detection_area.position = Vector2.ZERO
