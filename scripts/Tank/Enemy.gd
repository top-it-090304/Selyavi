class_name Enemy
extends Tank

signal enemy_died(type: int)

enum State { PATROL, CHASE }
enum TypeEnemy { LIGHT, MEDIUM, HEAVY, STATIONARY, TRIPLE, BOSS, ARTILLERY, SCOUT, MECHANIC, NONE, CUSTOM }

# Глобальная цель для всей артиллерии, которую "подсвечивают" разведчики
static var scout_target: Node2D = null
static var last_spotted_time: float = -100.0 # Время последнего обнаружения (в секундах)

# Ссылка на базу, которая создала этого врага
var creator_base: Node = null

# Данные врага из ресурса
@export var enemy_data: EnemyData

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

# Переменные для артиллерии
var _blind_fire_range: float = 600.0

# Переменные для разведчика
var _scout_search_timer: float = 0.0
var _scout_search_duration: float = 20.0 # Искать игрока 20 секунд
var _scout_found_player: bool = false
var _scout_failed_to_find: bool = false

# Переменные для задержки выстрела (реакция)
var _reaction_timer: float = 0.0
var _target_in_sight: bool = false
var _roll_out_timer: float = 0.0 # Таймер для "выкатывания" из-за угла

# Стабилизация движения
var _smoothed_avoidance: Vector2 = Vector2.ZERO
var _speed_limit_mult: float = 1.0
var _last_bypass_side: float = 0.0 # Стабилизация выбора стороны объезда
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
		_ray_cast.collide_with_areas = false # Игнорируем триггерные зоны
		_ray_cast.add_exception(self)
		_ray_cast.collision_mask = 1 # Только физические тела

	# Сброс статических данных засвета при старте уровня
	if scout_target != null and (not is_instance_valid(scout_target) or scout_target.get_tree() != get_tree()):
		scout_target = null
		last_spotted_time = -100.0

	# Сначала загружаем данные из ресурса, если он есть
	if enemy_data:
		_apply_data_from_resource()

	# Если тип все еще NONE, пытаемся определить по старой логике
	if _type_enemy == TypeEnemy.NONE:
		_randomize_enemy_type()

	# Если ресурса нет, подтягиваем его по типу
	if not enemy_data:
		_auto_assign_resource_by_type()
		if enemy_data: _apply_data_from_resource()

	if not enemy_data:
		_apply_enemy_stats()

	# Уменьшение хитбокса для турели
	if _type_enemy == TypeEnemy.STATIONARY:
		var collision = get_node_or_null("CollisionShape2D")
		if collision and collision.shape is CircleShape2D:
			collision.shape.radius *= 0.8

	match _type_enemy:
		TypeEnemy.ARTILLERY:
			_patrol_speed = 0
			_chase_speed = 0
			_blind_fire_range = 650.0
			_setup_artillery_flash()
		TypeEnemy.SCOUT:
			_scout_search_duration = 20.0
			_scout_search_timer = 0.0
			_current_state = State.CHASE

	if _shot_flash and _bullet_position and _type_enemy != TypeEnemy.ARTILLERY:
		if _shot_flash.get_parent() != _bullet_position:
			_shot_flash.get_parent().remove_child(_shot_flash)
			_bullet_position.add_child(_shot_flash)
		_shot_flash.position = Vector2.ZERO
		_shot_flash.rotation = 0

	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0: _player = players[0]

	for b in get_tree().get_nodes_in_group("bases"):
		if b.get("type_base") == 0: _base = b; break

	if _detection_area:
		_detection_area.body_entered.connect(_on_detection_area_entered)
		_detection_area.body_exited.connect(_on_detection_area_exited)

	_shoot_timer.wait_time = _fire_rate

func _setup_artillery_flash():
	if not _shot_flash:
		_shot_flash = AnimatedSprite2D.new()
		_bullet_position.add_child(_shot_flash)

	_shot_flash.sprite_frames = SpriteFrames.new()
	_shot_flash.sprite_frames.add_animation("Fire")
	_shot_flash.sprite_frames.set_animation_speed("Fire", 25.0)
	_shot_flash.sprite_frames.set_animation_loop("Fire", false)

	var textures = [
		null,
		"res://assets/future_tanks/PNG/Effects/Explosion_B.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_C.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_D.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_E.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_F.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_G.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_H.png",
		null
	]
	for tex_path in textures:
		if tex_path: _shot_flash.sprite_frames.add_frame("Fire", load(tex_path))
		else: _shot_flash.sprite_frames.add_frame("Fire", null)

	_shot_flash.scale = Vector2(0.45, 0.45)
	_shot_flash.position = Vector2(0, -45)
	_shot_flash.rotation = 0

func _physics_process(delta):
	if not is_instance_valid(_player) or (not is_instance_valid(_base) and _base != null):
		_find_targets()

	if _type_enemy == TypeEnemy.SCOUT:
		_process_scout_logic(delta)

	_update_target()
	_aim_gun(delta)
	_update_ray_cast()

	var was_visible = _target_in_sight
	_target_in_sight = _is_target_visible()

	# Если мы только что увидели цель, запускаем таймер "выкатывания"
	if _target_in_sight and not was_visible:
		_roll_out_timer = 0.3

	if _roll_out_timer > 0:
		_roll_out_timer -= delta

	if _target_in_sight:
		_reaction_timer += delta
	else:
		_reaction_timer = 0.0

	_check_and_fire()
	_move_enemy(delta)

	move_and_slide()
	_handle_movement_sound(velocity)

func _process_scout_logic(delta):
	if _scout_failed_to_find:
		# База подсвечивается только если скаут видит её напрямую и находится в радиусе обнаружения
		if is_instance_valid(_base) and global_position.distance_to(_base.global_position) <= _notice_range:
			if _is_target_visible_at(_base):
				Enemy.scout_target = _base
				Enemy.last_spotted_time = Time.get_ticks_msec() / 1000.0
		return

	_scout_search_timer += delta

	# Скаут засвечивает игрока только если видит его напрямую (LoS) и он в радиусе обнаружения
	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= _notice_range:
		if _is_target_visible_at(_player):
			Enemy.scout_target = _player
			_scout_found_player = true
			Enemy.last_spotted_time = Time.get_ticks_msec() / 1000.0
			_scout_search_timer = 0.0
		else:
			_scout_found_player = false
	else:
		_scout_found_player = false

	if _scout_search_timer >= _scout_search_duration:
		_scout_failed_to_find = true

func _apply_data_from_resource():
	if not enemy_data: return

	# Явное назначение типа из ресурса
	if enemy_data.is_boss:
		_type_enemy = TypeEnemy.BOSS
	elif enemy_data.enemy_type != -1:
		_type_enemy = enemy_data.enemy_type as TypeEnemy

	var current_hp = enemy_data.hp
	var lvl = 1
	if SaveManager: lvl = SaveManager.current_level

	if lvl <= 5 and enemy_data.hp_early_levels > 0:
		current_hp = enemy_data.hp_early_levels

	_hp = current_hp
	_max_hp = _hp
	_damage = enemy_data.damage
	_fire_rate = enemy_data.fire_rate
	_spread = enemy_data.spread

	_patrol_speed = enemy_data.patrol_speed
	_chase_speed = enemy_data.chase_speed
	_notice_range = enemy_data.notice_range
	_attack_range = enemy_data.attack_range

	if enemy_data.hull_texture and _body:
		_body.texture = enemy_data.hull_texture

	if enemy_data.gun_texture and _gun:
		_gun.texture = enemy_data.gun_texture
		_gun.position.y = enemy_data.gun_offset
		_gun.offset.y = -enemy_data.gun_offset

	self.scale = enemy_data.scale
	_shoot_timer.wait_time = _fire_rate

func _auto_assign_resource_by_type():
	var path = "res://resources/enemies/"
	match _type_enemy:
		TypeEnemy.LIGHT: enemy_data = load(path + "enemy_light.tres")
		TypeEnemy.MEDIUM: enemy_data = load(path + "enemy_medium.tres")
		TypeEnemy.HEAVY: enemy_data = load(path + "enemy_heavy.tres")
		TypeEnemy.STATIONARY: enemy_data = load(path + "enemy_stationary.tres")
		TypeEnemy.TRIPLE: enemy_data = load(path + "enemy_triple.tres")
		TypeEnemy.BOSS: enemy_data = load(path + "enemy_boss.tres")
		TypeEnemy.ARTILLERY: enemy_data = load(path + "enemy_artillery.tres")
		TypeEnemy.SCOUT: enemy_data = load(path + "enemy_scout.tres")
		TypeEnemy.MECHANIC: enemy_data = load(path + "enemy_medium.tres")

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
	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY or _type_enemy == TypeEnemy.ARTILLERY: return

	var nav_target = null
	if _type_enemy == TypeEnemy.SCOUT:
		if not _scout_failed_to_find and is_instance_valid(_player):
			nav_target = _player
		else:
			nav_target = _base
	else:
		nav_target = _player if (is_instance_valid(_player) and (_current_state == State.CHASE or _base == null)) else _base

	if is_instance_valid(nav_target):
		_nav2d.target_position = nav_target.global_position

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
			_gun.global_rotation = lerp_angle(_gun.global_rotation, target_angle, 0.15)

func _move_enemy(delta: float):
	var current_speed = _chase_speed if (_current_state == State.CHASE or _type_enemy == TypeEnemy.SCOUT) else _patrol_speed

	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY or _type_enemy == TypeEnemy.ARTILLERY or current_speed <= 0:
		velocity = velocity.move_toward(Vector2.ZERO, delta * 600.0)
		return

	var target = _get_current_target()
	var nav_dir = Vector2.ZERO
	if not _nav2d.is_navigation_finished():
		nav_dir = (_nav2d.get_next_path_position() - global_position).normalized()

	_speed_limit_mult = 1.0
	var avoidance_force = _compute_ally_avoidance(nav_dir)
	_smoothed_avoidance = _smoothed_avoidance.lerp(avoidance_force, delta * 10.0)

	var in_attack_range = false
	if is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		# Бот останавливается только если видит цель И таймер "выкатывания" закончился
		if dist <= _attack_range and _target_in_sight and _roll_out_timer <= 0:
			in_attack_range = true

	var final_dir = Vector2.ZERO
	if in_attack_range:
		final_dir = _smoothed_avoidance * 0.3
	else:
		# Вес обхода увеличен для босса
		var avoid_weight = 1.2 if _type_enemy == TypeEnemy.BOSS else 0.7
		final_dir = (nav_dir + _smoothed_avoidance * avoid_weight).normalized()

	var final_speed = current_speed * _speed_limit_mult

	if final_dir.length() < 0.1:
		velocity = velocity.move_toward(Vector2.ZERO, delta * current_speed * 5.0)
	else:
		var target_vel = final_dir * final_speed
		velocity = velocity.lerp(target_vel, delta * 7.0)

		if velocity.length() > 15.0:
			var target_rot = velocity.angle() + PI/2
			rotation = lerp_angle(rotation, target_rot, delta * 5.0)

func _compute_ally_avoidance(forward: Vector2) -> Vector2:
	var avoidance_force = Vector2.ZERO
	var my_pos = global_position
	var my_radius = 75.0 * max(scale.x, scale.y)
	var is_i_boss = _type_enemy == TypeEnemy.BOSS

	for other in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(other) or other == self or other.is_queued_for_deletion():
			continue
		if not (other is CharacterBody2D):
			continue

		# Игнорируем стационарные турели и артиллерию в логике объезда, чтобы не застревать в узких проходах
		var other_type = other.get("_type_enemy")
		if other_type == TypeEnemy.STATIONARY or other_type == TypeEnemy.ARTILLERY:
			continue

		var diff = my_pos - other.global_position
		var dist = diff.length()
		var other_radius = 75.0 * max(other.scale.x, other.scale.y)
		var min_sep_dist = (my_radius + other_radius) * 1.05
		var is_other_boss = other.get("_type_enemy") == TypeEnemy.BOSS

		# 1. СИЛА РАЗДЕЛЕНИЯ (Фильтрация, чтобы не ехать назад и в стены)
		if dist < min_sep_dist:
			var mag = (min_sep_dist - dist) / min_sep_dist
			var push_dir = diff.normalized()

			if forward.length() > 0.1:
				var dot_f = push_dir.dot(forward)
				# Если союзник прямо ПЕРЕД нами (push_dir смотрит назад), выталкиваем себя вбок
				if dot_f < -0.7:
					var side_perp = Vector2(-forward.y, forward.x)
					var side_sign = 1 if side_perp.dot(diff) > 0 else -1
					push_dir = (side_perp * side_sign).normalized()
					mag *= 1.5
				elif dot_f < 0:
					push_dir = (push_dir - forward * dot_f).normalized()

			# ЗАЩИТА ОТ СТЕН: если в направлении расталкивания стена - гасим силу
			if _is_wall_near(push_dir, my_radius * 0.8):
				mag *= 0.1

			avoidance_force += push_dir * mag * (3.5 if is_other_boss else 2.5)

		if forward.length() > 0.1:
			var rel = other.global_position - my_pos
			var along = rel.dot(forward)
			var side_perp = Vector2(-forward.y, forward.x)
			var dot_side = side_perp.dot(rel)

			# А) ПРЕПЯТСТВИЕ ВПЕРЕДИ
			# Дистанция прогноза увеличена для предотвращения столкновений сзади
			var look_ahead = min_sep_dist * (3.5 if is_i_boss else 2.0)
			if along > 0 and along < look_ahead:
				if abs(dot_side) < min_sep_dist * 1.1:
					var bypass_found = false

					# Стабилизация выбора стороны (jitter protection)
					var preferred_side = _last_bypass_side
					if preferred_side == 0:
						preferred_side = -1 if dot_side > 0 else 1

					for side in [preferred_side, -preferred_side]:
						var side_dir = side_perp * side
						if _has_space_for_bypass(side_dir, min_sep_dist):
							var boss_boost = 2.5 if is_i_boss else 1.5
							var bypass_mag = remap(along, 0, look_ahead, boss_boost, 0.4)
							avoidance_force += side_dir * bypass_mag
							_last_bypass_side = side
							bypass_found = true
							break

					if not bypass_found:
						_last_bypass_side = 0
						var other_vel_len = other.velocity.length()
						var my_base_speed = (_chase_speed if (_current_state == State.CHASE or _type_enemy == TypeEnemy.SCOUT) else _patrol_speed)

						# Более агрессивное торможение, чтобы не "липнуть" сзади
						var safety_dist = min_sep_dist * 0.9
						if along < safety_dist:
							_speed_limit_mult = min(_speed_limit_mult, remap(along, safety_dist * 0.4, safety_dist, 0.0, 0.5))
						else:
							var target_mult = clamp(other_vel_len / my_base_speed, 0.0, 1.0)
							var dist_factor = clamp((along - safety_dist) / (min_sep_dist * 1.5), 0.0, 1.0)
							_speed_limit_mult = min(_speed_limit_mult, lerp(target_mult * 0.85, 1.0, dist_factor))
				else:
					_last_bypass_side = 0

			# Б) БОСС СЗАДИ - УСТУПАЕМ ДОРОГУ
			elif along < 0 and abs(along) < min_sep_dist * 1.6 and is_other_boss and not is_i_boss:
				var side_options = [1, -1]
				if dot_side > 0: side_options = [-1, 1]

				for side in side_options:
					var escape_dir = side_perp * side
					# Проверяем наличие места, чтобы не вжиматься в стены
					if _has_space_for_bypass(escape_dir, min_sep_dist * 0.7):
						avoidance_force += escape_dir * 1.8
						break

	return avoidance_force

func _is_wall_near(dir: Vector2, distance: float) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * distance)
	query.exclude = [self]
	query.collision_mask = 1 # Стены
	return space_state.intersect_ray(query) != null

func _has_space_for_bypass(side_dir: Vector2, check_dist: float) -> bool:
	var space_state = get_world_2d().direct_space_state
	var directions = [
		side_dir,
		(side_dir + Vector2(0, -0.7).rotated(rotation)).normalized(),
		side_dir.rotated(0.3)
	]

	for dir in directions:
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * (check_dist * 1.3))
		query.exclude = [self]
		query.collision_mask = 1 # Только СТЕНЫ
		var result = space_state.intersect_ray(query)
		if result:
			return false

	return true

func _update_ray_cast():
	if _ray_cast == null: return
	var target = _get_current_target()
	if target:
		_ray_cast.target_position = _ray_cast.to_local(target.global_position)
		_ray_cast.enabled = true
		_ray_cast.force_raycast_update()

func _is_target_visible() -> bool:
	if _type_enemy == TypeEnemy.ARTILLERY:
		# СТРОГАЯ ПРОВЕРКА ДЛЯ АРТИЛЛЕРИИ:
		# 1. Проверяем засвет от скаута (приоритет)
		var time_since_spotted = (Time.get_ticks_msec() / 1000.0) - Enemy.last_spotted_time
		if time_since_spotted <= 2.5 and is_instance_valid(Enemy.scout_target):
			# Для арты по засвету скаута убираем все проверки препятствий у ствола.
			# Это навесной огонь, стены рядом не должны мешать.
			return true

		# 2. Самостоятельное обнаружение ТОЛЬКО ИГРОКА и только в пределах LoS (никаких стен)
		if is_instance_valid(_player):
			var dist = global_position.distance_to(_player.global_position)
			# Уменьшаем радиус "самостоятельной" стрельбы арты без скаута до 500
			if dist <= 500.0 and _is_target_visible_at(_player):
				return true

		return false

	var target = _get_current_target()
	if not is_instance_valid(target): return false

	# Базовая видимость центра
	if not _is_target_visible_at(target):
		return false

	# Дополнительная проверка боковых лучей (защита от стрельбы в стену полкорпусом)
	var is_base = target is Base
	# Для баз используем меньший офсет, чтобы боты не тупили перед стенами, но видели препятствие
	var side_offset = (20.0 if is_base else 35.0) * max(scale.x, scale.y)
	var dir_to_target = (target.global_position - global_position).normalized()
	var right = Vector2(-dir_to_target.y, dir_to_target.x) * side_offset

	for offset in [right, -right]:
		if not _is_line_clear_to_target(global_position + offset, target):
			return false

	return true

func _is_line_clear_to_target(from: Vector2, target_node_or_pos) -> bool:
	var target_pos = target_node_or_pos.global_position if target_node_or_pos is Node2D else target_node_or_pos
	var space_state = get_world_2d().direct_space_state

	# Список исключений для луча (те, сквозь кого мы "смотрим")
	var exclude_list: Array[RID] = [get_rid()]

	# Мы делаем несколько проходов (цикл), чтобы проверить, нет ли неразрушимых препятствий за разрушимыми
	# 10 итераций должно хватить для самых сложных нагромождений коробок
	for i in range(10):
		var query = PhysicsRayQueryParameters2D.create(from, target_pos)
		query.exclude = exclude_list
		query.collision_mask = 3 # Стены (1) и Танки/Базы (2)
		var result = space_state.intersect_ray(query)

		# Если луч ни во что не врезался - путь чист
		if result.is_empty():
			return true

		var collider = result.collider

		# 1. Если попали прямо в цель (или её физическое тело в случае базы)
		if target_node_or_pos is Node:
			if collider == target_node_or_pos or (collider is Node and collider.get_parent() == target_node_or_pos):
				return true

		# 2. Если попали в другого врага - игнорируем его (мы разрешили стрельбу сквозь своих)
		if collider is Enemy:
			exclude_list.append(collider.get_rid())
			continue

		# 3. Проверка на разрушаемость
		var is_destructible = false
		if collider.has_method("destroyable") and collider.destroyable():
			is_destructible = true
		elif collider.is_in_group("walls") and collider.has_method("destroyable") and collider.destroyable():
			is_destructible = true

		if is_destructible:
			# Если объект разрушаем, мы добавляем его в исключения и "смотрим" дальше.
			# Таким образом, если ЗА этой коробкой стоит бетонная стена, луч в итоге упрётся в неё
			# и вернёт false, и бот не будет тратить снаряды впустую.
			exclude_list.append(collider.get_rid())
			continue

		# 4. Если мы дошли до этой точки, значит попали во что-то твердое (неразрушимая стена)
		return false

	return false

func _is_target_visible_at(target) -> bool:
	if not is_instance_valid(target): return false

	# Для арты делаем "честный" старт луча чуть впереди, чтобы не застревать в своей коллизии
	var from = global_position
	if _type_enemy == TypeEnemy.ARTILLERY:
		var dir = (target.global_position - global_position).normalized()
		from = global_position + dir * 110.0

	return _is_line_clear_to_target(from, target)

func _get_current_target():
	if _type_enemy == TypeEnemy.ARTILLERY:
		var time_since_spotted = (Time.get_ticks_msec() / 1000.0) - Enemy.last_spotted_time
		if time_since_spotted <= 2.5 and is_instance_valid(Enemy.scout_target):
			return Enemy.scout_target
		return _player

	if _type_enemy == TypeEnemy.SCOUT:
		return _base if _scout_failed_to_find else _player

	if is_instance_valid(_player) and (_current_state == State.CHASE or _base == null):
		return _player
	return _base

func _check_and_fire():
	var target = _get_current_target()
	if target == null: return

	var dist = global_position.distance_to(target.global_position)

	var can_fire = false
	if _type_enemy == TypeEnemy.ARTILLERY:
		# Арта стреляет только если цель в прямой видимости (или по наводке)
		can_fire = _target_in_sight and _reaction_timer >= 1.2
	elif _type_enemy == TypeEnemy.SCOUT:
		if dist <= _attack_range and _target_in_sight:
			can_fire = true
	elif target == _player:
		if dist <= _attack_range and _target_in_sight:
			can_fire = true
	else:
		# Стрельба по базе или другим целям
		if dist <= 700.0 and _target_in_sight:
			can_fire = true

	if can_fire:
		if _type_enemy == TypeEnemy.STATIONARY:
			if _reaction_timer >= 1.0:
				_fire_at_pos(target.global_position)
		elif _type_enemy == TypeEnemy.ARTILLERY:
			_fire_artillery(target.global_position)
		else:
			_fire_at_pos(target.global_position)

func _fire_artillery(pos: Vector2):
	if _shoot_timer.time_left > 0: return

	var indicator_scene = load("res://scenes/Tank/ArtilleryTarget.tscn")
	if indicator_scene:
		var offset_radius = _spread * 600.0
		var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0, offset_radius)
		var target_pos = pos + random_offset

		var indicator = indicator_scene.instantiate()
		indicator.global_position = target_pos
		indicator.set("_damage", _damage)
		get_parent().add_child(indicator)

		if _shot_flash:
			_shot_flash.play("Fire")

		if _gun:
			var original_pos = _gun.position
			var shoot_dir = Vector2(0, 1).rotated(_gun.global_rotation)
			var tween = create_tween()
			tween.tween_property(_gun, "position", original_pos + shoot_dir * 15.0, 0.05)
			tween.tween_property(_gun, "position", original_pos, 0.15)

		if AudioManager: AudioManager.play_bullet_sound(2, global_position)

		_shoot_timer.start(_fire_rate)

func _fire_at_pos(pos: Vector2):
	if _shoot_timer.time_left > 0: return

	var base_angle = (pos - _gun.global_position).angle() + PI/2
	var sound_type = 2 if _type_enemy == TypeEnemy.STATIONARY else (1 if _type_enemy == TypeEnemy.TRIPLE else 0)

	if AudioManager:
		AudioManager.play_bullet_sound(sound_type, global_position)

	# ПРОВЕРКА НА ТРОЙНОЙ ВЫСТРЕЛ: строго по типу
	if _type_enemy == TypeEnemy.TRIPLE:
		var angles = [base_angle, base_angle - 0.4, base_angle + 0.4]
		for angle in angles:
			var bullet = _bullet_scene.instantiate()
			bullet.global_position = _bullet_position.global_position
			bullet.global_rotation = angle
			get_parent().add_child(bullet)
			bullet.init(1, false, _damage, get_rid())
	else:
		var bullet = _bullet_scene.instantiate()
		var angle = base_angle + randf_range(-_spread, _spread)
		bullet.global_position = _bullet_position.global_position
		bullet.global_rotation = angle
		get_parent().add_child(bullet)
		var b_type = 2 if _type_enemy == TypeEnemy.STATIONARY else 0
		bullet.init(b_type, false, _damage, get_rid())

	if _shot_flash:
		_shot_flash.play("Fire")
	_shoot_timer.start()

func _on_detection_area_entered(body):
	if body == _player: _current_state = State.CHASE

func _on_detection_area_exited(body):
	if body == _player: _current_state = State.PATROL

func _destroy():
	# Если умирает скаут, немедленно сбрасываем глобальный засвет для арты
	if _type_enemy == TypeEnemy.SCOUT:
		Enemy.scout_target = null
		Enemy.last_spotted_time = -100.0

	enemy_died.emit(_type_enemy)
	if is_instance_valid(_player) and _player.has_method("add_money"):
		var reward = enemy_data.reward_money if enemy_data else _get_reward()
		_player.add_money(reward)

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
		TypeEnemy.ARTILLERY: return 300
		TypeEnemy.SCOUT: return 150
		_: return 50

func _apply_enemy_stats():
	pass

func _randomize_enemy_type():
	var available_types = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY]
	var lvl = SaveManager.current_level if SaveManager else 1
	_type_enemy = available_types[randi() % available_types.size()]
