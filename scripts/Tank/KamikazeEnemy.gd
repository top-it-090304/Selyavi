extends Enemy
class_name KamikazeEnemy

var _is_detonating: bool = false
var _detonation_timer: float = 0.4
var _has_exploded: bool = false

func _ready():
	_type_enemy = TypeEnemy.KAMIKAZE
	super._ready()

	_current_state = State.CHASE
	_notice_range = 2000.0 
	_attack_range = 100.0 # Дистанция для начала мигания

	# Башня идеально по центру
	if _gun:
		_gun.position = Vector2.ZERO

func _physics_process(delta):
	if _has_exploded: return

	# Движение строго на базовой скорости
	_update_target()
	_move_towards_target(delta)
	move_and_slide()

	# Проверка физического контакта с игроком
	_check_player_contact()
	if _has_exploded: return

	# Логика таймера детонации
	if _is_detonating:
		_detonation_timer -= delta
		if _body:
			var pulse = abs(sin(Time.get_ticks_msec() * 0.03))
			_body.modulate = Color(1.0 + pulse * 5.0, 0.2, 0.2)
			if _gun: _gun.modulate = Color(1.0 + pulse * 5.0, 0.2, 0.2)

		if _detonation_timer <= 0:
			explode(true) # Полный взрыв по таймеру
		return

	# Начало подготовки к взрыву при приближении
	var target = _get_current_target()
	if is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= _attack_range:
			start_detonation()

func _check_player_contact():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if _is_collider_player(collider):
			explode(true) # Полный взрыв при касании
			break

func _is_collider_player(collider) -> bool:
	if not collider: return false
	if collider.is_in_group("players"): return true
	if collider.get_parent() and collider.get_parent().is_in_group("players"): return true
	return false

func _move_towards_target(delta):
	if _nav2d == null: return

	var current_speed = _chase_speed 
	var nav_dir = Vector2.ZERO
	
	if not _nav2d.is_navigation_finished():
		nav_dir = (_nav2d.get_next_path_position() - global_position).normalized()
	else:
		var target = _get_current_target()
		if is_instance_valid(target):
			nav_dir = (target.global_position - global_position).normalized()

	velocity = velocity.lerp(nav_dir * current_speed, delta * 8.0)

	if velocity.length() > 10.0:
		rotation = lerp_angle(rotation, velocity.angle() + PI/2, delta * 10.0)
		if _gun:
			_gun.rotation = 0

func start_detonation():
	if _is_detonating: return
	_is_detonating = true

func explode(is_full: bool = true):
	if _has_exploded: return
	_has_exploded = true

	# Настройка параметров взрыва
	var radius = 280.0 if is_full else 165.0
	var damage_val = int(_damage) if is_full else int(_damage * 0.5)

	# Мягкий персиковый цвет для малого взрыва — выглядит "безопаснее" оранжевого
	var color = Color(1.0, 0.3, 0.1) if is_full else Color(1.0, 0.6, 0.4)

	# Наносим урон в радиусе
	_spawn_explosion_damage(radius, damage_val)

	# Визуальный эффект (создаем через скрипт)
	var effect_script = load("res://scripts/ExplosionEffect.gd")
	if effect_script:
		var effect = Node2D.new()
		effect.set_script(effect_script)
		effect.global_position = global_position
		get_parent().add_child(effect)
		if effect.has_method("init"):
			effect.init(radius, color)

	# Оповещаем о смерти (для начисления денег и статистики)
	if not is_full:
		_report_death_to_system()
	
	queue_free()

func _report_death_to_system():
	enemy_died.emit(_type_enemy)
	var player = get_tree().get_first_node_in_group("players")
	if is_instance_valid(player) and player.has_method("add_money"):
		player.add_money(enemy_data.reward_money if enemy_data else 150)

func _spawn_explosion_damage(radius: float, damage_value: int):
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = radius

	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 1 | 2 

	var results = space_state.intersect_shape(query)
	var damaged_targets = []

	for result in results:
		var collider = result.collider
		if not is_instance_valid(collider) or collider == self: continue

		var target = collider
		if not target.has_method("take_damage"):
			if target.get_parent() and target.get_parent().has_method("take_damage"):
				target = target.get_parent()

		if target.has_method("take_damage") and not target in damaged_targets:
			target.take_damage(damage_value)
			damaged_targets.append(target)

	if AudioManager:
		AudioManager.play_bullet_sound(1, global_position)

func take_damage(amount: int):
	_hp -= amount
	if _hp <= 0:
		explode(false) # Малый взрыв при смерти от пуль
	else:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(5, 5, 5), 0.05)
		tween.tween_property(self, "modulate", Color.WHITE, 0.05)

func _destroy():
	if not _has_exploded:
		explode(false)
