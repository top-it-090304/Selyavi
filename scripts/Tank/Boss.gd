extends Enemy

var _spawn_timer: Timer
var _enemy_scene: PackedScene

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()

	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 7.0
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_spawn_minion)
	add_child(_spawn_timer)

func _spawn_minion():
	if not is_instance_valid(_player): return

	var minion = _enemy_scene.instantiate()
	# Спавним чуть в стороне от босса
	var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	minion.global_position = global_position + offset

	get_parent().add_child(minion)

	# Миньон сразу знает про отсутствие базы и преследует игрока
	if minion.has_method("_find_targets"):
		minion._find_targets()
