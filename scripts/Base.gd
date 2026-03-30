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
var _spawn_radius: float = 50.0

func _ready():
	connect("area_entered", self, "_on_body_entered")
	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	_enemy_position = get_node("EnemyPosition")
	
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

func _on_body_entered(body):
	# Вместо class_name используем проверку через get_script()
	if body.get_script() != null and body.get_script().resource_path.find("Bullet.gd") != -1:
		if (body.is_player() and type_base == TypeBase.ENEMY) or (not body.is_player() and type_base == TypeBase.PLAYER):
			_destroy()

func _on_heal_timeout():
	if type_base != TypeBase.PLAYER:
		return
	
	var player = get_node_or_null("/root/Field/PlayerTank")
	if player == null:
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
	
	var enemy = _enemy_scene.instance()
	enemy.global_position = _enemy_position.global_position
	get_tree().root.add_child(enemy)
	_spawn_timer.start()

func _process(delta):
	_time_since_last_check += delta
	if _time_since_last_check >= 0.5:
		_spawn_enemy()
		_time_since_last_check = 0
