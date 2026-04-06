class_name Base
extends Area2D

enum TypeBase { PLAYER, ENEMY }

signal base_state(type: int)

@export var type_base: int = TypeBase.ENEMY
@export var _hp: int = 100 # Здоровье базы
@export var _max_hp: int = 100

var _spawn_timer: Timer
var _heal_timer: Timer
var _enemy_position: Marker2D
var _enemy_scene: PackedScene
var _base_body: StaticBody2D # Ссылка на физическое тело базы

@export var _max_enemies: int = 3
@export var _heal_amount: int = 5
@export var _heal_interval: float = 1.0
@export var _heal_radius: float = 300.0
@export var _spawn_interval: float = 6.0
var _time_since_last_check: float = 0.0
var _spawn_radius: float = 60.0

func _enter_tree():
	add_to_group("bases")

func _ready():
	# Синхронизация уровня для спавна врагов
	_sync_current_level()

	# Установка здоровья в зависимости от типа базы
	if type_base == TypeBase.ENEMY:
		_max_hp = 250
	else:
		_max_hp = 150
	_hp = _max_hp

	area_entered.connect(_on_bullet_entered)
	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	_enemy_position = get_node_or_null("EnemyPosition")

	_setup_base_appearance()

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 0.1
	_spawn_timer.one_shot = true
	add_child(_spawn_timer)
	_spawn_timer.start()

	_heal_timer = Timer.new()
	_heal_timer.wait_time = _heal_interval
	_heal_timer.one_shot = false
	add_child(_heal_timer)
	_heal_timer.timeout.connect(_on_heal_timeout)
	_heal_timer.start()

	_setup_base_collision()

func _sync_current_level():
	if SaveManager == null: return

	# Пытаемся вытащить номер уровня из имени текущей сцены (Level_1, Level_6 и т.д.)
	var scene_name = get_tree().current_scene.name
	if scene_name.contains("Level_"):
		var lvl = scene_name.get_slice("_", 1).to_int()
		if lvl > 0:
			SaveManager.current_level = lvl
	elif SaveManager.has_meta("current_level"):
		SaveManager.current_level = SaveManager.get_meta("current_level")

func _setup_base_collision():
	_base_body = StaticBody2D.new()
	_base_body.name = "BaseStaticBody"
	add_child(_base_body)
	var cs = CollisionShape2D.new()
	var circle = CircleShape2D.new()

	var area_shape = get_node_or_null("CollisionShape2D")
	if area_shape and area_shape.shape is CircleShape2D:
		circle.radius = area_shape.shape.radius
	else:
		circle.radius = 60.0

	cs.shape = circle
	_base_body.add_child(cs)

func _on_bullet_entered(area):
	if area.has_method("is_player"):
		var is_player_bullet = area.is_player()
		if (is_player_bullet and type_base == TypeBase.ENEMY) or (not is_player_bullet and type_base == TypeBase.PLAYER):
			var damage = area.get("_damage") if "_damage" in area else 25
			take_damage(damage)
			if area.has_method("_destroy"):
				area._destroy()
			else:
				area.queue_free()

func _on_heal_timeout():
	if type_base != TypeBase.PLAYER:
		return

	var player = get_node_or_null("/root/Field/PlayerTank")
	if player == null or not is_instance_valid(player):
		return

	var distance = global_position.distance_to(player.global_position)
	if distance <= _heal_radius:
		if player.has_method("take_heal"):
			player.take_heal(_heal_amount)

func _setup_base_appearance():
	var sprite = get_node_or_null("Sprite2D")
	if sprite != null:
		if type_base == TypeBase.ENEMY:
			sprite.modulate = Color(1.0, 0.4, 0.4)
		else:
			sprite.modulate = Color(0.5, 1.0, 0.8)

func take_damage(amount: int):
	_hp -= amount
	_update_damage_visuals()
	if _hp <= 0:
		_destroy()

func _update_damage_visuals():
	var sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = self

	var target_color = Color(1.0, 0.4, 0.4) if type_base == TypeBase.ENEMY else Color(0.5, 1.0, 0.8)

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(5, 5, 5), 0.05)
	tween.tween_property(sprite, "modulate", target_color, 0.05)

func destroy():
	_destroy()

func _destroy():
	base_state.emit(type_base)
	queue_free()

func _count_enemies_on_scene() -> int:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
		if enemy.has_method("get_enemy_type"):
			if enemy.get_enemy_type() == 3:
				continue
		count += 1
	return count

func _spawn_enemy():
	if type_base == TypeBase.PLAYER:
		return

	var current_enemies = _count_enemies_on_scene()
	if current_enemies >= _max_enemies:
		return
	
	var spawn_pos = _get_safe_spawn_pos()
	if spawn_pos != Vector2.ZERO:
		var enemy = _enemy_scene.instantiate()
		enemy.global_position = spawn_pos
		get_parent().add_child(enemy)

func _get_safe_spawn_pos() -> Vector2:
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
			angle = base_angle + randf_range(-PI/4, PI/4)
		else:
			angle = randf_range(0, 2 * PI)

		var spawn_distance = randf_range(250, 400)
		var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * spawn_distance

		if _is_pos_safe(spawn_pos):
			return spawn_pos
		attempts += 1
	return Vector2.ZERO

func _is_pos_safe(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = 45.0

	var shape_query = PhysicsShapeQueryParameters2D.new()
	shape_query.set_shape(shape)
	shape_query.transform = Transform2D(0, pos)

	var exclude_list = [self]
	if is_instance_valid(_base_body):
		exclude_list.append(_base_body)
	shape_query.exclude = exclude_list

	var results = space_state.intersect_shape(shape_query)
	for result in results:
		var collider = result.collider
		if collider is TileMap or collider is StaticBody2D or collider is CharacterBody2D:
			return false
	return true

func _process(delta):
	_time_since_last_check += delta
	if _time_since_last_check >= _spawn_interval:
		_spawn_enemy()
		_time_since_last_check = 0
