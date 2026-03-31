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

var _stationary_enemies = []

func _ready():
	connect("area_entered", self, "_on_bullet_entered")
	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	_enemy_position = get_node_or_null("EnemyPosition")
	
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 0.1
	_spawn_timer.one_shot = true
	add_child(_spawn_timer)
	
	_spawn_timer.start(0.1)

	_heal_timer = Timer.new()
	_heal_timer.wait_time = _heal_interval
	_heal_timer.one_shot = false
	add_child(_heal_timer)
	_heal_timer.connect("timeout", self, "_on_heal_timeout")
	_heal_timer.start()

	_setup_base_collision()

func _setup_base_collision():
	var sb = StaticBody2D.new()
	add_child(sb)
	var cs = CollisionShape2D.new()
	var circle = CircleShape2D.new()

	var area_shape = get_node_or_null("CollisionShape2D")
	if area_shape and area_shape.shape is CircleShape2D:
		circle.radius = area_shape.shape.radius
	else:
		circle.radius = 60.0

	cs.shape = circle
	sb.add_child(cs)

func _on_bullet_entered(area):
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
	var count = 0
	for enemy in enemies:
		if enemy.get("_type_enemy") != 3: # Не считаем стационарных в общий лимит танков
			count += 1
	return count

func _is_enemy_on_base() -> bool:
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < _spawn_radius:
			return true
	return false

func _spawn_enemy():
	if type_base == TypeBase.PLAYER:
		return

	# Поддерживаем всегда 2 стационарных танка
	_maintain_stationary_enemies()

	var current_enemies = _count_enemies_on_scene()
	if current_enemies >= _max_enemies:
		return
	
	var spawn_pos = _get_safe_spawn_pos()
	if spawn_pos != Vector2.ZERO:
		var enemy = _enemy_scene.instance()
		enemy.global_position = spawn_pos
		get_tree().root.add_child(enemy)

func _maintain_stationary_enemies():
	var active_stationary = []
	for e in _stationary_enemies:
		if is_instance_valid(e):
			active_stationary.append(e)
	_stationary_enemies = active_stationary

	while _stationary_enemies.size() < 2:
		var spawn_pos = _get_safe_spawn_pos(true)
		if spawn_pos != Vector2.ZERO:
			var enemy = _enemy_scene.instance()
			if enemy.has_method("set_enemy_type"):
				enemy.set_enemy_type(3) # STATIONARY
			enemy.global_position = spawn_pos
			get_tree().root.add_child(enemy)
			_stationary_enemies.append(enemy)
		else:
			break

func _get_safe_spawn_pos(is_stationary: bool = false) -> Vector2:
	var player = get_node_or_null("/root/Field/PlayerTank")
	var player_base = null

	var bases = get_tree().get_nodes_in_group("bases")
	for b in bases:
		if b.type_base == TypeBase.PLAYER:
			player_base = b
			break

	var target_pos = Vector2.ZERO
	if is_instance_valid(player_base):
		target_pos = player_base.global_position
	elif is_instance_valid(player):
		target_pos = player.global_position

	var base_angle = 0.0
	var has_target = target_pos != Vector2.ZERO
	if has_target:
		base_angle = (target_pos - global_position).angle()

	var attempts = 0
	while attempts < 30:
		var angle = 0.0
		if has_target:
			angle = base_angle + rand_range(-PI/4, PI/4)
		else:
			angle = rand_range(0, 2 * PI)

		var spawn_distance = rand_range(150, 250) if is_stationary else rand_range(250, 400)
		var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * spawn_distance

		if _is_pos_safe(spawn_pos):
			return spawn_pos
		attempts += 1
	return Vector2.ZERO

func _is_pos_safe(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = 45.0

	var shape_query = Physics2DShapeQueryParameters.new()
	shape_query.set_shape(shape)
	shape_query.transform = Transform2D(0, pos)
	shape_query.exclude = [self]

	var results = space_state.intersect_shape(shape_query)
	for result in results:
		var collider = result.collider
		if collider is TileMap or collider is StaticBody2D or collider is KinematicBody2D:
			return false
	return true

func _process(delta):
	_time_since_last_check += delta
	if _time_since_last_check >= 0.1:
		_spawn_enemy()
		_time_since_last_check = 0
