class_name Enemy
extends Tank

signal enemy_died(type: int)

enum State { PATROL, CHASE }
enum TypeEnemy { LIGHT, MEDIUM, HEAVY, STATIONARY, TRIPLE, BOSS, NONE }

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
@export var _chase_speed: int = 60

var _fire_rate: float = 1.0
var _spread: float = 0.15
var _scan_angle: float = 0.0
var _scan_dir: int = 1
var _scan_wait_timer: float = 0.0
var _scan_limit: float = 45.0

# Дистанции поведения
var _notice_range: float = 850.0
var _attack_range: float = 450.0

# Переменные для задержки выстрела (реакция)
var _reaction_timer: float = 0.0
var _target_in_sight: bool = false
# endregion

func get_enemy_type() -> int:
	return _type_enemy

func _ready():
	add_to_group("enemies")
	_init_base_tank()

	_nav2d = get_node_or_null("NavigationAgent2D")
	_ray_cast = get_node_or_null("RayCast2D")
	_detection_area = get_node_or_null("DetectionArea")
	_shot_flash = get_node_or_null("ShotAnimation")

	if _ray_cast:
		_ray_cast.collide_with_areas = false
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
		if b.get("type_base") == 0: _base = b; break

	if _detection_area:
		_detection_area.body_entered.connect(_on_detection_area_entered)
		_detection_area.body_exited.connect(_on_detection_area_exited)

	_shoot_timer.wait_time = _fire_rate

func _physics_process(delta):
	if not is_instance_valid(_player) or (not is_instance_valid(_base) and _base != null):
		_find_targets()

	var target = _get_current_target()
	if not is_instance_valid(target):
		_target_in_sight = false
		_reaction_timer = 0.0
		return
	
	_update_target()
	_aim_gun(delta)
	_update_ray_cast()

	_target_in_sight = _is_target_visible()
	if _target_in_sight:
		_reaction_timer += delta
	else:
		_reaction_timer = 0.0

	_check_and_fire()
	_move_enemy()

	move_and_slide()
	_handle_movement_sound(velocity)

func _find_targets():
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_player = players[0]

	var bases = get_tree().get_nodes_in_group("bases")
	_base = null
	for b in bases:
		if b.get("type_base") == 0:
			_base = b
			break

	if _base == null:
		_current_state = State.CHASE

func _update_target():
	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY: return

	if is_instance_valid(_player) and (_current_state == State.CHASE or _base == null):
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

	var target = _get_current_target()

	# Логика остановки при приближении к игроку (только если бот видит игрока)
	if target == _player and is_instance_valid(_player):
		var dist = global_position.distance_to(_player.global_position)
		if dist <= _attack_range and _target_in_sight:
			velocity = Vector2.ZERO
			return

	if not _nav2d.is_navigation_finished():
		var dir = (_nav2d.get_next_path_position() - global_position).normalized()
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
		_ray_cast.force_raycast_update()

func _is_target_visible() -> bool:
	if _ray_cast == null: return false
	if not _ray_cast.is_colliding(): return true

	var collider = _ray_cast.get_collider()
	var target = _get_current_target()
	if target == null: return false

	if collider == target: return true

	if target == _base:
		if collider == _base or (collider.get_parent() != null and collider.get_parent() == _base):
			return true

	if collider is IngameWall:
		if collider.destroyable():
			return true

	return false

func _get_current_target():
	if is_instance_valid(_player) and (_current_state == State.CHASE or _base == null):
		return _player
	return _base

func _check_and_fire():
	var target = _get_current_target()
	if target == null: return

	var dist = global_position.distance_to(target.global_position)

	var can_fire = false
	if target == _player:
		if dist <= _attack_range and _target_in_sight:
			can_fire = true
	else:
		if dist <= 700.0 and _target_in_sight:
			can_fire = true

	if can_fire:
		if _type_enemy == TypeEnemy.STATIONARY:
			if _reaction_timer >= 1.0:
				_fire_at_pos(target.global_position)
		else:
			_fire_at_pos(target.global_position)

func _fire_at_pos(pos: Vector2):
	if _shoot_timer.time_left > 0: return

	var base_angle = (pos - _gun.global_position).angle() + PI/2
	var sound_type = 2 if _type_enemy == TypeEnemy.STATIONARY else (1 if _type_enemy == TypeEnemy.TRIPLE else 0)

	if AudioManager:
		AudioManager.play_bullet_sound(sound_type, global_position)

	if _type_enemy == TypeEnemy.TRIPLE:
		var angles = [base_angle, base_angle - 0.4, base_angle + 0.4]
		for angle in angles:
			var bullet = _bullet_scene.instantiate()
			bullet.global_position = _bullet_position.global_position
			bullet.global_rotation = angle
			get_parent().add_child(bullet)
			bullet.init(1, false, _damage)
	else:
		var bullet = _bullet_scene.instantiate()
		var angle = base_angle + randf_range(-_spread, _spread)
		bullet.global_position = _bullet_position.global_position
		bullet.global_rotation = angle
		get_parent().add_child(bullet)
		var b_type = 2 if _type_enemy == TypeEnemy.STATIONARY else 0
		bullet.init(b_type, false, _damage)

	if _shot_flash:
		_shot_flash.play("Fire")
	_shoot_timer.start()

func _on_detection_area_entered(body):
	if body == _player: _current_state = State.CHASE

func _on_detection_area_exited(body):
	if body == _player: _current_state = State.PATROL

func _destroy():
	enemy_died.emit(_type_enemy)
	if is_instance_valid(_player) and _player.has_method("add_money"):
		_player.add_money(_get_reward())

	if _type_enemy == TypeEnemy.STATIONARY or randf() <= 0.25:
		_spawn_heal_pickup()

	super._destroy()

func _spawn_heal_pickup():
	var pickup_script = load("res://scripts/HealPickup.gd")
	if not pickup_script:
		return

	var pickup = Area2D.new()
	pickup.set_script(pickup_script)
	pickup.global_position = global_position
	get_parent().call_deferred("add_child", pickup)

func _get_reward() -> int:
	match _type_enemy:
		TypeEnemy.LIGHT: return 50
		TypeEnemy.MEDIUM: return 75
		TypeEnemy.HEAVY: return 100
		TypeEnemy.STATIONARY: return 150
		TypeEnemy.TRIPLE: return 200
		TypeEnemy.BOSS: return 500
		_: return 50

func _apply_enemy_stats():
	var hull_path: String = ""; var gun_path: String = ""; var gun_offset: float = 42.0
	var lvl = 1; if SaveManager: lvl = SaveManager.current_level
	_notice_range = 800.0; _attack_range = 450.0

	match _type_enemy:
		TypeEnemy.LIGHT:
			_hp = 50; _damage = 10; _fire_rate = 1.0; _spread = 0.25
			hull_path = "res://assets/future_tanks/PNG/Hulls_Color_D/Hull_08.png"; gun_path = "res://assets/future_tanks/PNG/Weapon_Color_D/Gun_05.png"; gun_offset = 35.0
			_notice_range = 700.0; _attack_range = 500.0
		TypeEnemy.MEDIUM:
			_hp = 70; _damage = 25; _fire_rate = 1.2; _spread = 0.15; _notice_range = 700.0; _attack_range = 450.0
		TypeEnemy.HEAVY:
			_hp = 80 if lvl <= 5 else 100; _damage = 35; _fire_rate = 2.5; _spread = 0.1
			hull_path = "res://assets/future_tanks/PNG/Hulls_Color_D/Hull_06.png"; gun_path = "res://assets/future_tanks/PNG/Weapon_Color_D/Gun_07.png"; gun_offset = 40.0
			_notice_range = 600.0; _attack_range = 400.0
		TypeEnemy.STATIONARY:
			_hp = 75 if lvl <= 5 else 100; _damage = 40; _fire_rate = 1.5; _spread = 0.05
			hull_path = "res://assets/turret/SniperTurretBase.png"; gun_path = "res://assets/turret/SniperTurretGun.png"; gun_offset = 0.0; scale = Vector2(2.0, 2.0); _attack_range = 650.0
		TypeEnemy.TRIPLE:
			_hp = 100; _damage = 20; _fire_rate = 1.2; _spread = 0.05
			hull_path = "res://assets/future_tanks/PNG/Hulls_Color_D/Hull_05.png"; gun_path = "res://assets/future_tanks/PNG/Weapon_Color_D/Gun_04.png"; gun_offset = 35.0
			_notice_range = 600.0; _attack_range = 300.0
		TypeEnemy.BOSS:
			_hp = 1000; _damage = 30; _fire_rate = 1.0; _spread = 0.1
			hull_path = "res://assets/future_tanks/PNG/Hulls_Color_D/Hull_03.png"; gun_path = "res://assets/future_tanks/PNG/Weapon_Color_D/Gun_08.png"; gun_offset = 40.0; scale = Vector2(2, 2); _notice_range = 1200.0; _attack_range = 600.0

	_max_hp = _hp; _shoot_timer.wait_time = _fire_rate
	if _body and hull_path != "": _body.texture = load(hull_path)
	if _gun and gun_path != "": _gun.texture = load(gun_path); _gun.position.y = gun_offset; _gun.offset.y = -gun_offset
	if _shot_flash: _shot_flash.scale = Vector2(0.6/scale.x, 0.6/scale.x)

func _randomize_enemy_type():
	var available_types = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY]
	if SaveManager and SaveManager.current_level > 5: available_types.append(TypeEnemy.TRIPLE)
	_type_enemy = available_types[randi() % available_types.size()]
