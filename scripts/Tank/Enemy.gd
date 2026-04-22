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

# ОПТИМИЗАЦИЯ
var _logic_frame_offset: int = 0
var _cached_avoidance: Vector2 = Vector2.ZERO
# endregion

func get_enemy_type() -> int:
	return _type_enemy

func _ready():
	add_to_group("enemies")
	_init_base_tank()

	_logic_frame_offset = randi() % 10

	_nav2d = get_node_or_null("NavigationAgent2D")
	_ray_cast = get_node_or_null("RayCast2D")
	_detection_area = get_node_or_null("DetectionArea")
	_shot_flash = get_node_or_null("ShotAnimation")

	if _ray_cast:
		_ray_cast.collide_with_areas = false
		_ray_cast.add_exception(self)
		_ray_cast.collision_mask = 1

	if scout_target != null and (not is_instance_valid(scout_target) or scout_target.get_tree() != get_tree()):
		scout_target = null
		last_spotted_time = -100.0

	if enemy_data: _apply_data_from_resource()
	if _type_enemy == TypeEnemy.NONE: _randomize_enemy_type()
	if not enemy_data:
		_auto_assign_resource_by_type()
		if enemy_data: _apply_data_from_resource()
	if not enemy_data: _apply_enemy_stats()

	if _type_enemy == TypeEnemy.STATIONARY:
		var collision = get_node_or_null("CollisionShape2D")
		if collision and collision.shape is CircleShape2D:
			collision.shape.radius *= 0.8

	match _type_enemy:
		TypeEnemy.ARTILLERY:
			_patrol_speed = 0; _chase_speed = 0
			_blind_fire_range = 650.0; _setup_artillery_flash()
		TypeEnemy.SCOUT:
			_scout_search_duration = 20.0; _scout_search_timer = 0.0; _current_state = State.CHASE

	if _shot_flash and _bullet_position and _type_enemy != TypeEnemy.ARTILLERY:
		if _shot_flash.get_parent() != _bullet_position:
			_shot_flash.get_parent().remove_child(_shot_flash)
			_bullet_position.add_child(_shot_flash)
		_shot_flash.position = Vector2.ZERO; _shot_flash.rotation = 0; _shot_flash.scale = Vector2(0.5, 0.5)

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
	_shot_flash.sprite_frames = SpriteFrames.new(); _shot_flash.sprite_frames.add_animation("Fire"); _shot_flash.sprite_frames.set_animation_speed("Fire", 25.0); _shot_flash.sprite_frames.set_animation_loop("Fire", false)
	var textures = [null, "res://assets/future_tanks/PNG/Effects/Explosion_B.png", "res://assets/future_tanks/PNG/Effects/Explosion_C.png", "res://assets/future_tanks/PNG/Effects/Explosion_D.png", "res://assets/future_tanks/PNG/Effects/Explosion_E.png", "res://assets/future_tanks/PNG/Effects/Explosion_F.png", "res://assets/future_tanks/PNG/Effects/Explosion_G.png", "res://assets/future_tanks/PNG/Effects/Explosion_H.png", null]
	for tex_path in textures:
		if tex_path: _shot_flash.sprite_frames.add_frame("Fire", load(tex_path))
		else: _shot_flash.sprite_frames.add_frame("Fire", null)
	_shot_flash.scale = Vector2(0.5, 0.5); _shot_flash.position = Vector2(0, -45); _shot_flash.rotation = 0

func _physics_process(delta):
	var current_frame = Engine.get_physics_frames() + _logic_frame_offset
	if not is_instance_valid(_player) or (not is_instance_valid(_base) and _base != null):
		if current_frame % 30 == 0: _find_targets()
	if _type_enemy == TypeEnemy.SCOUT: _process_scout_logic(delta)
	if current_frame % 2 == 0: _update_target()
	_aim_gun(delta)
	_update_ray_cast()
	var was_visible = _target_in_sight
	_target_in_sight = _is_target_visible()
	if _target_in_sight and not was_visible: _roll_out_timer = 0.1
	if _roll_out_timer > 0: _roll_out_timer -= delta
	if _target_in_sight: _reaction_timer += delta
	else: _reaction_timer = 0.0
	_check_and_fire(); _move_enemy(delta); move_and_slide(); _handle_movement_sound(velocity)

func _process_scout_logic(delta):
	if (Engine.get_physics_frames() + _logic_frame_offset) % 4 != 0: return
	if _scout_failed_to_find:
		if is_instance_valid(_base) and global_position.distance_to(_base.global_position) <= _notice_range:
			if _is_target_visible_at(_base):
				Enemy.scout_target = _base; Enemy.last_spotted_time = Time.get_ticks_msec() / 1000.0
		return
	_scout_search_timer += delta
	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= _notice_range:
		if _is_target_visible_at(_player):
			Enemy.scout_target = _player; _scout_found_player = true; Enemy.last_spotted_time = Time.get_ticks_msec() / 1000.0; _scout_search_timer = 0.0
		else: _scout_found_player = false
	else: _scout_found_player = false
	if _scout_search_timer >= _scout_search_duration: _scout_failed_to_find = true

func _apply_data_from_resource():
	if not enemy_data: return
	if enemy_data.is_boss: _type_enemy = TypeEnemy.BOSS
	elif enemy_data.enemy_type != -1: _type_enemy = enemy_data.enemy_type as TypeEnemy
	var current_hp = enemy_data.hp; var lvl = SaveManager.current_level if SaveManager else 1
	if lvl <= 5 and enemy_data.hp_early_levels > 0: current_hp = enemy_data.hp_early_levels
	_hp = current_hp; _max_hp = _hp; _damage = enemy_data.damage; _fire_rate = enemy_data.fire_rate; _spread = enemy_data.spread; _patrol_speed = enemy_data.patrol_speed; _chase_speed = enemy_data.chase_speed; _notice_range = enemy_data.notice_range; _attack_range = enemy_data.attack_range
	if enemy_data.hull_texture and _body: _body.texture = enemy_data.hull_texture
	if enemy_data.gun_texture and _gun: _gun.texture = enemy_data.gun_texture; _gun.position.y = enemy_data.gun_offset; _gun.offset.y = -enemy_data.gun_offset
	self.scale = enemy_data.scale; _shoot_timer.wait_time = _fire_rate

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
	if players.size() > 0: _player = players[0]
	var bases = get_tree().get_nodes_in_group("bases")
	_base = null
	for b in bases:
		if b.get("type_base") == 0: _base = b; break
	if _base == null: _current_state = State.CHASE

func _update_target():
	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY or _type_enemy == TypeEnemy.ARTILLERY: return
	var nav_target = _player if (is_instance_valid(_player) and (_current_state == State.CHASE or _base == null)) else _base
	if _type_enemy == TypeEnemy.SCOUT: nav_target = _player if (not _scout_failed_to_find and is_instance_valid(_player)) else _base
	if is_instance_valid(nav_target): _nav2d.target_position = nav_target.global_position

func _aim_gun(delta: float):
	if _gun == null: return
	if _type_enemy == TypeEnemy.STATIONARY and _current_state == State.PATROL:
		if _scan_wait_timer > 0: _scan_wait_timer -= delta; return
		_scan_angle += 40.0 * delta * _scan_dir
		if abs(_scan_angle) >= _scan_limit: _scan_dir *= -1; _scan_wait_timer = 1.5
		_gun.rotation_degrees = _scan_angle
	else:
		var target = _get_current_target()
		if target:
			var target_angle = (target.global_position - _gun.global_position).angle() + PI / 2
			_gun.global_rotation = lerp_angle(_gun.global_rotation, target_angle, 0.25)

func _move_enemy(delta: float):
	_speed_limit_mult = 1.0 # СБРАСЫВАЕМ СКОРОСТЬ КАЖДЫЙ КАДР
	var current_speed = _chase_speed if (_current_state == State.CHASE or _type_enemy == TypeEnemy.SCOUT) else _patrol_speed
	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY or _type_enemy == TypeEnemy.ARTILLERY or current_speed <= 0:
		velocity = velocity.move_toward(Vector2.ZERO, delta * 600.0); return
	var target = _get_current_target()
	var nav_dir = Vector2.ZERO
	if not _nav2d.is_navigation_finished(): nav_dir = (_nav2d.get_next_path_position() - global_position).normalized()
	if (Engine.get_physics_frames() + _logic_frame_offset) % 2 == 0:
		_cached_avoidance = _compute_ally_avoidance(nav_dir)
	_smoothed_avoidance = _smoothed_avoidance.lerp(_cached_avoidance, delta * 12.0)
	var in_attack_range = false
	if is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= _attack_range and _target_in_sight and _roll_out_timer <= 0: in_attack_range = true
	var final_dir = _smoothed_avoidance * 0.3 if in_attack_range else (nav_dir + _smoothed_avoidance * (1.2 if _type_enemy == TypeEnemy.BOSS else 0.7)).normalized()
	velocity = velocity.lerp(final_dir * current_speed * _speed_limit_mult, delta * 9.0)
	if velocity.length() > 15.0: rotation = lerp_angle(rotation, velocity.angle() + PI/2, delta * 6.0)

func _compute_ally_avoidance(forward: Vector2) -> Vector2:
	var avoidance_force = Vector2.ZERO; var my_pos = global_position; var my_radius = 75.0 * max(scale.x, scale.y); var is_i_boss = _type_enemy == TypeEnemy.BOSS
	for other in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(other) or other == self or other.is_queued_for_deletion() or not (other is CharacterBody2D): continue
		var dist_sq = my_pos.distance_squared_to(other.global_position)
		if dist_sq > 360000: continue
		var other_type = other.get("_type_enemy")
		if other_type == TypeEnemy.STATIONARY or other_type == TypeEnemy.ARTILLERY: continue
		var diff = my_pos - other.global_position; var dist = sqrt(dist_sq); var min_sep_dist = (my_radius + (75.0 * max(other.scale.x, other.scale.y))) * 1.05
		if dist < min_sep_dist:
			var mag = (min_sep_dist - dist) / min_sep_dist; var push_dir = diff.normalized()
			if forward.length() > 0.1:
				var dot_f = push_dir.dot(forward)
				if dot_f < -0.7: var side_perp = Vector2(-forward.y, forward.x); push_dir = (side_perp * (1 if side_perp.dot(diff) > 0 else -1)).normalized(); mag *= 1.5
				elif dot_f < 0: push_dir = (push_dir - forward * dot_f).normalized()
			if _is_wall_near(push_dir, my_radius * 0.8): mag *= 0.1
			avoidance_force += push_dir * mag * (3.5 if other.get("_type_enemy") == TypeEnemy.BOSS else 2.5)
		if forward.length() > 0.1:
			var rel = other.global_position - my_pos; var along = rel.dot(forward); var look_ahead = min_sep_dist * (3.5 if is_i_boss else 2.0)
			if along > 0 and along < look_ahead:
				var side_perp = Vector2(-forward.y, forward.x); var dot_side = side_perp.dot(rel)
				if abs(dot_side) < min_sep_dist * 1.1:
					var side = _last_bypass_side if _last_bypass_side != 0 else (-1 if dot_side > 0 else 1)
					if _has_space_for_bypass(side_perp * side, min_sep_dist): avoidance_force += (side_perp * side) * remap(along, 0, look_ahead, (2.5 if is_i_boss else 1.5), 0.4); _last_bypass_side = side
					elif _has_space_for_bypass(side_perp * -side, min_sep_dist): avoidance_force += (side_perp * -side) * remap(along, 0, look_ahead, (2.5 if is_i_boss else 1.5), 0.4); _last_bypass_side = -side
					else: _last_bypass_side = 0
	return avoidance_force

func _is_wall_near(dir: Vector2, distance: float) -> bool:
	var q = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * distance); q.exclude = [self]; q.collision_mask = 1; return get_world_2d().direct_space_state.intersect_ray(q) != null

func _has_space_for_bypass(side_dir: Vector2, check_dist: float) -> bool:
	for dir in [side_dir, (side_dir + Vector2(0, -0.7).rotated(rotation)).normalized()]:
		var q = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * (check_dist * 1.3)); q.exclude = [self]; q.collision_mask = 1
		if get_world_2d().direct_space_state.intersect_ray(q): return false
	return true

func _update_ray_cast():
	if _ray_cast == null: return
	var target = _get_current_target()
	if target: _ray_cast.target_position = _ray_cast.to_local(target.global_position); _ray_cast.enabled = true; _ray_cast.force_raycast_update()

func _is_target_visible() -> bool:
	if _type_enemy == TypeEnemy.ARTILLERY:
		if (Time.get_ticks_msec() / 1000.0) - Enemy.last_spotted_time <= 2.5 and is_instance_valid(Enemy.scout_target): return true
		if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= 500.0 and _is_target_visible_at(_player): return true
		return false
	var target = _get_current_target(); if not is_instance_valid(target): return false
	if not _is_target_visible_at(target): return false
	if (Engine.get_physics_frames() + _logic_frame_offset) % 2 != 0: return true
	var dir = (target.global_position - global_position).normalized(); var right = Vector2(-dir.y, dir.x) * (35.0 * max(scale.x, scale.y))
	for offset in [right, -right]:
		if not _is_line_clear_to_target(global_position + offset, target): return false
	return true

func _is_line_clear_to_target(from: Vector2, target_node_or_pos) -> bool:
	var target_pos = target_node_or_pos.global_position if target_node_or_pos is Node2D else target_node_or_pos; var space_state = get_world_2d().direct_space_state; var exclude_list: Array[RID] = [get_rid()]
	for i in range(10):
		var q = PhysicsRayQueryParameters2D.create(from, target_pos); q.exclude = exclude_list; q.collision_mask = 3; var res = space_state.intersect_ray(q)
		if res.is_empty(): return true
		var c = res.collider
		if target_node_or_pos is Node and (c == target_node_or_pos or (c is Node and c.get_parent() == target_node_or_pos)): return true
		if c is Enemy or (c.has_method("destroyable") and c.destroyable()) or (c.is_in_group("walls") and c.has_method("destroyable") and c.destroyable()):
			exclude_list.append(c.get_rid()); continue
		return false
	return false

func _is_target_visible_at(target) -> bool:
	if not is_instance_valid(target): return false
	var from = global_position; if _type_enemy == TypeEnemy.ARTILLERY: from += (target.global_position - global_position).normalized() * 110.0
	return _is_line_clear_to_target(from, target)

func _get_current_target():
	if _type_enemy == TypeEnemy.ARTILLERY and (Time.get_ticks_msec() / 1000.0) - Enemy.last_spotted_time <= 2.5 and is_instance_valid(Enemy.scout_target): return Enemy.scout_target
	if _type_enemy == TypeEnemy.SCOUT: return _base if _scout_failed_to_find else _player
	return _player if (is_instance_valid(_player) and (_current_state == State.CHASE or _base == null)) else _base

func _check_and_fire():
	var target = _get_current_target(); if target == null: return
	var dist = global_position.distance_to(target.global_position); var can_fire = false
	if _type_enemy == TypeEnemy.ARTILLERY: can_fire = _target_in_sight and _reaction_timer >= 1.2
	else: can_fire = _target_in_sight and dist <= (_attack_range if target == _player or _type_enemy == TypeEnemy.SCOUT else 700.0)
	if can_fire:
		if _type_enemy == TypeEnemy.STATIONARY:
			if _reaction_timer >= 1.0: _fire_at_pos(target.global_position)
		elif _type_enemy == TypeEnemy.ARTILLERY: _fire_artillery(target.global_position)
		else: _fire_at_pos(target.global_position)

func _fire_artillery(pos: Vector2):
	if _shoot_timer.time_left > 0: return
	var ind = load("res://scenes/Tank/ArtilleryTarget.tscn")
	if ind:
		var target_pos = pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0, _spread * 600.0)
		var i = ind.instantiate(); i.global_position = target_pos; i.set("_damage", _damage); get_parent().add_child(i)
		if _shot_flash: _shot_flash.play("Fire")
		if _gun:
			var o = _gun.position
			var tween = create_tween()
			tween.tween_property(_gun, "position", o + Vector2(0, 1).rotated(_gun.global_rotation) * 15.0, 0.05)
			tween.tween_property(_gun, "position", o, 0.15)
		if AudioManager: AudioManager.play_bullet_sound(2, global_position)
		_shoot_timer.start(_fire_rate)

func _fire_at_pos(pos: Vector2):
	if _shoot_timer.time_left > 0: return
	var a = (pos - _gun.global_position).angle() + PI/2; var s = 2 if _type_enemy == TypeEnemy.STATIONARY else (1 if _type_enemy == TypeEnemy.TRIPLE else 0)
	if AudioManager: AudioManager.play_bullet_sound(s, global_position)
	if _type_enemy == TypeEnemy.TRIPLE:
		for off in [0.0, -0.4, 0.4]:
			var b = _bullet_scene.instantiate(); b.global_position = _bullet_position.global_position; b.global_rotation = a + off; get_parent().add_child(b); b.init(1, false, _damage, get_rid())
	else:
		var b = _bullet_scene.instantiate(); b.global_position = _bullet_position.global_position; b.global_rotation = a + randf_range(-_spread, _spread); get_parent().add_child(b); b.init(2 if _type_enemy == TypeEnemy.STATIONARY else 0, false, _damage, get_rid())
	if _shot_flash: _shot_flash.play("Fire")
	_shoot_timer.start()

func _on_detection_area_entered(body): if body == _player: _current_state = State.CHASE
func _on_detection_area_exited(body): if body == _player: _current_state = State.PATROL

func _destroy():
	if _type_enemy == TypeEnemy.SCOUT: Enemy.scout_target = null; Enemy.last_spotted_time = -100.0
	enemy_died.emit(_type_enemy)
	if is_instance_valid(_player) and _player.has_method("add_money"): _player.add_money(enemy_data.reward_money if enemy_data else _get_reward())
	if _type_enemy == TypeEnemy.STATIONARY or randf() <= 0.25: _spawn_heal_pickup()
	super._destroy()

func _spawn_heal_pickup():
	var ps = load("res://scripts/HealPickup.gd"); if not ps: return
	var p = Area2D.new(); p.set_script(ps); p.global_position = global_position; get_parent().call_deferred("add_child", p)

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

func _apply_enemy_stats(): pass
func _randomize_enemy_type(): _type_enemy = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY][randi() % 3]
