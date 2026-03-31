class_name Base
extends Area2D

enum TypeBase { PLAYER, ENEMY }

signal base_state()

export var type_base: int = TypeBase.ENEMY

var _spawn_timer: Timer
var _heal_timer: Timer
var _enemy_position: Position2D
var _enemy_scene: PackedScene

export var _max_enemies: int = 3
export var _heal_amount: int = 5
export var _heal_interval: float = 1.0
export var _heal_radius: float = 300.0
var _time_since_last_check: float = 0.0
var _spawn_radius: float = 60.0

func _ready():
	connect("area_entered", self, "_on_bullet_entered")
	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	_enemy_position = get_node_or_null("EnemyPosition")
	
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 3.0
	_spawn_timer.one_shot = true
	add_child(_spawn_timer)
	
	_spawn_timer.start(5.0)

	_heal_timer = Timer.new()
	_heal_timer.wait_time = _heal_interval
	_heal_timer.one_shot = false
	add_child(_heal_timer)
	_heal_timer.connect("timeout", self, "_on_heal_timeout")
	_heal_timer.start()

	_setup_base_collision()

func _setup_base_collision():
	# Добавляем StaticBody2D, чтобы танки не могли проезжать сквозь базу
	var sb = StaticBody2D.new()
	add_child(sb)
	var cs = CollisionShape2D.new()
	var circle = CircleShape2D.new()

	# Пытаемся взять радиус из существующей коллизии Area2D или ставим по умолчанию
	var area_shape = get_node_or_null("CollisionShape2D")
	if area_shape and area_shape.shape is CircleShape2D:
		circle.radius = area_shape.shape.radius
	else:
		circle.radius = 60.0

	cs.shape = circle
	sb.add_child(cs)

func _on_bullet_entered(area):
	# Проверка попадания пули (пуля должна быть Area2D)
	if area.has_method("is_player"):
		if (area.is_player() and type_base == TypeBase.ENEMY) or (not area.is_player() and type_base == TypeBase.PLAYER):
			_destroy()

func _on_heal_timeout():
	if type_base != TypeBase.PLAYER:
		return
	
	var player = get_node_or_null("/root/Field/PlayerTank")
	if player == null or not is_instance_valid(player):
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance <= _heal_radius:
		player.take_heal(_heal_amount)

func destroy():
	_destroy()

func _destroy():
	emit_signal("base_state")
	queue_free()

func _count_enemies_on_scene() -> int:
	var enemies = get_tree().get_nodes_in_group("enemies")
	return enemies.size()

func _is_enemy_on_base() -> bool:
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < _spawn_radius:
			return true
	return false

func _spawn_enemy():
	if _spawn_timer.time_left > 0:
		return
	
	if type_base == TypeBase.PLAYER:
		return
	
	if _is_enemy_on_base():
		return
	
	var current_enemies = _count_enemies_on_scene()
	
	if current_enemies >= _max_enemies:
		_spawn_timer.start()
		return
	
	var spawn_pos = _get_safe_spawn_pos()
	if spawn_pos != Vector2.ZERO:
		var enemy = _enemy_scene.instance()
		enemy.global_position = spawn_pos
		get_tree().root.add_child(enemy)
		_spawn_timer.start()

func _get_safe_spawn_pos() -> Vector2:
	var attempts = 0
	while attempts < 30:
		var angle = rand_range(0, 2 * PI)
		var spawn_distance = rand_range(200, 350)
		var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * spawn_distance

		if _is_pos_safe(spawn_pos):
			return spawn_pos
		attempts += 1
	return Vector2.ZERO

func _is_pos_safe(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state

	# Параметры запроса для проверки коллизий в точке спавна
	var query = Physics2DTestMotionResult.new()

	# Проверяем нет ли в этой точке препятствий (стены, игрок)
	# Мы используем intersect_point или intersect_shape
	var shape = CircleShape2D.new()
	shape.radius = 40.0 # Примерный размер танка

	var shape_query = Physics2DShapeQueryParameters.new()
	shape_query.set_shape(shape)
	shape_query.transform = Transform2D(0, pos)
	# Исключаем саму базу из проверки, чтобы она не мешала спавну
	shape_query.exclude = [self]

	var results = space_state.intersect_shape(shape_query)

	for result in results:
		var collider = result.collider
		# Если попали в стену (TileMap или StaticBody) или игрока/врага (KinematicBody)
		if collider is TileMap or collider is StaticBody2D or collider is KinematicBody2D:
			return false

	return true

func _process(delta):
	_time_since_last_check += delta
	if _time_since_last_check >= 0.5:
		_spawn_enemy()
		_time_since_last_check = 0
