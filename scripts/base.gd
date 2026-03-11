extends Area2D
class_name Base

enum TypeBase {
	PLAYER,
	ENEMY
}

signal base_state

@export var type_base: TypeBase
@export var max_enemies: int = 4

var _spawn_timer: Timer
var _enemy_position: Position2D
var enemy_scene: PackedScene
var _time_since_last_check: float = 0
var _spawn_radius: float = 50

func _ready():
	area_entered.connect(_on_body_entered)
	enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	_enemy_position = $EnemyPosition
	
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 3.0
	_spawn_timer.one_shot = true
	add_child(_spawn_timer)
	
	_spawn_timer.start(1.0)

func _on_body_entered(body: Node):
	if body is Bullet:
		var bullet = body as Bullet
		if (bullet.is_player and type_base == TypeBase.ENEMY) or (!bullet.is_player and type_base == TypeBase.PLAYER):
			destroy()

func destroy():
	base_state.emit()
	queue_free()

func count_enemies_on_scene() -> int:
	var enemies = get_tree().get_nodes_in_group("enemies")
	return enemies.size()

func is_enemy_on_base() -> bool:
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < _spawn_radius:
			return true
	return false

func spawn_enemy():
	if _spawn_timer.time_left > 0:
		return
	
	if type_base == TypeBase.PLAYER:
		return
	
	if is_enemy_on_base():
		return
	
	var current_enemies = count_enemies_on_scene()
	
	if current_enemies >= max_enemies:
		_spawn_timer.start()
		return
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = _enemy_position.global_position
	get_tree().root.add_child(enemy)
	_spawn_timer.start()

func _process(delta):
	_time_since_last_check += delta
	if _time_since_last_check >= 0.5:
		spawn_enemy()
		_time_since_last_check = 0
